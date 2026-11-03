// @ts-check
"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const {
  COLD_READER,
  CONTROL_AGENT,
  VARIANTS,
  agentFor,
  childEnvironment,
  childPrompt,
  createMarkers,
  evaluate,
  findClaude,
  main,
  parentPrompt,
  parseArgs,
  runVariant,
  sessionOptions,
  stageWorkspace,
} = require("../../scripts/probe-cold-reader-isolation");

/** @typedef {import('../../scripts/probe-cold-reader-isolation').QueryFunction} QueryFunction */
/** @typedef {import('../../scripts/probe-cold-reader-isolation').Variant} Variant */

const AGENT_ID = "toolu_agent";
const STAGED = {
  workspace: "/tmp/probe",
  inputFile: "/tmp/probe/probe-input.md",
};
let counter = 0;
const MARKERS = createMarkers(() => String(++counter).repeat(32));
const SUCCESS = { type: "result", subtype: "success", is_error: false };

/** @param {Record<string, unknown>} [overrides] */
function init(overrides = {}) {
  return {
    type: "system",
    subtype: "init",
    plugins: [{ name: "kramme-cc-workflow" }],
    agents: [COLD_READER, CONTROL_AGENT],
    ...overrides,
  };
}

/** @param {Variant} variant @param {Record<string, unknown>} [input] */
function launch(variant, input = {}) {
  return {
    type: "assistant",
    parent_tool_use_id: null,
    message: {
      content: [
        {
          type: "tool_use",
          id: AGENT_ID,
          name: "Agent",
          input: {
            subagent_type: agentFor(variant),
            prompt: childPrompt(variant, STAGED),
            ...input,
          },
        },
      ],
    },
  };
}

/** @param {string} text */
function childText(text) {
  return {
    type: "assistant",
    parent_tool_use_id: AGENT_ID,
    message: { content: [{ type: "text", text }] },
  };
}

/** @param {string} text */
function agentResult(text) {
  return {
    type: "user",
    parent_tool_use_id: null,
    message: {
      content: [
        {
          type: "tool_result",
          tool_use_id: AGENT_ID,
          content: [{ type: "text", text }],
        },
      ],
    },
  };
}

/** @param {string} filePath */
function childRead(filePath) {
  return {
    type: "assistant",
    parent_tool_use_id: AGENT_ID,
    message: {
      content: [
        {
          type: "tool_use",
          id: "toolu_read",
          name: "Read",
          input: { file_path: filePath },
        },
      ],
    },
  };
}

/** @param {boolean} isError */
function childReadResult(isError) {
  return {
    type: "user",
    parent_tool_use_id: AGENT_ID,
    message: {
      content: [
        {
          type: "tool_result",
          tool_use_id: "toolu_read",
          is_error: isError,
          content: "result",
        },
      ],
    },
  };
}

/** @param {Variant} variant @param {string} answer @param {unknown[]} [childEvents] */
function session(variant, answer, childEvents = []) {
  return [
    init(),
    launch(variant),
    ...childEvents,
    childText(answer),
    agentResult(answer),
    SUCCESS,
  ];
}

const UNREADABLE_EVENTS = [childRead(STAGED.inputFile), childReadResult(true)];

/** @param {unknown[]} events @param {Variant} [variant] */
function problems(events, variant = "isolated") {
  return evaluate(variant, events, MARKERS, STAGED).problems;
}

test("markers are unique and match the probe's marker format", () => {
  const markers = createMarkers();
  assert.match(markers.project, /^MARKER_[0-9a-f]{32}$/);
  assert.match(markers.imported, /^MARKER_[0-9a-f]{32}$/);
  assert.match(markers.parent, /^MARKER_[0-9a-f]{32}$/);
  assert.equal(
    new Set([markers.project, markers.imported, markers.parent]).size,
    3,
  );
});

