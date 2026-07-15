"use strict";

const assert = require("node:assert/strict");
const fs = require("fs/promises");
const os = require("os");
const path = require("path");
const test = require("node:test");

const {
  parseAskUserQuestionBlock,
} = require("../../scripts/convert-plugin/ask-user-question-parser");
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
  codexSharedScriptReplacements,
  rewriteCodexSharedScriptReferences,
} = require("../../scripts/convert-plugin/codex-shared-scripts");
const {
  convertClaudeToCodex,
  transformContentForCodex,
} = require("../../scripts/convert-plugin/codex-transformer");
const {
  codexName,
  formatFrontmatter,
  normalizeName,
  parseFrontmatter,
  sanitizeDescription,
} = require("../../scripts/convert-plugin/frontmatter");
const {
  installStagedDir,
  installStagedFile,
  preflightStagedDirInstall,
  pruneStaleManagedFiles,
  withInstallTransaction,
} = require("../../scripts/convert-plugin/install-staging");
const {
  loadInstallState,
} = require("../../scripts/convert-plugin/install-state");
const {
  readJson: readConverterJson,
  readJsonObject,
  pathExists: converterPathExists,
} = require("../../scripts/convert-plugin/filesystem");
const {
  loadClaudePlugin,
  normalizeFrontmatterField,
  resolvePluginInput,
  skillFrontmatterTypeErrors,
} = require("../../scripts/convert-plugin/loader");
const {
  writeCodexBundle,
} = require("../../scripts/convert-plugin/codex-writer");
const { skillContracts } = require("../../scripts/schemas/skill-contracts");

const NON_OBJECT_JSON_CASES = [
  { kind: "null", source: "null", value: null },
  { kind: "array", source: "[]", value: [] },
  { kind: "number", source: "42", value: 42 },
];

test("shared script rewrites preserve shell-safe quoting", () => {
  const replacements = codexSharedScriptReplacements(
    "/tmp/Codex Home",
    [],
    [{ targetPath: path.join("scripts", "collect-review-diff.sh") }],
  );
  const source = [
    'RESOLVED=$("${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh" --strict)',
    "${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh --decode-json",
  ].join("\n");

  assert.equal(
    rewriteCodexSharedScriptReferences(source, replacements),
    [
      "RESOLVED=$('/tmp/Codex Home/scripts/collect-review-diff.sh' --strict)",
      "'/tmp/Codex Home/scripts/collect-review-diff.sh' --decode-json",
    ].join("\n"),
  );
});

test("filesystem keeps generic JSON reads and validates object reads", async () => {
  await withTempDir(async (root) => {
    for (const testCase of NON_OBJECT_JSON_CASES) {
      const file = path.join(root, `${testCase.kind}.json`);
      await writeFile(file, `${testCase.source}\n`);

      assert.deepEqual(await readConverterJson(file), testCase.value);
      await assert.rejects(readJsonObject(file, "Fixture config"), (error) => {
        assertJsonObjectBoundaryError(
          error,
          file,
          "Fixture config",
          testCase.kind,
        );
        return true;
      });
    }
  });
});

test("loader rejects non-object plugin manifests at the file boundary", async () => {
  for (const testCase of NON_OBJECT_JSON_CASES) {
    await withTempDir(async (root) => {
      const pluginRoot = path.join(root, "invalid-manifest-plugin");
      const manifestPath = path.join(
        pluginRoot,
        ".claude-plugin",
        "plugin.json",
      );
      await writeFile(manifestPath, `${testCase.source}\n`);

      await assert.rejects(loadClaudePlugin(pluginRoot), (error) => {
        assertJsonObjectBoundaryError(
          error,
          manifestPath,
          "Plugin manifest",
          testCase.kind,
        );
        return true;
      });
    });
  }
});

test("loader rejects non-object marketplace manifests at the file boundary", async () => {
  for (const testCase of NON_OBJECT_JSON_CASES) {
    await withTempDir(async (root) => {
      const marketplacePath = path.join(
        root,
        ".claude-plugin",
        "marketplace.json",
      );
      await writeFile(marketplacePath, `${testCase.source}\n`);
      const previousCwd = process.cwd();
      process.chdir(root);
      try {
        await assert.rejects(resolvePluginInput("fixture-plugin"), (error) => {
          assertJsonObjectBoundaryError(
            error,
            marketplacePath,
            "Marketplace manifest",
            testCase.kind,
          );
          return true;
        });
      } finally {
        process.chdir(previousCwd);
      }
    });
  }
});

test("loader rejects non-object hooks and MCP config files", async () => {
  for (const testCase of NON_OBJECT_JSON_CASES) {
    for (const boundary of [
      { label: "Hooks config", relativePath: path.join("hooks", "hooks.json") },
      { label: "MCP config", relativePath: ".mcp.json" },
    ]) {
      await withTempDir(async (root) => {
        const pluginRoot = path.join(root, "invalid-config-plugin");
        await createFixturePlugin(pluginRoot, "invalid-config-plugin");
        const configPath = path.join(pluginRoot, boundary.relativePath);
        await writeFile(configPath, `${testCase.source}\n`);

        await assert.rejects(loadClaudePlugin(pluginRoot), (error) => {
          assertJsonObjectBoundaryError(
            error,
            configPath,
            boundary.label,
            testCase.kind,
          );
          return true;
        });
      });
    }
  }
});

test("loader rejects non-object nested hooks maps", async () => {
  for (const testCase of NON_OBJECT_JSON_CASES) {
    await withTempDir(async (root) => {
      const pluginRoot = path.join(root, "invalid-hooks-map-plugin");
      await createFixturePlugin(pluginRoot, "invalid-hooks-map-plugin");
      const configPath = path.join(pluginRoot, "hooks", "hooks.json");
      await writeJson(configPath, { hooks: testCase.value });

      await assert.rejects(loadClaudePlugin(pluginRoot), (error) => {
        assertJsonObjectBoundaryError(
          error,
          configPath,
          'Hooks config field "hooks"',
          testCase.kind,
        );
        return true;
      });
    });
  }
});

