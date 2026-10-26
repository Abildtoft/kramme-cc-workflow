"use strict";

const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");

const {
  TOOL_ONLY_ROW,
  buildCostRows,
  createSessionGrouper,
  indexTranscripts,
  median,
  renderCost,
  summarizeSession,
  weightedTokens,
} = require("../../scripts/lib/skill-usage-cost.js");

const SCRIPT = path.resolve(__dirname, "../../scripts/skill-usage.js");
const MIB = 1024 * 1024;
const PROMPT_MARKER = "PRIVATE_PROMPT_MARKER";
const DESCRIPTION_MARKER = "PRIVATE_DESCRIPTION_MARKER";
const PATH_MARKER = "PRIVATE_PATH_MARKER";
const LIMIT_TEXT = "You've hit your session limit · resets 5pm";

/** @param {string[]} args @param {NodeJS.ProcessEnv} [overrides] */
function runUsage(args, overrides = {}) {
  const env = { ...process.env };
  delete env.KRAMME_SKILL_USAGE_FILE;
  delete env.CLAUDE_CONFIG_DIR;
  return spawnSync(process.execPath, [SCRIPT, ...args], {
    encoding: "utf8",
    env: { ...env, ...overrides },
    maxBuffer: 5 * MIB,
  });
}

/** @param {import("node:test").TestContext} t */
async function tempDir(t) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "skill-usage-cost-"));
  t.after(() => fs.rm(root, { recursive: true, force: true }));
  return root;
}

/** @param {string} file @param {unknown[]} records */
async function writeJsonl(file, records) {
  await fs.mkdir(path.dirname(file), { recursive: true });
  await fs.writeFile(
    file,
    records
      .map((record) =>
        typeof record === "string" ? record : JSON.stringify(record),
      )
      .join("\n") + "\n",
  );
}

/** @param {string} file */
async function* readLines(file) {
  const text = await fs.readFile(file, "utf8");
  for (const line of text.split("\n")) yield { line, overlong: false };
}

function createDeps() {
  const calls = { skipped: /** @type {string[]} */ ([]), failures: 0 };
  return {
    calls,
    deps: {
      readLines,
      /** @param {string} _file @param {number} count @param {string} reason */
      skipped: (_file, count, reason) => {
        if (count > 0) calls.skipped.push(`${count} ${reason}`);
      },
      readFailure: () => {
        calls.failures += 1;
      },
    },
  };
}

/** @param {number} totalCostUSD @param {boolean} [unknown] */
function costState(totalCostUSD, unknown = false) {
  return {
    type: "cost-state",
    sessionId: "ignored",
    startTime: 1,
    totalCostUSD,
    hasUnknownModelCost: unknown,
    modelUsage: {},
  };
}

/** @param {string} id @param {Record<string, number>} usage @param {Record<string, unknown>} [extra] */
function assistant(id, usage, extra = {}) {
  return {
    type: "assistant",
    message: { id, role: "assistant", content: [{ type: "text" }], usage },
    ...extra,
  };
}

/** @param {string} sessionId @param {string} skill @param {string} recordedAt @param {Record<string, string>} [extra] */
function usage(sessionId, skill, recordedAt, extra = {}) {
  return {
    schemaVersion: 1,
    recordedAt,
    sessionId,
    cwd: `/work/${PATH_MARKER}`,
    platform: "claude-code",
    event: "UserPromptSubmit",
    skill,
    kind: "explicit",
    source: "prompt",
    ...extra,
  };
}

/**
 * Builds a usage log and a projects tree covering every report rule.
 * @param {string} root
 */
