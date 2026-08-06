"use strict";

const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const fs = require("fs/promises");
const path = require("path");
const test = require("node:test");

const {
  stageCodexBundleOutput,
} = require("../../scripts/convert-plugin/codex-bundle-output");

const {
  stageCodexConfig,
} = require("../../scripts/convert-plugin/codex-config");

const {
  stageCodexHookPluginBundle,
} = require("../../scripts/convert-plugin/codex-hook-plugin-writer");

const {
  writeCodexBundle,
} = require("../../scripts/convert-plugin/codex-writer");

const {
  emptyPreviousEntries,
  withTempDir,
  writeJson,
  writeSourceSkill,
  writeFile,
  readText,
  pathExists,
} = require("./converter-test-helpers");

/**
 * @typedef {import("../../scripts/convert-plugin/contracts").CodexBundle} CodexBundle
 * @typedef {import("../../scripts/convert-plugin/contracts").CodexSkillFile} CodexSkillFile
 * @typedef {import("../../scripts/convert-plugin/contracts").JsonObject} JsonObject
 * @typedef {{ skills: string[], skillFiles: Record<string, string[]>, agentSkills: string[], agentSkillFiles: Record<string, string[]> }} InstallManifestFixture
 * @typedef {{ plugins: Record<string, { codex: InstallManifestFixture }> }} InstallStateFixture
 */

test("codex config staging replaces managed MCP tables without disturbing adjacent config", async () => {
  await withTempDir(async (root) => {
    const codexRoot = path.join(root, "codex-home");
    const codexStagingRoot = path.join(root, "codex-staging");
    await writeFile(
      path.join(codexRoot, "config.toml"),
      `model = "gpt-5"

[profiles.dev]
model = "gpt-5-mini"

[mcp_servers.existing]
command = "existing-server"
args = ["--keep"]

[mcp_servers."demo-server"] # old managed table
command = "old-server"

[mcp_servers."demo-server".env] # old managed env table
DEMO_TOKEN = "old-placeholder"

[[history_entries]]
name = "keep-array-table"

[mcp_servers.demo-server-extra]
command = "keep-extra"

[mcp_servers.demo-server.env_extra]
SENTINEL = "keep-prefix"

[profiles.after]
model = "gpt-5"
`,
    );

    const stagedConfig = await stageCodexConfig(
      codexRoot,
      codexStagingRoot,
      {
        mcpServers: {
          "demo-server": {
            args: ["server.js", "--stdio"],
            command: "node",
            env: { DEMO_TOKEN: "placeholder" },
          },
        },
      },
      emptyPreviousEntries(),
      "demo-plugin",
    );

    assert.ok(stagedConfig);
    const output = await readText(stagedConfig.stagedPath);
    assert.match(
      /** @type {string} */ (stagedConfig.expectedTargetContent),
      /command = "old-server"/,
    );
    assert.match(output, /model = "gpt-5"/);
    assert.match(output, /\[profiles\.dev\]/);
    assert.match(output, /\[profiles\.after\]/);
    assert.match(output, /\[\[history_entries\]\]/);
    assert.match(output, /name = "keep-array-table"/);
    assert.match(output, /\[mcp_servers\.existing\]/);
    assert.match(output, /\[mcp_servers\.demo-server-extra\]/);
    assert.match(output, /command = "keep-extra"/);
    assert.match(output, /\[mcp_servers\.demo-server\.env_extra\]/);
    assert.match(output, /SENTINEL = "keep-prefix"/);
    assert.match(output, /\[mcp_servers\.demo-server\]/);
    assert.match(output, /command = "node"/);
    assert.match(output, /args = \["server.js", "--stdio"\]/);
    assert.match(output, /\[mcp_servers\.demo-server\.env\]/);
    assert.match(output, /DEMO_TOKEN = "placeholder"/);
    assert.doesNotMatch(output, /\[mcp_servers\."demo-server"\]/);
    assert.doesNotMatch(output, /\[mcp_servers\."demo-server"\.env\]/);
    assert.doesNotMatch(output, /command = "old-server"/);
    assert.doesNotMatch(output, /DEMO_TOKEN = "old-placeholder"/);

    await writeFile(path.join(codexRoot, "config.toml"), output);
    const restagedConfig = await stageCodexConfig(
      codexRoot,
      codexStagingRoot,
      {
        mcpServers: {
          "demo-server": {
            args: ["server.js", "--stdio"],
            command: "node",
            env: { DEMO_TOKEN: "placeholder" },
          },
        },
      },
      emptyPreviousEntries(),
      "demo-plugin",
    );
    assert.equal(restagedConfig, null);
  });
});

