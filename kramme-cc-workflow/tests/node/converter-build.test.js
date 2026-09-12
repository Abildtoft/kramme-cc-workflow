"use strict";

const assert = require("node:assert/strict");
const { execFileSync } = require("node:child_process");
const fs = require("fs/promises");
const path = require("path");
const test = require("node:test");

const {
  MARKETPLACE_MANIFEST,
  buildCodexMarketplace,
} = require("../../scripts/convert-plugin/codex-plugin-builder");
const {
  codexPluginRootExpression,
  hasClaudePluginRootReference,
  rewriteCodexPluginRootReferences,
} = require("../../scripts/convert-plugin/codex-shared-scripts");
const {
  convertClaudeToCodex,
} = require("../../scripts/convert-plugin/codex-transformer");
const { loadClaudePlugin } = require("../../scripts/convert-plugin/loader");

const {
  emptyCodexBundle,
  fixtureCodexPluginPackage,
  pathExists,
  readText,
  withTempDir,
  writeFile,
  writeJson,
} = require("./converter-test-helpers");

/** @param {string} name */
function hookControlSkill(name) {
  return {
    body: "Hook control.",
    description: "Hook control.",
    name,
    sourceDir: `/plugin/skills/${name}`,
  };
}

test("plugin root rewriting replaces every Claude plugin root form with the cache expression", () => {
  const rootExpression = codexPluginRootExpression(
    "plugins/cache/demo/demo/1.2.3",
  );
  assert.equal(
    rootExpression,
    "${CODEX_HOME:-$HOME/.codex}/plugins/cache/demo/demo/1.2.3",
  );

  const source = [
    'RESOLVED=$("${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh" --strict)',
    '[ -x "${CLAUDE_PLUGIN_ROOT:-}/scripts/collect-review-diff.sh" ]',
    'export PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$CODEX_HOME}"',
    "$CLAUDE_PLUGIN_ROOT/skills/demo/scripts/run.sh",
    "not found under CLAUDE_PLUGIN_ROOT",
    "$CLAUDE_PLUGIN_ROOT_OTHER stays",
  ].join("\n");

  assert.equal(
    rewriteCodexPluginRootReferences(source, rootExpression),
    [
      `RESOLVED=$("${rootExpression}/scripts/collect-review-diff.sh" --strict)`,
      `[ -x "${rootExpression}/scripts/collect-review-diff.sh" ]`,
      `export PLUGIN_ROOT="${rootExpression}"`,
      `${rootExpression}/skills/demo/scripts/run.sh`,
      "not found under CLAUDE_PLUGIN_ROOT",
      "$CLAUDE_PLUGIN_ROOT_OTHER stays",
    ].join("\n"),
  );
  assert.equal(hasClaudePluginRootReference(source), true);
  assert.equal(
    hasClaudePluginRootReference(
      rewriteCodexPluginRootReferences(source, rootExpression),
    ),
    false,
  );
});

test("the cache expression resolves through CODEX_HOME and falls back to the home directory", () => {
  const rootExpression = codexPluginRootExpression(
    "plugins/cache/demo/demo/1.0.0",
  );
  const command = `printf '%s' "${rootExpression}/scripts/x.sh"`;
  const baseEnv = { PATH: process.env.PATH ?? "", HOME: "/tmp/fixture home" };

  assert.equal(
    execFileSync("bash", ["-c", command], {
      encoding: "utf8",
      env: { ...baseEnv, CODEX_HOME: "/tmp/custom codex" },
    }),
    "/tmp/custom codex/plugins/cache/demo/demo/1.0.0/scripts/x.sh",
  );
  assert.equal(
    execFileSync("bash", ["-c", command], { encoding: "utf8", env: baseEnv }),
    "/tmp/fixture home/.codex/plugins/cache/demo/demo/1.0.0/scripts/x.sh",
  );
});