async function writeFixture(root) {
  const usageFile = path.join(root, "skill-usage.jsonl");
  const projects = path.join(root, "projects");
  const projectA = path.join(projects, `-work-${PATH_MARKER}-a`);
  const projectB = path.join(projects, "-work-b");

  await writeJsonl(usageFile, [
    usage("s-main", "kramme:verify:run", "2026-10-10T09:00:00.000Z", {
      kind: "tool",
      source: "tool_input",
    }),
    usage("s-main", "kramme:pr:create", "2026-10-10T10:00:00.000Z"),
    usage("s-main", "kramme:pr:rebase", "2026-10-10T11:00:00.000Z"),
    usage("s-limit", "kramme:pr:create", "2026-10-11T10:00:00.000Z"),
    usage("s-tool", "kramme:verify:run", "2026-10-12T10:00:00.000Z", {
      kind: "tool",
      source: "tool_input",
    }),
    usage("s-codex", "kramme:pr:code-review", "2026-10-12T10:00:00.000Z", {
      platform: "codex",
    }),
    usage("s-old", "kramme:code:plan-to-pr", "2026-09-01T10:00:00.000Z"),
    usage("s-missing", "kramme:qa", "2026-10-13T10:00:00.000Z"),
  ]);

  await writeJsonl(path.join(projectA, "s-main.jsonl"), [
    {
      type: "user",
      message: { role: "user", content: `${PROMPT_MARKER} /kramme:pr:create` },
    },
    costState(1.5),
    assistant("m1", {
      input_tokens: 100,
      cache_creation_input_tokens: 40,
      cache_read_input_tokens: 1000,
      output_tokens: 10,
    }),
    assistant("m1", {
      input_tokens: 100,
      cache_creation_input_tokens: 40,
      cache_read_input_tokens: 1000,
      output_tokens: 10,
    }),
    assistant("m2", { output_tokens: 20 }),
    {
      type: "user",
      isApiErrorMessage: true,
      parentRole: "assistant",
      message: { role: "user", content: [{ type: "text", text: LIMIT_TEXT }] },
    },
    '{"type":"assistant", broken',
    costState(4.25),
  ]);
  const subagents = path.join(projectA, "s-main", "subagents");
  await writeJsonl(path.join(subagents, "agent-a1.jsonl"), [
    assistant("a1", { input_tokens: 500 }, { isSidechain: true }),
  ]);
  await writeJsonl(path.join(subagents, "agent-a1.meta.json"), [
    {
      agentType: "kramme-cc-workflow:kramme:code-reviewer",
      description: DESCRIPTION_MARKER,
    },
  ]);
  await writeJsonl(path.join(subagents, "agent-a2.jsonl"), [
    assistant("a2", { input_tokens: 200 }, { isSidechain: true }),
  ]);
  await writeJsonl(path.join(subagents, "agent-a2.meta.json"), [
    { agentType: "general-purpose", model: "haiku", description: "x" },
  ]);
  await writeJsonl(path.join(subagents, "agent-a3.jsonl"), [
    assistant("a3", { input_tokens: 50 }, { isSidechain: true }),
  ]);
  await writeJsonl(path.join(subagents, "agent-a3.meta.json"), ["{not json"]);
  await fs.mkdir(path.join(projectA, "s-tool", "tool-results"), {
    recursive: true,
  });

  await writeJsonl(path.join(projectB, "s-limit.jsonl"), [
    costState(10, true),
    assistant(
      "err-1",
      { input_tokens: 0, output_tokens: 0 },
      {
        isApiErrorMessage: true,
        error: "rate_limit",
        message: {
          id: "err-1",
          role: "assistant",
          content: [{ type: "text", text: LIMIT_TEXT }],
          usage: {},
        },
      },
    ),
    JSON.stringify({ type: "user", text: "x".repeat(MIB + 16) }),
  ]);
  await writeJsonl(path.join(projectB, "s-tool.jsonl"), [costState(2)]);
  await writeJsonl(path.join(projectB, "s-old.jsonl"), [costState(99)]);
  await writeJsonl(path.join(projectB, "s-codex.jsonl"), [costState(50)]);

  return { usageFile, projects };
}

const EXPECTED_PR_CREATE = {
  entrySkill: "kramme:pr:create",
  sessions: 2,
  sessionsWithTranscript: 2,
  sessionsWithCost: 2,
  totalCostUSD: 14.25,
  medianCostUSD: 7.13,
  maxCostUSD: 10,
  unknownModelCostSessions: 1,
  limitHitSessions: 1,
  mainWeightedTokens: 400,
  subagentWeightedTokens: 750,
  subagentShare: 0.6522,
  agentTypes: [
    {
      agentType: "kramme-cc-workflow:kramme:code-reviewer",
      launches: 1,
      modelOverrides: 0,
      weightedTokens: 500,
      share: 0.4348,
    },
    {
      agentType: "general-purpose",
      launches: 1,
      modelOverrides: 1,
      weightedTokens: 200,
      share: 0.1739,
    },
    {
      agentType: "(unknown)",
      launches: 1,
      modelOverrides: 0,
      weightedTokens: 50,
      share: 0.0435,
    },
  ],
};