test("the workspace mirrors this repository's CLAUDE.md import of AGENTS.md", (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "probe-test-"));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const staged = stageWorkspace(root, MARKERS);
  const claude = fs.readFileSync(
    path.join(staged.workspace, "CLAUDE.md"),
    "utf8",
  );
  assert.ok(claude.includes(MARKERS.project));
  assert.ok(claude.includes("@AGENTS.md"));
  assert.ok(
    fs
      .readFileSync(path.join(staged.workspace, "AGENTS.md"), "utf8")
      .includes(MARKERS.imported),
  );
  assert.ok(
    fs.readFileSync(staged.inputFile, "utf8").includes(MARKERS.content),
  );
  assert.equal(staged.workspace, fs.realpathSync(staged.workspace));
});

test("only the control launches a normal agent", () => {
  assert.equal(agentFor("isolated"), COLD_READER);
  assert.equal(agentFor("unreadable"), COLD_READER);
  assert.equal(agentFor("control"), CONTROL_AGENT);
});

test("the parent prompt carries the marker, while the child prompt never does", () => {
  for (const variant of VARIANTS) {
    const prompt = parentPrompt(variant, MARKERS, STAGED);
    const child = childPrompt(variant, STAGED);
    assert.ok(prompt.includes(MARKERS.parent));
    assert.ok(prompt.includes(`subagent_type "${agentFor(variant)}"`));
    assert.ok(prompt.includes(child));
    assert.ok(!child.includes(MARKERS.parent));
    assert.ok(!/MARKER_[0-9a-f]{32}/.test(child));
  }
});

test("the child environment drops everything the CLI does not need", () => {
  const env = childEnvironment({
    PATH: "/bin",
    HOME: "/home/probe",
    ANTHROPIC_API_KEY: "key",
    ANTHROPIC_AUTH_TOKEN: "auth",
    CLAUDE_CODE_OAUTH_TOKEN: "oauth",
    CLAUDECODE: "1",
    CLAUDE_CODE_ENTRYPOINT: "cli",
    GH_TOKEN: "secret",
  });
  assert.equal(env.PATH, "/bin");
  assert.equal(env.HOME, "/home/probe");
  assert.equal(env.ANTHROPIC_API_KEY, "key");
  assert.equal(env.ANTHROPIC_AUTH_TOKEN, "auth");
  assert.equal(env.CLAUDE_CODE_OAUTH_TOKEN, "oauth");
  assert.equal(env.CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC, "1");
  assert.equal(env.CLAUDE_CODE_DISABLE_BACKGROUND_TASKS, "1");
  assert.equal(env.CLAUDECODE, undefined);
  assert.equal(env.CLAUDE_CODE_ENTRYPOINT, undefined);
  assert.equal(env.GH_TOKEN, undefined);
  assert.equal(childEnvironment({}).PATH, "/usr/bin:/bin");
});

test("sessions load project instructions and this plugin, persist nothing, and run no hooks", () => {
  const options = sessionOptions("isolated", STAGED, {
    model: "sonnet",
    env: {},
  });
  assert.deepEqual(options.settingSources, ["project"]);
  assert.equal(options.persistSession, false);
  assert.equal(options.forwardSubagentText, true);
  assert.equal(options.cwd, STAGED.workspace);
  assert.equal(options.model, "sonnet");
  assert.deepEqual(options.allowedTools, ["Agent"]);
  assert.deepEqual(options.mcpServers, {});
  assert.equal(options.strictMcpConfig, true);
  const settings = /** @type {Record<string, any>} */ (options.settings);
  assert.equal(settings.disableAllHooks, true);
  const plugin = /** @type {{path: string}[]} */ (options.plugins)[0];
  assert.equal(
    fs.existsSync(path.join(plugin.path, "agents", "kramme:cold-reader.md")),
    true,
  );
  assert.equal(options.stderr?.("ignored"), undefined);
  assert.equal(options.pathToClaudeCodeExecutable, undefined);
});

