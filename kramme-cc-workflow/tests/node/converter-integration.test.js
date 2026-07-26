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
  convertClaudeToCodex,
  transformContentForCodex,
} = require("../../scripts/convert-plugin/codex-transformer");

const {
  parseFrontmatter,
} = require("../../scripts/convert-plugin/frontmatter");

const {
  emptyPreviousEntries,
  withTempDir,
  createFixturePlugin,
  writeSourceSkill,
  readText,
  pathExists,
} = require("./converter-test-helpers");

test("converted skill roots contain no executable Claude controls and honor instruction files", async () => {
  await withTempDir(async (root) => {
    const agentsHome = path.join(root, "agents-home");
    const codexRoot = path.join(root, "codex-home");
    const codexStagingRoot = path.join(root, "codex-staging");
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

    const staged = await stageCodexBundleOutput(
      codexRoot,
      codexStagingRoot,
      bundle,
      emptyPreviousEntries(),
      "fixture-plugin",
      { agentsHome, confirm: { yes: true } },
    );
    assert.ok(staged.stagedAgentSkillsRoot);

    const generatedMarkdown = [
      ...(await readMarkdownTree(staged.stagedSkillsRoot)),
      ...(await readMarkdownTree(staged.stagedAgentSkillsRoot)),
    ];
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
    for (const { file, text } of generatedMarkdown) {
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

test("CLI emits no success line when transactional AGENTS.md publication fails", async () => {
  await withTempDir(async (root) => {
    const pluginRoot = path.join(root, "plugin");
    const outputRoot = path.join(root, "output");
    await createFixturePlugin(pluginRoot, "agents-cli-plugin");
    await fs.mkdir(path.join(outputRoot, ".codex", "AGENTS.md"), {
      recursive: true,
    });

    const result = spawnSync(
      process.execPath,
      [
        path.resolve(__dirname, "../../scripts/convert-plugin.js"),
        "install",
        pluginRoot,
        "--codex-home",
        outputRoot,
        "--agents-home",
        path.join(root, "agents-home"),
        "--yes",
      ],
      { encoding: "utf8" },
    );

    assert.notEqual(result.status, 0);
    assert.doesNotMatch(result.stdout, /^Installed .+ to .+$/m);
    assert.equal(
      await pathExists(
        path.join(outputRoot, ".codex", ".kramme-install-state.json"),
      ),
      false,
    );
  });
});

/** @param {string} root @returns {Promise<Array<{ file: string, text: string }>>} */
async function readMarkdownTree(root) {
  /** @type {Array<{ file: string, text: string }>} */
  const markdown = [];
  const entries = await fs.readdir(root, { withFileTypes: true });
  for (const entry of entries) {
    const file = path.join(root, entry.name);
    if (entry.isDirectory()) {
      markdown.push(...(await readMarkdownTree(file)));
    } else if (entry.isFile() && path.extname(entry.name) === ".md") {
      markdown.push({ file, text: await readText(file) });
    }
  }
  return markdown;
}