/** @param {string} entrySkill @param {number} cost */
function plainRow(entrySkill, cost) {
  return {
    entrySkill,
    sessions: 1,
    sessionsWithTranscript: 1,
    sessionsWithCost: 1,
    totalCostUSD: cost,
    medianCostUSD: cost,
    maxCostUSD: cost,
    unknownModelCostSessions: 0,
    limitHitSessions: 0,
    mainWeightedTokens: 0,
    subagentWeightedTokens: 0,
    subagentShare: 0,
    agentTypes: [],
  };
}

const EXPECTED_MISSING = {
  ...plainRow("kramme:qa", 0),
  sessionsWithTranscript: 0,
  sessionsWithCost: 0,
  medianCostUSD: null,
  maxCostUSD: null,
};

test("weightedTokens weights cache and output by relative price", () => {
  assert.equal(
    weightedTokens({
      input_tokens: 100,
      cache_creation_input_tokens: 40,
      cache_read_input_tokens: 1000,
      output_tokens: 10,
    }),
    300,
  );
  assert.equal(weightedTokens({ input_tokens: -5, output_tokens: "9" }), 0);
  assert.equal(weightedTokens(undefined), 0);
});

test("median handles odd, even, and empty inputs", () => {
  assert.equal(median([3, 1, 2]), 2);
  assert.equal(median([4, 1, 3, 2]), 2.5);
  assert.equal(median([]), null);
});

test("session grouper prefers the earliest explicit record over tool records", () => {
  const grouper = createSessionGrouper();
  /** @param {string} sessionId @param {string} skill @param {string} recordedAt */
  const record = (sessionId, skill, recordedAt, kind = "explicit") => ({
    sessionId,
    skill,
    recordedAt,
    kind,
  });
  grouper.add(record("a", "kramme:verify:run", "2026-10-01T00:00:00Z", "tool"));
  grouper.add(record("a", "kramme:pr:create", "2026-10-02T00:00:00Z"));
  grouper.add(record("a", "kramme:pr:rebase", "2026-10-03T00:00:00Z"));
  grouper.add(record("b", "kramme:verify:run", "2026-10-05T00:00:00Z", "tool"));
  grouper.add(record("", "kramme:qa", "2026-10-05T00:00:00Z"));

  assert.deepEqual(grouper.entries(null), [
    { sessionId: "a", entrySkill: "kramme:pr:create" },
    { sessionId: "b", entrySkill: TOOL_ONLY_ROW },
  ]);
  assert.deepEqual(grouper.entries(new Date("2026-10-04T00:00:00Z")), [
    { sessionId: "b", entrySkill: TOOL_ONLY_ROW },
  ]);
});

test("summarizeSession keeps the last snapshot, dedupes messages, and counts only assistant limit errors", async (t) => {
  const root = await tempDir(t);
  const { projects } = await writeFixture(root);
  const { deps, calls } = createDeps();
  const index = await indexTranscripts(projects, deps);

  assert.deepEqual([...index.keys()].sort(), [
    "s-codex",
    "s-limit",
    "s-main",
    "s-old",
    "s-tool",
  ]);
  assert.equal(index.get("s-limit")?.subagentsDir, null);

  const main = await summarizeSession(index.get("s-main"), deps);
  assert.equal(main.costUSD, 4.25);
  assert.equal(main.limitHit, false);
  assert.equal(main.weightedTokens, 400);
  assert.deepEqual(main.subagents, [
    {
      agentType: "kramme-cc-workflow:kramme:code-reviewer",
      modelOverride: false,
      weightedTokens: 500,
    },
    { agentType: "general-purpose", modelOverride: true, weightedTokens: 200 },
    { agentType: "(unknown)", modelOverride: false, weightedTokens: 50 },
  ]);
  assert.deepEqual(calls.skipped, [
    "1 malformed JSONL",
    "1 invalid subagent meta",
  ]);

  const limited = await summarizeSession(index.get("s-limit"), deps);
  assert.equal(limited.limitHit, true);
  assert.equal(limited.unknownModelCost, true);

  const tool = await summarizeSession(index.get("s-tool"), deps);
  assert.deepEqual(tool.subagents, []);
  assert.equal(calls.failures, 0);

  assert.deepEqual(await summarizeSession(undefined, deps), {
    hasTranscript: false,
    costUSD: null,
    unknownModelCost: false,
    limitHit: false,
    weightedTokens: 0,
    subagents: [],
  });
});