test("loader rejects non-object inline config with manifest path context", async () => {
  for (const boundary of [
    { field: "hooks", label: "Plugin manifest hooks field" },
    { field: "mcpServers", label: "Plugin manifest mcpServers field" },
  ]) {
    await withTempDir(async (root) => {
      const pluginRoot = path.join(root, "invalid-inline-config-plugin");
      const manifestPath = path.join(
        pluginRoot,
        ".claude-plugin",
        "plugin.json",
      );
      await writeJson(manifestPath, {
        agents: [],
        commands: [],
        name: "invalid-inline-config-plugin",
        skills: [],
        version: "1.0.0",
        [boundary.field]: 42,
      });

      await assert.rejects(loadClaudePlugin(pluginRoot), (error) => {
        assertJsonObjectBoundaryError(
          error,
          manifestPath,
          boundary.label,
          "number",
        );
        return true;
      });
    });
  }
});

test("frontmatter module parses and formats converter metadata", () => {
  const parsed = parseFrontmatter(`---
name: Demo Skill
description: |
  First line
  Usage: keep exactly
  second line
argument-hint: [aspects] [--base <branch>]
summary: [experimental] Capture local behavior: screenshots, terminal output
allowed-tools:
  - Read
  - Edit(src/**)
examples:
  - Capture: screenshots
user-invocable: true
---
Body`);

  assert.deepEqual(parsed.data["allowed-tools"], ["Read", "Edit(src/**)"]);
  assert.deepEqual(parsed.data.examples, ["Capture: screenshots"]);
  assert.equal(
    parsed.data.description,
    "First line\nUsage: keep exactly\nsecond line",
  );
  assert.equal(
    parsed.data.summary,
    "[experimental] Capture local behavior: screenshots, terminal output",
  );
  assert.equal(parsed.data["argument-hint"], "[aspects] [--base <branch>]");
  assert.equal(parsed.data["user-invocable"], true);
  assert.equal(parsed.body, "Body");
  assert.equal(normalizeName("Kramme: Demo/Skill!"), "kramme-demo-skill");
  assert.equal(codexName("Demo Skill!"), "demo-skill");
  assert.equal(sanitizeDescription(" First\n\nSecond "), "First Second");

  const bracketHint = parseFrontmatter(`---
name: Demo Skill
argument-hint: [path]
disable-model-invocation: { true|false }
---
Body`);
  assert.equal(bracketHint.data["argument-hint"], "[path]");
  assert.equal(bracketHint.data["disable-model-invocation"], "{ true|false }");

  const formatted = formatFrontmatter(
    {
      name: "demo-skill",
      "argument-hint": bracketHint.data["argument-hint"],
      "allowed-tools": ["Read", "Edit(src/**)"],
      metadata: { owner: "platform" },
      "user-invocable": true,
    },
    "Body",
  );
  assert.match(formatted, /argument-hint: "\[path\]"/);
  assert.match(formatted, /allowed-tools:\n  - Read\n  - Edit\(src\/\*\*\)/);
  assert.match(formatted, /metadata:\n  owner: platform/);
  assert.match(formatted, /user-invocable: true/);
});

test("frontmatter module parses supported YAML shapes and nested metadata", () => {
  const parsed = parseFrontmatter(`---
name: "Quoted Skill"
description: >
  First line
  second line
enabled: false
attempts: 3
ratio: -2.5
empty: null
fallback: ~
tags: [alpha, "beta:two", false, 2]
allowed-tools:
  - Read
  - Edit(src/**)
metadata:
  owner: platform
  channels:
    - cli
    - codex
examples:
  - name: Capture
    description: Capture local behavior: screenshots
  - name: Replay
    description: Replay terminal output
---

Body line one
---
Body line two`);

  assert.equal(parsed.data.name, "Quoted Skill");
  assert.equal(parsed.data.description, "First line second line");
  assert.equal(parsed.data.enabled, false);
  assert.equal(parsed.data.attempts, 3);
  assert.equal(parsed.data.ratio, -2.5);
  assert.equal(parsed.data.empty, null);
  assert.equal(parsed.data.fallback, null);
  assert.deepEqual(parsed.data.tags, ["alpha", "beta:two", false, 2]);
  assert.deepEqual(parsed.data["allowed-tools"], ["Read", "Edit(src/**)"]);
  assert.deepEqual(parsed.data.metadata, {
    owner: "platform",
    channels: ["cli", "codex"],
  });
  assert.deepEqual(parsed.data.examples, [
    {
      name: "Capture",
      description: "Capture local behavior: screenshots",
    },
    {
      name: "Replay",
      description: "Replay terminal output",
    },
  ]);
  assert.equal(Object.hasOwn(parsed.data, "owner"), false);
  assert.equal(parsed.body, "\nBody line one\n---\nBody line two");
});

test("ask user question parser reads structured prompt blocks", () => {
  const parsed = parseAskUserQuestionBlock(`
AskUserQuestion
header: "Release scope"
question: |
  Which release scopes should this include?
  Choose every applicable area.
multiSelect: "true"
options:
  - label: "Converter"
    description: "Converter behavior and tests"
  - (freeform) Something else
`);

  assert.deepEqual(parsed, {
    header: "Release scope",
    question:
      "Which release scopes should this include?\nChoose every applicable area.",
    multiSelect: true,
    options: [
      {
        label: "Converter",
        description: "Converter behavior and tests",
      },
      {
        label: "Something else",
        description: "",
      },
    ],
  });

  const folded = parseAskUserQuestionBlock(`
question: >
  Pick the route
  for this plan.
options: []
`);
  assert.ok(folded);
  assert.equal(folded.question, "Pick the route for this plan.");
  assert.equal(parseAskUserQuestionBlock("plain markdown"), null);
});

