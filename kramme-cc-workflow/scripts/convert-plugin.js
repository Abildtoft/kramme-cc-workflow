#!/usr/bin/env node
"use strict";

const fs = require("fs/promises");
const os = require("os");
const path = require("path");

const ERROR_CAUSE_DEPTH_LIMIT = 5;
const MARKETPLACE_DIR_NAME = ".kramme-plugin-marketplaces";
const COMMON_OPTIONS = ["to"];
const HOME_OPTIONS = ["codex-home", "codexHome", "agents-home", "agentsHome"];
const CONFIRM_OPTIONS = ["yes", "y", "non-interactive", "nonInteractive"];
const COMMAND_OPTIONS = {
  build: ["out"],
  install: [...HOME_OPTIONS, ...CONFIRM_OPTIONS, "marketplace-dir"],
  stats: ["json"],
  uninstall: [...HOME_OPTIONS, ...CONFIRM_OPTIONS, "marketplace-dir"],
};

/** @typedef {Record<string, string | boolean | string[]> & { _: string[] }} ParsedArgs */
/** @typedef {import("./convert-plugin/contracts").CodexBundle} CodexBundle */

async function main() {
  const argv = process.argv.slice(2);
  if (argv.length === 0 || isHelp(argv[0])) {
    printHelp(0);
    return;
  }

  const command = argv[0];
  const handlers = {
    build: runBuild,
    install: runInstall,
    stats: runStats,
    uninstall: runUninstall,
  };
  const handler = handlers[/** @type {keyof typeof handlers} */ (command)];
  if (!handler) {
    console.error(`Unknown command: ${command}`);
    printHelp(1);
    return;
  }
  const parsed = parseArgs(argv.slice(1));
  validateOptions(
    command,
    parsed,
    COMMAND_OPTIONS[/** @type {keyof typeof COMMAND_OPTIONS} */ (command)],
  );
  await handler(parsed);
}

/** @param {ParsedArgs} parsed */
async function runBuild(parsed) {
  const outputRoot = readPathOption(parsed, "out");
  if (!outputRoot) {
    throw new Error("build requires --out <dir>.");
  }
  const { bundle } = await loadCodexBundle(parsed);
  const {
    buildCodexMarketplace,
  } = require("./convert-plugin/codex-plugin-builder");
  const built = await buildCodexMarketplace(
    path.resolve(expandHome(outputRoot)),
    bundle,
  );
  console.log(
    `Built ${bundle.codexPlugin.name} ${bundle.codexPlugin.version} (${built.skillCount} skills) to ${built.marketplaceRoot}`,
  );
}

/** @param {ParsedArgs} parsed */
async function runInstall(parsed) {
  const { agentsHome, codexHome } = resolveHomeRoots(parsed);
  const confirmOptions = readConfirmOptions(parsed);
  const { bundle, pluginName } = await loadCodexBundle(parsed);
  const marketplaceRoot = resolveMarketplaceRoot(parsed, codexHome, bundle);
  const {
    cleanupLegacyInstall,
  } = require("./convert-plugin/legacy-install-cleanup");
  const {
    buildCodexMarketplace,
  } = require("./convert-plugin/codex-plugin-builder");
  const { registerCodexPlugin } = require("./convert-plugin/codex-cli");

  await replaceMarketplace(marketplaceRoot, bundle, buildCodexMarketplace);
  const installed = await registerCodexPlugin({
    codexHome,
    codexPlugin: bundle.codexPlugin,
    marketplaceRoot,
  });
  await cleanupLegacyInstall({
    agentsHome,
    codexHome,
    confirmOptions,
    pluginName,
    preservePaths: [marketplaceRoot, installed.installedPath],
  });
  console.log(
    `Installed ${bundle.codexPlugin.name} ${bundle.codexPlugin.version} to ${installed.installedPath}`,
  );
}

