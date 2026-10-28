"use strict";

const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");

const {
  PLATFORM_CLAUDE_CODE,
  PLATFORM_CODEX,
  detectPlatform,
  openCodexRollout,
  readPluginVersion,
  stripConductorInstructions,
} = require("../../scripts/lib/skill-usage-hosts.js");

const SCRIPT = path.resolve(__dirname, "../../scripts/skill-usage.js");
const MIB = 1024 * 1024;
const CONDUCTOR_BLOCK =
  "<system_instruction>\nRun /kramme:conductor:hidden first\n</system_instruction>\n";

/**
 * Builds a child environment free of host markers inherited from the shell
 * that runs the tests, then applies the case's own values.
 * @param {NodeJS.ProcessEnv} [overrides]
 * @returns {NodeJS.ProcessEnv}
 */
function hostEnv(overrides = {}) {
  const env = { ...process.env };
  delete env.CLAUDECODE;
  delete env.KRAMME_AGENT_PLATFORM;
  delete env.KRAMME_SKILL_USAGE_FILE;
  return { ...env, ...overrides };
}

/** @param {string[]} args @param {{ input?: string, env?: NodeJS.ProcessEnv }} [options] */
function runUsage(args, { input, env } = {}) {
  return spawnSync(process.execPath, [SCRIPT, ...args], {
    encoding: "utf8",
    input,
    env: hostEnv(env),
    maxBuffer: 5 * MIB,
  });
}

/** @param {import("node:test").TestContext} t */
async function tempDir(t) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "skill-usage-hosts-"));
  t.after(() => fs.rm(root, { recursive: true, force: true }));
  return root;
}

/** @param {string} file @param {unknown[]} lines */
async function writeJsonLines(file, lines) {
  const text = lines
    .map((line) => (typeof line === "string" ? line : JSON.stringify(line)))
    .join("\n");
  await fs.writeFile(file, `${text}\n`);
}

/** @param {string} id @param {Record<string, unknown>} [payload] */
function sessionMeta(id, payload = {}) {
  return {
    timestamp: "2026-10-10T09:00:00.000Z",
    type: "session_meta",
    payload: {
      id,
      session_id: id,
      timestamp: "2026-10-10T09:00:00.000Z",
      cwd: "/repo",
      originator: "codex_vscode",
      cli_version: "0.162.1",
      source: "vscode",
      ...payload,
    },
  };
}

/** @param {string} role @param {string} timestamp @param {...string} texts */
function message(role, timestamp, ...texts) {
  return {
    timestamp,
    type: "response_item",
    payload: {
      type: "message",
      role,
      content: texts.map((text) => ({
        type: role === "assistant" ? "output_text" : "input_text",
        text,
      })),
    },
  };
}

/** @param {string} timestamp @param {...string} texts */
function userMessage(timestamp, ...texts) {
  return message("user", timestamp, ...texts);
}

const SUBAGENT_SOURCE = {
  subagent: { thread_spawn: { parent_thread_id: "thread-top", depth: 1 } },
};

