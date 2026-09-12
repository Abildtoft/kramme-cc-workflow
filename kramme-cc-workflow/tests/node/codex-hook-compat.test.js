"use strict";

const assert = require("node:assert/strict");
const { spawn } = require("node:child_process");
const path = require("path");
const test = require("node:test");

const {
  buildCodexMarketplace,
} = require("../../scripts/convert-plugin/codex-plugin-builder");
const {
  convertClaudeToCodex,
} = require("../../scripts/convert-plugin/codex-transformer");

const {
  emptyCodexBundle,
  fixtureCodexPluginPackage,
  pathExists,
  readText,
  withTempDir,
  writeFile,
} = require("./converter-test-helpers");

const REPO_ROOT = path.join(__dirname, "..", "..");

/**
 * @typedef {import("../../scripts/convert-plugin/contracts").ClaudeSkill} ClaudeSkill
 * @typedef {import("../../scripts/convert-plugin/contracts").CodexBundle} CodexBundle
 * @typedef {import("../../scripts/convert-plugin/contracts").JsonObject} JsonObject
 * @typedef {JsonObject & { command: string }} CommandHook
 * @typedef {{ code: number | null, signal: NodeJS.Signals | null, stdout: string, stderr: string }} ProcessResult
 */

test("source hook commands resolve to bundled POSIX shell scripts", async () => {
  const hookConfig = await readJson(
    path.join(REPO_ROOT, "hooks", "hooks.json"),
  );
  const hookDocs = await readText(path.join(REPO_ROOT, "docs", "hooks.md"));
  const commandHooks = collectCommandHooks(hookConfig);

  assert.ok(commandHooks.length > 0, "expected command hooks in hooks.json");
  assert.match(hookDocs, /POSIX shell command strings/);
  assert.match(hookDocs, /Windows compatibility is not promised/);

  for (const hook of commandHooks) {
    assert.equal(
      Object.hasOwn(hook, "commandWindows"),
      false,
      "commandWindows should only be introduced with documented support",
    );

    const referencedHookFiles = Array.from(
      hook.command.matchAll(/\$\{CLAUDE_PLUGIN_ROOT\}\/hooks\/([^\s"';&|]+)/g),
      (match) => match[1],
    );
    assert.ok(
      referencedHookFiles.length > 0,
      `expected hook command to reference a bundled hook file: ${hook.command}`,
    );

    for (const relativePath of referencedHookFiles) {
      assert.equal(
        await pathExists(path.join(REPO_ROOT, "hooks", relativePath)),
        true,
        `missing hook command target: hooks/${relativePath}`,
      );
    }
  }
});

test("generated hook scripts execute from the built plugin without a plugin root variable", async () => {
  await withTempDir(async (root) => {
    const hookSourceDir = path.join(root, "source-plugin", "hooks");
    const bundle = fixtureHookBundle({
      hookSourceDir,
      hooks: {
        PreToolUse: [
          {
            matcher: "Bash",
            hooks: [
              {
                type: "command",
                command: "bash ${CLAUDE_PLUGIN_ROOT}/hooks/cache-probe.sh",
              },
            ],
          },
        ],
      },
    });

    await writeFile(
      path.join(hookSourceDir, "lib", "check-enabled.sh"),
      minimalCheckEnabledScript(),
    );
    await writeFile(path.join(hookSourceDir, "root-marker.txt"), "cache-ok\n");
    await writeFile(
      path.join(hookSourceDir, "cache-probe.sh"),
      [
        "#!/bin/bash",
        "set -uo pipefail",
        'source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/check-enabled.sh"',
        'is_hook_enabled "cache-probe"',
        'printf "root=%s\\n" "$CLAUDE_PLUGIN_ROOT"',
        'cat "${CLAUDE_PLUGIN_ROOT}/hooks/root-marker.txt"',
        "",
      ].join("\n"),
    );

    const built = await buildCodexMarketplace(
      path.join(root, "marketplace"),
      bundle,
    );
    const result = await runHookScript(
      path.join(built.pluginRoot, "hooks", "cache-probe.sh"),
      { env: isolatedHookEnv(root) },
    );

    assert.equal(result.code, 0, result.stderr);
    assert.equal(result.stdout, `root=${built.pluginRoot}\ncache-ok\n`);
    assert.equal(
      await pathExists(path.join(built.pluginRoot, "hooks", "hooks.json")),
      true,
    );
  });
});

test("local hook state and config files never ship in the built plugin", async () => {
  await withTempDir(async (root) => {
    const hookSourceDir = path.join(root, "source-plugin", "hooks");
    const bundle = fixtureHookBundle({
      hookSourceDir,
      hooks: { PreToolUse: [] },
    });

    await writeFile(path.join(hookSourceDir, "alpha-hook.sh"), "echo ok\n");
    await writeFile(path.join(hookSourceDir, "hook-state.json"), "{}\n");
    await writeFile(
      path.join(hookSourceDir, "context-links.config"),
      'CONTEXT_LINKS_LINEAR_WORKSPACE_SLUG="local"\n',
    );
    await writeFile(
      path.join(hookSourceDir, "context-links.config.example"),
      'CONTEXT_LINKS_LINEAR_WORKSPACE_SLUG="example"\n',
    );

    const built = await buildCodexMarketplace(
      path.join(root, "marketplace"),
      bundle,
    );
    const hooksRoot = path.join(built.pluginRoot, "hooks");
    assert.equal(await pathExists(path.join(hooksRoot, "alpha-hook.sh")), true);
    assert.equal(
      await pathExists(path.join(hooksRoot, "context-links.config.example")),
      true,
    );
    assert.equal(
      await pathExists(path.join(hooksRoot, "hook-state.json")),
      false,
    );
    assert.equal(
      await pathExists(path.join(hooksRoot, "context-links.config")),
      false,
    );
  });
});

test("fixture SubagentStart hook events are preserved in generated hook config", async () => {
  await withTempDir(async (root) => {
    const sourceHookConfig = {
      SubagentStart: [
        {
          matcher: "Task",
          hooks: [
            {
              type: "command",
              command: "bash ${CLAUDE_PLUGIN_ROOT}/hooks/subagent-start.sh",
            },
          ],
        },
      ],
    };
    const sourceRoot = path.join(root, "source-plugin");
    const controlSkills = [
      hookControlSkill(sourceRoot, "kramme:hooks:toggle"),
      hookControlSkill(sourceRoot, "kramme:hooks:configure-links"),
    ];
    for (const skill of controlSkills) {
      await writeFile(path.join(skill.sourceDir, "SKILL.md"), "control\n");
    }
    const plugin = {
      agents: [],
      commands: [],
      hooks: sourceHookConfig,
      manifest: {
        description: "Demo plugin.",
        name: "demo-hooks",
        version: "1.0.0",
      },
      root: sourceRoot,
      skills: controlSkills,
    };
    const bundle = convertClaudeToCodex(plugin);
    assert.deepEqual(bundle.codexPlugin.hooks, sourceHookConfig);

    await writeFile(
      path.join(root, "source-plugin", "hooks", "subagent-start.sh"),
      "echo subagent\n",
    );
    const built = await buildCodexMarketplace(
      path.join(root, "marketplace"),
      bundle,
    );
    const generatedHookConfig = await readJson(
      path.join(built.pluginRoot, "hooks", "hooks.json"),
    );
    assert.deepEqual(
      generatedHookConfig.SubagentStart,
      sourceHookConfig.SubagentStart,
    );

    const withoutControls = convertClaudeToCodex({ ...plugin, skills: [] });
    const unhooked = await buildCodexMarketplace(
      path.join(root, "marketplace-without-hooks"),
      withoutControls,
    );
    assert.equal(
      await pathExists(path.join(unhooked.pluginRoot, "hooks")),
      false,
      "hook packaging requires the hook control skills",
    );
  });
});

test("generated bootstrap does not wait for open stdin when the hook does not read it", async () => {
  await withTempDir(async (root) => {
    const hookSourceDir = path.join(root, "source-plugin", "hooks");
    const bundle = fixtureHookBundle({
      hookSourceDir,
      hooks: {
        PreToolUse: [
          {
            matcher: "Bash",
            hooks: [
              {
                type: "command",
                command: "bash ${CLAUDE_PLUGIN_ROOT}/hooks/open-stdin-probe.sh",
              },
            ],
          },
        ],
      },
    });

    await writeFile(
      path.join(hookSourceDir, "lib", "check-enabled.sh"),
      minimalCheckEnabledScript(),
    );
    await writeFile(
      path.join(hookSourceDir, "open-stdin-probe.sh"),
      [
        "#!/bin/bash",
        "set -uo pipefail",
        'source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/check-enabled.sh"',
        'is_hook_enabled "open-stdin-probe"',
        'printf "{}\\n"',
        "",
      ].join("\n"),
    );

    const built = await buildCodexMarketplace(
      path.join(root, "marketplace"),
      bundle,
    );
    const result = await runHookScriptWithOpenStdin(
      path.join(built.pluginRoot, "hooks", "open-stdin-probe.sh"),
      { env: isolatedHookEnv(root), timeoutMs: 1000 },
    );

    assert.equal(result.code, 0, result.stderr);
    assert.equal(result.stdout, "{}\n");
  });
});

/** @param {unknown} value @param {CommandHook[]} [found] @returns {CommandHook[]} */
function collectCommandHooks(value, found = []) {
  if (!value || typeof value !== "object") return found;
  const record = /** @type {JsonObject} */ (value);
  if (typeof record.command === "string") {
    found.push(/** @type {CommandHook} */ (record));
  }
  for (const child of Object.values(record)) {
    if (Array.isArray(child)) {
      for (const item of child) collectCommandHooks(item, found);
    } else if (child && typeof child === "object") {
      collectCommandHooks(child, found);
    }
  }
  return found;
}

/** @param {{ hookSourceDir: string, hooks: JsonObject }} fixture @returns {CodexBundle} */
function fixtureHookBundle({ hookSourceDir, hooks }) {
  const codexPlugin = fixtureCodexPluginPackage({ name: "demo-hooks" });
  return emptyCodexBundle({
    codexPlugin: {
      ...codexPlugin,
      hookSourceDir,
      hooks,
      manifest: { ...codexPlugin.manifest, hooks: "./hooks/hooks.json" },
    },
  });
}

function minimalCheckEnabledScript() {
  return [
    "#!/bin/bash",
    "is_hook_enabled() {",
    "  return 0",
    "}",
    "exit_if_hook_disabled() {",
    "  return 0",
    "}",
    "",
  ].join("\n");
}

/** @param {string} sourceRoot @param {string} name @returns {ClaudeSkill} */
function hookControlSkill(sourceRoot, name) {
  return {
    body: "Hook control.",
    description: "Hook control.",
    name,
    sourceDir: path.join(sourceRoot, "skills", name),
  };
}

/** @param {string} root */
function isolatedHookEnv(root) {
  /** @type {NodeJS.ProcessEnv} */
  const env = {
    ...process.env,
    HOME: path.join(root, "home"),
    XDG_CONFIG_HOME: path.join(root, "config"),
    XDG_STATE_HOME: path.join(root, "state"),
  };
  delete env.CLAUDE_PLUGIN_ROOT;
  return env;
}

/** @param {string} scriptPath @param {{ env: NodeJS.ProcessEnv }} options */
async function runHookScript(scriptPath, { env }) {
  return runProcess("bash", [scriptPath], { env });
}

/** @param {string} scriptPath @param {{ env: NodeJS.ProcessEnv, timeoutMs: number }} options */
async function runHookScriptWithOpenStdin(scriptPath, { env, timeoutMs }) {
  return runProcess("bash", [scriptPath], {
    env,
    keepStdinOpen: true,
    timeoutMs,
  });
}

/**
 * @param {string} command
 * @param {string[]} args
 * @param {{ env: NodeJS.ProcessEnv, keepStdinOpen?: boolean, timeoutMs?: number }} options
 * @returns {Promise<ProcessResult>}
 */
function runProcess(
  command,
  args,
  { env, keepStdinOpen = false, timeoutMs = 5000 },
) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      env,
      stdio: ["pipe", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    let settled = false;
    const timer = setTimeout(() => {
      child.kill("SIGKILL");
      finish(
        reject,
        new Error(
          `${command} ${args.join(" ")} did not exit within ${timeoutMs}ms`,
        ),
      );
    }, timeoutMs);

    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", (chunk) => {
      stdout += chunk;
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk;
    });
    child.on("error", (error) => {
      finish(reject, error);
    });
    child.on("close", (code, signal) => {
      finish(resolve, { code, signal, stdout, stderr });
    });
    if (!keepStdinOpen) {
      child.stdin.end();
    }

    /** @template T @param {(value: T) => void} callback @param {T} value */
    function finish(callback, value) {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      callback(value);
    }
  });
}

/** @param {string} file @returns {Promise<JsonObject>} */
async function readJson(file) {
  return /** @type {JsonObject} */ (JSON.parse(await readText(file)));
}