/** @param {ParsedArgs} parsed */
async function runUninstall(parsed) {
  const { agentsHome, codexHome } = resolveHomeRoots(parsed);
  const confirmOptions = readConfirmOptions(parsed);
  const { bundle, pluginName } = await loadCodexBundle(parsed);
  const marketplaceRoot = resolveMarketplaceRoot(parsed, codexHome, bundle);
  const { unregisterCodexPlugin } = require("./convert-plugin/codex-cli");
  const {
    cleanupLegacyInstall,
  } = require("./convert-plugin/legacy-install-cleanup");

  await assertReplaceableMarketplaceRoot(marketplaceRoot, bundle);
  await unregisterCodexPlugin({
    codexHome,
    codexPlugin: bundle.codexPlugin,
    marketplaceRoot,
  });
  await fs.rm(marketplaceRoot, { force: true, recursive: true });
  await fs.rmdir(path.dirname(marketplaceRoot)).catch(() => {});
  await cleanupLegacyInstall({
    agentsHome,
    codexHome,
    confirmOptions,
    pluginName,
  });
  console.log(`Uninstalled ${bundle.codexPlugin.name} from ${codexHome}`);
}

/** @param {ParsedArgs} parsed */
async function runStats(parsed) {
  const outputAsJson = readBooleanOption(parsed, "json");
  const { bundle } = await loadCodexBundle(parsed);
  const stats = {
    codex_skills: bundle.skillDirs.length + bundle.generatedSkills.length,
    agent_skills: bundle.agentSkills.length,
  };

  if (outputAsJson) {
    console.log(JSON.stringify(stats));
    return;
  }

  for (const [key, value] of Object.entries(stats)) {
    console.log(`${key}=${value}`);
  }
}

/**
 * @param {ParsedArgs} parsed
 * @returns {Promise<{ bundle: CodexBundle, pluginName: string }>}
 */
async function loadCodexBundle(parsed) {
  resolveTargetName(parsed);
  const pluginInput = parsed._[0] ?? process.cwd();
  const {
    convertClaudeToCodex,
  } = require("./convert-plugin/codex-transformer");
  const {
    loadClaudePlugin,
    resolvePluginInput,
  } = require("./convert-plugin/loader");
  const plugin = await loadClaudePlugin(await resolvePluginInput(pluginInput));
  return {
    bundle: convertClaudeToCodex(plugin),
    pluginName: String(plugin.manifest.name ?? "plugin"),
  };
}

/**
 * Build into a sibling temporary directory and swap it into place so a failed
 * build never leaves a half-written marketplace behind.
 *
 * @param {string} marketplaceRoot
 * @param {CodexBundle} bundle
 * @param {typeof import("./convert-plugin/codex-plugin-builder").buildCodexMarketplace} buildCodexMarketplace
 */
async function replaceMarketplace(
  marketplaceRoot,
  bundle,
  buildCodexMarketplace,
) {
  await assertReplaceableMarketplaceRoot(marketplaceRoot, bundle);
  await fs.mkdir(path.dirname(marketplaceRoot), { recursive: true });
  const stagingRoot = `${marketplaceRoot}.build-${process.pid}`;
  await fs.rm(stagingRoot, { force: true, recursive: true });
  try {
    await buildCodexMarketplace(stagingRoot, bundle);
    await fs.rm(marketplaceRoot, { force: true, recursive: true });
    await fs.rename(stagingRoot, marketplaceRoot);
  } finally {
    await fs.rm(stagingRoot, { force: true, recursive: true });
  }
}

/**
 * Only replace a directory this converter generated for the same marketplace,
 * or one that is empty or absent.
 *
 * @param {string} marketplaceRoot @param {CodexBundle} bundle
 */
async function assertReplaceableMarketplaceRoot(marketplaceRoot, bundle) {
  let entries;
  try {
    entries = await fs.readdir(marketplaceRoot);
  } catch (error) {
    if (/** @type {NodeJS.ErrnoException} */ (error).code === "ENOENT") return;
    throw error;
  }
  if (entries.length === 0) return;
  const {
    MARKETPLACE_MANIFEST,
    OWNERSHIP_MARKER,
  } = require("./convert-plugin/codex-plugin-builder");
  let manifest;
  let ownership;
  try {
    manifest = JSON.parse(
      await fs.readFile(
        path.join(marketplaceRoot, MARKETPLACE_MANIFEST),
        "utf8",
      ),
    );
    ownership = JSON.parse(
      await fs.readFile(path.join(marketplaceRoot, OWNERSHIP_MARKER), "utf8"),
    );
  } catch {
    manifest = null;
    ownership = null;
  }
  const owned =
    ownership?.generatedBy === "kramme-cc-workflow" &&
    ownership?.markerVersion === 1 &&
    ownership?.marketplaceName === bundle.codexPlugin.marketplaceName &&
    ownership?.pluginName === bundle.codexPlugin.name &&
    typeof ownership?.pluginVersion === "string";
  if (!owned || manifest?.name !== bundle.codexPlugin.marketplaceName) {
    throw new Error(
      `Refusing to replace ${marketplaceRoot}: ownership could not be verified for ${bundle.codexPlugin.marketplaceName}.`,
    );
  }
}