test("transformer rewrites task calls, references, and AskUserQuestion guidance", () => {
  const knownCommands = new Set(["kramme:pr:create", "demo-command"]);
  const knownAgentSkills = new Map([
    ["kramme:reviewer", "kramme:reviewer"],
    ["support-reviewer", "support-reviewer"],
  ]);
  const input = [
    "Task support-reviewer(review this parser)",
    "Run /kramme:pr:create, then /unknown, and keep /usr/bin.",
    "Ask @support-reviewer to inspect the output.",
    "Use `agents/kramme:reviewer.md` and [reviewer](agents/kramme:reviewer.md).",
    "1. Ask for the issue ID:",
    "   ````yaml",
    '   header: "Linear issue"',
    '   question: "Enter the Linear issue ID (e.g., WAN-521):"',
    "   options: []",
    "   ````",
    "### Using AskUserQuestion Correctly",
    "",
    "The AskUserQuestion tool requires **2-4 predefined options** per question.",
    'Users can always select "Other" to provide free-text input.',
    "- `header`: Short label",
    "- `question`: The full question text",
    "- `multiSelect`: Set `true` for non-exclusive choices",
  ].join("\n");

  const output = transformContentForCodex(input, {
    knownCommands,
    knownAgentSkills,
  });

  assert.match(
    output,
    /Use the \$support-reviewer skill to: review this parser/,
  );
  assert.match(
    output,
    /Run \$kramme:pr:create, then \/unknown, and keep \/usr\/bin\./,
  );
  assert.match(output, /Ask \$support-reviewer skill to inspect the output\./);
  assert.match(
    output,
    /Use \$kramme:reviewer skill and \$kramme:reviewer skill\./,
  );
  assert.match(
    output,
    /1\. Ask for the issue ID:\n   Ask the user directly in chat:\n   Question label: Linear issue\n   Question: Enter the Linear issue ID \(e\.g\., WAN-521\):/,
  );
  assert.match(output, /### Asking Questions in Codex/);
  assert.match(
    output,
    /When asking directly in chat, offer a small set of concrete options/,
  );
  assert.match(output, /Users can always ignore the suggested options/);
  assert.match(output, /- `Label`: Short label/);
  assert.match(output, /- `Question`: The full question text/);
  assert.match(output, /- `Multi-select`: Use this style only/);
  assert.doesNotMatch(output, /AskUserQuestion|````yaml/);
});

test("transformer rewrites Codex-supported team controls without changing code identifiers", () => {
  const input = [
    "Monitor task progress via TaskList.",
    "Monitor TaskList for completed tasks.",
    "Message them using SendMessage when findings overlap.",
    "function TaskList() { return <TaskFilters />; }",
  ].join("\n");

  const output = transformContentForCodex(input);

  assert.match(output, /Monitor task progress with list_agents\./);
  assert.match(
    output,
    /Monitor agent progress with list_agents for completed tasks\./,
  );
  assert.match(
    output,
    /Message them using send_message when findings overlap\./,
  );
  assert.match(output, /function TaskList\(\)/);
  assert.equal(transformContentForCodex(output), output);
});

test("loader derives invocable skill commands and normalizes boolean fields", async () => {
  await withTempDir(async (root) => {
    const pluginRoot = path.join(root, "boolean-plugin");
    await createFixturePlugin(pluginRoot, "boolean-plugin");

    await writeSkillFile(
      pluginRoot,
      "quoted-hidden",
      `---
name: quoted-hidden
description: Quoted hidden skill
disable-model-invocation: "true"
user-invocable: "false"
---
Hidden body.
`,
    );
    await writeSkillFile(
      pluginRoot,
      "literal-hidden",
      `---
name: literal-hidden
description: Literal hidden skill
disable-model-invocation: true
user-invocable: false
---
Hidden body.
`,
    );
    await writeSkillFile(
      pluginRoot,
      "quoted-enabled",
      `---
name: quoted-enabled
description: Quoted enabled skill
disable-model-invocation: "false"
user-invocable: "true"
---
Enabled body.
`,
    );
    await writeSkillFile(
      pluginRoot,
      "literal-enabled",
      `---
name: literal-enabled
description: Literal enabled skill
disable-model-invocation: false
user-invocable: true
---
Enabled body.
`,
    );

    const plugin = await loadClaudePlugin(pluginRoot);
    assert.deepEqual(plugin.commands.map((command) => command.name).sort(), [
      "literal-enabled",
      "quoted-enabled",
    ]);

    const skills = Object.fromEntries(
      plugin.skills.map((skill) => [skill.name, skill]),
    );
    assert.equal(skills["quoted-hidden"].userInvocable, false);
    assert.equal(skills["literal-hidden"].userInvocable, false);
    assert.equal(skills["quoted-enabled"].userInvocable, true);
    assert.equal(skills["literal-enabled"].userInvocable, true);
    assert.equal(skills["quoted-hidden"].disableModelInvocation, true);
    assert.equal(skills["quoted-enabled"].disableModelInvocation, false);
  });

  const fields = skillContracts.skill_frontmatter.fields;
  for (const [field, contract] of Object.entries(fields)) {
    if (contract.type === "boolean") {
      assert.equal(normalizeFrontmatterField(field, "true"), true, field);
      assert.equal(normalizeFrontmatterField(field, "false"), false, field);
    } else {
      assert.equal(normalizeFrontmatterField(field, "true"), "true", field);
    }
  }
});

test("loader accepts every schema-declared primitive frontmatter type", async () => {
  await withTempDir(async (root) => {
    const pluginRoot = path.join(root, "typed-plugin");
    await createFixturePlugin(pluginRoot, "typed-plugin");
    await writeSkillFile(
      pluginRoot,
      "typed-skill",
      `---
name: typed-skill
description: Typed skill
argument-hint: "[target]"
disable-model-invocation: "false"
user-invocable: true
kramme-platforms: [Claude-Code, "CODEX"]
---
Typed body.
`,
    );

    const plugin = await loadClaudePlugin(pluginRoot);
    assert.equal(plugin.skills[0].argumentHint, "[target]");
    assert.equal(plugin.skills[0].disableModelInvocation, false);
    assert.equal(plugin.skills[0].userInvocable, true);
    assert.deepEqual(plugin.skills[0].platforms, ["claude-code", "codex"]);
  });
});

test("loader validates agent descriptions and capabilities before conversion", async () => {
  const invalidAgents = [
    {
      expected: 'frontmatter field "description" must be a string',
      frontmatter: `description:
  nested: value`,
    },
    {
      expected: 'frontmatter field "capabilities" must be an array of strings',
      frontmatter: `description: Reviews changes.
capabilities: Read`,
    },
    {
      expected: 'frontmatter field "capabilities" must be an array of strings',
      frontmatter: `description: Reviews changes.
capabilities:
  - Read
  - target:
      name: Write`,
    },
  ];

  for (const [index, invalidAgent] of invalidAgents.entries()) {
    await withTempDir(async (root) => {
      const pluginRoot = path.join(root, `invalid-agent-plugin-${index}`);
      await createFixturePlugin(pluginRoot, `invalid-agent-plugin-${index}`);
      const agentPath = path.join(pluginRoot, "agents", "reviewer.md");
      await writeFile(
        agentPath,
        `---
name: reviewer
${invalidAgent.frontmatter}
---
Review changes.
`,
      );

      await assert.rejects(loadClaudePlugin(pluginRoot), (error) => {
        assert.ok(error instanceof Error);
        assert.ok(error.message.includes(agentPath));
        assert.match(error.message, new RegExp(invalidAgent.expected));
        return true;
      });
    });
  }

  await withTempDir(async (root) => {
    const pluginRoot = path.join(root, "valid-agent-plugin");
    await createFixturePlugin(pluginRoot, "valid-agent-plugin");
    await writeFile(
      path.join(pluginRoot, "agents", "reviewer.md"),
      `---
name: reviewer
description: Reviews changes.
capabilities:
  - Read
  - Write
---
Review changes.
`,
    );

    const plugin = await loadClaudePlugin(pluginRoot);
    const bundle = convertClaudeToCodex(plugin);
    assert.match(
      bundle.agentSkills[0].content,
      /description: Reviews changes\./,
    );
    assert.match(
      bundle.agentSkills[0].content,
      /## Capabilities\n- Read\n- Write/,
    );
  });
});

test("loader accepts legacy numeric strings and escaped quotes", async () => {
  await withTempDir(async (root) => {
    const pluginRoot = path.join(root, "legacy-scalars-plugin");
    await createFixturePlugin(pluginRoot, "legacy-scalars-plugin");
    await writeSkillFile(
      pluginRoot,
      "legacy-scalars-skill",
      String.raw`---
name: +1
description: 1e3
disable-model-invocation: false
user-invocable: true
kramme-platforms:
  - -1e2
  - "claude\",code"
---
Typed body.
`,
    );

    const plugin = await loadClaudePlugin(pluginRoot);
    assert.equal(plugin.skills[0].name, "+1");
    assert.equal(plugin.skills[0].description, "1e3");
    assert.deepEqual(plugin.skills[0].platforms, ["-1e2", 'claude",code']);
  });
});

test("loader rejects decoded-empty and nested block array values", async () => {
  const invalidFrontmatter = [
    String.raw`description: "\n"`,
    `description: Typed skill
kramme-platforms:
  - target:
      name: codex`,
    `description: Typed skill
kramme-platforms:
  - |`,
  ];

  for (const fields of invalidFrontmatter) {
    await withTempDir(async (root) => {
      const pluginRoot = path.join(root, "invalid-block-plugin");
      await createFixturePlugin(pluginRoot, "invalid-block-plugin");
      await writeSkillFile(
        pluginRoot,
        "invalid-block-skill",
        `---
name: invalid-block-skill
${fields}
disable-model-invocation: false
user-invocable: true
---
Typed body.
`,
      );

      await assert.rejects(loadClaudePlugin(pluginRoot), /must be a/);
    });
  }
});

test("loader rejects invalid schema-declared primitive frontmatter types", async () => {
  const cases = [
    ["name", "false", "non-empty string"],
    ["description", "", "non-empty string"],
    ["argument-hint", "false", "non-empty string"],
    ["disable-model-invocation", "maybe", "boolean"],
    ["user-invocable", "0", "boolean"],
    ["kramme-platforms", "codex", "non-empty array of non-empty strings"],
  ];

  for (const [field, value, expectedType] of cases) {
    await withTempDir(async (root) => {
      const pluginRoot = path.join(root, "invalid-plugin");
      await createFixturePlugin(pluginRoot, "invalid-plugin");
      const fields = {
        name: "typed-skill",
        description: "Typed skill",
        "argument-hint": '"[target]"',
        "disable-model-invocation": "false",
        "user-invocable": "true",
        "kramme-platforms": "[claude-code, codex]",
      };
      fields[field] = value;
      const frontmatter = Object.entries(fields)
        .map(([key, entry]) => `${key}: ${entry}`)
        .join("\n");
      await writeSkillFile(
        pluginRoot,
        "typed-skill",
        `---\n${frontmatter}\n---\nTyped body.\n`,
      );

      await assert.rejects(loadClaudePlugin(pluginRoot), (error) => {
        assert.ok(error instanceof Error);
        assert.match(error.message, /skills[/\\]typed-skill[/\\]SKILL\.md/);
        assert.match(error.message, new RegExp(`frontmatter field "${field}"`));
        assert.match(error.message, new RegExp(`must be a ${expectedType}`));
        return true;
      });
    });
  }
});

test("loader frontmatter type verdicts match the shared converter oracle", async () => {
  const fixturePath = path.join(
    __dirname,
    "..",
    "fixtures",
    "frontmatter-type-cases.json",
  );
  const { cases } = JSON.parse(await fs.readFile(fixturePath, "utf8"));
  assert.ok(cases.length > 0, "expected shared frontmatter fixtures");

  for (const testCase of cases) {
    const { data } = parseFrontmatter(testCase.text);
    const fields = skillFrontmatterTypeErrors(data)
      .map((error) => error.field)
      .sort();
    assert.deepEqual(
      fields,
      [...testCase.invalidFields].sort(),
      `frontmatter type verdict drifted for fixture: ${testCase.name}`,
    );
  }
});

test("conversion preserves skill and generated command frontmatter contracts", () => {
  const bundle = convertClaudeToCodex({
    agents: [],
    commands: [
      {
        allowedTools: ["Read", "Edit(src/**)"],
        body: "Use /kramme:demo-command.",
        description: "Demo command",
        disableModelInvocation: true,
        name: "kramme:demo-command",
        sourcePath: "/plugin/commands/demo-command.md",
      },
    ],
    manifest: { name: "contract-plugin", version: "1.0.0" },
    root: "/plugin",
    skills: [
      {
        allowedTools: ["Read", "Edit(src/**)"],
        body: "Use /kramme:demo-command.",
        description: "Demo skill",
        disableModelInvocation: false,
        name: "demo-skill",
        platforms: ["codex"],
        sourceDir: "/plugin/skills/demo",
        userInvocable: true,
      },
    ],
  });

  const skill = parseFrontmatter(bundle.skillDirs[0].content).data;
  assert.equal(skill.name, "demo-skill");
  assert.deepEqual(skill["allowed-tools"], ["Read", "Edit(src/**)"]);
  assert.equal(skill["disable-model-invocation"], false);
  assert.equal(skill["user-invocable"], true);
  assert.deepEqual(skill["kramme-platforms"], ["codex"]);

  const generated = parseFrontmatter(bundle.generatedSkills[0].content).data;
  assert.equal(generated.name, "kramme:demo-command");
  assert.deepEqual(generated["allowed-tools"], ["Read", "Edit(src/**)"]);
  assert.equal(generated["disable-model-invocation"], true);
  assert.equal(generated["user-invocable"], true);
});

test("hook plugin conversion requires controls and sanitizes manifest description", () => {
  const plugin = {
    agents: [],
    commands: [],
    hooks: { hooks: { PreToolUse: [] } },
    manifest: {
      description: `First line\nsecond line ${"x".repeat(1100)}`,
      name: "hook-description-plugin",
      version: "1.0.0",
    },
    root: "/plugin",
    skills: [],
  };

  assert.equal(convertClaudeToCodex(plugin).codexPlugin, undefined);

  const withControls = {
    ...plugin,
    skills: [
      {
        body: "Toggle hooks.",
        description: "Toggle hooks.",
        name: "kramme:hooks:toggle",
        sourceDir: "/plugin/skills/toggle",
      },
      {
        body: "Configure hooks.",
        description: "Configure hooks.",
        name: "kramme:hooks:configure-links",
        sourceDir: "/plugin/skills/configure",
      },
    ],
  };
  const codexPlugin = convertClaudeToCodex(withControls).codexPlugin;

  assert.ok(codexPlugin);
  assert.equal(codexPlugin.name, "hook-description-plugin");
  assert.equal(codexPlugin.manifest.hooks, "./hooks/hooks.json");
  assert.match(codexPlugin.manifest.description, /^First line second line /);
  assert.match(codexPlugin.manifest.description, /\.\.\.$/);
  assert.equal(codexPlugin.manifest.description.includes("\n"), false);
  assert.ok(codexPlugin.manifest.description.length <= 1024);
});

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

    const stagedConfigPath = await stageCodexConfig(
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

    const output = await readText(stagedConfigPath);
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
    const restagedConfigPath = await stageCodexConfig(
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
    assert.equal(restagedConfigPath, null);
  });
});

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

    const { fromDisk, recoveryReason, state } = await loadInstallState(root);

    assert.equal(fromDisk, false);
    assert.equal(recoveryReason, "missing");
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

