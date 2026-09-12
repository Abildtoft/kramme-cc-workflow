"use strict";

const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const path = require("path");
const test = require("node:test");

const {
  buildCodexMarketplace,
} = require("../../scripts/convert-plugin/codex-plugin-builder");
const {
  convertClaudeToCodex,
  transformContentForCodex,
} = require("../../scripts/convert-plugin/codex-transformer");
const {
  parseFrontmatter,
} = require("../../scripts/convert-plugin/frontmatter");
const { loadClaudePlugin } = require("../../scripts/convert-plugin/loader");

const {
  pathExists,
  readMarkdownTree,
  readText,
  withTempDir,
  writeFile,
  writeSourceSkill,
} = require("./converter-test-helpers");

test("converted skill roots contain no executable Claude controls and honor instruction files", async () => {
  await withTempDir(async (root) => {
    const outputRoot = path.join(root, "marketplace");
    const sourceDir = path.join(root, "plugin", "skills", "fixture-skill");
    const canonicalResource = [
      "Message teammates using SendMessage.",
      "Use the Read tool, Edit/MultiEdit, and Question tool.",
      "Invoke via Skill tool with subagent_type=Explore.",
      "",
    ].join("\n");
    await writeSourceSkill(sourceDir, {
      "SKILL.md": "Canonical skill source.\n",
      "references/team-mode.md": canonicalResource,
    });

    const bundle = convertClaudeToCodex({
      agents: [
        {
          body: [
            "Read AGENTS.md first. Follow CLAUDE.md conventions.",
            "Read repo-root `AGENTS.md` and `CLAUDE.md` when present.",
            "Treat an explicit CLAUDE.md violation as a high-confidence finding.",
            "Project rules are typically in CLAUDE.md or equivalent.",
            "Flag each specific CLAUDE.md rule that the change violates.",
            "Monitor TaskList for completed tasks.",
            "Coordinate using SendMessage.",
          ].join("\n"),
          description:
            "Review against CLAUDE.md conventions using the Task tool.",
          name: "Fixture Reviewer",
          sourcePath: "/plugin/agents/fixture-reviewer.md",
        },
      ],
      commands: [
        {
          body: "Use AskUserQuestion to ask, then use TodoWrite/TodoRead.",
          description: "Run the fixture workflow.",
          name: "Fixture Command",
          sourcePath: "/plugin/commands/fixture-command.md",
        },
      ],
      manifest: { name: "fixture-plugin", version: "1.0.0" },
      root: path.join(root, "plugin"),
      skills: [
        {
          body: "Monitor task progress via TaskList using the Task tool.",
          description: "Fixture skill.",
          name: "Fixture Skill",
          sourceDir,
        },
      ],
    });

    const built = await buildCodexMarketplace(outputRoot, bundle);
    const skillsRoot = path.join(built.pluginRoot, "skills");
    assert.equal(
      await pathExists(path.join(skillsRoot, "fixture-reviewer", "SKILL.md")),
      true,
      "agent skills are packaged beside converted skills",
    );

    const forbiddenControls = [
      /AskUserQuestion/,
      /\bTask tool\b/,
      /\bSkill tool\b/,
      /\bTodoWrite\b/,
      /\bTodoRead\b/,
      /\bQuestion tool\b/,
      /\bRead tool\b/,
      /\bEdit\/MultiEdit\b/,
      /\bMultiEdit\b/,
      /\bsubagent_type\s*[=:]\s*Explore\b/,
      /\bSendMessage\b/,
      /\bMonitor (?:task progress via )?TaskList\b/,
    ];
    for (const { file, text } of await readMarkdownTree(skillsRoot)) {
      for (const pattern of forbiddenControls) {
        assert.doesNotMatch(text, pattern, `${file} retained ${pattern}`);
      }
      assert.equal(
        transformContentForCodex(text),
        text,
        `${file} is not idempotent`,
      );
    }

    const agentContent = bundle.agentSkills[0].content;
    const agentFrontmatter = parseFrontmatter(agentContent);
    assert.match(
      /** @type {string} */ (agentFrontmatter.data.description),
      /AGENTS\.md/,
    );
    assert.match(
      /** @type {string} */ (agentFrontmatter.data.description),
      /CLAUDE\.md/,
    );
    assert.match(
      /** @type {string} */ (agentFrontmatter.data.description),
      /conventions from/,
    );
    assert.match(agentFrontmatter.body, /AGENTS\.md/);
    assert.match(agentFrontmatter.body, /CLAUDE\.md/);
    assert.match(
      agentFrontmatter.body,
      /Read repo-root `AGENTS\.md` and `CLAUDE\.md` when present\./,
    );
    assert.match(agentFrontmatter.body, /closest nested equivalents/);
    assert.match(agentFrontmatter.body, /conventions from/);
    assert.match(agentFrontmatter.body, /violation of/);
    assert.match(agentFrontmatter.body, /or closest nested equivalent/);
    assert.match(agentFrontmatter.body, /rule from/);
    assert.doesNotMatch(
      agentContent,
      /closest nested equivalents (?:conventions|violation|or equivalent)/,
    );
    assert.equal(
      await readText(path.join(sourceDir, "references", "team-mode.md")),
      canonicalResource,
    );
  });
});

