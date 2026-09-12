// @ts-check
"use strict";

const { spawn } = require("child_process");
const fs = require("fs/promises");
const os = require("os");
const path = require("path");

/**
 * @typedef {import("./contracts").CodexPluginPackage} CodexPluginPackage
 * @typedef {{ status: number | null, stdout: string, stderr: string }} CodexCommandResult
 * @typedef {{ installedPath: string, version: string }} CodexInstallResult
 */

const CODEX_BIN = "codex";

/** Codex's own default home, honouring the `CODEX_HOME` override it reads. */
function defaultCodexHome() {
  const override = process.env.CODEX_HOME?.trim();
  return override ? path.resolve(override) : path.join(os.homedir(), ".codex");
}

/**
 * @param {string[]} args
 * @param {{ codexHome: string }} options
 * @returns {Promise<CodexCommandResult>}
 */
function runCodex(args, { codexHome }) {
  return new Promise((resolve, reject) => {
    const child = spawn(CODEX_BIN, args, {
      env: { ...process.env, CODEX_HOME: codexHome },
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", (chunk) => {
      stdout += chunk;
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk;
    });
    child.on("error", (error) => {
      if (/** @type {NodeJS.ErrnoException} */ (error).code === "ENOENT") {
        reject(
          new Error(
            `The ${CODEX_BIN} CLI was not found on PATH. Install it with \`npm install -g @openai/codex\`, or register the built marketplace yourself with \`codex plugin marketplace add <dir>\`.`,
            { cause: error },
          ),
        );
        return;
      }
      reject(error);
    });
    child.on("close", (status) => resolve({ status, stdout, stderr }));
  });
}

/** @param {string} command @param {CodexCommandResult} result */
function codexCommandError(command, result) {
  const detail = (result.stderr || result.stdout).trim().split(/\r?\n/).at(-1);
  return new Error(
    `codex ${command} failed (exit ${result.status ?? "signal"})${detail ? `: ${detail}` : ""}`,
  );
}

/** @param {CodexCommandResult} result */
function isMissingRegistration(result) {
  return /not (configured|installed|found)|no plugin/i.test(
    `${result.stderr}\n${result.stdout}`,
  );
}

/** @param {string} codexHome @returns {Promise<Array<{name: string, root: string}>>} */
async function listCodexMarketplaces(codexHome) {
  const result = await runCodex(
    ["plugin", "marketplace", "list", "--json"],
    { codexHome },
  );
  if (result.status !== 0) {
    throw codexCommandError("plugin marketplace list", result);
  }
  let parsed;
  try {
    parsed = JSON.parse(result.stdout);
  } catch (error) {
    throw new Error("codex plugin marketplace list returned invalid JSON.", {
      cause: error,
    });
  }
  if (!parsed || !Array.isArray(parsed.marketplaces)) {
    throw new Error("codex plugin marketplace list returned no marketplaces.");
  }
  /** @type {Array<{name?: unknown, root?: unknown}>} */
  const marketplaces = parsed.marketplaces;
  return marketplaces
    .filter(
      /** @returns {marketplace is {name: string, root: string}} */
      (marketplace) =>
        marketplace &&
        typeof marketplace.name === "string" &&
        typeof marketplace.root === "string",
    )
    .map((marketplace) => ({
      name: marketplace.name,
      root: marketplace.root,
    }));
}

/**
 * Register the built marketplace with Codex and install the plugin from it.
 *
 * Codex refuses to re-add a marketplace name from a different source. A
 * replacement is never forced through an existing registration. Codex copies
 * the plugin into its own cache; the converted skills reference that cache directory, so the reported
 * install path must match the one baked into the build.
 *
 * @param {{ codexHome: string, marketplaceRoot: string, codexPlugin: CodexPluginPackage }} options
 * @returns {Promise<CodexInstallResult>}
 */