test("the probe runs the installed claude rather than the SDK's bundled copy", (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "probe-test-"));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const installed = path.join(root, "claude");
  fs.writeFileSync(installed, "");
  assert.equal(
    findClaude({ PATH: `:/nonexistent${path.delimiter}${root}` }),
    installed,
  );
  assert.equal(findClaude({ PATH: "/nonexistent" }), undefined);
  assert.equal(findClaude({}), undefined);
  assert.equal(
    sessionOptions("isolated", STAGED, {
      model: "sonnet",
      env: {},
      claudePath: installed,
    }).pathToClaudeCodeExecutable,
    installed,
  );
});

test("marker variants withhold file tools without a deny rule that would stop CLAUDE.md loading", () => {
  /** @param {Variant} variant */
  const session = (variant) => {
    const options = sessionOptions(variant, STAGED, {
      model: "sonnet",
      env: {},
    });
    const settings = /** @type {Record<string, any>} */ (options.settings);
    return {
      tools: options.tools,
      deny: /** @type {string[]} */ (settings.permissions.deny),
    };
  };
  for (const variant of /** @type {Variant[]} */ (["isolated", "control"])) {
    assert.deepEqual(session(variant), { tools: ["Agent"], deny: [] });
  }
  assert.deepEqual(session("unreadable"), {
    tools: ["Agent", "Read"],
    deny: [`Read(/${STAGED.inputFile})`],
  });
});

test("a marker variant whose subagent used a tool is not counted", () => {
  const events = [childRead("/tmp/probe/CLAUDE.md"), childReadResult(false)];
  for (const variant of /** @type {Variant[]} */ (["isolated", "control"])) {
    assert.ok(
      problems(session(variant, "UNKNOWN", events), variant).includes(
        "subagent used a tool, so its answer does not show what it had at startup",
      ),
    );
  }
});

test("an isolated cold reader that sees nothing passes", () => {
  const result = evaluate(
    "isolated",
    session("isolated", "UNKNOWN"),
    MARKERS,
    STAGED,
  );
  assert.deepEqual(result.problems, []);
  assert.equal(result.passed, true);
  assert.equal(result.agent, COLD_READER);
  assert.equal(result.answer, "UNKNOWN");
  assert.equal(result.version, null);
});

test("the result names the Claude Code version that ran", () => {
  const result = evaluate(
    "isolated",
    [
      init({ claude_code_version: "2.1.316" }),
      ...session("isolated", "UNKNOWN"),
    ],
    MARKERS,
    STAGED,
  );
  assert.equal(result.version, "2.1.316");
});

test("a hedged answer does not count as isolated or unreadable", () => {
  assert.ok(
    problems(
      session("isolated", "I do see some instructions but\nUNKNOWN"),
    ).includes("cold reader did not answer UNKNOWN"),
  );
  assert.ok(
    problems(
      session(
        "unreadable",
        "UNREADABLE-ish, the first line is probably a heading",
        UNREADABLE_EVENTS,
      ),
      "unreadable",
    ).includes("cold reader answered instead of reporting UNREADABLE"),
  );
});

test("a control fed the markers by its parent does not prove anything", () => {
  const both = `${MARKERS.project}\n${MARKERS.imported}`;
  assert.ok(
    problems(
      [
        init(),
        launch("control", {
          prompt: `${childPrompt("control", STAGED)}\n${both}`,
        }),
        childText(both),
        SUCCESS,
      ],
      "control",
    ).includes("parent changed the probe prompt; result is inconclusive"),
  );
});

test("the answer falls back to the agent result when subagent text is absent", () => {
  const result = evaluate(
    "isolated",
    [init(), launch("isolated"), agentResult("UNKNOWN"), SUCCESS],
    MARKERS,
    STAGED,
  );
  assert.deepEqual(result.problems, []);
  assert.equal(result.answer, "UNKNOWN");
});

test("a cold reader that reports a project marker fails", () => {
  for (const marker of [MARKERS.project, MARKERS.imported]) {
    const found = problems(session("isolated", marker));
    assert.ok(found.includes("cold reader saw project instruction files"));
    assert.ok(found.includes("cold reader did not answer UNKNOWN"));
  }
});