test("plugin package describes the native Codex plugin manifest", () => {
  const mcpServers = { "demo-server": { command: "demo", args: ["--serve"] } };
  const plugin = {
    agents: [],
    commands: [],
    hooks: { hooks: { PreToolUse: [] } },
    manifest: {
      author: { name: "Fixture" },
      description: `First line\nsecond line ${"x".repeat(1100)}`,
      name: "Demo Plugin",
      version: "1.0.0",
    },
    mcpServers,
    root: "/plugin",
    skills: [
      hookControlSkill("kramme:hooks:toggle"),
      hookControlSkill("kramme:hooks:configure-links"),
    ],
  };

  const { codexPlugin } = convertClaudeToCodex(plugin);
  assert.equal(codexPlugin.name, "demo-plugin");
  assert.equal(codexPlugin.marketplaceName, "demo-plugin");
  assert.equal(codexPlugin.version, "1.0.0");
  assert.equal(
    codexPlugin.cacheRelativePath,
    "plugins/cache/demo-plugin/demo-plugin/1.0.0",
  );
  assert.equal(
    codexPlugin.rootExpression,
    "${CODEX_HOME:-$HOME/.codex}/plugins/cache/demo-plugin/demo-plugin/1.0.0",
  );
  assert.equal(codexPlugin.hookSourceDir, path.join("/plugin", "hooks"));
  assert.deepEqual(codexPlugin.hooks, plugin.hooks);
  assert.deepEqual(Object.keys(codexPlugin.manifest), [
    "name",
    "version",
    "description",
    "skills",
    "hooks",
    "mcpServers",
    "author",
  ]);
  assert.equal(codexPlugin.manifest.skills, "./skills/");
  assert.equal(codexPlugin.manifest.hooks, "./hooks/hooks.json");
  assert.deepEqual(codexPlugin.manifest.mcpServers, mcpServers);
  assert.notEqual(codexPlugin.manifest.mcpServers, mcpServers);
  assert.deepEqual(codexPlugin.manifest.author, { name: "Fixture" });
  assert.match(codexPlugin.manifest.description, /^First line second line /);
  assert.match(codexPlugin.manifest.description, /\.\.\.$/);
  assert.equal(codexPlugin.manifest.description.includes("\n"), false);
  assert.ok(codexPlugin.manifest.description.length <= 1024);

  const withoutHooks = convertClaudeToCodex({
    ...plugin,
    hooks: undefined,
    manifest: { name: "demo-plugin", version: "2.0.0" },
    mcpServers: {},
  }).codexPlugin;
  assert.equal(withoutHooks.hooks, undefined);
  assert.deepEqual(withoutHooks.manifest, {
    description: "Converted from the demo-plugin Claude Code plugin.",
    name: "demo-plugin",
    skills: "./skills/",
    version: "2.0.0",
  });

  for (const control of plugin.skills) {
    for (const disposition of ["missing", "platform-filtered"]) {
      const skills = plugin.skills.flatMap((skill) => {
        if (skill !== control) return [skill];
        return disposition === "missing"
          ? []
          : [{ ...skill, platforms: ["claude-code"] }];
      });
      const ineligible = convertClaudeToCodex({ ...plugin, skills });
      const label = `${control.name} ${disposition}`;
      assert.equal(ineligible.codexPlugin.hooks, undefined, label);
      assert.equal(ineligible.codexPlugin.manifest.hooks, undefined, label);
      assert.ok(ineligible.sharedScriptDirs.length > 0, label);
    }
  }

  assert.throws(
    () =>
      convertClaudeToCodex({
        ...plugin,
        manifest: { name: "demo-plugin", version: "../escape" },
      }),
    /cannot name a Codex plugin cache directory/,
  );
});