test("summarizeSession includes agents nested in workflow directories", async (t) => {
  const root = await tempDir(t);
  const { projects } = await writeFixture(root);
  const nested = path.join(
    projects,
    `-work-${PATH_MARKER}-a`,
    "s-main",
    "subagents",
    "workflows",
    "wf-1",
  );
  await writeJsonl(path.join(nested, "agent-nested.jsonl"), [
    assistant("nested", { input_tokens: 75 }),
  ]);
  await writeJsonl(path.join(nested, "agent-nested.meta.json"), [
    { agentType: "nested-reviewer" },
  ]);

  const { deps } = createDeps();
  const index = await indexTranscripts(projects, deps);
  const summary = await summarizeSession(index.get("s-main"), deps);
  assert.deepEqual(summary.subagents.at(-1), {
    agentType: "nested-reviewer",
    modelOverride: false,
    weightedTokens: 75,
  });
});

test("summarizeSession excludes a transcript after a read failure", async () => {
  const { deps, calls } = createDeps();
  deps.readLines = async function* () {
    throw Object.assign(new Error("permission denied"), { code: "EACCES" });
  };

  const summary = await summarizeSession(
    { transcript: "/unreadable/session.jsonl", subagentsDir: null },
    deps,
  );
  assert.equal(summary.hasTranscript, false);
  assert.equal(calls.failures, 1);
});

test("cost reports entry-skill rows with diagnostics and excludes Codex sessions", async (t) => {
  const root = await tempDir(t);
  const { usageFile, projects } = await writeFixture(root);

  const result = runUsage([
    "cost",
    "--file",
    usageFile,
    "--projects",
    projects,
    "--since",
    "2026-10-01",
    "--json",
  ]);

  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(result.stdout), {
    summary: [EXPECTED_PR_CREATE, plainRow(TOOL_ONLY_ROW, 2), EXPECTED_MISSING],
    diagnostics: { skippedLines: 3, readFailures: 0 },
  });
  assert.match(result.stderr, /skipped 1 overlong JSONL line file=/);
  assert.match(result.stderr, /skipped 1 malformed JSONL line file=/);
  assert.match(result.stderr, /skipped 1 invalid subagent meta line file=/);

  const strict = runUsage([
    "cost",
    `--file=${usageFile}`,
    `--projects=${projects}`,
    "--json",
    "--strict",
    "--limit",
    "2",
  ]);
  assert.equal(strict.status, 1);
  const strictResult = JSON.parse(strict.stdout);
  assert.deepEqual(
    strictResult.summary.map(
      (/** @type {{ entrySkill: string }} */ row) => row.entrySkill,
    ),
    ["kramme:code:plan-to-pr", "kramme:pr:create"],
  );
});

test("cost renders a labelled table and keeps private text off stdout", async (t) => {
  const root = await tempDir(t);
  const { usageFile, projects } = await writeFixture(root);

  const result = runUsage(
    ["cost", "--file", usageFile, "--since", "2026-10-01"],
    {
      CLAUDE_CONFIG_DIR: path.dirname(projects),
    },
  );
  const json = runUsage([
    "cost",
    "--file",
    usageFile,
    "--projects",
    projects,
    "--json",
  ]);

  assert.equal(result.status, 0, result.stderr);
  const lines = result.stdout.trimEnd().split("\n");
  assert.match(
    lines[0],
    /^API-equivalent cost from local Claude Code cost-state records since=\S+Z$/,
  );
  assert.match(
    lines[1],
    /^Entry Skill\s+Sessions\s+Transcripts\s+Total \$\s+Median \$\s+Limit Hits\s+Subagent Share\s+Top Agent Types$/,
  );
  assert.match(
    result.stdout,
    /kramme:pr:create\s+2\s+2\s+14\.25\s+7\.13\s+1\s+65\.2%\s+kramme:code-reviewer 43\.5%, general-purpose 17\.4%, \(unknown\) 4\.3%\n/,
  );
  assert.match(
    result.stdout,
    /kramme:qa\s+1\s+0\s+0\.00\s+-\s+0\s+0\.0%\s+-\n/,
  );
  assert.equal(
    lines.at(-2),
    "total sessions=4 transcripts=3 cost=$16.25 limitHits=1 subagentShare=65.2%",
  );
  assert.equal(lines.at(-1), "diagnostics skippedLines=3 readFailures=0");

  for (const output of [result.stdout, json.stdout]) {
    for (const marker of [
      PROMPT_MARKER,
      DESCRIPTION_MARKER,
      PATH_MARKER,
      root,
    ]) {
      assert.equal(output.includes(marker), false, marker);
    }
  }
});