/** @param {ParsedArgs} parsed @param {string} codexHome @param {CodexBundle} bundle */
function resolveMarketplaceRoot(parsed, codexHome, bundle) {
  const explicit = readPathOption(parsed, "marketplace-dir");
  if (explicit) return path.resolve(expandHome(explicit));
  return path.join(
    codexHome,
    MARKETPLACE_DIR_NAME,
    bundle.codexPlugin.marketplaceName,
  );
}

/** @param {ParsedArgs} parsed */
function resolveTargetName(parsed) {
  const targetName = String(parsed.to ?? "codex");
  if (targetName !== "codex") {
    throw new Error(`Unknown target: ${targetName}`);
  }
  return targetName;
}

/** @param {string} command @param {ParsedArgs} parsed @param {string[]} allowed */
function validateOptions(command, parsed, allowed) {
  const allowedKeys = new Set(["_", ...COMMON_OPTIONS, ...allowed]);
  const unsupported = Object.keys(parsed).find((key) => !allowedKeys.has(key));
  if (unsupported) {
    throw new Error(`${command} does not support --${unsupported}.`);
  }
  if (parsed._.length > 1) {
    throw new Error(`${command} accepts at most one plugin name or path.`);
  }
  // Read path values eagerly so malformed options fail before plugin loading.
  readPathOption(parsed, "out");
  readPathOption(parsed, "marketplace-dir");
  if (command === "install" || command === "uninstall") {
    resolveHomeRoots(parsed);
    readConfirmOptions(parsed);
  }
  readBooleanOption(parsed, "json");
}

/**
 * @param {ParsedArgs} parsed
 * @param {string} kebabKey
 * @param {string[]} [aliasKeys]
 */
function readOptionValue(parsed, kebabKey, aliasKeys = []) {
  for (const key of [kebabKey, ...aliasKeys]) {
    if (Object.hasOwn(parsed, key)) return parsed[key];
  }
  return undefined;
}

/**
 * @param {ParsedArgs} parsed
 * @param {string} kebabKey
 * @param {string[]} [aliasKeys]
 */
function readPathOption(parsed, kebabKey, aliasKeys = []) {
  const value = readOptionValue(parsed, kebabKey, aliasKeys);
  if (value === undefined) return undefined;
  if (typeof value !== "string" || !value.trim()) {
    throw new Error(`--${kebabKey} requires a directory.`);
  }
  return value.trim();
}

/**
 * @param {ParsedArgs} parsed
 * @param {string} kebabKey
 * @param {string[]} [aliasKeys]
 */
function readBooleanOption(parsed, kebabKey, aliasKeys = []) {
  const value = readOptionValue(parsed, kebabKey, aliasKeys);
  if (value === undefined) return false;
  if (typeof value === "boolean") return value;
  const normalized =
    typeof value === "string" ? value.trim().toLowerCase() : "";
  if (["true", "1", "yes"].includes(normalized)) return true;
  if (["false", "0", "no"].includes(normalized)) return false;
  throw new Error(
    `--${kebabKey} requires a boolean value when one is provided.`,
  );
}

/** @param {ParsedArgs} parsed */
function readConfirmOptions(parsed) {
  return {
    yes: readBooleanOption(parsed, "yes", ["y"]),
    nonInteractive: readBooleanOption(parsed, "non-interactive", [
      "nonInteractive",
    ]),
  };
}