test("converter path checks treat only ENOENT as absence", async () => {
  await withTempDir(async (root) => {
    const missingPath = path.join(root, "missing");
    assert.equal(await converterPathExists(missingPath), false);

    const originalAccess = fs.access;
    const accessError = Object.assign(new Error("permission denied"), {
      code: "EACCES",
    });
    fs.access = async () => {
      throw accessError;
    };
    try {
      await assert.rejects(
        () => converterPathExists(missingPath),
        (error) => {
          assertFilesystemError(error, {
            cause: accessError,
            code: "EACCES",
            message: /Failed to check path/,
            path: missingPath,
          });
          return true;
        },
      );
    } finally {
      fs.access = originalAccess;
    }
  });
});

test("install state records corrupt-data recovery provenance", async () => {
  await withTempDir(async (root) => {
    const statePath = path.join(root, ".kramme-install-state.json");
    await writeFile(statePath, "{not json\n");

    let loaded = await loadInstallState(root);
    assert.equal(loaded.fromDisk, false);
    assert.equal(loaded.recoveryReason, "malformed-json");
    assert.deepEqual(loaded.state.plugins, {});

    await writeJson(statePath, []);
    loaded = await loadInstallState(root);
    assert.equal(loaded.fromDisk, false);
    assert.equal(loaded.recoveryReason, "invalid-shape");
    assert.deepEqual(loaded.state.plugins, {});
  });
});