test("canonical plugin build preserves runtime path dependency closure", async () => {
  await withTempDir(async (root) => {
    const pluginRoot = path.resolve(__dirname, "../..");
    const plugin = await loadClaudePlugin(pluginRoot);
    const bundle = convertClaudeToCodex(plugin);
    const built = await buildCodexMarketplace(
      path.join(root, "marketplace"),
      bundle,
    );

    assert.equal(
      await pathExists(
        path.join(built.pluginRoot, "hooks", "confirm-review-artifacts.txt"),
      ),
      true,
      "shared review collector must retain its artifact inventory",
    );
    assert.equal(
      await pathExists(path.join(built.pluginRoot, "hooks", "hooks.json")),
      true,
      "canonical plugin ships its hook controls, so hooks are packaged",
    );
    assert.equal(
      built.skillCount,
      bundle.skillDirs.length +
        bundle.generatedSkills.length +
        bundle.agentSkills.length,
    );

    const skillsRoot = path.join(built.pluginRoot, "skills");
    const unresolvedRuntimePaths = (await readMarkdownTree(skillsRoot))
      .filter(({ text }) => /\$\{?CLAUDE_PLUGIN_ROOT\b/.test(text))
      .map(({ file }) => path.relative(skillsRoot, file));
    assert.deepEqual(
      unresolvedRuntimePaths,
      [],
      "converted skills must not retain Claude-only plugin root references",
    );
    const codeReview = await readText(
      path.join(skillsRoot, "kramme:pr:code-review", "SKILL.md"),
    );
    assert.match(
      codeReview,
      /"\$\{CODEX_HOME:-\$HOME\/\.codex\}\/plugins\/cache\/kramme-cc-workflow\/kramme-cc-workflow\/[^/]+\/scripts\/collect-review-diff\.sh"/,
      "shared helpers resolve through the Codex plugin cache directory",
    );
  });
});

test("CLI build refuses a non-empty output directory without reporting success", async () => {
  await withTempDir(async (root) => {
    const pluginRoot = path.join(root, "plugin");
    const outputRoot = path.join(root, "output");
    await writeFile(
      path.join(pluginRoot, ".claude-plugin", "plugin.json"),
      JSON.stringify({ name: "cli-plugin", version: "1.0.0" }),
    );
    await writeFile(path.join(outputRoot, "keep.txt"), "user file\n");

    const result = spawnSync(
      process.execPath,
      [
        path.resolve(__dirname, "../../scripts/convert-plugin.js"),
        "build",
        pluginRoot,
        "--out",
        outputRoot,
      ],
      { encoding: "utf8" },
    );

    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /is not empty/);
    assert.doesNotMatch(result.stdout, /^Built /m);
    assert.equal(
      await readText(path.join(outputRoot, "keep.txt")),
      "user file\n",
    );
    assert.equal(await pathExists(path.join(outputRoot, "plugins")), false);
  });
});