/** @param {ParsedArgs} parsed */
function resolveHomeRoots(parsed) {
  const { defaultCodexHome } = require("./convert-plugin/codex-cli");
  const codexHome = readPathOption(parsed, "codex-home", ["codexHome"]);
  const agentsHome = readPathOption(parsed, "agents-home", ["agentsHome"]);
  return {
    codexHome: codexHome
      ? path.resolve(expandHome(codexHome))
      : defaultCodexHome(),
    agentsHome: agentsHome
      ? path.resolve(expandHome(agentsHome))
      : path.join(os.homedir(), ".agents"),
  };
}

/** @param {number} exitCode */
function printHelp(exitCode) {
  const help = `Usage:
  scripts/convert-plugin.js build <plugin-name|path> --out <dir>
  scripts/convert-plugin.js install <plugin-name|path> [options]
  scripts/convert-plugin.js uninstall <plugin-name|path> [options]
  scripts/convert-plugin.js stats <plugin-name|path> [--json]

build writes a Codex plugin marketplace to --out (which must be empty or
absent). Register it with \`codex plugin marketplace add <dir>\` and install
with \`codex plugin add <plugin>@<plugin>\`.

install builds the marketplace under the Codex home and runs those two Codex
CLI commands. uninstall removes the plugin and marketplace registration, the
generated marketplace, and any legacy converter output.

Options:
  --out <dir>             (build) Marketplace output directory
  --codex-home <dir>      Codex home (default: $CODEX_HOME or ~/.codex)
  --agents-home <dir>     Agents home holding legacy agent skills (default: ~/.agents)
  --marketplace-dir <dir> Generated marketplace location
                          (default: <codex-home>/${MARKETPLACE_DIR_NAME}/<plugin>)
  --yes, -y               Assume "yes" when asked to remove legacy converter output
  --non-interactive       Never prompt; keep legacy output unless --yes is given
  --json                  (stats) print JSON instead of key=value lines
  --to codex              Accepted for compatibility; codex is the only target

Long boolean options (--yes, --non-interactive, --json) also accept an explicit
=true or =false value (or 1/0, yes/no); any other value is rejected.

Stats fields:
  codex_skills            Number of Codex skills (skill directories plus generated command skills)
  agent_skills            Number of generated Codex agent skills
`;
  console.log(help);
  if (exitCode) process.exit(exitCode);
}

/** @param {string | undefined} value */
function isHelp(value) {
  return value === "-h" || value === "--help";
}

/** @param {string[]} argv @returns {ParsedArgs} */
function parseArgs(argv) {
  /** @type {ParsedArgs} */
  const result = { _: [] };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg.startsWith("--")) {
      const body = arg.slice(2);
      const separator = body.indexOf("=");
      if (separator !== -1) {
        result[body.slice(0, separator)] = body.slice(separator + 1);
        continue;
      }
      const next = argv[i + 1];
      if (next && !next.startsWith("-")) {
        result[body] = next;
        i += 1;
      } else {
        result[body] = true;
      }
      continue;
    }
    if (arg.startsWith("-")) {
      result[arg.slice(1)] = true;
      continue;
    }
    result._.push(arg);
  }
  return result;
}

/** @param {string} value */
function expandHome(value) {
  if (value === "~") return os.homedir();
  if (value.startsWith(`~${path.sep}`)) {
    return path.join(os.homedir(), value.slice(2));
  }
  return value;
}

/** @param {unknown} error */
function formatError(error) {
  if (!(error instanceof Error)) return error;

  /** @type {string[]} */
  const messages = [];
  /** @type {unknown} */
  let current = error;

  for (let depth = 0; depth < ERROR_CAUSE_DEPTH_LIMIT; depth += 1) {
    if (!(current instanceof Error)) break;

    const normalized = current.message.split(/\r?\n/, 1)[0].trim();
    const alreadyRendered = messages.some(
      (message) =>
        message === normalized ||
        message.endsWith(`: ${normalized}`) ||
        message.startsWith(`${normalized} `),
    );
    if (normalized && !alreadyRendered) {
      messages.push(normalized);
    }

    if (current.cause === undefined) break;
    current = current.cause;
  }

  return messages.join(": ");
}

main().catch((error) => {
  console.error(formatError(error));
  process.exit(1);
});