test("cost returns a plain array for healthy input and tolerates an empty projects directory", async (t) => {
  const root = await tempDir(t);
  const usageFile = path.join(root, "usage.jsonl");
  const projects = path.join(root, "projects");
  await writeJsonl(usageFile, [
    usage("s1", "kramme:pr:create", "2026-10-10T10:00:00.000Z"),
  ]);
  await writeJsonl(path.join(projects, "p", "s1.jsonl"), [costState(1.234)]);

  const healthy = runUsage([
    "cost",
    "--file",
    usageFile,
    "--projects",
    projects,
    "--json",
    "--strict",
  ]);
  assert.equal(healthy.status, 0, healthy.stderr);
  assert.deepEqual(JSON.parse(healthy.stdout), [
    plainRow("kramme:pr:create", 1.23),
  ]);

  const empty = path.join(root, "empty");
  await fs.mkdir(empty);
  const missing = runUsage(["cost", "--file", usageFile, "--projects", empty]);
  assert.equal(missing.status, 0, missing.stderr);
  assert.match(missing.stdout, /kramme:pr:create\s+1\s+0\s+0\.00\s+-/);

  const noSessions = renderCost(
    [],
    { skippedLines: 0, readFailures: 0 },
    false,
    null,
  );
  assert.equal(
    noSessions,
    "API-equivalent cost from local Claude Code cost-state records\nNo Claude Code skill sessions found.\n",
  );

  const invalid = runUsage(["cost", "--file", usageFile, "--limit", "0"]);
  assert.equal(invalid.status, 1);
  assert.match(invalid.stderr, /Invalid --limit value: 0/);
});

test("cost counts unreadable transcripts and missing projects as read failures", async (t) => {
  const root = await tempDir(t);
  const usageFile = path.join(root, "usage.jsonl");
  const projects = path.join(root, "projects");
  await writeJsonl(usageFile, [
    usage("s1", "kramme:pr:create", "2026-10-10T10:00:00.000Z"),
  ]);
  const transcript = path.join(projects, "p", "s1.jsonl");
  await writeJsonl(transcript, [costState(1)]);
  const agent = path.join(projects, "p", "s1", "subagents", "agent-x.jsonl");
  await writeJsonl(agent, [assistant("x", { input_tokens: 1 })]);

  const noMeta = runUsage([
    "cost",
    "--file",
    usageFile,
    "--projects",
    projects,
    "--json",
  ]);
  assert.equal(noMeta.status, 0, noMeta.stderr);
  const noMetaResult = JSON.parse(noMeta.stdout);
  assert.deepEqual(noMetaResult.diagnostics, {
    skippedLines: 0,
    readFailures: 1,
  });
  assert.equal(noMetaResult.summary[0].agentTypes[0].agentType, "(unknown)");

  const absent = runUsage([
    "cost",
    "--file",
    usageFile,
    "--projects",
    path.join(root, "absent"),
    "--json",
    "--strict",
  ]);
  assert.equal(absent.status, 1);
  assert.deepEqual(JSON.parse(absent.stdout).diagnostics, {
    skippedLines: 0,
    readFailures: 1,
  });

  await fs.chmod(transcript, 0o000);
  try {
    await fs.readFile(transcript);
    t.skip("file permissions do not deny reads for this user");
    return;
  } catch {
    // Expected: the transcript is unreadable.
  }
  const denied = runUsage([
    "cost",
    "--file",
    usageFile,
    "--projects",
    projects,
    "--json",
  ]);
  assert.equal(denied.status, 0, denied.stderr);
  assert.equal(JSON.parse(denied.stdout).diagnostics.readFailures, 2);
  assert.match(denied.stderr, /read failure file=.*s1\.jsonl reason=EACCES/);
});

test("buildCostRows sorts by total cost, then sessions, then name", () => {
  /** @param {number} costUSD */
  const summary = (costUSD) => ({
    hasTranscript: true,
    costUSD,
    unknownModelCost: false,
    limitHit: false,
    weightedTokens: 0,
    subagents: [],
  });
  const rows = buildCostRows([
    { entrySkill: "b", summary: summary(1) },
    { entrySkill: "a", summary: summary(1) },
    { entrySkill: "c", summary: summary(0.5) },
    { entrySkill: "c", summary: summary(0.5) },
    { entrySkill: "d", summary: summary(3) },
  ]);
  assert.deepEqual(
    rows.map((row) => row.entrySkill),
    ["d", "c", "a", "b"],
  );
});