test("install state rebuild skips malformed and invalid-shape manifests", async () => {
  await withTempDir(async (root) => {
    const manifestsDir = path.join(root, ".kramme-install-manifests");
    await writeFile(path.join(manifestsDir, "malformed-codex.json"), "{bad\n");
    await writeJson(path.join(manifestsDir, "invalid-codex.json"), []);

    const loaded = await loadInstallState(root);

    assert.equal(loaded.fromDisk, false);
    assert.equal(loaded.recoveryReason, "missing");
    assert.deepEqual(loaded.state.plugins, {});
  });
});

test("install state rethrows operational read failures without mutation", async () => {
  await withTempDir(async (root) => {
    const statePath = path.join(root, ".kramme-install-state.json");
    await writeJson(statePath, { plugins: {}, version: 1 });

    const originalReadFile = fs.readFile;
    const readError = Object.assign(new Error("input/output error"), {
      code: "EIO",
    });
    fs.readFile = /** @type {typeof fs.readFile} */ (
      async (file, ...args) => {
        if (file === statePath) throw readError;
        return originalReadFile(file, ...args);
      }
    );
    try {
      await assert.rejects(
        () => loadInstallState(root),
        (error) => {
          assertFilesystemError(error, {
            cause: readError,
            code: "EIO",
            message: /Failed to read install state/,
            path: statePath,
          });
          return true;
        },
      );
    } finally {
      fs.readFile = originalReadFile;
    }

    assert.deepEqual(await fs.readdir(root), [".kramme-install-state.json"]);
  });
});