test("build writes a marketplace with skills, shared runtime, and rewritten plugin root references", async () => {
  await withTempDir(async (root) => {
    const pluginRoot = path.join(root, "plugin");
    const outputRoot = path.join(root, "marketplace");
    await writeJson(path.join(pluginRoot, ".claude-plugin", "plugin.json"), {
      name: "build-plugin",
      version: "3.1.4",
    });
    await writeFile(
      path.join(pluginRoot, "skills", "kramme:demo:run", "SKILL.md"),
      [
        "---",
        "name: kramme:demo:run",
        "description: Run the demo.",
        "disable-model-invocation: false",
        "user-invocable: true",
        "---",
        '"${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh" --strict',
        '[ -x "${CLAUDE_PLUGIN_ROOT:-}/skills/kramme:demo:run/scripts/run.sh" ]',
        "Use AskUserQuestion to ask about scope.",
        "",
      ].join("\n"),
    );
    await writeFile(
      path.join(
        pluginRoot,
        "skills",
        "kramme:demo:run",
        "references",
        "notes.md",
      ),
      "Helper lives at ${CLAUDE_PLUGIN_ROOT}/scripts/dev-server/detect-url.sh.\nUse AskUserQuestion to confirm.\n",
    );
    await writeFile(
      path.join(
        pluginRoot,
        "skills",
        "kramme:demo:run",
        "references",
        "sources-snapshot",
        "fetched.txt",
      ),
      "fetched upstream body\n",
    );
    await writeFile(
      path.join(pluginRoot, "skills", "kramme:demo:run", "scripts", "run.sh"),
      "#!/bin/sh\necho run\n",
    );
    await writeFile(
      path.join(pluginRoot, "agents", "demo-reviewer.md"),
      "---\nname: Demo Reviewer\ndescription: Reviews demos.\n---\nReview the demo.\n",
    );
    await writeFile(
      path.join(pluginRoot, "commands", "demo-command.md"),
      "---\nname: Demo Command\ndescription: Runs a demo command.\n---\nRun it.\n",
    );
    await writeFile(
      path.join(pluginRoot, "scripts", "collect-review-diff.sh"),
      "#!/bin/sh\necho diff\n",
    );
    await writeFile(
      path.join(pluginRoot, "scripts", "dev-server", "detect-url.sh"),
      "#!/bin/sh\necho url\n",
    );
    await writeFile(
      path.join(pluginRoot, "scripts", "lib", "shared.sh"),
      "shared() { :; }\n",
    );

    const plugin = await loadClaudePlugin(pluginRoot);
    const bundle = convertClaudeToCodex(plugin);
    const built = await buildCodexMarketplace(outputRoot, bundle);

    assert.equal(built.marketplaceRoot, outputRoot);
    assert.equal(
      built.pluginRoot,
      path.join(outputRoot, "plugins", "build-plugin"),
    );
    assert.equal(built.skillCount, 3);
    assert.deepEqual(
      JSON.parse(await readText(path.join(outputRoot, MARKETPLACE_MANIFEST))),
      {
        interface: { displayName: "build-plugin" },
        name: "build-plugin",
        plugins: [
          {
            category: "Productivity",
            name: "build-plugin",
            policy: { authentication: "ON_INSTALL", installation: "AVAILABLE" },
            source: { path: "./plugins/build-plugin", source: "local" },
          },
        ],
      },
    );
    assert.deepEqual(
      JSON.parse(
        await readText(
          path.join(built.pluginRoot, ".codex-plugin", "plugin.json"),
        ),
      ),
      {
        description: "Converted from the build-plugin Claude Code plugin.",
        name: "build-plugin",
        skills: "./skills/",
        version: "3.1.4",
      },
    );

    const skillsRoot = path.join(built.pluginRoot, "skills");
    const rootExpression =
      "${CODEX_HOME:-$HOME/.codex}/plugins/cache/build-plugin/build-plugin/3.1.4";
    const skill = await readText(
      path.join(skillsRoot, "kramme:demo:run", "SKILL.md"),
    );
    assert.match(
      skill,
      new RegExp(
        `"\\$\\{CODEX_HOME:-\\$HOME/\\.codex\\}/plugins/cache/build-plugin/build-plugin/3\\.1\\.4/scripts/collect-review-diff\\.sh" --strict`,
      ),
    );
    assert.ok(
      skill.includes(
        `[ -x "${rootExpression}/skills/kramme:demo:run/scripts/run.sh" ]`,
      ),
    );
    assert.doesNotMatch(skill, /AskUserQuestion|CLAUDE_PLUGIN_ROOT/);
    const notes = await readText(
      path.join(skillsRoot, "kramme:demo:run", "references", "notes.md"),
    );
    assert.equal(
      notes,
      `Helper lives at ${rootExpression}/scripts/dev-server/detect-url.sh.\nAsk the user directly in chat to confirm.\n`,
    );
    assert.equal(
      await pathExists(
        path.join(
          skillsRoot,
          "kramme:demo:run",
          "references",
          "sources-snapshot",
        ),
      ),
      false,
      "fetched source snapshots never ship",
    );
    assert.equal(
      await readText(
        path.join(skillsRoot, "kramme:demo:run", "scripts", "run.sh"),
      ),
      "#!/bin/sh\necho run\n",
    );
    assert.match(
      await readText(path.join(skillsRoot, "demo-reviewer", "SKILL.md")),
      /^---\nname: demo-reviewer\n/,
    );
    assert.match(
      await readText(path.join(skillsRoot, "demo-command", "SKILL.md")),
      /^---\nname: demo-command\n/,
    );

    const executable = async (/** @type {string} */ relativePath) =>
      ((await fs.stat(path.join(built.pluginRoot, relativePath))).mode &
        0o111) !==
      0;
    assert.equal(await executable("scripts/collect-review-diff.sh"), true);
    assert.equal(await executable("scripts/dev-server/detect-url.sh"), true);
    assert.equal(await executable("scripts/lib/shared.sh"), false);
    assert.equal(
      await pathExists(path.join(built.pluginRoot, "hooks")),
      false,
      "a plugin without hooks ships no hook directory",
    );
  });
});

test("build refuses non-empty output roots and duplicate skill names", async () => {
  await withTempDir(async (root) => {
    const occupied = path.join(root, "occupied");
    await writeFile(path.join(occupied, "keep.txt"), "user file\n");
    await assert.rejects(
      buildCodexMarketplace(occupied, emptyCodexBundle()),
      /is not empty/,
    );
    assert.equal(
      await readText(path.join(occupied, "keep.txt")),
      "user file\n",
    );

    const sourceDir = path.join(root, "source-skill");
    await writeFile(path.join(sourceDir, "SKILL.md"), "source\n");
    await assert.rejects(
      buildCodexMarketplace(
        path.join(root, "duplicate"),
        emptyCodexBundle({
          generatedSkills: [{ content: "generated", name: "same-name" }],
          skillDirs: [{ content: "copied", name: "same-name", sourceDir }],
        }),
      ),
      /Duplicate Codex skill name: same-name/,
    );

    await assert.rejects(
      buildCodexMarketplace(
        path.join(root, "escape"),
        emptyCodexBundle({
          generatedSkills: [{ content: "generated", name: "../escape" }],
        }),
      ),
      /Invalid skill name/,
    );

    const empty = path.join(root, "empty");
    await fs.mkdir(empty);
    const built = await buildCodexMarketplace(
      empty,
      emptyCodexBundle({
        codexPlugin: fixtureCodexPluginPackage({ name: "empty-plugin" }),
      }),
    );
    assert.equal(built.skillCount, 0);
    assert.equal(
      await pathExists(path.join(built.pluginRoot, "skills")),
      true,
      "the manifest points at ./skills/, so the directory always exists",
    );
  });
});