test("a parent marker in the subagent's answer fails every variant", () => {
  for (const variant of VARIANTS) {
    assert.ok(
      problems(session(variant, MARKERS.parent), variant).includes(
        "subagent saw the parent conversation",
      ),
    );
  }
});

test("the control proves the probe can detect a leak", () => {
  const both = `${MARKERS.project}\n${MARKERS.imported}`;
  assert.deepEqual(problems(session("control", both), "control"), []);
  for (const answer of ["UNKNOWN", MARKERS.project, MARKERS.imported]) {
    assert.ok(
      problems(session("control", answer), "control").includes(
        "control agent did not report both project markers; the probe cannot detect a leak",
      ),
    );
  }
});

test("a cold reader that cannot read a named file reports it instead of answering", () => {
  const answer = `UNREADABLE: ${STAGED.inputFile}`;
  assert.deepEqual(
    problems(session("unreadable", answer, UNREADABLE_EVENTS), "unreadable"),
    [],
  );
});

test("a reader may explain itself after reporting an unreadable file", () => {
  const answer = `UNREADABLE: ${STAGED.inputFile}\n\nThe Read tool returned an error.`;
  assert.deepEqual(
    problems(session("unreadable", answer, UNREADABLE_EVENTS), "unreadable"),
    [],
  );
});

test("the unreadable variant catches a reader that guesses, skips the read, or gets through", () => {
  assert.ok(
    problems(
      session("unreadable", "first line", UNREADABLE_EVENTS),
      "unreadable",
    ).includes("cold reader answered instead of reporting UNREADABLE"),
  );
  assert.ok(
    problems(session("unreadable", "UNREADABLE: x"), "unreadable").includes(
      "cold reader never tried to read the named file",
    ),
  );
  const through = problems(
    session("unreadable", MARKERS.content, [
      childRead(STAGED.inputFile),
      childReadResult(false),
    ]),
    "unreadable",
  );
  assert.ok(
    through.includes("a subagent tool call succeeded despite the deny rules"),
  );
  assert.ok(
    through.includes("cold reader returned content it should not have read"),
  );
  assert.ok(
    problems(
      session("unreadable", "UNREADABLE: x", [
        childRead("/elsewhere.md"),
        childReadResult(true),
      ]),
      "unreadable",
    ).includes("cold reader never tried to read the named file"),
  );
});

test("a run with a broken session or plugin load fails", () => {
  assert.ok(
    problems([launch("isolated"), childText("UNKNOWN"), SUCCESS]).includes(
      "session never initialized",
    ),
  );
  assert.ok(
    problems([init(), launch("isolated"), childText("UNKNOWN")]).includes(
      "session did not finish successfully",
    ),
  );
  assert.ok(
    problems([
      init(),
      launch("isolated"),
      childText("UNKNOWN"),
      { type: "result", subtype: "success", is_error: true },
    ]).includes("session did not finish successfully"),
  );
  assert.ok(
    problems([init({ plugins: [] }), ...session("isolated", "UNKNOWN")]).some(
      (problem) => problem.includes("did not load"),
    ),
  );
  assert.ok(
    problems([init({ plugins: "none" })]).some((problem) =>
      problem.includes("did not load"),
    ),
  );
  assert.ok(
    problems([
      init({ plugin_errors: [{ type: "generic-error" }] }),
      ...session("isolated", "UNKNOWN"),
    ]).includes("plugin reported load errors"),
  );
  assert.ok(
    problems([init({ agents: [] }), ...session("isolated", "UNKNOWN")]).some(
      (problem) => problem.includes("is not registered"),
    ),
  );
});