test("install manifest rethrows operational read failures", async () => {
  await withTempDir(async (root) => {
    const manifestPath = path.join(
      root,
      ".kramme-install-manifests",
      "demo-codex.json",
    );
    await writeJson(manifestPath, { skills: ["demo"] });

    const originalReadFile = fs.readFile;
    const readError = Object.assign(new Error("input/output error"), {
      code: "EIO",
    });
    fs.readFile = /** @type {typeof fs.readFile} */ (
      async (file, ...args) => {
        if (file === manifestPath) throw readError;
        return originalReadFile(file, ...args);
      }
    );
    try {
      await assert.rejects(
        () => loadInstallState(root),
        (error) => {
          assertFilesystemError(error, {
            cause: readError,
            code: "EIO",
            message: /Failed to read install manifest/,
            path: manifestPath,
          });
          return true;
        },
      );
    } finally {
      fs.readFile = originalReadFile;
    }
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

test("agent portability document names stable adapter statuses and surfaces", async () => {
  const doc = await readText(
    path.join(__dirname, "..", "..", "docs", "agent-portability.md"),
  );
  const requiredContractText = [
    "`canonical`",
    "`generated`",
    "`thin adapter`",
    "`instruction-only`",
    "`local-only`",
    "`unsupported`",
    "Claude Code plugin",
    "Codex skills, prompts, and MCP config",
    "Codex agent skills",
    "Codex hook plugin and shared scripts",
    "Codex `AGENTS.md` tool map",
    "Local repository-maintenance skills",
    "Other hosts",
    "`manifest.mcpServers`",
    "`.mcp.json`",
    "`scripts/skill-usage.js`",
    "selected agents home's `skills/`",
    "Repository-local `./.agents/skills/`",
    "`prompts`",
    "`skillDirs`",
    "`generatedSkills`",
    "`agentSkills`",
    "`mcpServers`",
    "`codexPlugin`",
  ];

  for (const text of requiredContractText) {
    assert.equal(
      doc.includes(text),
      true,
      `missing portability contract text: ${text}`,
    );
  }
});

test("transformer exposes documented Codex generated surface fields", () => {
  const mcpServers = { "demo-server": { command: "demo" } };
  const bundle = convertClaudeToCodex({
    agents: [
      {
        body: "Review changes.",
        description: "Reviews changes.",
        name: "Reviewer",
        sourcePath: "/plugin/agents/reviewer.md",
      },
    ],
    commands: [
      {
        body: "Run the extra workflow.",
        name: "Extra Command",
        sourcePath: "/plugin/commands/extra-command.md",
      },
    ],
    hooks: { PreToolUse: [] },
    manifest: {
      description: "Demo plugin.",
      name: "demo-plugin",
      version: "1.0.0",
    },
    mcpServers,
    root: "/plugin",
    skills: [
      {
        body: "Toggle hooks.",
        description: "Toggles hooks.",
        name: "kramme:hooks:toggle",
        sourceDir: "/plugin/skills/kramme-hooks-toggle",
      },
      {
        body: "Configure hook links.",
        description: "Configures hook links.",
        name: "kramme:hooks:configure-links",
        sourceDir: "/plugin/skills/kramme-hooks-configure-links",
      },
      {
        body: "Codex instructions.",
        description: "Available in Codex.",
        name: "Codex Tool",
        sourceDir: "/plugin/skills/codex-tool",
      },
    ],
  });

  assert.equal(Array.isArray(bundle.prompts), true);
  assert.equal(Array.isArray(bundle.skillDirs), true);
  assert.equal(Array.isArray(bundle.generatedSkills), true);
  assert.equal(Array.isArray(bundle.agentSkills), true);
  assert.deepEqual(bundle.mcpServers, mcpServers);
  assert.ok(bundle.codexPlugin);
  assert.equal(bundle.codexPlugin.name, "demo-plugin");
  assert.equal(bundle.codexPlugin.hookSourceDir, "/plugin/hooks");
  assert.deepEqual(
    bundle.generatedSkills.map((skill) => skill.name),
    ["extra-command"],
  );
  assert.deepEqual(
    bundle.agentSkills.map((skill) => skill.name),
    ["reviewer"],
  );
});

test("agent transformations use collision-resolved skill names", () => {
  const bundle = convertClaudeToCodex({
    agents: [
      {
        body: "Review changes.",
        description: "Reviews changes.",
        name: "Support Reviewer",
        sourcePath: "/plugin/agents/support-reviewer.md",
      },
      {
        body: [
          "Task support-reviewer(review this parser)",
          "Ask @support-reviewer to verify the result.",
        ].join("\n"),
        description: "Coordinates review.",
        name: "Review Coordinator",
        sourcePath: "/plugin/agents/review-coordinator.md",
      },
    ],
    commands: [],
    manifest: { name: "fixture-plugin", version: "1.0.0" },
    mcpServers: {},
    root: "/plugin",
    skills: [
      {
        body: "Existing skill.",
        description: "Occupies the original agent name.",
        name: "Support Reviewer",
        sourceDir: "/plugin/skills/support-reviewer",
      },
    ],
  });

  assert.deepEqual(
    bundle.agentSkills.map((skill) => skill.name),
    ["support-reviewer-2", "review-coordinator"],
  );
  assert.match(
    bundle.agentSkills[1].content,
    /Use the \$support-reviewer-2 skill to: review this parser/,
  );
  assert.match(
    bundle.agentSkills[1].content,
    /Ask \$support-reviewer-2 skill to verify the result/,
  );
});

test("canonical agent names take precedence over filename aliases", () => {
  const bundle = convertClaudeToCodex({
    agents: [
      {
        body: "Review changes.",
        description: "Reviews changes.",
        name: "Support Reviewer",
        sourcePath: "/plugin/agents/review-helper.md",
      },
      {
        body: "Review other changes.",
        description: "Reviews other changes.",
        name: "Other Reviewer",
        sourcePath: "/plugin/agents/support-reviewer.md",
      },
      {
        body: [
          "Task support-reviewer(review this parser)",
          "Ask @support-reviewer to verify the result.",
        ].join("\n"),
        description: "Coordinates review.",
        name: "Review Coordinator",
        sourcePath: "/plugin/agents/review-coordinator.md",
      },
    ],
    commands: [],
    manifest: { name: "fixture-plugin", version: "1.0.0" },
    mcpServers: {},
    root: "/plugin",
    skills: [],
  });

  assert.match(
    bundle.agentSkills[2].content,
    /Use the \$support-reviewer skill to: review this parser/,
  );
  assert.match(
    bundle.agentSkills[2].content,
    /Ask \$support-reviewer skill to verify the result/,
  );
});

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
    assert.match(agentFrontmatter.data.description, /AGENTS\.md/);
    assert.match(agentFrontmatter.data.description, /CLAUDE\.md/);
    assert.match(agentFrontmatter.data.description, /conventions from/);
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
      [
        "Run /extra-command before review.",
        "Use agents/reviewer.md in copied resources.",
        "Use colon punctuation agents/reviewer.md: copied resources.",
        "Keep anchored paths like agents/reviewer.md#usage.",
        "Keep parent paths like ../agents/reviewer.md.",
        "",
      ].join("\n"),
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

    let manifest = await readJson(manifestPath);
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
    const state = await readJson(statePath);
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

    manifest = await readJson(manifestPath);
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

    manifest = await readJson(manifestPath);
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

test("install staging does not prune stale files through symlinked ancestors", async () => {
  await withTempDir(async (root) => {
    const skillDir = path.join(root, "skill");
    const outsideDir = path.join(root, "outside");
    await fs.mkdir(skillDir, { recursive: true });
    await fs.mkdir(outsideDir, { recursive: true });

    const outsideFile = path.join(outsideDir, "OLD.md");
    await writeFile(outsideFile, "outside\n");
    await fs.symlink(outsideDir, path.join(skillDir, "references"), "dir");

    await pruneStaleManagedFiles(skillDir, ["references/OLD.md"], ["SKILL.md"]);

    assert.equal(await readText(outsideFile), "outside\n");
    assert.equal(
      (await fs.lstat(path.join(skillDir, "references"))).isSymbolicLink(),
      true,
    );
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

    const state = await readJson(
      path.join(root, ".codex", ".kramme-install-state.json"),
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

test("writer rejects stale journals targeting paths outside owned roots", async () => {
  await withTempDir(async (root) => {
    const installRoot = path.join(root, "install-root");
    const victimPath = path.join(root, "outside-victim.txt");
    const token = "unowned-target-transaction";
    const journalPath = path.join(
      installRoot,
      ".kramme-install-transactions",
      token,
      "journal.json",
    );
    const owner = {
      version: 1,
      token,
      pid: 2_147_483_647,
      pluginName: "unowned-target-plugin",
      createdAtMs: 1,
      lockRoots: [installRoot],
      transactionRoot: installRoot,
      journalPath,
    };

    await writeFile(victimPath, "must survive\n");
    await writeJson(journalPath, {
      version: 1,
      token,
      status: "active",
      records: [
        {
          operation: "create",
          target: victimPath,
          backup: null,
        },
      ],
    });
    await writeJson(
      path.join(installRoot, ".kramme-install-lock", "owner.json"),
      owner,
    );

    await assert.rejects(
      () =>
        withInstallTransaction(
          installRoot,
          { pluginName: "next-plugin" },
          async () => {},
        ),
      /Refusing to recover invalid install journal/,
    );
    assert.equal(await readText(victimPath), "must survive\n");
  });
});

test("transaction recovers an interrupted partial multi-root lock acquisition", async () => {
  await withTempDir(async (root) => {
    const firstRoot = path.join(root, "a-shared-root");
    const transactionRoot = path.join(root, "z-transaction-root");
    const token = "partial-lock-acquisition";
    const journalPath = path.join(
      transactionRoot,
      ".kramme-install-transactions",
      token,
      "journal.json",
    );
    const owner = {
      version: 1,
      token,
      pid: 2_147_483_647,
      pluginName: "partial-lock-plugin",
      createdAtMs: 1,
      lockRoots: [firstRoot, transactionRoot],
      transactionRoot,
      journalPath,
    };

    await writeJson(
      path.join(firstRoot, ".kramme-install-lock", "owner.json"),
      owner,
    );

    let callbackRan = false;
    await withInstallTransaction(
      transactionRoot,
      {
        lockRoots: [firstRoot],
        pluginName: "next-plugin",
      },
      async () => {
        callbackRan = true;
      },
    );

    assert.equal(callbackRan, true);
    assert.equal(
      await pathExists(path.join(firstRoot, ".kramme-install-lock")),
      false,
    );
    assert.equal(
      await pathExists(path.join(transactionRoot, ".kramme-install-lock")),
      false,
    );
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
    const owner = await readJson(ownerPath);
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

test("transaction preserves the primary error when rollback cleanup fails", async () => {
  await withTempDir(async (root) => {
    const targetPath = path.join(root, "target.txt");
    const stagedPath = path.join(root, "staged.txt");
    const primaryError = new Error("primary install failure");
    const cleanupError = Object.assign(new Error("rollback cleanup failure"), {
      code: "EIO",
    });
    const originalRm = fs.rm;

    await writeFile(targetPath, "stable\n");
    await writeFile(stagedPath, "replacement\n");
    fs.rm = async (target, rmOptions) => {
      if (String(target).includes(".kramme-install-backups")) {
        throw cleanupError;
      }
      return originalRm(target, rmOptions);
    };
    try {
      await assert.rejects(
        () =>
          withInstallTransaction(
            root,
            { pluginName: "rollback-cleanup-plugin" },
            async () => {
              await installStagedFile(stagedPath, targetPath, {
                replace: true,
              });
              throw primaryError;
            },
          ),
        (error) => {
          assert.ok(error instanceof Error);
          assert.equal(error.cause, primaryError);
          assert.match(error.message, /primary install failure/);
          assert.match(error.message, /rollback cleanup failure/);
          return true;
        },
      );
    } finally {
      fs.rm = originalRm;
    }

    assert.equal(await readText(targetPath), "stable\n");
    assert.equal(
      await pathExists(path.join(root, ".kramme-install-lock")),
      true,
    );
  });
});

test("transaction attempts every lock release and preserves the primary error", async () => {
  await withTempDir(async (root) => {
    const sharedRoot = path.join(root, "shared-root");
    const sharedLock = path.join(sharedRoot, ".kramme-install-lock");
    const primaryError = new Error("primary transaction failure");
    const releaseError = Object.assign(new Error("lock release failure"), {
      code: "EIO",
    });
    const originalRename = fs.rename;

    fs.rename = async (source, target) => {
      if (
        source === sharedLock &&
        String(target).includes(".kramme-install-lock.release-")
      ) {
        throw releaseError;
      }
      return originalRename(source, target);
    };
    try {
      await assert.rejects(
        () =>
          withInstallTransaction(
            root,
            {
              lockRoots: [sharedRoot],
              pluginName: "release-cleanup-plugin",
            },
            async () => {
              throw primaryError;
            },
          ),
        (error) => {
          assert.ok(error instanceof Error);
          assert.equal(error.cause, primaryError);
          assert.match(error.message, /primary transaction failure/);
          assert.match(error.message, /lock release failure/);
          return true;
        },
      );
    } finally {
      fs.rename = originalRename;
    }

    assert.equal(
      await pathExists(path.join(root, ".kramme-install-lock")),
      false,
    );
    assert.equal(await pathExists(sharedLock), true);
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

function delayForTest(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function assertJsonObjectBoundaryError(error, file, label, kind) {
  assert.ok(error instanceof Error);
  assert.ok(error.message.includes(file));
  assert.match(error.message, new RegExp(`${label} must be a JSON object`));
  assert.match(error.message, new RegExp(`received ${kind}`));
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

async function readJson(file) {
  return JSON.parse(await readText(file));
}

async function createFixturePlugin(pluginRoot, pluginName = "fixture-plugin") {
  await writeJson(path.join(pluginRoot, ".claude-plugin", "plugin.json"), {
    agents: [],
    commands: [],
    name: pluginName,
    skills: [],
    version: "1.0.0",
  });
}

async function writeSkillFile(pluginRoot, skillDir, content) {
  await writeFile(
    path.join(pluginRoot, "skills", skillDir, "SKILL.md"),
    content,
  );
}

async function writeSourceSkill(sourceDir, files) {
  await fs.rm(sourceDir, { force: true, recursive: true });
  for (const [relativePath, content] of Object.entries(files)) {
    await writeFile(path.join(sourceDir, relativePath), content);
  }
}

async function writeFile(file, content) {
  await fs.mkdir(path.dirname(file), { recursive: true });
  await fs.writeFile(file, content, "utf8");
}

async function readText(file) {
  return fs.readFile(file, "utf8");
}

async function readMarkdownTree(root) {
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

async function readFileTree(root, prefix = "") {
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

async function pathExists(file) {
  try {
    await fs.access(file);
    return true;
  } catch {
    return false;
  }
}

function assertFilesystemError(error, { cause, code, message, path: file }) {
  assert.ok(error instanceof Error);
  const filesystemError = /** @type {NodeJS.ErrnoException} */ (error);
  assert.equal(filesystemError.code, code);
  assert.equal(filesystemError.path, file);
  assert.equal(filesystemError.cause, cause);
  assert.match(filesystemError.message, message);
}
