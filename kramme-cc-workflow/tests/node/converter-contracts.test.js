"use strict";

const assert = require("node:assert/strict");
const fs = require("fs/promises");
const os = require("os");
const path = require("path");
const test = require("node:test");

const {
  stageCodexBundleOutput,
} = require("../../scripts/convert-plugin/codex-bundle-output");
const {
  stageCodexHookPluginBundle,
} = require("../../scripts/convert-plugin/codex-hook-plugin-writer");
const {
  convertClaudeToCodex,
} = require("../../scripts/convert-plugin/codex-transformer");
const {
  installStagedDir,
  preflightStagedDirInstall,
  pruneStaleManagedFiles,
} = require("../../scripts/convert-plugin/install-staging");
const {
  loadInstallState,
} = require("../../scripts/convert-plugin/install-state");

test("install state rebuild sanitizes legacy manifests and managed file paths", async () => {
  await withTempDir(async (root) => {
    await writeJson(
      path.join(
        root,
        ".kramme-install-manifests",
        `${encodeURIComponent("Demo Plugin")}-codex.json`,
      ),
      {
        agentSkillFiles: {
          reviewer: ["notes.md", "SKILL.md", "notes.md"],
        },
        agentSkills: [" reviewer "],
        hookMarketplaces: [" .kramme-plugin-marketplaces/demo "],
        pluginCaches: "not an array",
        prompts: [" prompt.md ", "", null],
        skillFiles: {
          " ": ["ignored.md"],
          alpha: [
            "SKILL.md",
            "docs\\guide.md",
            "docs/guide.md",
            "../escape.md",
            "/absolute.md",
            "nested//bad.md",
            "nested/../bad.md",
            null,
          ],
          beta: "not an array",
        },
        skills: [" alpha ", "beta"],
        updatedAtMs: "42",
      },
    );

    const { fromDisk, state } = await loadInstallState(root);

    assert.equal(fromDisk, false);
    assert.deepEqual(state.plugins["Demo Plugin"].codex, {
      agentSkillFiles: {
        reviewer: ["SKILL.md", "notes.md"],
      },
      agentSkills: ["reviewer"],
      hookMarketplaces: [".kramme-plugin-marketplaces/demo"],
      pluginCaches: [],
      prompts: ["prompt.md"],
      skillFiles: {
        alpha: ["SKILL.md", "docs/guide.md"],
        beta: [],
      },
      skills: ["alpha", "beta"],
      updatedAtMs: 42,
    });
  });
});

test("transformer filters non-codex skills and paired commands before conversion", () => {
  const bundle = convertClaudeToCodex({
    agents: [],
    commands: [
      {
        body: "Should not be generated.",
        name: "Claude Only",
        sourcePath: "/plugin/commands/claude-only.md",
      },
      {
        body: "Run /codex-tool before finishing.",
        name: "Extra Command",
        sourcePath: "/plugin/commands/extra-command.md",
      },
    ],
    manifest: { name: "demo-plugin", version: "1.0.0" },
    root: "/plugin",
    skills: [
      {
        body: "Codex instructions.",
        description: "Available in Codex.",
        name: "Codex Tool",
        platforms: ["codex"],
        sourceDir: "/plugin/skills/codex-tool",
      },
      {
        body: "Claude-only instructions.",
        description: "Not available in Codex.",
        name: "Claude Only",
        platforms: ["claude"],
        sourceDir: "/plugin/skills/claude-only",
      },
    ],
  });

  assert.deepEqual(
    bundle.skillDirs.map((skill) => skill.name),
    ["Codex Tool"],
  );
  assert.deepEqual(
    bundle.generatedSkills.map((skill) => skill.name),
    ["extra-command"],
  );
  assert.equal(bundle.knownCommands.has("codex-tool"), true);
  assert.equal(bundle.knownCommands.has("extra-command"), true);
  assert.equal(bundle.knownCommands.has("claude-only"), false);
  assert.match(bundle.generatedSkills[0].content, /\$codex-tool/);
});

test("install staging treats stale managed files as removable without overwriting local files", async () => {
  await withTempDir(async (root) => {
    const stagedDir = path.join(root, "staged");
    const targetDir = path.join(root, "target");
    const previousManagedFiles = ["notes/old.md"];
    const currentManagedFiles = ["notes"];

    await writeFile(path.join(stagedDir, "notes"), "new notes");
    await writeFile(path.join(targetDir, "notes", "local.md"), "local notes");

    await assert.rejects(
      () =>
        preflightStagedDirInstall(stagedDir, targetDir, {
          currentManagedFiles,
          label: "skill demo",
          previousManagedFiles,
        }),
      /conflicts with staged file notes/,
    );

    await fs.rm(targetDir, { force: true, recursive: true });
    await writeFile(path.join(targetDir, "notes", "old.md"), "old notes");

    await preflightStagedDirInstall(stagedDir, targetDir, {
      currentManagedFiles,
      label: "skill demo",
      previousManagedFiles,
    });
    await pruneStaleManagedFiles(
      targetDir,
      previousManagedFiles,
      currentManagedFiles,
      { label: "skill demo" },
    );
    await installStagedDir(stagedDir, targetDir);

    assert.equal(await readText(path.join(targetDir, "notes")), "new notes");
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
      "Run /extra-command before review.\n",
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
        knownAgentSkills: new Map(),
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
    assert.equal(
      await readText(
        path.join(codexStagingRoot, "skills", "source-skill", "notes.md"),
      ),
      "Run $extra-command before review.\n",
    );
    assert.deepEqual(
      new Set(stagedBundle.stagedSkillFiles["source-skill"]),
      new Set(["SKILL.md", "notes.md"]),
    );
    assert.deepEqual(
      new Set(stagedBundle.stagedSkillFiles["extra-command"]),
      new Set(["SKILL.md"]),
    );
    assert.equal(stagedBundle.agentSkillsRoot, path.join(agentsHome, "skills"));
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

async function withTempDir(fn) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "converter-contracts-"));
  try {
    return await fn(root);
  } finally {
    await fs.rm(root, { force: true, recursive: true });
  }
}

async function writeJson(file, data) {
  await writeFile(file, JSON.stringify(data, null, 2) + "\n");
}

async function writeFile(file, content) {
  await fs.mkdir(path.dirname(file), { recursive: true });
  await fs.writeFile(file, content, "utf8");
}

async function readText(file) {
  return fs.readFile(file, "utf8");
}

async function pathExists(file) {
  try {
    await fs.access(file);
    return true;
  } catch {
    return false;
  }
}