test("a run whose parent misbehaves is not counted as isolated", () => {
  assert.ok(
    problems([init(), childText("UNKNOWN"), SUCCESS]).includes(
      "expected one agent launch, saw 0",
    ),
  );
  assert.ok(
    problems([
      init(),
      launch("isolated"),
      launch("isolated"),
      childText("UNKNOWN"),
      SUCCESS,
    ]).includes("expected one agent launch, saw 2"),
  );
  assert.ok(
    problems([
      init(),
      launch("isolated", { subagent_type: "general-purpose" }),
      childText("UNKNOWN"),
      SUCCESS,
    ]).some((problem) => problem.startsWith("launched general-purpose")),
  );
  assert.ok(
    problems([
      init(),
      launch("isolated", { resume: "agent-1" }),
      childText("UNKNOWN"),
      SUCCESS,
    ]).includes("resumed an earlier agent instead of starting a new one"),
  );
  assert.ok(
    problems([
      init(),
      launch("isolated", { prompt: "Summarized probe" }),
      childText("UNKNOWN"),
      SUCCESS,
    ]).includes("parent changed the probe prompt; result is inconclusive"),
  );
  assert.ok(
    problems([
      init(),
      launch("isolated", {
        prompt: `${childPrompt("isolated", STAGED)} ${MARKERS.parent}`,
      }),
      childText("UNKNOWN"),
      SUCCESS,
    ]).includes("parent changed the probe prompt; result is inconclusive"),
  );
  assert.ok(
    problems([
      init(),
      launch("isolated", { prompt: 7 }),
      childText("UNKNOWN"),
      SUCCESS,
    ]).includes("parent changed the probe prompt; result is inconclusive"),
  );
});

test("the last result decides a session that reports more than once", () => {
  const events = [
    init(),
    launch("isolated"),
    agentResult("Async agent launched"),
    { type: "result", subtype: "success", is_error: false, result: "running" },
    childText("UNKNOWN"),
    SUCCESS,
  ];
  assert.deepEqual(problems(events), []);
  assert.ok(
    problems([
      ...events,
      { type: "result", subtype: "error_during_execution" },
    ]).includes("session did not finish successfully"),
  );
});

test("evaluation ignores content it does not understand", () => {
  const result = evaluate(
    "isolated",
    [
      "not an event",
      [],
      init(),
      { type: "assistant", message: { content: "plain" } },
      {
        type: "assistant",
        parent_tool_use_id: AGENT_ID,
        message: { content: [{ type: "text", text: 7 }, { type: "thinking" }] },
      },
      {
        type: "assistant",
        message: { content: [{ type: "tool_use", name: "Read" }] },
      },
      { type: "user", message: { content: [{ type: "text", text: "hello" }] } },
      {
        type: "user",
        parent_tool_use_id: AGENT_ID,
        message: { content: [{ type: "text", text: "hello" }] },
      },
      launch("isolated"),
      childText("UNKNOWN"),
      {
        type: "user",
        parent_tool_use_id: null,
        message: {
          content: [
            { type: "tool_result", tool_use_id: AGENT_ID, content: "UNKNOWN" },
          ],
        },
      },
      SUCCESS,
    ],
    MARKERS,
    STAGED,
  );
  assert.deepEqual(result.problems, []);
});

test("an empty session reports no answer", () => {
  const result = evaluate("isolated", [], MARKERS, STAGED);
  assert.equal(result.answer, null);
  assert.equal(result.passed, false);
});

/** @param {(prompt: string) => unknown[]} events @param {{closed?: number}} [state] */
function fakeQuery(events, state = {}) {
  /** @type {QueryFunction} */
  return ({ prompt }) =>
    Object.assign(
      (async function* () {
        yield* events(prompt);
      })(),
      {
        close() {
          state.closed = (state.closed || 0) + 1;
        },
      },
    );
}

test("a variant run removes its workspace and closes the session", async (t) => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "probe-test-"));
  t.after(() => fs.rmSync(tmp, { recursive: true, force: true }));
  const state = { closed: 0 };
  const result = await runVariant("isolated", {
    query: fakeQuery(() => session("isolated", "UNKNOWN"), state),
    model: "sonnet",
    env: {},
    tmp,
  });
  assert.equal(state.closed, 1);
  assert.deepEqual(fs.readdirSync(tmp), []);
  // The real workspace path differs from the fixture's, so only the prompt text varies.
  assert.deepEqual(result.problems, []);
  assert.equal(result.passed, true);
});