/** @param {string} root */
async function writeCodexSessions(root) {
  const day = path.join(root, "2026", "10", "10");
  await fs.mkdir(day, { recursive: true });
  const topFile = path.join(
    day,
    "rollout-2026-10-10T09-00-00-thread-top.jsonl",
  );
  await writeJsonLines(topFile, [
    sessionMeta("thread-top"),
    userMessage(
      "2026-10-10T09:00:01.000Z",
      "# AGENTS.md instructions for /repo\n\nUse /kramme:skill:create to add skills.",
    ),
    userMessage(
      "2026-10-10T09:00:01.000Z",
      "<environment_context>\n  <cwd>/repo</cwd> /kramme:env:probe\n</environment_context>",
    ),
    {
      timestamp: "2026-10-10T09:59:00.000Z",
      type: "turn_context",
      payload: { cwd: "/repo" },
    },
    userMessage(
      "2026-10-10T10:00:00.000Z",
      CONDUCTOR_BLOCK,
      "$kramme:pr:create please",
    ),
    message("developer", "2026-10-10T10:00:00.000Z", "Try $kramme:other:dev"),
    message("assistant", "2026-10-10T10:00:01.000Z", "Ran $kramme:other:reply"),
    {
      timestamp: "2026-10-10T10:00:02.000Z",
      type: "event_msg",
      payload: {
        type: "item_completed",
        item: {
          type: "UserMessage",
          content: [{ type: "text", text: "$kramme:pr:create please" }],
        },
      },
    },
    {
      timestamp: "2026-10-10T10:30:00.000Z",
      type: "compacted",
      payload: {
        message: "",
        replacement_history: [
          {
            type: "message",
            role: "user",
            content: [{ type: "input_text", text: "$kramme:pr:create please" }],
          },
        ],
      },
    },
    "{malformed",
    userMessage(
      "2026-10-12T08:00:00.000Z",
      "/kramme:qa first, then $kramme:qa again",
    ),
  ]);

  const execFile = path.join(
    day,
    "rollout-2026-10-10T11-00-00-thread-exec.jsonl",
  );
  await writeJsonLines(execFile, [
    sessionMeta("thread-exec", { thread_source: "user", source: "exec" }),
    userMessage(
      "2026-10-15T12:00:00.000Z",
      "$kramme:pr:create then $kramme-cc-workflow:kramme-pr-rebase",
    ),
  ]);

  const subagentFile = path.join(day, "rollout-2026-10-10T10-05-00-sub.jsonl");
  await writeJsonLines(subagentFile, [
    sessionMeta("thread-sub", {
      thread_source: "subagent",
      parent_thread_id: "thread-top",
      source: SUBAGENT_SOURCE,
    }),
    userMessage("2026-10-10T10:05:00.000Z", "$kramme:pr:create please"),
    "{malformed subagent line",
    "{another malformed subagent line",
  ]);

  // Forked subagents replay the parent's history after a second, top-level
  // looking `session_meta`; only the first record classifies the file.
  const forkedFile = path.join(day, "rollout-2026-10-10T10-06-00-fork.jsonl");
  await writeJsonLines(forkedFile, [
    sessionMeta("thread-fork", { source: SUBAGENT_SOURCE }),
    sessionMeta("thread-top"),
    userMessage("2026-10-10T10:00:00.000Z", "$kramme:pr:create please"),
  ]);

  return { topFile };
}

test("detectPlatform prefers explicit overrides over detected hosts", () => {
  const codexPayload = { turn_id: "turn-1" };
  assert.equal(
    detectPlatform(
      { ...codexPayload, platform: "custom" },
      { KRAMME_AGENT_PLATFORM: "env-value", CLAUDECODE: "1" },
    ),
    "custom",
  );
  assert.equal(
    detectPlatform(codexPayload, {
      KRAMME_AGENT_PLATFORM: "env-value",
      CLAUDECODE: "1",
    }),
    "env-value",
  );
  assert.equal(
    detectPlatform(
      { platform: "", turn_id: "turn-1" },
      { KRAMME_AGENT_PLATFORM: "" },
    ),
    PLATFORM_CODEX,
  );
});

test("detectPlatform checks Codex markers before CLAUDECODE", () => {
  assert.equal(
    detectPlatform({ turn_id: "turn-1" }, { CLAUDECODE: "1" }),
    PLATFORM_CODEX,
  );
  assert.equal(
    detectPlatform(
      {
        transcript_path:
          "/home/u/.codex/sessions/2026/10/10/rollout-2026-10-10T09-00-00-abc.jsonl",
      },
      { CLAUDECODE: "1" },
    ),
    PLATFORM_CODEX,
  );
  assert.equal(
    detectPlatform(
      {
        turn_id: "",
        transcript_path: "/home/u/.claude/projects/repo/abc.jsonl",
      },
      { CLAUDECODE: "1" },
    ),
    PLATFORM_CLAUDE_CODE,
  );
  assert.equal(detectPlatform({ transcript_path: null, turn_id: 7 }, {}), "");
  assert.equal(detectPlatform({}, { CLAUDECODE: "0" }), "");
  assert.equal(detectPlatform(null, {}), "");
});

