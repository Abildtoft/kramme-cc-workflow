"use strict";

const assert = require("node:assert/strict");
const { spawn } = require("node:child_process");
const fs = require("fs/promises");
const os = require("os");
const path = require("path");
const test = require("node:test");

const {
  finalizeCodexHookPluginBundle,
  stageCodexHookPluginBundle,
} = require("../../scripts/convert-plugin/codex-hook-plugin-writer");
const {
  convertClaudeToCodex,
} = require("../../scripts/convert-plugin/codex-transformer");

const REPO_ROOT = path.join(__dirname, "..", "..");

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

test("generated hook scripts execute from the plugin cache without source checkout state", async () => {
  await withTempDir(async (root) => {
    const codexRoot = path.join(root, "codex-home");
    const codexStagingRoot = path.join(root, "codex-staging");
    const hookSourceDir = path.join(root, "source-plugin", "hooks");
    const codexPlugin = fixtureCodexHookPlugin({
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

    await stageCodexHookPluginBundle(
      codexRoot,
      codexStagingRoot,
      codexPlugin,
      emptyPreviousEntries(),
      { confirmOptions: { yes: true } },
    );

    const pluginCacheRoot = stagedPluginCacheRoot(
      codexStagingRoot,
      codexPlugin,
    );
    const result = await runHookScript(
      path.join(pluginCacheRoot, "hooks", "cache-probe.sh"),
      {
        env: isolatedHookEnv(root),
      },
    );

    assert.equal(result.code, 0, result.stderr);
    assert.equal(result.stdout, `root=${pluginCacheRoot}\ncache-ok\n`);
  });
});

test("local hook state and config files are excluded and removed on reinstall", async () => {
  await withTempDir(async (root) => {
    const codexRoot = path.join(root, "codex-home");
    const hookSourceDir = path.join(root, "source-plugin", "hooks");
    const codexPlugin = fixtureCodexHookPlugin({
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

    const firstStagingRoot = path.join(root, "codex-staging-first");
    const firstStage = await stageCodexHookPluginBundle(
      codexRoot,
      firstStagingRoot,
      codexPlugin,
      emptyPreviousEntries(),
      { confirmOptions: { yes: true } },
    );
    await withMutedConsole(() =>
      finalizeCodexHookPluginBundle(
        codexRoot,
        firstStagingRoot,
        codexPlugin,
        emptyPreviousEntries(),
        firstStage.targets,
        { confirmOptions: { yes: true } },
      ),
    );

    const finalHooksRoots = [
      finalMarketplaceHooksRoot(codexRoot, codexPlugin),
      finalPluginCacheHooksRoot(codexRoot, codexPlugin),
    ];
    for (const hooksRoot of finalHooksRoots) {
      await writeFile(path.join(hooksRoot, "hook-state.json"), "stale\n");
      await writeFile(path.join(hooksRoot, "context-links.config"), "stale\n");
    }

    const previousEntries = {
      ...emptyPreviousEntries(),
      hookMarketplaces: firstStage.hookMarketplaces,
      pluginCaches: firstStage.pluginCaches,
    };
    const secondStagingRoot = path.join(root, "codex-staging-second");
    const secondStage = await stageCodexHookPluginBundle(
      codexRoot,
      secondStagingRoot,
      codexPlugin,
      previousEntries,
      { confirmOptions: { yes: true } },
    );
    await withMutedConsole(() =>
      finalizeCodexHookPluginBundle(
        codexRoot,
        secondStagingRoot,
        codexPlugin,
        previousEntries,
        secondStage.targets,
        { confirmOptions: { yes: true } },
      ),
    );

    for (const hooksRoot of finalHooksRoots) {
      assert.equal(
        await pathExists(path.join(hooksRoot, "alpha-hook.sh")),
        true,
      );
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
    }
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
    const bundle = convertClaudeToCodex({
      agents: [],
      commands: [],
      hooks: sourceHookConfig,
      manifest: {
        description: "Demo plugin.",
        name: "demo-hooks",
        version: "1.0.0",
      },
      root: path.join(root, "source-plugin"),
      skills: [
        hookControlSkill("kramme:hooks:toggle"),
        hookControlSkill("kramme:hooks:configure-links"),
      ],
    });

    assert.ok(bundle.codexPlugin);
    assert.deepEqual(bundle.codexPlugin.hooks, sourceHookConfig);

    const codexRoot = path.join(root, "codex-home");
    const codexStagingRoot = path.join(root, "codex-staging");
    await writeFile(
      path.join(root, "source-plugin", "hooks", "subagent-start.sh"),
      "echo subagent\n",
    );
    await stageCodexHookPluginBundle(
      codexRoot,
      codexStagingRoot,
      bundle.codexPlugin,
      emptyPreviousEntries(),
      { confirmOptions: { yes: true } },
    );

    const generatedHookConfig = await readJson(
      path.join(
        stagedPluginCacheRoot(codexStagingRoot, bundle.codexPlugin),
        "hooks",
        "hooks.json",
      ),
    );
    assert.deepEqual(
      generatedHookConfig.SubagentStart,
      sourceHookConfig.SubagentStart,
    );
  });
});

test("generated bootstrap does not wait for open stdin when the hook does not read it", async () => {
  await withTempDir(async (root) => {
    const codexRoot = path.join(root, "codex-home");
    const codexStagingRoot = path.join(root, "codex-staging");
    const hookSourceDir = path.join(root, "source-plugin", "hooks");
    const codexPlugin = fixtureCodexHookPlugin({
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

    await stageCodexHookPluginBundle(
      codexRoot,
      codexStagingRoot,
      codexPlugin,
      emptyPreviousEntries(),
      { confirmOptions: { yes: true } },
    );

    const result = await runHookScriptWithOpenStdin(
      path.join(
        stagedPluginCacheRoot(codexStagingRoot, codexPlugin),
        "hooks",
        "open-stdin-probe.sh",
      ),
      {
        env: isolatedHookEnv(root),
        timeoutMs: 1000,
      },
    );

    assert.equal(result.code, 0, result.stderr);
    assert.equal(result.stdout, "{}\n");
  });
});

function collectCommandHooks(value, found = []) {
  if (!value || typeof value !== "object") return found;
  if (typeof value.command === "string") {
    found.push(value);
  }
  for (const child of Object.values(value)) {
    if (Array.isArray(child)) {
      for (const item of child) collectCommandHooks(item, found);
    } else if (child && typeof child === "object") {
      collectCommandHooks(child, found);
    }
  }
  return found;
}

function fixtureCodexHookPlugin({ hookSourceDir, hooks }) {
  return {
    hookSourceDir,
    hooks,
    manifest: {
      description: "Converted hooks.",
      hooks: "./hooks/hooks.json",
      name: "demo-hooks",
      version: "1.0.0",
    },
    marketplaceName: "demo-hooks",
    name: "demo-hooks",
    sharedScriptDirs: [],
    sharedScriptFiles: [],
    version: "1.0.0",
  };
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

function hookControlSkill(name) {
  return {
    body: "Hook control.",
    description: "Hook control.",
    name,
    sourceDir: `/plugin/skills/${name}`,
  };
}

function emptyPreviousEntries() {
  return {
    agentSkillFiles: {},
    agentSkills: [],
    hookMarketplaces: [],
    pluginCaches: [],
    prompts: [],
    skillFiles: {},
    skills: [],
  };
}

function stagedPluginCacheRoot(codexStagingRoot, codexPlugin) {
  return path.join(
    codexStagingRoot,
    "plugins",
    "cache",
    codexPlugin.marketplaceName,
    codexPlugin.name,
    codexPlugin.version,
  );
}

function finalMarketplaceHooksRoot(codexRoot, codexPlugin) {
  return path.join(
    codexRoot,
    ".kramme-plugin-marketplaces",
    codexPlugin.marketplaceName,
    "plugins",
    codexPlugin.name,
    "hooks",
  );
}

function finalPluginCacheHooksRoot(codexRoot, codexPlugin) {
  return path.join(
    codexRoot,
    "plugins",
    "cache",
    codexPlugin.marketplaceName,
    codexPlugin.name,
    codexPlugin.version,
    "hooks",
  );
}

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

async function runHookScript(scriptPath, { env }) {
  return runProcess("bash", [scriptPath], { env });
}

async function runHookScriptWithOpenStdin(scriptPath, { env, timeoutMs }) {
  return runProcess("bash", [scriptPath], {
    env,
    keepStdinOpen: true,
    timeoutMs,
  });
}

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

    function finish(callback, value) {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      callback(value);
    }
  });
}

async function withTempDir(fn) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "codex-hook-compat-"));
  try {
    return await fn(root);
  } finally {
    await fs.rm(root, { force: true, recursive: true });
  }
}

async function withMutedConsole(fn) {
  const log = console.log;
  console.log = () => {};
  try {
    return await fn();
  } finally {
    console.log = log;
  }
}

async function writeFile(file, content) {
  await fs.mkdir(path.dirname(file), { recursive: true });
  await fs.writeFile(file, content, "utf8");
}

async function readText(file) {
  return fs.readFile(file, "utf8");
}

async function readJson(file) {
  return JSON.parse(await readText(file));
}

async function pathExists(file) {
  try {
    await fs.access(file);
    return true;
  } catch {
    return false;
  }
}