test("bundle output stages prompts, skills, generated skills, and agent skills", async () => {
  await withTempDir(async (root) => {
    const agentsHome = path.join(root, "agents-home");
    const codexRoot = path.join(root, "codex-home");
    const codexStagingRoot = path.join(root, "codex-staging");
    const sourceSkillDir = path.join(root, "plugin", "skills", "source-skill");

    await writeFile(path.join(sourceSkillDir, "SKILL.md"), "original skill\n");
    await writeFile(
      path.join(sourceSkillDir, "notes.md"),
      [
        "Run /extra-command before review.",
        "Use agents/reviewer.md in copied resources.",
        "Use colon punctuation agents/reviewer.md: copied resources.",
        "Keep anchored paths like agents/reviewer.md#usage.",
        "Keep parent paths like ../agents/reviewer.md.",
        "",
      ].join("\n"),
    );
    await writeFile(
      path.join(
        sourceSkillDir,
        "references",
        "sources-snapshot",
        "upstream.md",
      ),
      "repository-maintenance baseline\n",
    );

    const stagedBundle = await stageCodexBundleOutput(
      codexRoot,
      codexStagingRoot,
      {
        agentSkills: [
          {
            content: "---\nname: review-agent\n---\n\nAgent instructions.",
            name: "review-agent",
          },
        ],
        generatedSkills: [
          {
            content: "---\nname: extra-command\n---\n\nGenerated instructions.",
            name: "extra-command",
          },
        ],
        knownAgentSkills: new Map([["reviewer", "review-agent"]]),
        knownCommands: new Set(["extra-command"]),
        prompts: [{ content: "Prompt body", name: "daily" }],
        skillDirs: [
          {
            content: "---\nname: source-skill\n---\n\nUse $extra-command.",
            name: "source-skill",
            sourceDir: sourceSkillDir,
          },
        ],
      },
      emptyPreviousEntries(),
      "demo-plugin",
      { agentsHome, confirm: { yes: true } },
    );

    assert.equal(
      await readText(path.join(codexStagingRoot, "prompts", "daily.md")),
      "Prompt body\n",
    );
    assert.match(
      await readText(
        path.join(codexStagingRoot, "skills", "source-skill", "SKILL.md"),
      ),
      /\$extra-command/,
    );
    assert.deepEqual(
      new Set(stagedBundle.stagedSkillFiles["source-skill"]),
      new Set(["SKILL.md", "notes.md"]),
    );
    assert.equal(
      await pathExists(
        path.join(
          codexStagingRoot,
          "skills",
          "source-skill",
          "references",
          "sources-snapshot",
        ),
      ),
      false,
    );
    assert.deepEqual(
      new Set(stagedBundle.stagedSkillFiles["extra-command"]),
      new Set(["SKILL.md"]),
    );
    assert.equal(stagedBundle.agentSkillsRoot, path.join(agentsHome, "skills"));
    assert.ok(stagedBundle.stagedAgentSkillsRoot);
    assert.equal(
      await readText(
        path.join(
          stagedBundle.stagedAgentSkillsRoot,
          "review-agent",
          "SKILL.md",
        ),
      ),
      "---\nname: review-agent\n---\n\nAgent instructions.\n",
    );
    const notes = await readText(
      path.join(codexStagingRoot, "skills", "source-skill", "notes.md"),
    );
    assert.match(notes, /Run \$extra-command before review\./);
    assert.match(notes, /Use \$review-agent skill in copied resources\./);
    assert.match(
      notes,
      /Use colon punctuation \$review-agent skill: copied resources\./,
    );
    assert.match(notes, /agents\/reviewer\.md#usage/);
    assert.match(notes, /\.\.\/agents\/reviewer\.md/);
    assert.equal(
      await pathExists(path.join(codexRoot, "prompts", "daily.md")),
      false,
    );
  });
});

test("hook plugin staging excludes local hook state and config files", async () => {
  await withTempDir(async (root) => {
    const codexRoot = path.join(root, "codex-home");
    const codexStagingRoot = path.join(root, "codex-staging");
    const hookSourceDir = path.join(root, "plugin", "hooks");

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

    await stageCodexHookPluginBundle(
      codexRoot,
      codexStagingRoot,
      {
        hookSourceDir,
        hooks: { PreToolUse: [] },
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
      },
      emptyPreviousEntries(),
      { confirmOptions: { yes: true } },
    );

    for (const hooksRoot of [
      path.join(
        codexStagingRoot,
        ".kramme-plugin-marketplaces",
        "demo-hooks",
        "plugins",
        "demo-hooks",
        "hooks",
      ),
      path.join(
        codexStagingRoot,
        "plugins",
        "cache",
        "demo-hooks",
        "demo-hooks",
        "1.0.0",
        "hooks",
      ),
    ]) {
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

test("writer preserves exact skill group outputs across pruning and removal", async () => {
  await withTempDir(async (root) => {
    const agentsHome = path.join(root, "agents-home");
    const sourceDir = path.join(root, "source-skill");
    const options = {
      agentsHome,
      confirm: { yes: true },
      pluginName: "managed-file-plugin",
    };

    /** @param {string} version @returns {CodexBundle} */
    function bundle(version) {
      return {
        agentSkills: [{ content: `Agent ${version}`, name: "fixture-agent" }],
        codexPlugin: undefined,
        generatedSkills: [
          { content: `Generated ${version}`, name: "fixture-generated" },
        ],
        knownAgentSkills: new Map(),
        knownCommands: new Set(),
        mcpServers: {},
        prompts: [],
        skillDirs: [
          {
            content: "",
            name: "fixture-managed",
            sourceDir,
          },
        ],
      };
    }

    await writeSourceSkill(sourceDir, {
      "SKILL.md": "Managed v1\n",
      "references/OLD.md": "old managed file\n",
    });
    await writeCodexBundle(root, bundle("v1"), options);

    const skillDir = path.join(root, ".codex", "skills", "fixture-managed");
    const generatedSkillDir = path.join(
      root,
      ".codex",
      "skills",
      "fixture-generated",
    );
    const agentSkillDir = path.join(agentsHome, "skills", "fixture-agent");
    const oldManagedFile = path.join(skillDir, "references", "OLD.md");
    const newManagedFile = path.join(skillDir, "references", "NEW.md");
    const localNotes = path.join(skillDir, "LOCAL-NOTES.md");
    const manifestPath = path.join(
      root,
      ".codex",
      ".kramme-install-manifests",
      "managed-file-plugin-codex.json",
    );
    assert.equal(await pathExists(oldManagedFile), true);

    let manifest = /** @type {InstallManifestFixture} */ (
      await readJson(manifestPath)
    );
    assert.deepEqual(manifest.skillFiles["fixture-managed"], [
      "SKILL.md",
      "references/OLD.md",
    ]);
    assert.deepEqual(manifest.skillFiles["fixture-generated"], ["SKILL.md"]);
    assert.deepEqual(manifest.agentSkillFiles["fixture-agent"], ["SKILL.md"]);
    assert.deepEqual(await readFileTree(path.join(root, ".codex", "skills")), {
      "fixture-generated/SKILL.md": "Generated v1\n",
      "fixture-managed/SKILL.md": "Managed v1\n",
      "fixture-managed/references/OLD.md": "old managed file\n",
    });
    assert.deepEqual(await readFileTree(path.join(agentsHome, "skills")), {
      "fixture-agent/SKILL.md": "Agent v1\n",
    });

    await writeFile(localNotes, "keep local notes\n");
    await writeFile(path.join(generatedSkillDir, "OLD.md"), "old generated\n");
    await writeFile(path.join(agentSkillDir, "OLD.md"), "old agent\n");

    const statePath = path.join(root, ".codex", ".kramme-install-state.json");
    const state = /** @type {InstallStateFixture} */ (
      await readJson(statePath)
    );
    const entries = state.plugins["managed-file-plugin"].codex;
    entries.skillFiles["fixture-generated"] = ["OLD.md", "SKILL.md"];
    entries.agentSkillFiles["fixture-agent"] = ["OLD.md", "SKILL.md"];
    await writeJson(statePath, state);
    manifest.skillFiles["fixture-generated"] = ["OLD.md", "SKILL.md"];
    manifest.agentSkillFiles["fixture-agent"] = ["OLD.md", "SKILL.md"];
    await writeJson(manifestPath, manifest);

    await writeSourceSkill(sourceDir, {
      "SKILL.md": "Managed v2\n",
      "references/NEW.md": "new managed file\n",
    });

    await writeCodexBundle(root, bundle("v2"), {
      ...options,
      confirm: { nonInteractive: true },
    });

    assert.equal(await pathExists(oldManagedFile), false);
    assert.equal(await pathExists(newManagedFile), true);
    assert.equal(await readText(localNotes), "keep local notes\n");

    manifest = /** @type {InstallManifestFixture} */ (
      await readJson(manifestPath)
    );
    assert.deepEqual(manifest.skillFiles["fixture-managed"], [
      "SKILL.md",
      "references/NEW.md",
    ]);
    assert.deepEqual(manifest.skillFiles["fixture-generated"], ["SKILL.md"]);
    assert.deepEqual(manifest.agentSkillFiles["fixture-agent"], ["SKILL.md"]);
    assert.deepEqual(await readFileTree(path.join(root, ".codex", "skills")), {
      "fixture-generated/SKILL.md": "Generated v2\n",
      "fixture-managed/LOCAL-NOTES.md": "keep local notes\n",
      "fixture-managed/SKILL.md": "Managed v2\n",
      "fixture-managed/references/NEW.md": "new managed file\n",
    });
    assert.deepEqual(await readFileTree(path.join(agentsHome, "skills")), {
      "fixture-agent/SKILL.md": "Agent v2\n",
    });

    await writeCodexBundle(
      root,
      {
        ...bundle("removed"),
        agentSkills: [],
        generatedSkills: [],
        skillDirs: [],
      },
      options,
    );

    manifest = /** @type {InstallManifestFixture} */ (
      await readJson(manifestPath)
    );
    assert.deepEqual(
      await readFileTree(path.join(root, ".codex", "skills")),
      {},
    );
    assert.deepEqual(await readFileTree(path.join(agentsHome, "skills")), {});
    assert.deepEqual(manifest.skills, []);
    assert.deepEqual(manifest.skillFiles, {});
    assert.deepEqual(manifest.agentSkills, []);
    assert.deepEqual(manifest.agentSkillFiles, {});
  });
});

test("writer preserves previous skill files when stale pruning preflight fails", async () => {
  await withTempDir(async (root) => {
    const agentsHome = path.join(root, "agents-home");
    const sourceDir = path.join(root, "source-skill");
    const options = {
      agentsHome,
      confirm: { yes: true },
      pluginName: "managed-prune-conflict-plugin",
    };

    function bundle() {
      return {
        agentSkills: [],
        codexPlugin: undefined,
        generatedSkills: [],
        knownAgentSkills: new Map(),
        knownCommands: new Set(),
        mcpServers: {},
        prompts: [],
        skillDirs: [
          {
            content: "",
            name: "fixture-managed",
            sourceDir,
          },
        ],
      };
    }

    await writeSourceSkill(sourceDir, {
      "OLD.md": "old managed file\n",
      "SKILL.md": "Managed v1\n",
    });
    await writeCodexBundle(root, bundle(), options);

    const skillDir = path.join(root, ".codex", "skills", "fixture-managed");
    const oldManagedFile = path.join(skillDir, "OLD.md");
    const blockingFile = path.join(skillDir, "conflict");
    const statePath = path.join(root, ".codex", ".kramme-install-state.json");
    const manifestPath = path.join(
      root,
      ".codex",
      ".kramme-install-manifests",
      "managed-prune-conflict-plugin-codex.json",
    );
    const stateBefore = await readText(statePath);
    const manifestBefore = await readText(manifestPath);
    await writeFile(blockingFile, "local blocker\n");

    await writeSourceSkill(sourceDir, {
      "SKILL.md": "Managed v2\n",
      "conflict/NEW.md": "new managed file\n",
    });

    await assert.rejects(
      () =>
        writeCodexBundle(root, bundle(), {
          ...options,
          confirm: { nonInteractive: true },
        }),
      /conflicts with staged directory conflict/,
    );

    assert.equal(await pathExists(oldManagedFile), true);
    assert.equal(
      await readText(path.join(skillDir, "SKILL.md")),
      "Managed v1\n",
    );
    assert.equal(await readText(blockingFile), "local blocker\n");
    assert.equal(await readText(statePath), stateBefore);
    assert.equal(await readText(manifestPath), manifestBefore);
  });
});

test("writer preserves untracked same-name skill directories on first install", async () => {
  await withTempDir(async (root) => {
    const agentsHome = path.join(root, "agents-home");
    const sourceDir = path.join(root, "source-skill");
    const sourceSkillDir = path.join(
      root,
      ".codex",
      "skills",
      "collision-source",
    );
    const codexSkillDir = path.join(
      root,
      ".codex",
      "skills",
      "collision-skill",
    );
    const agentSkillDir = path.join(agentsHome, "skills", "collision-agent");
    await writeFile(path.join(sourceDir, "SKILL.md"), "Source\n");
    await writeFile(
      path.join(sourceSkillDir, "LOCAL-NOTES.md"),
      "keep source\n",
    );
    await writeFile(path.join(codexSkillDir, "LOCAL-NOTES.md"), "keep codex\n");
    await writeFile(path.join(agentSkillDir, "LOCAL-NOTES.md"), "keep agent\n");

    await writeCodexBundle(
      root,
      {
        agentSkills: [{ content: "Agent", name: "collision-agent" }],
        codexPlugin: undefined,
        generatedSkills: [{ content: "Generated", name: "collision-skill" }],
        knownAgentSkills: new Map(),
        knownCommands: new Set(),
        prompts: [],
        skillDirs: [{ content: "", name: "collision-source", sourceDir }],
      },
      {
        agentsHome,
        confirm: { yes: true },
        pluginName: "collision-plugin",
      },
    );

    assert.equal(
      await readText(path.join(sourceSkillDir, "LOCAL-NOTES.md")),
      "keep source\n",
    );
    assert.equal(
      await readText(path.join(codexSkillDir, "LOCAL-NOTES.md")),
      "keep codex\n",
    );
    assert.equal(
      await readText(path.join(agentSkillDir, "LOCAL-NOTES.md")),
      "keep agent\n",
    );
    assert.equal(
      await readText(path.join(sourceSkillDir, "SKILL.md")),
      "Source\n",
    );
    assert.equal(
      await readText(path.join(codexSkillDir, "SKILL.md")),
      "Generated\n",
    );
    assert.equal(
      await readText(path.join(agentSkillDir, "SKILL.md")),
      "Agent\n",
    );
  });
});

test("writer rejects non-identical unowned prompt and shared-script files", async () => {
  for (const collision of ["prompt", "shared-script"]) {
    await withTempDir(async (root) => {
      const bundle = await createTransactionalBundle(root, "v1");
      const codexRoot = path.join(root, ".codex");
      const targetPath =
        collision === "prompt"
          ? path.join(codexRoot, "prompts", "daily.md")
          : path.join(codexRoot, "scripts", "shared.js");
      await writeFile(targetPath, `custom ${collision}\n`);
      const before = await readTreeSnapshot(codexRoot);

      await assert.rejects(
        () =>
          writeCodexBundle(root, bundle, {
            agentsHome: path.join(root, "agents-home"),
            confirm: { yes: true },
            pluginName: `${collision}-collision-plugin`,
          }),
        /non-identical unowned file/,
      );

      assert.deepEqual(await readTreeSnapshot(codexRoot), before);
    });
  }
});

test("writer adopts byte-identical unowned prompt and shared-script files", async () => {
  await withTempDir(async (root) => {
    const bundle = await createTransactionalBundle(root, "v1");
    const codexRoot = path.join(root, ".codex");
    await writeFile(path.join(codexRoot, "prompts", "daily.md"), "Prompt v1\n");
    await writeFile(
      path.join(codexRoot, "scripts", "shared.js"),
      'module.exports = "v1";\n',
    );

    await writeCodexBundle(root, bundle, {
      agentsHome: path.join(root, "agents-home"),
      confirm: { yes: true },
      pluginName: "identical-collision-plugin",
    });

    assert.equal(
      await readText(path.join(codexRoot, "prompts", "daily.md")),
      "Prompt v1\n",
    );
    assert.equal(
      await readText(path.join(codexRoot, "scripts", "shared.js")),
      'module.exports = "v1";\n',
    );
  });
});

test("writer rejects edits to adopted prompts made after preflight", async () => {
  await withTempDir(async (root) => {
    const codexRoot = path.join(root, ".codex");
    const promptPath = path.join(codexRoot, "prompts", "daily.md");
    const userEdit = "# User edit after adoption preflight\n";
    const bundle = await createTransactionalBundle(root, "v1");
    await writeFile(promptPath, "Prompt v1\n");

    await assert.rejects(
      () =>
        writeCodexBundle(root, bundle, {
          agentsHome: path.join(root, "agents-home"),
          confirm: { yes: true },
          pluginName: "prompt-adoption-race-plugin",
          async onInstallPhase(phase) {
            if (phase === "shared-scripts") {
              await writeFile(promptPath, userEdit);
            }
          },
        }),
      /changed during installation/,
    );

    assert.equal(await readText(promptPath), userEdit);
    assert.equal(
      await pathExists(path.join(codexRoot, ".kramme-install-state.json")),
      false,
    );
  });
});

test("writer rejects config edits made after config staging", async () => {
  await withTempDir(async (root) => {
    const codexRoot = path.join(root, ".codex");
    const configPath = path.join(codexRoot, "config.toml");
    const userEdit = "# Concurrent config edit\n";
    await writeFile(configPath, "# Original config\n");
    const originalWriteFile = fs.writeFile;
    let injected = false;
    fs.writeFile = async (file, data, options) => {
      const result = await originalWriteFile(file, data, options);
      if (
        !injected &&
        path.basename(String(file)) === "AGENTS.md" &&
        String(file).includes(".kramme-install-staging")
      ) {
        injected = true;
        await originalWriteFile(configPath, userEdit, "utf8");
      }
      return result;
    };
    try {
      await assert.rejects(
        () =>
          writeCodexBundle(
            root,
            {
              agentSkills: [],
              codexPlugin: undefined,
              generatedSkills: [],
              knownAgentSkills: new Map(),
              knownCommands: new Set(),
              mcpServers: { demo: { command: "demo" } },
              prompts: [],
              skillDirs: [],
            },
            {
              agentsHome: path.join(root, "agents-home"),
              confirm: { yes: true },
              pluginName: "config-staging-race-plugin",
            },
          ),
        /changed during installation/,
      );
    } finally {
      fs.writeFile = originalWriteFile;
    }

    assert.equal(injected, true);
    assert.equal(await readText(configPath), userEdit);
    assert.equal(
      await pathExists(path.join(codexRoot, ".kramme-install-state.json")),
      false,
    );
  });
});

test("writer rejects shared-directory edits made after final preflight", async () => {
  await withTempDir(async (root) => {
    const codexRoot = path.join(root, ".codex");
    const sourceDir = path.join(root, "shared-directory-source");
    const targetDir = path.join(codexRoot, "scripts", "dev-server");
    const targetFile = path.join(targetDir, "detect.sh");
    const userEdit = "# Concurrent shared-directory edit\n";
    await writeFile(path.join(sourceDir, "detect.sh"), "# Managed script\n");
    await writeFile(targetFile, "# Managed script\n");
    const bundle = await createTransactionalBundle(root, "v1");
    assert.ok(bundle.codexPlugin);
    bundle.codexPlugin.sharedScriptDirs = [
      { sourceDir, targetDir: path.join("scripts", "dev-server") },
    ];

    const originalMkdir = fs.mkdir;
    let injected = false;
    fs.mkdir = /** @type {typeof fs.mkdir} */ (
      async (dir, options) => {
        const result = await originalMkdir(dir, options);
        if (
          !injected &&
          String(dir).startsWith(
            path.join(codexRoot, "scripts", ".kramme-install-backups") +
              path.sep,
          )
        ) {
          injected = true;
          await fs.writeFile(targetFile, userEdit, "utf8");
        }
        return result;
      }
    );
    try {
      await assert.rejects(
        () =>
          writeCodexBundle(root, bundle, {
            agentsHome: path.join(root, "agents-home"),
            confirm: { yes: true },
            pluginName: "shared-directory-race-plugin",
          }),
        /changed during installation/,
      );
    } finally {
      fs.mkdir = originalMkdir;
    }

    assert.equal(injected, true);
    assert.equal(await readText(targetFile), userEdit);
    assert.equal(
      await pathExists(path.join(codexRoot, ".kramme-install-state.json")),
      false,
    );
  });
});

test("writer rejects managed output beneath an unlocked symlinked directory", async () => {
  await withTempDir(async (root) => {
    const codexRoot = path.join(root, ".codex");
    const externalPrompts = path.join(root, "external-prompts");
    const promptsLink = path.join(codexRoot, "prompts");
    await fs.mkdir(codexRoot, { recursive: true });
    await fs.mkdir(externalPrompts, { recursive: true });
    await fs.symlink(externalPrompts, promptsLink);

    await assert.rejects(
      () =>
        writeCodexBundle(
          root,
          {
            agentSkills: [],
            codexPlugin: undefined,
            generatedSkills: [],
            knownAgentSkills: new Map(),
            knownCommands: new Set(),
            mcpServers: {},
            prompts: [{ content: "Prompt", name: "daily" }],
            skillDirs: [],
          },
          {
            agentsHome: path.join(root, "agents-home"),
            confirm: { yes: true },
            pluginName: "unlocked-symlink-plugin",
          },
        ),
      /outside the acquired install locks/,
    );

    assert.equal((await fs.lstat(promptsLink)).isSymbolicLink(), true);
    assert.equal(
      await pathExists(path.join(externalPrompts, "daily.md")),
      false,
    );
    assert.equal(
      await pathExists(path.join(codexRoot, ".kramme-install-state.json")),
      false,
    );
  });
});

test("writer replaces prompt and shared-script files proven by prior install state", async () => {
  await withTempDir(async (root) => {
    const options = {
      agentsHome: path.join(root, "agents-home"),
      confirm: { yes: true },
      pluginName: "managed-file-upgrade-plugin",
    };
    await writeCodexBundle(
      root,
      await createTransactionalBundle(root, "v1"),
      options,
    );
    await writeCodexBundle(
      root,
      await createTransactionalBundle(root, "v2"),
      options,
    );

    assert.equal(
      await readText(path.join(root, ".codex", "prompts", "daily.md")),
      "Prompt v2\n",
    );
    assert.equal(
      await readText(path.join(root, ".codex", "scripts", "shared.js")),
      'module.exports = "v2";\n',
    );
  });
});

test("writer uses a previous marketplace copy when the plugin cache was evicted", async () => {
  await withTempDir(async (root) => {
    const codexRoot = path.join(root, ".codex");
    const options = {
      agentsHome: path.join(root, "agents-home"),
      confirm: { yes: true },
      pluginName: "marketplace-provenance-plugin",
    };
    await writeCodexBundle(
      root,
      await createTransactionalBundle(root, "v1"),
      options,
    );
    await fs.rm(
      path.join(
        codexRoot,
        "plugins",
        "cache",
        "transaction-hooks",
        "transaction-hooks",
        "1.0.1",
      ),
      { recursive: true, force: true },
    );
    assert.equal(
      await readText(
        path.join(
          codexRoot,
          ".kramme-plugin-marketplaces",
          "transaction-hooks",
          "plugins",
          "transaction-hooks",
          "scripts",
          "shared.js",
        ),
      ),
      'module.exports = "v1";\n',
    );

    await writeCodexBundle(
      root,
      await createTransactionalBundle(root, "v2"),
      options,
    );

    assert.equal(
      await readText(path.join(codexRoot, "scripts", "shared.js")),
      'module.exports = "v2";\n',
    );
  });
});

test("writer preflights AGENTS.md directory and permission failures before publication", async () => {
  for (const failure of ["directory", "permission"]) {
    await withTempDir(async (root) => {
      const codexRoot = path.join(root, ".codex");
      const agentsPath = path.join(codexRoot, "AGENTS.md");
      const bundle = await createTransactionalBundle(root, "v1");
      if (failure === "directory") {
        await writeFile(path.join(agentsPath, "LOCAL.md"), "local\n");
      } else {
        await writeFile(agentsPath, "# Local instructions\n");
      }
      const before = await readTreeSnapshot(codexRoot);
      const permissionError = Object.assign(
        new Error("injected AGENTS.md permission failure"),
        { code: "EACCES" },
      );
      const originalWriteFile = fs.writeFile;
      if (failure === "permission") {
        fs.writeFile = async (file, data, options) => {
          if (
            path.basename(String(file)) === "AGENTS.md" &&
            String(file).includes(".kramme-install-staging")
          ) {
            throw permissionError;
          }
          return originalWriteFile(file, data, options);
        };
      }
      try {
        await assert.rejects(
          () =>
            writeCodexBundle(root, bundle, {
              agentsHome: path.join(root, "agents-home"),
              confirm: { yes: true },
              pluginName: `agents-${failure}-plugin`,
            }),
          failure === "directory"
            ? (error) => {
                if (!(error instanceof Error)) return false;
                const filesystemError = /** @type {NodeJS.ErrnoException} */ (
                  error
                );
                return (
                  filesystemError.code === "EISDIR" ||
                  /directory/.test(error.message)
                );
              }
            : (error) => error === permissionError,
        );
      } finally {
        fs.writeFile = originalWriteFile;
      }

      assert.deepEqual(await readTreeSnapshot(codexRoot), before);
    });
  }
});

test("writer preserves the existing AGENTS.md mode on successful publication", async () => {
  await withTempDir(async (root) => {
    const codexRoot = path.join(root, ".codex");
    const agentsPath = path.join(codexRoot, "AGENTS.md");
    await writeFile(agentsPath, "# Private local instructions\n");
    await fs.chmod(agentsPath, 0o600);

    await writeCodexBundle(root, await createTransactionalBundle(root, "v1"), {
      agentsHome: path.join(root, "agents-home"),
      confirm: { yes: true },
      pluginName: "agents-mode-plugin",
    });

    assert.equal((await fs.stat(agentsPath)).mode & 0o7777, 0o600);
    assert.match(await readText(agentsPath), /# Private local instructions/);
    assert.match(await readText(agentsPath), /BEGIN KRAMME CODEX TOOL MAP/);
  });
});

test("writer preserves existing AGENTS.md extended attributes", async (t) => {
  if (process.platform === "win32") {
    t.skip("extended-attribute fixture is POSIX-only");
    return;
  }
  await withTempDir(async (root) => {
    const codexRoot = path.join(root, ".codex");
    const agentsPath = path.join(codexRoot, "AGENTS.md");
    const attribute =
      process.platform === "darwin"
        ? "com.kramme.review-marker"
        : "user.kramme_review_marker";
    await writeFile(agentsPath, "# Local instructions\n");
    const setResult = setExtendedAttribute(
      agentsPath,
      attribute,
      "review-marker",
    );
    if (
      setResult.status !== 0 &&
      /not supported|operation not permitted/i.test(
        `${setResult.stdout}${setResult.stderr}`,
      )
    ) {
      t.skip("filesystem does not support user extended attributes");
      return;
    }
    assert.equal(setResult.status, 0, setResult.stderr);

    await writeCodexBundle(root, await createTransactionalBundle(root, "v1"), {
      agentsHome: path.join(root, "agents-home"),
      confirm: { yes: true },
      pluginName: "agents-xattr-plugin",
    });

    const getResult = getExtendedAttribute(agentsPath, attribute);
    assert.equal(getResult.status, 0, getResult.stderr);
    assert.equal(getResult.stdout.trimEnd(), "review-marker");
  });
});

test("writer does not resurrect AGENTS.md attributes removed during finalization", async (t) => {
  if (process.platform === "win32") {
    t.skip("extended-attribute fixture is POSIX-only");
    return;
  }
  await withTempDir(async (root) => {
    const codexRoot = path.join(root, ".codex");
    const agentsPath = path.join(codexRoot, "AGENTS.md");
    const attribute =
      process.platform === "darwin"
        ? "com.kramme.removed-marker"
        : "user.kramme_removed_marker";
    await writeFile(agentsPath, "# Local instructions\n");
    const setResult = setExtendedAttribute(agentsPath, attribute, "remove-me");
    if (
      setResult.status !== 0 &&
      /not supported|operation not permitted/i.test(
        `${setResult.stdout}${setResult.stderr}`,
      )
    ) {
      t.skip("filesystem does not support user extended attributes");
      return;
    }
    assert.equal(setResult.status, 0, setResult.stderr);

    await writeCodexBundle(root, await createTransactionalBundle(root, "v1"), {
      agentsHome: path.join(root, "agents-home"),
      confirm: { yes: true },
      pluginName: "agents-removed-xattr-plugin",
      onInstallPhase(phase) {
        if (phase !== "shared-scripts") return;
        const removeResult = removeExtendedAttribute(agentsPath, attribute);
        assert.equal(removeResult.status, 0, removeResult.stderr);
      },
    });

    const listResult = listExtendedAttributes(agentsPath);
    assert.equal(listResult.status, 0, listResult.stderr);
    assert.doesNotMatch(listResult.stdout, new RegExp(attribute));
  });
});

test("writer preserves AGENTS.md attributes through cross-device publication", async (t) => {
  if (process.platform === "win32") {
    t.skip("extended-attribute fixture is POSIX-only");
    return;
  }
  await withTempDir(async (root) => {
    const codexRoot = path.join(root, ".codex");
    const agentsPath = path.join(codexRoot, "AGENTS.md");
    const attribute =
      process.platform === "darwin"
        ? "com.kramme.cross-device-marker"
        : "user.kramme_cross_device_marker";
    await writeFile(agentsPath, "# Local instructions\n");
    const setResult = setExtendedAttribute(agentsPath, attribute, "keep-me");
    if (
      setResult.status !== 0 &&
      /not supported|operation not permitted/i.test(
        `${setResult.stdout}${setResult.stderr}`,
      )
    ) {
      t.skip("filesystem does not support user extended attributes");
      return;
    }
    assert.equal(setResult.status, 0, setResult.stderr);

    const originalLink = fs.link;
    let injected = false;
    fs.link = async (source, target) => {
      if (
        !injected &&
        target === agentsPath &&
        String(source).includes(".kramme-install-staging")
      ) {
        injected = true;
        throw Object.assign(new Error("simulated cross-device publication"), {
          code: "EXDEV",
        });
      }
      return originalLink(source, target);
    };
    try {
      await writeCodexBundle(
        root,
        await createTransactionalBundle(root, "v1"),
        {
          agentsHome: path.join(root, "agents-home"),
          confirm: { yes: true },
          pluginName: "agents-cross-device-xattr-plugin",
        },
      );
    } finally {
      fs.link = originalLink;
    }

    assert.equal(injected, true);
    const getResult = getExtendedAttribute(agentsPath, attribute);
    assert.equal(getResult.status, 0, getResult.stderr);
    assert.equal(getResult.stdout.trimEnd(), "keep-me");
  });
});

test("writer preserves a symlinked AGENTS.md and updates its referent transactionally", async () => {
  await withTempDir(async (root) => {
    const codexRoot = path.join(root, ".codex");
    const agentsPath = path.join(codexRoot, "AGENTS.md");
    const referent = path.join(root, "dotfiles", "AGENTS.md");
    const relativeReferent = path.relative(path.dirname(agentsPath), referent);
    await writeFile(referent, "# Shared local instructions\n");
    await fs.chmod(referent, 0o600);
    await fs.mkdir(path.dirname(agentsPath), { recursive: true });
    await fs.symlink(relativeReferent, agentsPath);

    await writeCodexBundle(root, await createTransactionalBundle(root, "v1"), {
      agentsHome: path.join(root, "agents-home"),
      confirm: { yes: true },
      pluginName: "agents-symlink-plugin",
    });

    assert.equal((await fs.lstat(agentsPath)).isSymbolicLink(), true);
    assert.equal(await fs.readlink(agentsPath), relativeReferent);
    assert.equal((await fs.stat(referent)).mode & 0o7777, 0o600);
    assert.match(await readText(referent), /# Shared local instructions/);
    assert.match(await readText(referent), /BEGIN KRAMME CODEX TOOL MAP/);
    assert.equal(
      await pathExists(
        path.join(path.dirname(referent), ".kramme-install-lock"),
      ),
      false,
    );
  });
});

test("writer retries with the moved AGENTS.md destination it discovered", async () => {
  await withTempDir(async (root) => {
    const codexRoot = path.join(root, ".codex");
    const lockDir = path.join(codexRoot, ".kramme-install-lock");
    const agentsPath = path.join(codexRoot, "AGENTS.md");
    const externalRoot = path.join(root, "dotfiles");
    const referent = path.join(externalRoot, "AGENTS.md");
    await writeFile(referent, "# Shared local instructions\n");
    await fs.mkdir(codexRoot, { recursive: true });
    const bundle = await createTransactionalBundle(root, "v1");

    const originalLstat = fs.lstat;
    const originalRename = fs.rename;
    let moved = false;
    let lockAcquisitions = 0;
    fs.lstat = /** @type {typeof fs.lstat} */ (
      /** @param {import("fs").PathLike} target */
      async (target) => {
        try {
          return await originalLstat(target);
        } finally {
          // The first resolution runs before any lock is held. Move the
          // destination there so the locked attempt observes a different one.
          if (!moved && String(target) === agentsPath) {
            moved = true;
            await fs.symlink(referent, agentsPath);
          }
        }
      }
    );
    fs.rename = async (source, target) => {
      if (String(target) === lockDir) lockAcquisitions += 1;
      return originalRename(source, target);
    };
    try {
      await writeCodexBundle(root, bundle, {
        agentsHome: path.join(root, "agents-home"),
        confirm: { yes: true },
        pluginName: "agents-destination-retry-plugin",
      });
    } finally {
      fs.lstat = originalLstat;
      fs.rename = originalRename;
    }

    assert.equal(moved, true);
    // One rejected attempt plus the retry that adopted the moved destination.
    assert.equal(lockAcquisitions, 2);
    assert.equal((await fs.lstat(agentsPath)).isSymbolicLink(), true);
    assert.equal(await fs.readlink(agentsPath), referent);
    assert.match(await readText(referent), /# Shared local instructions/);
    assert.match(await readText(referent), /BEGIN KRAMME CODEX TOOL MAP/);
    assert.equal(await pathExists(lockDir), false);
    assert.equal(
      await pathExists(path.join(externalRoot, ".kramme-install-lock")),
      false,
    );
  });
});

test("writer rolls back when a symlinked AGENTS.md is retargeted during publication", async () => {
  await withTempDir(async (root) => {
    const codexRoot = path.join(root, ".codex");
    const agentsPath = path.join(codexRoot, "AGENTS.md");
    const externalRoot = path.join(root, "dotfiles");
    const originalReferent = path.join(externalRoot, "ORIGINAL.md");
    const replacementReferent = path.join(externalRoot, "REPLACEMENT.md");
    await writeFile(originalReferent, "# Original referent\n");
    await writeFile(replacementReferent, "# Replacement referent\n");
    await fs.mkdir(codexRoot, { recursive: true });
    await fs.symlink(originalReferent, agentsPath);

    const originalMkdir = fs.mkdir;
    let retargeted = false;
    fs.mkdir = /** @type {typeof fs.mkdir} */ (
      async (dir, options) => {
        const result = await originalMkdir(dir, options);
        if (
          !retargeted &&
          String(dir).startsWith(
            path.join(externalRoot, ".kramme-install-backups") + path.sep,
          )
        ) {
          retargeted = true;
          await fs.unlink(agentsPath);
          await fs.symlink(replacementReferent, agentsPath);
        }
        return result;
      }
    );
    try {
      await assert.rejects(
        () =>
          writeCodexBundle(
            root,
            {
              agentSkills: [],
              codexPlugin: undefined,
              generatedSkills: [],
              knownAgentSkills: new Map(),
              knownCommands: new Set(),
              mcpServers: {},
              prompts: [],
              skillDirs: [],
            },
            {
              agentsHome: path.join(root, "agents-home"),
              confirm: { yes: true },
              pluginName: "agents-retarget-plugin",
            },
          ),
        /destination changed during installation/,
      );
    } finally {
      fs.mkdir = originalMkdir;
    }

    assert.equal(retargeted, true);
    assert.equal(await fs.readlink(agentsPath), replacementReferent);
    assert.equal(await readText(originalReferent), "# Original referent\n");
    assert.equal(
      await readText(replacementReferent),
      "# Replacement referent\n",
    );
    assert.equal(
      await pathExists(path.join(codexRoot, ".kramme-install-state.json")),
      false,
    );
  });
});

test("writer preserves invalid lock directories beside external AGENTS.md referents", async () => {
  await withTempDir(async (root) => {
    const codexRoot = path.join(root, ".codex");
    const agentsPath = path.join(codexRoot, "AGENTS.md");
    const referent = path.join(root, "dotfiles", "AGENTS.md");
    const userNote = path.join(
      path.dirname(referent),
      ".kramme-install-lock",
      "user-notes.txt",
    );
    await writeFile(referent, "# Shared local instructions\n");
    await writeFile(userNote, "keep this directory\n");
    await fs.mkdir(codexRoot, { recursive: true });
    await fs.symlink(
      path.relative(path.dirname(agentsPath), referent),
      agentsPath,
    );

    await assert.rejects(
      () =>
        writeCodexBundle(
          root,
          {
            agentSkills: [],
            codexPlugin: undefined,
            generatedSkills: [],
            knownAgentSkills: new Map(),
            knownCommands: new Set(),
            mcpServers: {},
            prompts: [],
            skillDirs: [],
          },
          {
            agentsHome: path.join(root, "agents-home"),
            confirm: { yes: true },
            lockTimeoutMs: 0,
            pluginName: "agents-external-lock-plugin",
          },
        ),
      /Refusing to reclaim invalid install lock/,
    );

    assert.equal(await readText(userNote), "keep this directory\n");
    assert.equal(await readText(referent), "# Shared local instructions\n");
    assert.equal(
      await pathExists(path.join(codexRoot, ".kramme-install-lock")),
      false,
    );
  });
});

test("writer deduplicates physically identical AGENTS.md lock roots", async () => {
  await withTempDir(async (root) => {
    const physicalParent = path.join(root, "physical");
    const physicalCodexRoot = path.join(physicalParent, ".codex");
    const linkedParent = path.join(root, "linked");
    const agentsPath = path.join(physicalCodexRoot, "AGENTS.md");
    const referent = path.join(physicalCodexRoot, "SHARED.md");
    await fs.mkdir(physicalCodexRoot, { recursive: true });
    await fs.symlink(physicalParent, linkedParent);
    await writeFile(referent, "# Shared local instructions\n");
    await fs.symlink("SHARED.md", agentsPath);

    await writeCodexBundle(
      path.join(linkedParent, ".codex"),
      {
        agentSkills: [],
        codexPlugin: undefined,
        generatedSkills: [],
        knownAgentSkills: new Map(),
        knownCommands: new Set(),
        mcpServers: {},
        prompts: [],
        skillDirs: [],
      },
      {
        agentsHome: path.join(root, "agents-home"),
        confirm: { yes: true },
        lockTimeoutMs: 100,
        pluginName: "agents-lock-alias-plugin",
      },
    );

    assert.equal((await fs.lstat(agentsPath)).isSymbolicLink(), true);
    assert.match(await readText(referent), /BEGIN KRAMME CODEX TOOL MAP/);
    assert.equal(
      await pathExists(path.join(physicalCodexRoot, ".kramme-install-lock")),
      false,
    );
  });
});

test("writer recovers legacy stale locks recorded through a symlink alias", async () => {
  await withTempDir(async (root) => {
    const physicalParent = path.join(root, "physical");
    const linkedParent = path.join(root, "linked");
    const physicalCodexRoot = path.join(physicalParent, ".codex");
    const linkedCodexRoot = path.join(linkedParent, ".codex");
    const token = "legacy-alias-stale";
    const journalPath = path.join(
      linkedCodexRoot,
      ".kramme-install-transactions",
      token,
      "journal.json",
    );
    await fs.mkdir(physicalCodexRoot, { recursive: true });
    await fs.symlink(physicalParent, linkedParent);
    await writeJson(journalPath, {
      version: 1,
      token,
      status: "active",
      records: [],
    });
    await writeJson(
      path.join(physicalCodexRoot, ".kramme-install-lock", "owner.json"),
      {
        version: 1,
        token,
        pid: 2_147_483_647,
        pluginName: "legacy-alias-plugin",
        createdAtMs: 1,
        lockRoots: [linkedCodexRoot],
        transactionRoot: linkedCodexRoot,
        journalPath,
      },
    );

    await writeCodexBundle(
      linkedParent,
      {
        agentSkills: [],
        codexPlugin: undefined,
        generatedSkills: [],
        knownAgentSkills: new Map(),
        knownCommands: new Set(),
        mcpServers: {},
        prompts: [],
        skillDirs: [],
      },
      {
        agentsHome: path.join(root, "agents-home"),
        confirm: { yes: true },
        pluginName: "legacy-alias-plugin",
      },
    );

    assert.equal(
      await pathExists(path.join(physicalCodexRoot, ".kramme-install-lock")),
      false,
    );
    assert.match(
      await readText(path.join(physicalCodexRoot, "AGENTS.md")),
      /BEGIN KRAMME CODEX TOOL MAP/,
    );
  });
});

test("writer rejects hard-linked AGENTS.md without severing the link", async () => {
  await withTempDir(async (root) => {
    const codexRoot = path.join(root, ".codex");
    const agentsPath = path.join(codexRoot, "AGENTS.md");
    const sharedPath = path.join(root, "dotfiles", "AGENTS.md");
    await writeFile(sharedPath, "# Shared local instructions\n");
    await fs.mkdir(codexRoot, { recursive: true });
    await fs.link(sharedPath, agentsPath);
    const originalInode = (await fs.stat(sharedPath)).ino;

    await assert.rejects(
      () =>
        writeCodexBundle(
          root,
          {
            agentSkills: [],
            codexPlugin: undefined,
            generatedSkills: [],
            knownAgentSkills: new Map(),
            knownCommands: new Set(),
            mcpServers: {},
            prompts: [],
            skillDirs: [],
          },
          {
            agentsHome: path.join(root, "agents-home"),
            confirm: { yes: true },
            pluginName: "agents-hard-link-plugin",
          },
        ),
      /hard-linked to another file/,
    );

    assert.equal((await fs.stat(agentsPath)).ino, originalInode);
    assert.equal((await fs.stat(sharedPath)).ino, originalInode);
    assert.equal(await readText(agentsPath), "# Shared local instructions\n");
    assert.equal(await readText(sharedPath), "# Shared local instructions\n");
  });
});

test("writer rejects hard links created after final AGENTS.md staging", async () => {
  await withTempDir(async (root) => {
    const codexRoot = path.join(root, ".codex");
    const agentsPath = path.join(codexRoot, "AGENTS.md");
    const lateLink = path.join(root, "late-hard-link.md");
    await writeFile(agentsPath, "# Local instructions\n");
    const originalMkdir = fs.mkdir;
    let armed = false;
    let injected = false;
    fs.mkdir = /** @type {typeof fs.mkdir} */ (
      async (dir, options) => {
        const result = await originalMkdir(dir, options);
        if (
          armed &&
          !injected &&
          String(dir).startsWith(
            path.join(codexRoot, ".kramme-install-backups") + path.sep,
          )
        ) {
          injected = true;
          await fs.link(agentsPath, lateLink);
        }
        return result;
      }
    );
    try {
      await assert.rejects(
        () =>
          writeCodexBundle(
            root,
            {
              agentSkills: [],
              codexPlugin: undefined,
              generatedSkills: [],
              knownAgentSkills: new Map(),
              knownCommands: new Set(),
              mcpServers: {},
              prompts: [],
              skillDirs: [],
            },
            {
              agentsHome: path.join(root, "agents-home"),
              confirm: { yes: true },
              onInstallPhase(phase) {
                if (phase === "config") armed = true;
              },
              pluginName: "agents-late-hard-link-plugin",
            },
          ),
        /changed during installation/,
      );
    } finally {
      fs.mkdir = originalMkdir;
    }

    assert.equal(injected, true);
    assert.equal(
      (await fs.stat(agentsPath)).ino,
      (await fs.stat(lateLink)).ino,
    );
    assert.equal(await readText(agentsPath), "# Local instructions\n");
    assert.equal(await readText(lateLink), "# Local instructions\n");
    assert.equal(
      await pathExists(path.join(codexRoot, ".kramme-install-state.json")),
      false,
    );
  });
});

test("writer preserves AGENTS.md edits made during bundle finalization", async () => {
  await withTempDir(async (root) => {
    const codexRoot = path.join(root, ".codex");
    const agentsPath = path.join(codexRoot, "AGENTS.md");
    await writeFile(agentsPath, "# Original local instructions\n");

    await writeCodexBundle(root, await createTransactionalBundle(root, "v1"), {
      agentsHome: path.join(root, "agents-home"),
      confirm: { yes: true },
      pluginName: "agents-concurrent-edit-plugin",
      async onInstallPhase(phase) {
        if (phase === "config") {
          await writeFile(agentsPath, "# Concurrent user edit\n");
        }
      },
    });

    assert.match(await readText(agentsPath), /# Concurrent user edit/);
    assert.doesNotMatch(
      await readText(agentsPath),
      /# Original local instructions/,
    );
    assert.match(await readText(agentsPath), /BEGIN KRAMME CODEX TOOL MAP/);
  });
});

test("writer rejects an AGENTS.md edit made after final staging", async () => {
  await withTempDir(async (root) => {
    const codexRoot = path.join(root, ".codex");
    const agentsPath = path.join(codexRoot, "AGENTS.md");
    const backupRoot = path.join(codexRoot, ".kramme-install-backups");
    await writeFile(agentsPath, "# Original local instructions\n");
    const bundle = await createTransactionalBundle(root, "v1");
    const originalMkdir = fs.mkdir;
    let armed = false;
    let injected = false;
    fs.mkdir = /** @type {typeof fs.mkdir} */ (
      async (dir, options) => {
        const result = await originalMkdir(dir, options);
        if (
          armed &&
          !injected &&
          String(dir).startsWith(backupRoot + path.sep)
        ) {
          injected = true;
          await fs.writeFile(
            agentsPath,
            "# Edit after final staging\n",
            "utf8",
          );
        }
        return result;
      }
    );
    try {
      await assert.rejects(
        () =>
          writeCodexBundle(root, bundle, {
            agentsHome: path.join(root, "agents-home"),
            confirm: { yes: true },
            pluginName: "agents-late-edit-plugin",
            onInstallPhase(phase) {
              if (phase === "config") armed = true;
            },
          }),
        /changed during installation/,
      );
    } finally {
      fs.mkdir = originalMkdir;
    }

    assert.equal(injected, true);
    assert.equal(await readText(agentsPath), "# Edit after final staging\n");
    assert.equal(
      await pathExists(path.join(codexRoot, ".kramme-install-state.json")),
      false,
    );
  });
});

test("writer rejects AGENTS.md created after final staging", async () => {
  await withTempDir(async (root) => {
    const codexRoot = path.join(root, ".codex");
    const agentsPath = path.join(codexRoot, "AGENTS.md");
    const stagedAgentsSuffix = `${path.sep}.kramme-install-staging`;
    const userContent = "# Created during installation\n";
    const originalAccess = fs.access;
    let armed = false;
    let stagedAccesses = 0;
    let injected = false;
    fs.access = async (file, mode) => {
      const result = await originalAccess(file, mode);
      if (
        armed &&
        String(file).endsWith(`${path.sep}AGENTS.md`) &&
        String(file).includes(stagedAgentsSuffix)
      ) {
        stagedAccesses += 1;
        if (stagedAccesses === 2) {
          injected = true;
          await writeFile(agentsPath, userContent);
        }
      }
      return result;
    };
    try {
      await assert.rejects(
        () =>
          writeCodexBundle(
            root,
            {
              agentSkills: [],
              codexPlugin: undefined,
              generatedSkills: [],
              knownAgentSkills: new Map(),
              knownCommands: new Set(),
              mcpServers: {},
              prompts: [],
              skillDirs: [],
            },
            {
              agentsHome: path.join(root, "agents-home"),
              confirm: { yes: true },
              pluginName: "agents-late-create-plugin",
              onInstallPhase(phase) {
                if (phase === "config") armed = true;
              },
            },
          ),
        /created during installation/,
      );
    } finally {
      fs.access = originalAccess;
    }

    assert.equal(injected, true);
    assert.equal(await readText(agentsPath), userContent);
    assert.equal(
      await pathExists(path.join(codexRoot, ".kramme-install-state.json")),
      false,
    );
  });
});

test("writer rolls back changes to a symlinked AGENTS.md referent", async () => {
  await withTempDir(async (root) => {
    const codexRoot = path.join(root, ".codex");
    const agentsPath = path.join(codexRoot, "AGENTS.md");
    const referent = path.join(root, "dotfiles", "AGENTS.md");
    const relativeReferent = path.relative(path.dirname(agentsPath), referent);
    await writeFile(referent, "# Shared local instructions\n");
    await fs.mkdir(path.dirname(agentsPath), { recursive: true });
    await fs.symlink(relativeReferent, agentsPath);
    const injectedError = new Error("injected agents phase failure");
    const bundle = await createTransactionalBundle(root, "v1");

    await assert.rejects(
      () =>
        writeCodexBundle(root, bundle, {
          agentsHome: path.join(root, "agents-home"),
          confirm: { yes: true },
          pluginName: "agents-symlink-rollback-plugin",
          onInstallPhase(phase) {
            if (phase === "agents") throw injectedError;
          },
        }),
      (error) => error === injectedError,
    );

    assert.equal((await fs.lstat(agentsPath)).isSymbolicLink(), true);
    assert.equal(await fs.readlink(agentsPath), relativeReferent);
    assert.equal(await readText(referent), "# Shared local instructions\n");
  });
});

test("writer preserves AGENTS.md edits made after publication when rollback runs", async () => {
  await withTempDir(async (root) => {
    const codexRoot = path.join(root, ".codex");
    const agentsPath = path.join(codexRoot, "AGENTS.md");
    const injectedError = new Error("failure after AGENTS.md user edit");
    await writeFile(agentsPath, "# Original local instructions\n");

    await assert.rejects(
      () =>
        writeCodexBundle(
          root,
          {
            agentSkills: [],
            codexPlugin: undefined,
            generatedSkills: [],
            knownAgentSkills: new Map(),
            knownCommands: new Set(),
            mcpServers: {},
            prompts: [],
            skillDirs: [],
          },
          {
            agentsHome: path.join(root, "agents-home"),
            confirm: { yes: true },
            pluginName: "agents-rollback-edit-plugin",
            async onInstallPhase(phase) {
              if (phase !== "agents") return;
              await writeFile(agentsPath, "# User edit after publication\n");
              throw injectedError;
            },
          },
        ),
      (error) => error === injectedError,
    );

    assert.equal(await readText(agentsPath), "# Original local instructions\n");
    const conflictsRoot = path.join(
      codexRoot,
      ".kramme-install-recovery-conflicts",
    );
    const conflictTokens = await fs.readdir(conflictsRoot);
    assert.equal(conflictTokens.length, 1);
    assert.equal(
      await readText(path.join(conflictsRoot, conflictTokens[0], "edited-0")),
      "# User edit after publication\n",
    );
  });
});

test("writer preserves AGENTS.md deletion made after publication when rollback runs", async () => {
  await withTempDir(async (root) => {
    const codexRoot = path.join(root, ".codex");
    const agentsPath = path.join(codexRoot, "AGENTS.md");
    const injectedError = new Error("failure after AGENTS.md user deletion");
    await writeFile(agentsPath, "# Original local instructions\n");

    await assert.rejects(
      () =>
        writeCodexBundle(
          root,
          {
            agentSkills: [],
            codexPlugin: undefined,
            generatedSkills: [],
            knownAgentSkills: new Map(),
            knownCommands: new Set(),
            mcpServers: {},
            prompts: [],
            skillDirs: [],
          },
          {
            agentsHome: path.join(root, "agents-home"),
            confirm: { yes: true },
            pluginName: "agents-rollback-delete-plugin",
            async onInstallPhase(phase) {
              if (phase !== "agents") return;
              const transactionRoot = path.join(
                codexRoot,
                ".kramme-install-transactions",
              );
              const transactionTokens = await fs.readdir(transactionRoot);
              assert.equal(transactionTokens.length, 1);
              const journal = await readJson(
                path.join(
                  transactionRoot,
                  transactionTokens[0],
                  "journal.json",
                ),
              );
              assert.ok(Array.isArray(journal.rollbackTargetExpectations));
              assert.equal(
                /** @type {{target?: unknown}[]} */ (
                  journal.rollbackTargetExpectations
                )[0]?.target,
                agentsPath,
              );
              await fs.rm(agentsPath, { force: true });
              throw injectedError;
            },
          },
        ),
      (error) => error === injectedError,
    );

    assert.equal(await pathExists(agentsPath), false);
  });
});

test("writer preserves AGENTS.md metadata edits made before rollback", async () => {
  await withTempDir(async (root) => {
    const codexRoot = path.join(root, ".codex");
    const agentsPath = path.join(codexRoot, "AGENTS.md");
    const injectedError = new Error("failure after AGENTS.md mode edit");
    await writeFile(agentsPath, "# Original local instructions\n");
    await fs.chmod(agentsPath, 0o600);

    await assert.rejects(
      () =>
        writeCodexBundle(
          root,
          {
            agentSkills: [],
            codexPlugin: undefined,
            generatedSkills: [],
            knownAgentSkills: new Map(),
            knownCommands: new Set(),
            mcpServers: {},
            prompts: [],
            skillDirs: [],
          },
          {
            agentsHome: path.join(root, "agents-home"),
            confirm: { yes: true },
            pluginName: "agents-rollback-mode-plugin",
            async onInstallPhase(phase) {
              if (phase !== "agents") return;
              await fs.chmod(agentsPath, 0o644);
              throw injectedError;
            },
          },
        ),
      (error) => error === injectedError,
    );

    assert.equal(await readText(agentsPath), "# Original local instructions\n");
    assert.equal((await fs.stat(agentsPath)).mode & 0o7777, 0o600);
    const conflictsRoot = path.join(
      codexRoot,
      ".kramme-install-recovery-conflicts",
    );
    const conflictTokens = await fs.readdir(conflictsRoot);
    assert.equal(conflictTokens.length, 1);
    const preservedAgentsPath = path.join(
      conflictsRoot,
      conflictTokens[0],
      "edited-0",
    );
    assert.match(
      await readText(preservedAgentsPath),
      /BEGIN KRAMME CODEX TOOL MAP/,
    );
    assert.equal((await fs.stat(preservedAgentsPath)).mode & 0o7777, 0o644);
  });
});

test("writer rolls back byte-identical state when the AGENTS.md final write fails", async () => {
  await withTempDir(async (root) => {
    const codexRoot = path.join(root, ".codex");
    const agentsPath = path.join(codexRoot, "AGENTS.md");
    const options = {
      agentsHome: path.join(root, "agents-home"),
      confirm: { yes: true },
      pluginName: "agents-final-write-plugin",
    };
    await writeCodexBundle(
      root,
      await createTransactionalBundle(root, "v1"),
      options,
    );
    await writeFile(agentsPath, "# Local instructions\n");
    const replacement = await createTransactionalBundle(root, "v2");
    const before = await readTreeSnapshot(root, {
      exclude: ["fixture-sources"],
    });
    const finalWriteError = Object.assign(
      new Error("injected AGENTS.md final write failure"),
      { code: "ENOSPC" },
    );
    const originalLink = fs.link;
    fs.link = async (source, target) => {
      if (
        target === agentsPath &&
        String(source).includes(".kramme-install-staging")
      ) {
        throw finalWriteError;
      }
      return originalLink(source, target);
    };
    try {
      await assert.rejects(
        () => writeCodexBundle(root, replacement, options),
        (error) => error === finalWriteError,
      );
    } finally {
      fs.link = originalLink;
    }

    assert.deepEqual(
      await readTreeSnapshot(root, { exclude: ["fixture-sources"] }),
      before,
    );
  });
});

test("writer does not require an agent home for Codex-only installs", async () => {
  await withTempDir(async (root) => {
    const agentsHome = path.join(root, "agents-home");
    await writeFile(agentsHome, "reserved for another use\n");

    await writeCodexBundle(
      root,
      {
        agentSkills: [],
        codexPlugin: undefined,
        generatedSkills: [],
        knownAgentSkills: new Map(),
        knownCommands: new Set(),
        mcpServers: {},
        prompts: [{ content: "Codex only", name: "codex-only" }],
        skillDirs: [],
      },
      {
        agentsHome,
        confirm: { yes: true },
        pluginName: "codex-only-plugin",
      },
    );

    assert.equal(await readText(agentsHome), "reserved for another use\n");
    assert.equal(
      await readText(path.join(root, ".codex", "prompts", "codex-only.md")),
      "Codex only\n",
    );
  });
});

test("writer preserves previous install when replacement bundle fails", async () => {
  await withTempDir(async (root) => {
    const agentsHome = path.join(root, "agents-home");
    const options = {
      agentsHome,
      confirm: { yes: true },
      pluginName: "transactional-plugin",
    };
    /** @param {CodexSkillFile} skill @returns {CodexBundle} */
    const bundleWithGeneratedSkill = (skill) => ({
      agentSkills: [],
      codexPlugin: undefined,
      generatedSkills: [skill],
      knownAgentSkills: new Map(),
      knownCommands: new Set(),
      mcpServers: {},
      prompts: [],
      skillDirs: [],
    });
    const stableSkill = path.join(
      root,
      ".codex",
      "skills",
      "stable-skill",
      "SKILL.md",
    );
    const statePath = path.join(root, ".codex", ".kramme-install-state.json");
    const manifestPath = path.join(
      root,
      ".codex",
      ".kramme-install-manifests",
      "transactional-plugin-codex.json",
    );

    await writeCodexBundle(
      root,
      bundleWithGeneratedSkill({
        content: "Stable v1",
        name: "stable-skill",
      }),
      options,
    );
    assert.equal(await readText(stableSkill), "Stable v1\n");
    const stateBefore = await readText(statePath);
    const manifestBefore = await readText(manifestPath);

    await assert.rejects(
      () =>
        writeCodexBundle(
          root,
          bundleWithGeneratedSkill({
            content: "Broken",
            name: "../invalid-skill",
          }),
          options,
        ),
      /Invalid skill name/,
    );

    assert.equal(await readText(stableSkill), "Stable v1\n");
    assert.equal(await readText(statePath), stateBefore);
    assert.equal(await readText(manifestPath), manifestBefore);
  });
});

test("writer removes agent staging when agent skill staging fails", async () => {
  await withTempDir(async (root) => {
    const agentsHome = path.join(root, "agents-home");

    await assert.rejects(
      () =>
        writeCodexBundle(
          root,
          {
            agentSkills: [
              { content: "Broken", name: "../invalid-agent-skill" },
            ],
            codexPlugin: undefined,
            generatedSkills: [],
            knownAgentSkills: new Map(),
            knownCommands: new Set(),
            prompts: [],
            skillDirs: [],
          },
          {
            agentsHome,
            confirm: { yes: true },
            pluginName: "agent-staging-plugin",
          },
        ),
      /Invalid agent skill name/,
    );

    assert.equal(
      await pathExists(path.join(agentsHome, ".kramme-install-staging")),
      false,
    );
  });
});

test("writer preserves previous install when finalization is blocked", async () => {
  await withTempDir(async (root) => {
    const agentsHome = path.join(root, "agents-home");
    const options = {
      agentsHome,
      confirm: { yes: true },
      pluginName: "finalization-plugin",
    };
    /** @param {CodexSkillFile[]} skills @returns {CodexBundle} */
    const bundleWithGeneratedSkills = (skills) => ({
      agentSkills: [],
      codexPlugin: undefined,
      generatedSkills: skills,
      knownAgentSkills: new Map(),
      knownCommands: new Set(),
      mcpServers: {},
      prompts: [],
      skillDirs: [],
    });
    const skillsRoot = path.join(root, ".codex", "skills");
    const stableSkill = path.join(skillsRoot, "stable-skill", "SKILL.md");
    const blockedSkill = path.join(skillsRoot, "blocked-skill");
    const statePath = path.join(root, ".codex", ".kramme-install-state.json");
    const manifestPath = path.join(
      root,
      ".codex",
      ".kramme-install-manifests",
      "finalization-plugin-codex.json",
    );

    await writeCodexBundle(
      root,
      bundleWithGeneratedSkills([
        { content: "Stable v1", name: "stable-skill" },
      ]),
      options,
    );
    assert.equal(await readText(stableSkill), "Stable v1\n");
    const stateBefore = await readText(statePath);
    const manifestBefore = await readText(manifestPath);

    await writeFile(blockedSkill, "blocking file\n");

    await assert.rejects(
      () =>
        writeCodexBundle(
          root,
          bundleWithGeneratedSkills([
            { content: "Blocked", name: "blocked-skill" },
            { content: "Stable v2", name: "stable-skill" },
          ]),
          options,
        ),
      /not a directory/,
    );

    assert.equal(await readText(stableSkill), "Stable v1\n");
    assert.equal(await readText(blockedSkill), "blocking file\n");
    assert.equal(await readText(statePath), stateBefore);
    assert.equal(await readText(manifestPath), manifestBefore);
  });
});

test("writer rolls back every finalized phase byte-for-byte", async () => {
  const phases = [
    "shared-scripts",
    "prompts",
    "codex-skills",
    "agent-skills",
    "hooks",
    "config",
    "agents",
    "manifest",
    "state",
  ];

  for (const [index, phase] of phases.entries()) {
    await withTempDir(async (root) => {
      const agentsHome = path.join(root, "agents-home");
      const options = {
        agentsHome,
        confirm: { yes: true },
        pluginName: "phase-rollback-plugin",
      };
      await writeCodexBundle(
        root,
        await createTransactionalBundle(root, "v1"),
        options,
      );
      const before = await readTreeSnapshot(root, {
        exclude: ["fixture-sources"],
      });
      const injectedError = Object.assign(
        new Error(`injected ${phase} failure`),
        { code: index % 2 === 0 ? "EACCES" : "ENOSPC" },
      );

      await assert.rejects(
        async () =>
          writeCodexBundle(root, await createTransactionalBundle(root, "v2"), {
            ...options,
            async onInstallPhase(currentPhase) {
              if (currentPhase === phase) throw injectedError;
            },
          }),
        (error) => error === injectedError,
      );

      assert.deepEqual(
        await readTreeSnapshot(root, { exclude: ["fixture-sources"] }),
        before,
        `phase ${phase} must restore the complete prior installation`,
      );
    });
  }
});

test("writer serializes concurrent installs and publishes matching ownership", async () => {
  await withTempDir(async (root) => {
    const agentsHome = path.join(root, "agents-home");
    const options = {
      agentsHome,
      confirm: { yes: true },
      pluginName: "serialized-plugin",
    };
    await writeCodexBundle(
      root,
      await createTransactionalBundle(root, "v0"),
      options,
    );

    const firstReached = deferred();
    const releaseFirst = deferred();
    const secondReached = deferred();
    const firstInstall = writeCodexBundle(
      root,
      await createTransactionalBundle(root, "v1"),
      {
        ...options,
        async onInstallPhase(phase) {
          if (phase !== "shared-scripts") return;
          firstReached.resolve();
          await releaseFirst.promise;
        },
      },
    );
    await firstReached.promise;

    const originalMkdir = fs.mkdir;
    let waitingPublicationAttempts = 0;
    let secondInstall = null;
    fs.mkdir = /** @type {typeof fs.mkdir} */ (
      async (dir, mkdirOptions) => {
        if (String(dir).includes(".kramme-install-lock.tmp-")) {
          waitingPublicationAttempts += 1;
        }
        return originalMkdir(dir, mkdirOptions);
      }
    );
    try {
      secondInstall = writeCodexBundle(
        root,
        await createTransactionalBundle(root, "v2"),
        {
          ...options,
          onInstallPhase(phase) {
            if (phase === "shared-scripts") secondReached.resolve();
          },
        },
      );
      assert.equal(
        await Promise.race([
          secondReached.promise.then(() => "entered"),
          delayForTest(100).then(() => "waiting"),
        ]),
        "waiting",
      );
      assert.equal(waitingPublicationAttempts, 0);

      releaseFirst.resolve();
      await Promise.all([firstInstall, secondInstall]);
    } finally {
      releaseFirst.resolve();
      fs.mkdir = originalMkdir;
      await Promise.allSettled(
        secondInstall ? [firstInstall, secondInstall] : [firstInstall],
      );
    }
    assert.equal(
      await readText(path.join(root, ".codex", "prompts", "daily.md")),
      "Prompt v2\n",
    );
    assert.equal(
      await readText(
        path.join(root, ".codex", "skills", "transaction-skill", "SKILL.md"),
      ),
      "Skill v2\n",
    );

    const state =
      /** @type {{ plugins: Record<string, { codex: unknown }> }} */ (
        await readJson(path.join(root, ".codex", ".kramme-install-state.json"))
      );
    const manifest = await readJson(
      path.join(
        root,
        ".codex",
        ".kramme-install-manifests",
        "serialized-plugin-codex.json",
      ),
    );
    assert.deepEqual(state.plugins["serialized-plugin"].codex, manifest);
    assert.equal(
      await pathExists(path.join(root, ".codex", ".kramme-install-lock")),
      false,
    );
  });
});

test("writer serializes installs from different Codex roots sharing one agent home", async () => {
  await withTempDir(async (root) => {
    const firstRoot = path.join(root, "first-output");
    const secondRoot = path.join(root, "second-output");
    const agentsHome = path.join(root, "agents-home");
    const options = {
      agentsHome,
      confirm: { yes: true },
      pluginName: "shared-agent-root-plugin",
    };
    await writeCodexBundle(
      firstRoot,
      await createTransactionalBundle(path.join(root, "first-source"), "v0"),
      options,
    );
    await writeCodexBundle(
      secondRoot,
      await createTransactionalBundle(path.join(root, "second-source"), "v0"),
      options,
    );

    const firstReached = deferred();
    const releaseFirst = deferred();
    const secondReached = deferred();
    const firstInstall = writeCodexBundle(
      firstRoot,
      await createTransactionalBundle(path.join(root, "first-source"), "v1"),
      {
        ...options,
        async onInstallPhase(phase) {
          if (phase !== "shared-scripts") return;
          firstReached.resolve();
          await releaseFirst.promise;
        },
      },
    );
    await firstReached.promise;

    const secondInstall = writeCodexBundle(
      secondRoot,
      await createTransactionalBundle(path.join(root, "second-source"), "v2"),
      {
        ...options,
        onInstallPhase(phase) {
          if (phase === "shared-scripts") secondReached.resolve();
        },
      },
    );
    assert.equal(
      await Promise.race([
        secondReached.promise.then(() => "entered"),
        delayForTest(100).then(() => "waiting"),
      ]),
      "waiting",
    );

    releaseFirst.resolve();
    await Promise.all([firstInstall, secondInstall]);
    assert.equal(
      await readText(
        path.join(agentsHome, "skills", "transaction-agent", "SKILL.md"),
      ),
      "Agent v2\n",
    );
    assert.equal(
      await pathExists(path.join(agentsHome, ".kramme-install-lock")),
      false,
    );
  });
});

test("writer elects one recovery owner across every stale transaction lock", async () => {
  await withTempDir(async (root) => {
    const firstRoot = path.join(root, "a-output");
    const codexRoot = path.join(firstRoot, ".codex");
    const agentsHome = path.join(root, "m-agents");
    const secondRoot = path.join(root, "z-output");
    const token = "multi-root-stale-transaction";
    const promptPath = path.join(codexRoot, "prompts", "daily.md");
    const backupPath = path.join(
      codexRoot,
      "prompts",
      ".kramme-install-backups",
      token,
      "0",
    );
    const journalPath = path.join(
      codexRoot,
      ".kramme-install-transactions",
      token,
      "journal.json",
    );
    const lockRoots = [codexRoot, agentsHome].sort();
    const owner = {
      version: 1,
      token,
      pid: 2_147_483_647,
      pluginName: "multi-root-recovery-plugin",
      createdAtMs: 1,
      lockRoots,
      transactionRoot: codexRoot,
      journalPath,
    };

    await writeFile(backupPath, "stable prompt\n");
    await writeFile(promptPath, "interrupted prompt\n");
    for (const { outputRoot, prompts } of [
      { outputRoot: codexRoot, prompts: ["daily.md"] },
      { outputRoot: path.join(secondRoot, ".codex"), prompts: [] },
    ]) {
      await writeJson(path.join(outputRoot, ".kramme-install-state.json"), {
        version: 1,
        plugins: {
          "multi-root-recovery-plugin": {
            codex: {
              ...emptyPreviousEntries(),
              agentSkillFiles: {
                "transaction-agent": ["SKILL.md"],
              },
              agentSkills: ["transaction-agent"],
              prompts,
            },
          },
        },
      });
    }
    await writeJson(journalPath, {
      version: 1,
      token,
      status: "active",
      records: [
        {
          operation: "backup-rename",
          target: promptPath,
          backup: backupPath,
        },
      ],
    });
    for (const lockRoot of lockRoots) {
      await writeJson(
        path.join(lockRoot, ".kramme-install-lock", "owner.json"),
        owner,
      );
    }

    const firstBundle = await createTransactionalBundle(
      path.join(root, "first-source"),
      "v1",
    );
    const secondBundle = await createTransactionalBundle(
      path.join(root, "second-source"),
      "v2",
    );
    const options = {
      agentsHome,
      confirm: { yes: true },
      pluginName: "multi-root-recovery-plugin",
    };
    const originalLstat = fs.lstat;
    let staleBackupChecks = 0;
    fs.lstat = /** @type {typeof fs.lstat} */ (
      async (file, lstatOptions) => {
        if (file === backupPath) {
          staleBackupChecks += 1;
          await delayForTest(100);
        }
        return originalLstat(file, lstatOptions);
      }
    );
    try {
      await Promise.all([
        writeCodexBundle(firstRoot, firstBundle, options),
        writeCodexBundle(secondRoot, secondBundle, options),
      ]);
    } finally {
      fs.lstat = originalLstat;
    }

    assert.equal(staleBackupChecks, 1);
    for (const lockRoot of lockRoots) {
      assert.equal(
        await pathExists(path.join(lockRoot, ".kramme-install-lock")),
        false,
      );
    }
    assert.equal(
      await pathExists(path.join(codexRoot, ".kramme-install-recovery-claims")),
      false,
    );
  });
});

test("writer never publishes a lock without complete owner metadata", async () => {
  await withTempDir(async (root) => {
    const agentsHome = path.join(root, "agents-home");
    const codexRoot = path.join(root, ".codex");
    const lockDir = path.join(codexRoot, ".kramme-install-lock");
    const options = {
      agentsHome,
      confirm: { yes: true },
      pluginName: "atomic-lock-plugin",
    };
    const bundle = await createTransactionalBundle(root, "v1");
    const originalRename = fs.rename;
    const publicationError = Object.assign(
      new Error("injected lock publication failure"),
      { code: "EIO" },
    );
    fs.rename = async (source, target) => {
      if (target === lockDir && String(source).includes(".tmp-")) {
        throw publicationError;
      }
      return originalRename(source, target);
    };
    try {
      await assert.rejects(
        () => writeCodexBundle(root, bundle, options),
        (error) => error === publicationError,
      );
    } finally {
      fs.rename = originalRename;
    }

    assert.equal(await pathExists(lockDir), false);
    await writeCodexBundle(root, bundle, options);
    assert.equal(await pathExists(lockDir), false);
  });
});

test("stale recovery preserves AGENTS.md deletion recorded after publication", async () => {
  await withTempDir(async (root) => {
    const codexRoot = path.join(root, ".codex");
    const agentsPath = path.join(codexRoot, "AGENTS.md");
    const token = "stale-agents-deletion";
    const backupPath = path.join(
      codexRoot,
      ".kramme-install-backups",
      token,
      "0",
    );
    const journalPath = path.join(
      codexRoot,
      ".kramme-install-transactions",
      token,
      "journal.json",
    );
    const owner = {
      version: 1,
      token,
      pid: 2_147_483_647,
      pluginName: "stale-agents-deletion-plugin",
      createdAtMs: 1,
      lockRoots: [codexRoot],
      transactionRoot: codexRoot,
      journalPath,
    };
    const installedContent = [
      "# Original local instructions",
      "",
      "<!-- BEGIN KRAMME CODEX TOOL MAP -->",
      "interrupted install",
      "<!-- END KRAMME CODEX TOOL MAP -->",
      "",
    ].join("\n");

    await writeFile(backupPath, "# Original local instructions\n");
    await writeJson(journalPath, {
      version: 1,
      token,
      status: "active",
      records: [
        {
          operation: "backup-rename",
          target: agentsPath,
          backup: backupPath,
        },
      ],
      rollbackTargetExpectations: [
        {
          target: agentsPath,
          contentBase64: Buffer.from(installedContent).toString("base64"),
          metadata: null,
        },
      ],
    });
    await writeJson(
      path.join(codexRoot, ".kramme-install-lock", "owner.json"),
      owner,
    );

    const interruption = new Error("stop after stale AGENTS.md recovery");
    await assert.rejects(
      () =>
        writeCodexBundle(
          root,
          {
            agentSkills: [],
            codexPlugin: undefined,
            generatedSkills: [],
            knownAgentSkills: new Map(),
            knownCommands: new Set(),
            mcpServers: {},
            prompts: [],
            skillDirs: [],
          },
          {
            agentsHome: path.join(root, "agents-home"),
            confirm: { yes: true },
            pluginName: owner.pluginName,
            onInstallPhase(phase) {
              if (phase === "shared-scripts") throw interruption;
            },
          },
        ),
      (error) => error === interruption,
    );

    assert.equal(await pathExists(agentsPath), false);
    assert.equal(await pathExists(journalPath), false);
    assert.equal(await pathExists(backupPath), false);
  });
});

test("writer recovers a stale owned journal before starting a new transaction", async () => {
  await withTempDir(async (root) => {
    const agentsHome = path.join(root, "agents-home");
    const codexRoot = path.join(root, ".codex");
    const options = {
      agentsHome,
      confirm: { yes: true },
      pluginName: "stale-lock-plugin",
    };
    await writeCodexBundle(
      root,
      await createTransactionalBundle(root, "v1"),
      options,
    );
    const before = await readTreeSnapshot(root, {
      exclude: ["fixture-sources"],
    });

    const token = "stale-owned-transaction";
    const promptPath = path.join(codexRoot, "prompts", "daily.md");
    const backupPath = path.join(
      codexRoot,
      "prompts",
      ".kramme-install-backups",
      token,
      "0",
    );
    await fs.mkdir(path.dirname(backupPath), { recursive: true });
    await fs.rename(promptPath, backupPath);
    await writeFile(promptPath, "interrupted output\n");
    const journalPath = path.join(
      codexRoot,
      ".kramme-install-transactions",
      token,
      "journal.json",
    );
    await writeJson(journalPath, {
      version: 1,
      token,
      records: [
        {
          operation: "backup-rename",
          target: promptPath,
          backup: backupPath,
        },
      ],
    });
    await writeJson(
      path.join(codexRoot, ".kramme-install-lock", "owner.json"),
      {
        version: 1,
        token,
        pid: 2_147_483_647,
        pluginName: options.pluginName,
        createdAtMs: 1,
        journalPath,
      },
    );

    const interruption = Object.assign(new Error("interrupted again"), {
      code: "EINTR",
    });
    await assert.rejects(
      async () =>
        writeCodexBundle(root, await createTransactionalBundle(root, "v2"), {
          ...options,
          onInstallPhase(phase) {
            if (phase === "shared-scripts") throw interruption;
          },
        }),
      (error) => error === interruption,
    );
    const recoveryConflictsRoot = path.join(
      codexRoot,
      "prompts",
      ".kramme-install-recovery-conflicts",
    );
    assert.equal(
      await readText(path.join(recoveryConflictsRoot, token, "0")),
      "interrupted output\n",
    );
    assert.deepEqual(
      await readTreeSnapshot(root, {
        exclude: [
          "fixture-sources",
          path.relative(root, recoveryConflictsRoot),
        ],
      }),
      before,
    );
  });
});

test("writer releases the recovery claim when stale recovery fails", async () => {
  await withTempDir(async (root) => {
    const codexRoot = path.join(root, ".codex");
    const agentsHome = path.join(root, "agents-home");
    const token = "invalid-stale-transaction";
    const journalPath = path.join(
      codexRoot,
      ".kramme-install-transactions",
      token,
      "journal.json",
    );
    const claimPath = path.join(
      codexRoot,
      ".kramme-install-recovery-claims",
      token,
    );
    const owner = {
      version: 1,
      token,
      pid: 2_147_483_647,
      pluginName: "claim-cleanup-plugin",
      createdAtMs: 1,
      lockRoots: [codexRoot],
      transactionRoot: codexRoot,
      journalPath,
    };
    const bundle = {
      agentSkills: [],
      codexPlugin: undefined,
      generatedSkills: [],
      knownAgentSkills: new Map(),
      knownCommands: new Set(),
      mcpServers: {},
      prompts: [],
      skillDirs: [],
    };
    const options = {
      agentsHome,
      confirm: { yes: true },
      lockTimeoutMs: 100,
      pluginName: owner.pluginName,
    };

    await writeJson(journalPath, {
      version: 999,
      token,
      records: [],
    });
    await writeJson(
      path.join(codexRoot, ".kramme-install-lock", "owner.json"),
      owner,
    );

    await assert.rejects(
      () => writeCodexBundle(root, bundle, options),
      /Refusing to recover invalid install journal/,
    );
    assert.equal(await pathExists(claimPath), false);

    await writeJson(journalPath, {
      version: 1,
      token,
      status: "active",
      records: [],
    });
    await writeCodexBundle(root, bundle, options);
    assert.equal(await pathExists(claimPath), false);
    assert.equal(
      await pathExists(path.join(codexRoot, ".kramme-install-lock")),
      false,
    );
  });
});

test("writer elects one stale-journal recovery owner", async () => {
  await withTempDir(async (root) => {
    const agentsHome = path.join(root, "agents-home");
    const codexRoot = path.join(root, ".codex");
    const options = {
      agentsHome,
      confirm: { yes: true },
      pluginName: "contended-recovery-plugin",
    };
    await writeCodexBundle(
      root,
      await createTransactionalBundle(path.join(root, "initial-source"), "v1"),
      options,
    );

    const token = "contended-stale-transaction";
    const promptPath = path.join(codexRoot, "prompts", "daily.md");
    const backupPath = path.join(
      codexRoot,
      "prompts",
      ".kramme-install-backups",
      token,
      "0",
    );
    await fs.mkdir(path.dirname(backupPath), { recursive: true });
    await fs.rename(promptPath, backupPath);
    await writeFile(promptPath, "interrupted output\n");
    const journalPath = path.join(
      codexRoot,
      ".kramme-install-transactions",
      token,
      "journal.json",
    );
    await writeJson(journalPath, {
      version: 1,
      token,
      status: "active",
      records: [
        {
          operation: "backup-rename",
          target: promptPath,
          backup: backupPath,
        },
      ],
    });
    await writeJson(
      path.join(codexRoot, ".kramme-install-lock", "owner.json"),
      {
        version: 1,
        token,
        pid: 2_147_483_647,
        pluginName: options.pluginName,
        createdAtMs: 1,
        transactionRoot: codexRoot,
        journalPath,
      },
    );

    const firstBundle = await createTransactionalBundle(
      path.join(root, "first-source"),
      "v2",
    );
    const secondBundle = await createTransactionalBundle(
      path.join(root, "second-source"),
      "v3",
    );
    const originalLstat = fs.lstat;
    let staleBackupChecks = 0;
    fs.lstat = /** @type {typeof fs.lstat} */ (
      async (file, lstatOptions) => {
        if (file === backupPath) {
          staleBackupChecks += 1;
          await delayForTest(100);
        }
        return originalLstat(file, lstatOptions);
      }
    );
    try {
      await Promise.all([
        writeCodexBundle(root, firstBundle, options),
        writeCodexBundle(root, secondBundle, options),
      ]);
    } finally {
      fs.lstat = originalLstat;
    }

    assert.equal(staleBackupChecks, 1);
    assert.equal(
      await pathExists(path.join(codexRoot, ".kramme-install-lock")),
      false,
    );
    assert.equal(
      await pathExists(path.join(codexRoot, ".kramme-install-recovery-claims")),
      false,
    );
  });
});

test("writer retains committed recovery state when transaction cleanup fails", async () => {
  await withTempDir(async (root) => {
    const agentsHome = path.join(root, "agents-home");
    const codexRoot = path.join(root, ".codex");
    const options = {
      agentsHome,
      confirm: { yes: true },
      pluginName: "commit-cleanup-plugin",
    };
    await writeCodexBundle(
      root,
      await createTransactionalBundle(root, "v1"),
      options,
    );

    const originalRm = fs.rm;
    const cleanupError = Object.assign(new Error("injected cleanup failure"), {
      code: "EIO",
    });
    let failCleanup = false;
    let cleanupFailed = false;
    const replacementBundle = await createTransactionalBundle(root, "v2");
    fs.rm = async (target, rmOptions) => {
      if (
        failCleanup &&
        !cleanupFailed &&
        String(target).includes(".kramme-install-backups")
      ) {
        cleanupFailed = true;
        throw cleanupError;
      }
      return originalRm(target, rmOptions);
    };
    try {
      await assert.rejects(
        () =>
          writeCodexBundle(root, replacementBundle, {
            ...options,
            onInstallPhase(phase) {
              if (phase === "state") failCleanup = true;
            },
          }),
        (error) => {
          assert.ok(error instanceof Error);
          assert.equal(error.cause, cleanupError);
          assert.match(error.message, /committed, but cleanup failed/);
          return true;
        },
      );
    } finally {
      fs.rm = originalRm;
    }

    const lockPaths = [
      path.join(codexRoot, ".kramme-install-lock"),
      path.join(agentsHome, ".kramme-install-lock"),
    ];
    for (const lockPath of lockPaths) {
      assert.equal(await pathExists(lockPath), true);
    }
    const ownerPath = path.join(lockPaths[0], "owner.json");
    const owner = /** @type {{ journalPath: string }} */ (
      await readJson(ownerPath)
    );
    const journal = await readJson(owner.journalPath);
    assert.equal(journal.status, "committed");
    assert.equal(
      await readText(path.join(codexRoot, "prompts", "daily.md")),
      "Prompt v2\n",
    );

    for (const lockPath of lockPaths) {
      const lockOwnerPath = path.join(lockPath, "owner.json");
      await writeJson(lockOwnerPath, {
        ...(await readJson(lockOwnerPath)),
        pid: 2_147_483_647,
      });
    }
    await writeCodexBundle(
      root,
      await createTransactionalBundle(root, "v3"),
      options,
    );
    assert.equal(
      await readText(path.join(codexRoot, "prompts", "daily.md")),
      "Prompt v3\n",
    );
    for (const lockPath of lockPaths) {
      assert.equal(await pathExists(lockPath), false);
    }
  });
});

test("writer reports rollback failures and retains the owned recovery lock", async () => {
  await withTempDir(async (root) => {
    const agentsHome = path.join(root, "agents-home");
    const options = {
      agentsHome,
      confirm: { yes: true },
      pluginName: "rollback-reporting-plugin",
    };
    await writeCodexBundle(
      root,
      await createTransactionalBundle(root, "v1"),
      options,
    );

    const originalRename = fs.rename;
    const installError = new Error("injected finalization failure");
    const rollbackError = Object.assign(
      new Error("injected rollback I/O failure"),
      {
        code: "EIO",
      },
    );
    let failBackupRestore = false;
    fs.rename = async (source, target) => {
      if (
        failBackupRestore &&
        String(source).includes(".kramme-install-backups")
      ) {
        throw rollbackError;
      }
      return originalRename(source, target);
    };
    try {
      await assert.rejects(
        async () =>
          writeCodexBundle(root, await createTransactionalBundle(root, "v2"), {
            ...options,
            onInstallPhase(phase) {
              if (phase !== "prompts") return;
              failBackupRestore = true;
              throw installError;
            },
          }),
        (error) => {
          assert.ok(error instanceof Error);
          assert.equal(error.cause, installError);
          assert.match(
            error.message,
            /Rollback failed for install transaction/,
          );
          assert.match(error.message, /injected rollback I\/O failure/);
          return true;
        },
      );
    } finally {
      fs.rename = originalRename;
    }
    assert.equal(
      await pathExists(path.join(root, ".codex", ".kramme-install-lock")),
      true,
    );
  });
});

/**
 * @param {string} root
 * @param {string} version
 * @returns {Promise<import("../../scripts/convert-plugin/contracts").CodexBundle>}
 */
async function createTransactionalBundle(root, version) {
  const sourcesRoot = path.join(root, "fixture-sources");
  const sharedScript = path.join(sourcesRoot, "shared.js");
  const hookSourceDir = path.join(sourcesRoot, "hooks");
  await writeFile(
    sharedScript,
    `module.exports = ${JSON.stringify(version)};\n`,
  );
  await writeFile(
    path.join(hookSourceDir, "transaction-hook.sh"),
    `#!/bin/sh\necho ${version}\n`,
  );
  const pluginVersion = version.replace(/\D/g, "") || "0";
  return {
    agentSkills: [{ content: `Agent ${version}`, name: "transaction-agent" }],
    codexPlugin: {
      name: "transaction-hooks",
      marketplaceName: "transaction-hooks",
      version: `1.0.${pluginVersion}`,
      manifest: {
        name: "transaction-hooks",
        version: `1.0.${pluginVersion}`,
        description: `Transaction hooks ${version}`,
        hooks: "./hooks/hooks.json",
      },
      hooks: { PreToolUse: [] },
      hookSourceDir,
      sharedScriptDirs: [],
      sharedScriptFiles: [
        { sourceFile: sharedScript, targetPath: "scripts/shared.js" },
      ],
    },
    generatedSkills: [
      { content: `Skill ${version}`, name: "transaction-skill" },
    ],
    knownAgentSkills: new Map(),
    knownCommands: new Set(),
    mcpServers: {
      transaction: { command: "echo", args: [version] },
    },
    prompts: [{ content: `Prompt ${version}`, name: "daily" }],
    skillDirs: [],
  };
}

/**
 * @param {string} root
 * @param {{exclude?: string[]}} [options]
 * @param {string} [prefix]
 * @returns {Promise<Record<string, {content?: string, mode?: number, target?: string, type: string}>>}
 */
async function readTreeSnapshot(root, { exclude = [] } = {}, prefix = "") {
  const snapshot =
    /** @type {Record<string, {content?: string, mode?: number, target?: string, type: string}>} */ ({});
  const entries = await fs.readdir(root, { withFileTypes: true });
  entries.sort((left, right) => left.name.localeCompare(right.name));
  for (const entry of entries) {
    const relativePath = prefix ? `${prefix}/${entry.name}` : entry.name;
    if (exclude.includes(relativePath)) continue;
    const file = path.join(root, entry.name);
    const stats = await fs.lstat(file);
    if (entry.isDirectory()) {
      snapshot[`${relativePath}/`] = { mode: stats.mode & 0o777, type: "dir" };
      Object.assign(
        snapshot,
        await readTreeSnapshot(file, { exclude }, relativePath),
      );
    } else if (entry.isSymbolicLink()) {
      snapshot[relativePath] = {
        target: await fs.readlink(file),
        type: "symlink",
      };
    } else if (entry.isFile()) {
      snapshot[relativePath] = {
        content: (await fs.readFile(file)).toString("base64"),
        mode: stats.mode & 0o777,
        type: "file",
      };
    }
  }
  return snapshot;
}

/** @returns {{promise: Promise<void>, resolve: () => void}} */
function deferred() {
  let resolve = () => {};
  const promise = /** @type {Promise<void>} */ (
    new Promise((resolvePromise) => {
      resolve = () => resolvePromise();
    })
  );
  return { promise, resolve };
}

/** @param {number} milliseconds */
function delayForTest(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

/** @param {string} file @param {string} attribute @param {string} value */
function setExtendedAttribute(file, attribute, value) {
  if (process.platform === "darwin") {
    return spawnSync("xattr", ["-w", attribute, value, file], {
      encoding: "utf8",
    });
  }
  return spawnSync(
    "python3",
    [
      "-c",
      "import os,sys; os.setxattr(sys.argv[1], sys.argv[2], sys.argv[3].encode())",
      file,
      attribute,
      value,
    ],
    { encoding: "utf8" },
  );
}

/** @param {string} file @param {string} attribute */
function getExtendedAttribute(file, attribute) {
  if (process.platform === "darwin") {
    return spawnSync("xattr", ["-p", attribute, file], { encoding: "utf8" });
  }
  return spawnSync(
    "python3",
    [
      "-c",
      "import os,sys; sys.stdout.buffer.write(os.getxattr(sys.argv[1], sys.argv[2]))",
      file,
      attribute,
    ],
    { encoding: "utf8" },
  );
}

/** @param {string} file @param {string} attribute */
function removeExtendedAttribute(file, attribute) {
  if (process.platform === "darwin") {
    return spawnSync("xattr", ["-d", attribute, file], { encoding: "utf8" });
  }
  return spawnSync(
    "python3",
    [
      "-c",
      "import os,sys; os.removexattr(sys.argv[1], sys.argv[2])",
      file,
      attribute,
    ],
    { encoding: "utf8" },
  );
}

/** @param {string} file */
function listExtendedAttributes(file) {
  if (process.platform === "darwin") {
    return spawnSync("xattr", [file], { encoding: "utf8" });
  }
  return spawnSync(
    "python3",
    ["-c", "import os,sys; print('\\n'.join(os.listxattr(sys.argv[1])))", file],
    { encoding: "utf8" },
  );
}

/** @param {string} file @returns {Promise<JsonObject>} */
async function readJson(file) {
  return /** @type {JsonObject} */ (JSON.parse(await readText(file)));
}

/** @param {string} root @param {string} [prefix] @returns {Promise<Record<string, string>>} */
async function readFileTree(root, prefix = "") {
  /** @type {Record<string, string>} */
  const tree = {};
  const entries = await fs.readdir(root, { withFileTypes: true });
  entries.sort((left, right) => left.name.localeCompare(right.name));
  for (const entry of entries) {
    const relativePath = prefix ? `${prefix}/${entry.name}` : entry.name;
    const file = path.join(root, entry.name);
    if (entry.isDirectory()) {
      Object.assign(tree, await readFileTree(file, relativePath));
    } else if (entry.isFile()) {
      tree[relativePath] = await readText(file);
    }
  }
  return tree;
}