test("readPluginVersion reads the Claude Code manifest, then the Codex one", async (t) => {
  const root = await tempDir(t);
  /** @param {string} name @param {Record<string, string>} manifests */
  const pluginRoot = async (name, manifests) => {
    const dir = path.join(root, name);
    for (const [file, content] of Object.entries(manifests)) {
      await fs.mkdir(path.join(dir, path.dirname(file)), { recursive: true });
      await fs.writeFile(path.join(dir, file), content);
    }
    return dir;
  };

  const roots = [
    await pluginRoot("claude", {
      ".claude-plugin/plugin.json": '{"version":"0.90.0"}',
      ".codex-plugin/plugin.json": '{"version":"0.89.0"}',
    }),
    await pluginRoot("codex", {
      ".codex-plugin/plugin.json": '{"version":"0.89.0"}',
    }),
    await pluginRoot("broken", {
      ".claude-plugin/plugin.json": "{not json",
      ".codex-plugin/plugin.json": '{"version":"0.88.0"}',
    }),
    await pluginRoot("unversioned", {
      ".claude-plugin/plugin.json": '{"name":"kramme-cc-workflow"}',
    }),
    path.join(root, "missing"),
  ];

  assert.deepEqual(roots.map(readPluginVersion), [
    "0.90.0",
    "0.89.0",
    "0.88.0",
    "",
    "",
  ]);
});

test("stripConductorInstructions keeps only text after the last block", () => {
  assert.equal(stripConductorInstructions("$kramme:qa"), "$kramme:qa");
  assert.equal(
    stripConductorInstructions(`${CONDUCTOR_BLOCK}$kramme:qa`),
    "\n$kramme:qa",
  );
  assert.equal(
    stripConductorInstructions(
      "<system_instruction>a</system_instruction> b </system_instruction>tail",
    ),
    "tail",
  );
});

test("openCodexRollout classifies threads by their first session_meta", () => {
  assert.equal(openCodexRollout(null), null);
  assert.equal(openCodexRollout({ type: "user", message: {} }), null);
  assert.equal(openCodexRollout({ type: "session_meta", payload: [] }), null);

  const topLevel = openCodexRollout(sessionMeta("thread-top"));
  assert.ok(topLevel);
  assert.equal(topLevel.skipFile, false);
  assert.equal(topLevel.sessionId, "thread-top");

  const exec = openCodexRollout(
    sessionMeta("", {
      session_id: "thread-exec",
      thread_source: "user",
      source: "exec",
    }),
  );
  assert.ok(exec);
  assert.equal(exec.skipFile, false);
  assert.equal(exec.sessionId, "thread-exec");

  const subagent = openCodexRollout(
    sessionMeta("thread-sub", { thread_source: "subagent", source: "vscode" }),
  );
  assert.equal(subagent?.skipFile, true);
  const forked = openCodexRollout(
    sessionMeta("thread-fork", { source: SUBAGENT_SOURCE }),
  );
  assert.equal(forked?.skipFile, true);
});

test("Codex rollout prompts include only the user's own message text", () => {
  const rollout = openCodexRollout(sessionMeta("thread-top"));
  assert.ok(rollout);
  assert.deepEqual(
    rollout.prompts(
      userMessage("2026-10-10T10:00:00.000Z", CONDUCTOR_BLOCK, "$kramme:qa"),
    ),
    [{ text: "\n\n$kramme:qa", recordedAt: "2026-10-10T10:00:00.000Z" }],
  );
  assert.deepEqual(
    rollout.prompts(userMessage("t", "  # AGENTS.md instructions for /repo")),
    [],
  );
  assert.deepEqual(
    rollout.prompts(userMessage("t", "<environment_context>")),
    [],
  );
  assert.deepEqual(
    rollout.prompts(message("developer", "t", "$kramme:qa")),
    [],
  );
  assert.deepEqual(
    rollout.prompts({
      type: "response_item",
      payload: { type: "message", role: "user" },
    }),
    [],
  );
  assert.deepEqual(
    rollout.prompts({
      type: "response_item",
      payload: {
        type: "message",
        role: "user",
        content: [
          { type: "input_image" },
          { type: "input_text", text: "$kramme:qa" },
        ],
      },
    }),
    [{ text: "$kramme:qa", recordedAt: "" }],
  );
});