test("a failed session is reported and still cleans up", async (t) => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "probe-test-"));
  t.after(() => fs.rmSync(tmp, { recursive: true, force: true }));
  const result = await runVariant("control", {
    query: () => {
      throw new Error("no credentials");
    },
    model: "sonnet",
    env: {},
    tmp,
    markers: MARKERS,
  });
  assert.equal(result.passed, false);
  assert.deepEqual(result.problems, ["session failed: no credentials"]);
  assert.deepEqual(fs.readdirSync(tmp), []);
  const withStderr = await runVariant("control", {
    query: ({ options }) => {
      options.stderr?.("Not logged in\n");
      throw new Error("exited with code 1");
    },
    model: "sonnet",
    env: {},
    tmp,
  });
  assert.deepEqual(withStderr.problems, [
    "session failed: exited with code 1\nNot logged in",
  ]);
  const nonError = await runVariant("control", {
    query: () => {
      throw "plain failure";
    },
    model: "sonnet",
    env: {},
    tmp,
  });
  assert.deepEqual(nonError.problems, ["session failed: plain failure"]);
});

test("arguments select a model and one variant, and reject anything else", () => {
  assert.deepEqual(parseArgs([]), { model: "sonnet", variants: VARIANTS });
  assert.deepEqual(parseArgs(["--model", "opus", "--variant", "control"]), {
    model: "opus",
    variants: ["control"],
  });
  assert.deepEqual(parseArgs(["--claude-path", "/opt/claude"]), {
    model: "sonnet",
    variants: VARIANTS,
    claudePath: "/opt/claude",
  });
  for (const argv of [
    ["--variant", "nope"],
    ["--model"],
    ["--model", "--variant"],
    ["--claude-path"],
    ["--unknown", "x"],
  ]) {
    assert.throws(() => parseArgs(argv), /Usage:/);
  }
});

/**
 * @param {string[]} argv
 * @param {(prompt: string) => unknown[]} events
 * @param {import('node:test').TestContext} t
 */
async function runMain(argv, events, t) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "probe-test-"));
  t.after(() => fs.rmSync(tmp, { recursive: true, force: true }));
  let output = "";
  const code = await main(argv, {
    query: fakeQuery(events),
    env: {},
    tmp,
    write: (text) => {
      output += text;
    },
  });
  return { code, output };
}

test("the report is JSON and the exit code reflects the variants", async (t) => {
  const pass = await runMain(
    ["--variant", "isolated"],
    () => session("isolated", "UNKNOWN"),
    t,
  );
  assert.equal(pass.code, 0);
  const report = JSON.parse(pass.output);
  assert.equal(report.probe, "cold-reader-isolation");
  assert.equal(report.claude, "bundled with the Agent SDK");
  assert.equal(report.passed, true);
  assert.equal(report.results.length, 1);

  const fail = await runMain(["--variant", "isolated"], () => [], t);
  assert.equal(fail.code, 1);
  assert.equal(JSON.parse(fail.output).passed, false);

  const usage = await runMain(["--variant", "nope"], () => [], t);
  assert.equal(usage.code, 2);
  assert.match(usage.output, /^Usage:/);
});

test("the default run covers every variant", async (t) => {
  /** @type {string[]} */ const prompts = [];
  const run = await runMain(
    [],
    (prompt) => {
      prompts.push(prompt);
      return [];
    },
    t,
  );
  assert.equal(run.code, 1);
  assert.equal(prompts.length, VARIANTS.length);
  assert.ok(prompts[0].includes(COLD_READER));
  assert.ok(prompts[1].includes(CONTROL_AGENT));
  assert.ok(prompts[2].includes("probe-input.md"));
});
