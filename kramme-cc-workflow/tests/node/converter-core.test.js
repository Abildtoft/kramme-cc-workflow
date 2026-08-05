"use strict";

const assert = require("node:assert/strict");
const { execFileSync } = require("node:child_process");
const fs = require("fs/promises");
const path = require("path");
const test = require("node:test");

const {
  parseAskUserQuestionBlock,
} = require("../../scripts/convert-plugin/ask-user-question-parser");

const {
  codexSkillLocalReplacements,
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

const { skillContracts } = require("../../scripts/schemas/skill-contracts");

const {
  withTempDir,
  writeJson,
  createFixturePlugin,
  writeFile,
  readText,
  assertFilesystemError,
} = require("./converter-test-helpers");

const NON_OBJECT_JSON_CASES = [
  { kind: "null", source: "null", value: null },
  { kind: "array", source: "[]", value: [] },
  { kind: "number", source: "42", value: 42 },
];

test("shared script rewrites preserve shell-safe quoting", () => {
  const replacements = codexSharedScriptReplacements(
    "/tmp/Codex Home",
    [
      {
        sourceDir: path.join("/plugin", "scripts", "dev-server"),
        targetDir: path.join("scripts", "dev-server"),
      },
    ],
    [{ targetPath: path.join("scripts", "collect-review-diff.sh") }],
  );
  const source = [
    'RESOLVED=$("${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh" --strict)',
    "${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh --decode-json",
    '[ -x "${CLAUDE_PLUGIN_ROOT:-}/scripts/collect-review-diff.sh" ]',
    '"${CLAUDE_PLUGIN_ROOT:-}/scripts/dev-server/detect-url.sh" auto',
  ].join("\n");

  assert.equal(
    rewriteCodexSharedScriptReferences(source, replacements),
    [
      "RESOLVED=$('/tmp/Codex Home/scripts/collect-review-diff.sh' --strict)",
      "'/tmp/Codex Home/scripts/collect-review-diff.sh' --decode-json",
      "[ -x '/tmp/Codex Home/scripts/collect-review-diff.sh' ]",
      '"/tmp/Codex Home/scripts/dev-server/detect-url.sh" auto',
    ].join("\n"),
  );
});

test("skill-local rewrites preserve shell-safe quoting", () => {
  const replacements = codexSkillLocalReplacements(
    "/tmp/Codex Home",
    "kramme:git:recreate-commits",
  );
  const source =
    "${CLAUDE_PLUGIN_ROOT}/skills/kramme:git:recreate-commits/scripts/resolve-push-target.sh";

  assert.equal(
    rewriteCodexSharedScriptReferences(source, replacements),
    "'/tmp/Codex Home/skills/kramme:git:recreate-commits'/scripts/resolve-push-target.sh",
  );
});

test("skill-local rewrites execute quoted paths without shell expansion", async () => {
  await withTempDir(async (root) => {
    const codexRoot = path.join(root, "Codex Home $(touch pwned)");
    const skillName = "kramme:git:recreate-commits";
    const helper = path.join(
      codexRoot,
      "skills",
      skillName,
      "scripts",
      "resolve-push-target.sh",
    );
    await fs.mkdir(path.dirname(helper), { recursive: true });
    await fs.writeFile(helper, "#!/bin/sh\nprintf 'resolved\\n'\n");
    await fs.chmod(helper, 0o755);

    const replacements = codexSkillLocalReplacements(codexRoot, skillName);
    const source = `"\${CLAUDE_PLUGIN_ROOT}/skills/${skillName}/scripts/resolve-push-target.sh"`;
    const command = rewriteCodexSharedScriptReferences(source, replacements);

    assert.equal(
      execFileSync("bash", ["-c", command], {
        cwd: root,
        encoding: "utf8",
      }),
      "resolved\n",
    );
    await assert.rejects(fs.stat(path.join(root, "pwned")), { code: "ENOENT" });
  });
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

test("loader rejects non-string marketplace plugin sources", async () => {
  await withTempDir(async (root) => {
    const marketplacePath = path.join(
      root,
      ".claude-plugin",
      "marketplace.json",
    );
    await writeJson(marketplacePath, {
      plugins: [{ name: "fixture-plugin", source: null }],
    });
    const previousCwd = process.cwd();
    process.chdir(root);
    try {
      await assert.rejects(
        resolvePluginInput("fixture-plugin"),
        new RegExp(
          `${escapeRegExp(marketplacePath)}: marketplace plugin "fixture-plugin" source must be a string`,
        ),
      );
    } finally {
      process.chdir(previousCwd);
    }
  });
});

test("loader rejects invalid manifest component path lists", async () => {
  const invalidComponentPaths = [
    { field: "agents", value: 42 },
    { field: "commands", value: ["commands", null] },
    { field: "skills", value: { path: "skills" } },
  ];
  for (const { field, value } of invalidComponentPaths) {
    await withTempDir(async (root) => {
      const pluginRoot = path.join(root, `invalid-${field}-paths-plugin`);
      await writeJson(path.join(pluginRoot, ".claude-plugin", "plugin.json"), {
        agents: [],
        commands: [],
        name: `invalid-${field}-paths-plugin`,
        skills: [],
        version: "1.0.0",
        [field]: value,
      });

      await assert.rejects(
        loadClaudePlugin(pluginRoot),
        new RegExp(
          `Plugin manifest ${field} field must be a string or an array of strings`,
        ),
      );
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

test("loader validates MCP server field types", async () => {
  const invalidConfigs = [
    {
      config: { demo: null },
      message: 'MCP config server "demo" must be a JSON object',
    },
    {
      config: { demo: { args: "--stdio" } },
      message:
        'MCP config server "demo" field "args" must be an array of strings',
    },
    {
      config: { demo: { env: { PORT: 3000 } } },
      message: 'MCP config server "demo" field "env.PORT" must be a string',
    },
  ];

  for (const { config, message } of invalidConfigs) {
    await withTempDir(async (root) => {
      const pluginRoot = path.join(root, "invalid-mcp-server-plugin");
      await createFixturePlugin(pluginRoot, "invalid-mcp-server-plugin");
      const configPath = path.join(pluginRoot, ".mcp.json");
      await writeJson(configPath, config);

      await assert.rejects(
        loadClaudePlugin(pluginRoot),
        new RegExp(`${escapeRegExp(configPath)}: ${escapeRegExp(message)}`),
      );
    });
  }
});

test("loader preserves special MCP server and string-map keys", async () => {
  await withTempDir(async (root) => {
    const pluginRoot = path.join(root, "special-mcp-key-plugin");
    await createFixturePlugin(pluginRoot, "special-mcp-key-plugin");
    const configPath = path.join(pluginRoot, ".mcp.json");
    await writeJson(
      configPath,
      JSON.parse(
        '{"__proto__":{"command":"demo","env":{"__proto__":"env-value"},"headers":{"__proto__":"header-value"}}}',
      ),
    );

    const plugin = await loadClaudePlugin(pluginRoot);

    assert.deepEqual(Object.keys(plugin.mcpServers ?? {}), ["__proto__"]);
    const server = plugin.mcpServers?.__proto__;
    assert.equal(server?.command, "demo");
    assert.equal(server?.env?.__proto__, "env-value");
    assert.equal(server?.headers?.__proto__, "header-value");
    assert.equal(Object.hasOwn(server?.env ?? {}, "__proto__"), true);
    assert.equal(Object.hasOwn(server?.headers ?? {}, "__proto__"), true);
  });
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
      /** @type {Record<string, string>} */
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
  assert.deepEqual(codexPlugin.sharedScriptDirs, [
    {
      sourceDir: path.join("/plugin", "scripts", "dev-server"),
      targetDir: path.join("scripts", "dev-server"),
    },
    {
      sourceDir: path.join("/plugin", "scripts", "lib"),
      targetDir: path.join("scripts", "lib"),
    },
  ]);
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

/** @param {unknown} error @param {string} file @param {string} label @param {string} kind */
function assertJsonObjectBoundaryError(error, file, label, kind) {
  assert.ok(error instanceof Error);
  assert.ok(error.message.includes(file));
  assert.match(error.message, new RegExp(`${label} must be a JSON object`));
  assert.match(error.message, new RegExp(`received ${kind}`));
}

/** @param {string} value */
function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/** @param {string} pluginRoot @param {string} skillDir @param {string} content */
async function writeSkillFile(pluginRoot, skillDir, content) {
  await writeFile(
    path.join(pluginRoot, "skills", skillDir, "SKILL.md"),
    content,
  );
}