test("scan counts explicit invocations in top-level Codex threads only", async (t) => {
  const root = await tempDir(t);
  const { topFile } = await writeCodexSessions(root);

  const result = runUsage(["scan", root, "--json"]);

  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(result.stdout), {
    summary: [
      {
        skill: "kramme:pr:create",
        total: 2,
        explicit: 2,
        tool: 0,
        firstUsedAt: "2026-10-10T10:00:00.000Z",
        lastUsedAt: "2026-10-15T12:00:00.000Z",
        sessions: 2,
      },
      {
        skill: "kramme:pr:rebase",
        total: 1,
        explicit: 1,
        tool: 0,
        firstUsedAt: "2026-10-15T12:00:00.000Z",
        lastUsedAt: "2026-10-15T12:00:00.000Z",
        sessions: 1,
      },
      {
        skill: "kramme:qa",
        total: 1,
        explicit: 1,
        tool: 0,
        firstUsedAt: "2026-10-12T08:00:00.000Z",
        lastUsedAt: "2026-10-12T08:00:00.000Z",
        sessions: 1,
      },
    ],
    diagnostics: { skippedLines: 1, readFailures: 0 },
  });
  assert.equal(
    result.stderr,
    `skill-usage: skipped 1 malformed JSONL line file=${topFile}\n`,
  );

  const strict = runUsage(["scan", root, "--json", "--strict"]);
  assert.equal(strict.status, 1);
});

test("scan filters Codex invocations by message timestamp", async (t) => {
  const root = await tempDir(t);
  await writeCodexSessions(root);

  const result = runUsage(["scan", root, "--since", "2026-10-11", "--json"]);

  assert.equal(result.status, 0, result.stderr);
  const { summary } = JSON.parse(result.stdout);
  assert.deepEqual(
    summary.map((/** @type {{ skill: string, total: number }} */ row) => [
      row.skill,
      row.total,
    ]),
    [
      ["kramme:pr:create", 1],
      ["kramme:pr:rebase", 1],
      ["kramme:qa", 1],
    ],
  );
});

test("scan reports overlong Codex lines and keeps counting", async (t) => {
  const root = await tempDir(t);
  const file = path.join(root, "rollout-2026-10-10T09-00-00-big.jsonl");
  await writeJsonLines(file, [
    sessionMeta("thread-big"),
    JSON.stringify({
      type: "event_msg",
      payload: { output: "x".repeat(MIB + 1) },
    }),
    userMessage("2026-10-10T10:00:00.000Z", "$kramme:qa"),
  ]);

  const result = runUsage(["scan", file, "--json"]);

  assert.equal(result.status, 0, result.stderr);
  const parsed = JSON.parse(result.stdout);
  assert.equal(parsed.summary[0].skill, "kramme:qa");
  assert.deepEqual(parsed.diagnostics, { skippedLines: 1, readFailures: 0 });
  assert.equal(
    result.stderr,
    `skill-usage: skipped 1 overlong JSONL line file=${file}\n`,
  );
});

/** @param {string} file */
async function readUsageLines(file) {
  const text = await fs.readFile(file, "utf8");
  return text
    .trim()
    .split("\n")
    .map((line) => JSON.parse(line));
}

test("record recognises Codex prompt syntax after the Conductor block", async (t) => {
  const root = await tempDir(t);
  const usageFile = path.join(root, "usage.jsonl");
  const payload = {
    hook_event_name: "UserPromptSubmit",
    session_id: "thread-1",
    turn_id: "turn-1",
    transcript_path: null,
    cwd: "/repo",
    model: "gpt-5",
    permission_mode: "default",
    prompt: `${CONDUCTOR_BLOCK}$kramme-cc-workflow:kramme-pr-create and /kramme:qa`,
  };

  const result = runUsage(["record", "--file", usageFile], {
    input: JSON.stringify(payload),
    env: { CLAUDECODE: "1" },
  });

  assert.equal(result.status, 0, result.stderr);
  const records = await readUsageLines(usageFile);
  assert.deepEqual(
    records.map((record) => [record.skill, record.platform, record.sessionId]),
    [
      ["kramme:pr:create", "codex", "thread-1"],
      ["kramme:qa", "codex", "thread-1"],
    ],
  );
});