async function registerCodexPlugin({
  codexHome,
  marketplaceRoot,
  codexPlugin,
}) {
  const { marketplaceName, name, cacheRelativePath } = codexPlugin;
  const addArgs = ["plugin", "marketplace", "add", marketplaceRoot];
  const added = await runCodex(addArgs, { codexHome });
  if (
    added.status !== 0 &&
    /already added from a different source/.test(added.stderr + added.stdout)
  ) {
    const existing = (await listCodexMarketplaces(codexHome)).find(
      (marketplace) => marketplace.name === marketplaceName,
    );
    const source = existing?.root ?? "an unknown source";
    throw new Error(
      `Refusing to replace marketplace ${marketplaceName} from ${source}; expected ${marketplaceRoot}. Remove the existing registration explicitly before retrying.`,
    );
  }
  if (added.status !== 0) {
    throw codexCommandError("plugin marketplace add", added);
  }

  const installed = await runCodex(
    ["plugin", "add", `${name}@${marketplaceName}`, "--json"],
    { codexHome },
  );
  if (installed.status !== 0) {
    throw codexCommandError("plugin add", installed);
  }
  const result = parseInstallResult(installed.stdout);
  const expectedPath = path.join(codexHome, cacheRelativePath);
  if (!(await samePath(result.installedPath, expectedPath))) {
    throw new Error(
      `Codex installed ${name} to ${result.installedPath}, but the converted skills reference ${expectedPath}. This converter targets the Codex plugin cache layout plugins/cache/<marketplace>/<plugin>/<version>; report this mismatch with your Codex version.`,
    );
  }
  return result;
}

/**
 * Remove the plugin and marketplace registration. Missing registrations do
 * not fail the removal.
 *
 * @param {{ codexHome: string, codexPlugin: CodexPluginPackage, marketplaceRoot: string }} options
 */
async function unregisterCodexPlugin({
  codexHome,
  codexPlugin,
  marketplaceRoot,
}) {
  const existing = (await listCodexMarketplaces(codexHome)).find(
    (marketplace) => marketplace.name === codexPlugin.marketplaceName,
  );
  if (!existing) return;
  if (!(await samePath(existing.root, marketplaceRoot))) {
    throw new Error(
      `Refusing to remove marketplace ${codexPlugin.marketplaceName} from ${existing.root}; expected ${marketplaceRoot}.`,
    );
  }
  const removed = await runCodex(
    ["plugin", "remove", `${codexPlugin.name}@${codexPlugin.marketplaceName}`],
    { codexHome },
  );
  if (removed.status !== 0 && !isMissingRegistration(removed)) {
    throw codexCommandError("plugin remove", removed);
  }
  const marketplaceRemoved = await runCodex(
    ["plugin", "marketplace", "remove", codexPlugin.marketplaceName],
    { codexHome },
  );
  if (marketplaceRemoved.status !== 0 && !isMissingRegistration(marketplaceRemoved)) {
    throw codexCommandError("plugin marketplace remove", marketplaceRemoved);
  }
}

/** @param {string} stdout @returns {CodexInstallResult} */
function parseInstallResult(stdout) {
  const start = stdout.indexOf("{");
  let parsed;
  try {
    parsed = JSON.parse(start >= 0 ? stdout.slice(start) : stdout);
  } catch (error) {
    throw new Error("codex plugin add returned no JSON install result.", {
      cause: error,
    });
  }
  if (
    !parsed ||
    typeof parsed !== "object" ||
    typeof parsed.installedPath !== "string" ||
    !parsed.installedPath
  ) {
    throw new Error(
      "codex plugin add returned an install result without installedPath.",
    );
  }
  return {
    installedPath: parsed.installedPath,
    version: typeof parsed.version === "string" ? parsed.version : "",
  };
}

/** @param {string} left @param {string} right */
async function samePath(left, right) {
  try {
    return (await fs.realpath(left)) === (await fs.realpath(right));
  } catch {
    return path.resolve(left) === path.resolve(right);
  }
}

module.exports = {
  defaultCodexHome,
  listCodexMarketplaces,
  registerCodexPlugin,
  runCodex,
  unregisterCodexPlugin,
};