test("record keeps the Claude Code prompt syntax and marks the host", async (t) => {
  const root = await tempDir(t);
  const usageFile = path.join(root, "usage.jsonl");
  const payload = {
    hook_event_name: "UserPromptSubmit",
    session_id: "claude-1",
    prompt: "Ignore $kramme:pr:create but run /kramme:qa",
  };

  const claude = runUsage(["record", "--file", usageFile], {
    input: JSON.stringify(payload),
    env: { CLAUDECODE: "1" },
  });
  const unknown = runUsage(["record", "--file", usageFile], {
    input: JSON.stringify(payload),
  });

  assert.equal(claude.status, 0, claude.stderr);
  assert.equal(unknown.status, 0, unknown.stderr);
  const records = await readUsageLines(usageFile);
  assert.deepEqual(
    records.map((record) => [record.skill, record.platform]),
    [
      ["kramme:qa", "claude-code"],
      ["kramme:qa", ""],
    ],
  );
});

test("record lets explicit platform overrides win over detection", async (t) => {
  const root = await tempDir(t);
  const usageFile = path.join(root, "usage.jsonl");

  const fromPayload = runUsage(["record", "--file", usageFile], {
    input: JSON.stringify({
      platform: "custom",
      turn_id: "turn-1",
      prompt: "/kramme:qa",
    }),
    env: { KRAMME_AGENT_PLATFORM: "codex" },
  });
  const fromEnv = runUsage(["record", "--file", usageFile], {
    input: JSON.stringify({ prompt: "$kramme:pr:create" }),
    env: { KRAMME_AGENT_PLATFORM: "codex", CLAUDECODE: "1" },
  });

  assert.equal(fromPayload.status, 0, fromPayload.stderr);
  assert.equal(fromEnv.status, 0, fromEnv.stderr);
  const records = await readUsageLines(usageFile);
  assert.deepEqual(
    records.map((record) => [record.skill, record.platform]),
    [
      ["kramme:qa", "custom"],
      ["kramme:pr:create", "codex"],
    ],
  );
});

test("report filters usage records by platform", async (t) => {
  const root = await tempDir(t);
  const usageFile = path.join(root, "usage.jsonl");
  await writeJsonLines(
    usageFile,
    [
      ["kramme:pr:create", "codex"],
      ["kramme:qa", "claude-code"],
      ["kramme:verify:run", ""],
    ].map(([skill, platform], index) => ({
      schemaVersion: 1,
      recordedAt: `2026-10-1${index}T10:00:00.000Z`,
      sessionId: `session-${index}`,
      platform,
      skill,
      kind: "explicit",
    })),
  );

  /** @param {string[]} args */
  const skills = (...args) => {
    const result = runUsage(["report", "--file", usageFile, "--json", ...args]);
    assert.equal(result.status, 0, result.stderr);
    return JSON.parse(result.stdout).map(
      (/** @type {{ skill: string }} */ row) => row.skill,
    );
  };

  assert.deepEqual(skills("--platform", "codex"), ["kramme:pr:create"]);
  assert.deepEqual(skills("--platform=claude-code"), ["kramme:qa"]);
  assert.deepEqual(skills("--platform", "unknown"), ["kramme:verify:run"]);
  assert.deepEqual(skills("--platform", "all"), [
    "kramme:pr:create",
    "kramme:qa",
    "kramme:verify:run",
  ]);
  assert.deepEqual(skills(), skills("--platform", "all"));

  const table = runUsage([
    "report",
    "--file",
    usageFile,
    "--platform",
    "codex",
  ]);
  assert.equal(table.status, 0, table.stderr);
  assert.match(table.stdout.split("\n")[0], / platform=codex$/);
  const unfiltered = runUsage(["report", "--file", usageFile]);
  assert.doesNotMatch(unfiltered.stdout, /platform=/);
});
