"use strict";

const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");

const SCRIPT = path.resolve(__dirname, "../../scripts/skill-usage.js");
const MIB = 1024 * 1024;

/**
 * @param {string[]} args
 * @param {NodeJS.ProcessEnv} [env]
 */
function runUsage(args, env) {
  return spawnSync(process.execPath, [SCRIPT, ...args], {
    encoding: "utf8",
    env: env ? { ...process.env, ...env } : process.env,
    maxBuffer: 5 * MIB,
  });
}

/** @param {string} file */
function runUsageWithGrowingFile(file) {
  const wrapper = [
    'const fs = require("node:fs");',
    "const createReadStream = fs.createReadStream;",
    'const appendedLine = "Please run /kramme:race " + "x".repeat(6 * 1024 * 1024) + "\\n";',
    "fs.createReadStream = (inputFile, options) => {",
    "  const streamOptions = options && typeof options === 'object' ? options : {};",
    "  const input = createReadStream(inputFile, {",
    "    ...streamOptions,",
    "    highWaterMark: 4 * 1024,",
    "  });",
    '  input.once("open", () => fs.appendFileSync(inputFile, appendedLine));',
    "  return input;",
    "};",
    `process.argv = [process.execPath, ${JSON.stringify(SCRIPT)}, "scan", ${JSON.stringify(file)}, "--json", "--strict"];`,
    `const { runCli } = require(${JSON.stringify(SCRIPT)});`,
    "void runCli();",
  ].join("\n");
  return spawnSync(process.execPath, ["-e", wrapper], {
    encoding: "utf8",
    maxBuffer: 5 * MIB,
  });
}

/** @param {import("node:test").TestContext} t */
async function tempDir(t) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "skill-usage-test-"));
  t.after(() => fs.rm(root, { recursive: true, force: true }));
  return root;
}

/** @param {string} file @param {string} line @param {number} targetBytes */
async function writeRepeatedFile(file, line, targetBytes) {
  const chunk = line.repeat(Math.ceil((256 * 1024) / line.length));
  const handle = await fs.open(file, "w");
  try {
    let written = 0;
    while (written < targetBytes) {
      await handle.write(chunk);
      written += Buffer.byteLength(chunk);
    }
  } finally {
    await handle.close();
  }
}

/** @param {string[]} args */
function runUsageWithRss(args) {
  const wrapper = [
    `process.argv = [process.execPath, ${JSON.stringify(SCRIPT)}, ...${JSON.stringify(args)}];`,
    `const { runCli } = require(${JSON.stringify(SCRIPT)});`,
    "Promise.resolve(runCli()).then(() => {",
    "  process.stderr.write(`FINAL_RSS=${process.memoryUsage().rss}\\n`);",
    "});",
  ].join("\n");
  return spawnSync(process.execPath, ["-e", wrapper], {
    encoding: "utf8",
    maxBuffer: 5 * MIB,
    timeout: 25_000,
  });
}

/** @param {import("node:child_process").SpawnSyncReturns<string>} result */
function assertBoundedRss(result) {
  assert.equal(result.status, 0, result.stderr);
  const match = result.stderr.match(/FINAL_RSS=(\d+)/);
  assert.ok(match, `missing RSS sample in stderr: ${result.stderr}`);
  assert.ok(
    Number(match[1]) < 256 * MIB,
    `expected RSS below 256 MiB, got ${Number(match[1]) / MIB} MiB`,
  );
}

test("report preserves valid JSON output byte-for-byte", async (t) => {
  const root = await tempDir(t);
  const usageFile = path.join(root, "usage.jsonl");
  await fs.writeFile(
    usageFile,
    [
      JSON.stringify({
        recordedAt: "2026-07-01T10:00:00.000Z",
        sessionId: "session-1",
        skill: "kramme:qa",
        kind: "explicit",
      }),
      "",
    ].join("\n"),
  );

  const result = runUsage(["report", "--file", usageFile, "--json"]);

  assert.equal(result.status, 0);
  assert.equal(result.stderr, "");
  assert.equal(
    result.stdout,
    `${JSON.stringify(
      [
        {
          skill: "kramme:qa",
          total: 1,
          explicit: 1,
          tool: 0,
          firstUsedAt: "2026-07-01T10:00:00.000Z",
          lastUsedAt: "2026-07-01T10:00:00.000Z",
          sessions: 1,
        },
      ],
      null,
      2,
    )}\n`,
  );
});

test("report preserves valid totals and returns exact degraded diagnostics", async (t) => {
  const root = await tempDir(t);
  const usageFile = path.join(root, "degraded.jsonl");
  await fs.writeFile(
    usageFile,
    [
      JSON.stringify({
        recordedAt: "2026-07-01T10:00:00.000Z",
        sessionId: "session-1",
        skill: "kramme:qa",
        kind: "explicit",
      }),
      "{malformed",
      JSON.stringify({ skill: 42, kind: "tool" }),
      '{"skill":"kramme:truncated"',
      "",
    ].join("\n"),
  );

  const result = runUsage(["report", "--file", usageFile, "--json"]);

  assert.equal(result.status, 0);
  assert.deepEqual(JSON.parse(result.stdout), {
    summary: [
      {
        skill: "kramme:qa",
        total: 1,
        explicit: 1,
        tool: 0,
        firstUsedAt: "2026-07-01T10:00:00.000Z",
        lastUsedAt: "2026-07-01T10:00:00.000Z",
        sessions: 1,
      },
    ],
    diagnostics: {
      skippedLines: 3,
      readFailures: 0,
    },
  });
  assert.equal(
    result.stderr,
    [
      `skill-usage: skipped 2 malformed JSONL lines file=${usageFile}`,
      `skill-usage: skipped 1 invalid usage record line file=${usageFile}`,
      "",
    ].join("\n"),
  );
});

test("strict mode exits non-zero after rendering a degraded snapshot", async (t) => {
  const root = await tempDir(t);
  const usageFile = path.join(root, "degraded.jsonl");
  await fs.writeFile(
    usageFile,
    [
      JSON.stringify({
        sessionId: "session-1",
        skill: "kramme:qa",
        kind: "explicit",
      }),
      "{truncated",
      "",
    ].join("\n"),
  );

  const result = runUsage([
    "report",
    "--file",
    usageFile,
    "--json",
    "--strict",
  ]);

  assert.equal(result.status, 1);
  assert.deepEqual(JSON.parse(result.stdout).diagnostics, {
    skippedLines: 1,
    readFailures: 0,
  });
  assert.equal(
    result.stderr,
    `skill-usage: skipped 1 malformed JSONL line file=${usageFile}\n`,
  );
});

test("reports diagnose an explicitly missing usage file", async (t) => {
  const root = await tempDir(t);
  const missingFile = path.join(root, "missing.jsonl");
  const expected = {
    summary: [],
    diagnostics: {
      skippedLines: 0,
      readFailures: 1,
    },
  };
  const stderr = `skill-usage: read failure file=${missingFile} reason=ENOENT\n`;

  const tolerant = runUsage(["report", "--file", missingFile, "--json"]);
  assert.equal(tolerant.status, 0);
  assert.deepEqual(JSON.parse(tolerant.stdout), expected);
  assert.equal(tolerant.stderr, stderr);

  const strict = runUsage([
    "report",
    "--file",
    missingFile,
    "--json",
    "--strict",
  ]);
  assert.equal(strict.status, 1);
  assert.deepEqual(JSON.parse(strict.stdout), expected);
  assert.equal(strict.stderr, stderr);
});

test("strict reports preserve empty first-run defaults", async (t) => {
  const root = await tempDir(t);

  const result = runUsage(["report", "--json", "--strict"], {
    XDG_STATE_HOME: root,
    KRAMME_SKILL_USAGE_FILE: "",
  });

  assert.equal(result.status, 0);
  assert.equal(result.stdout, "[]\n");
  assert.equal(result.stderr, "");
});

test("scan tolerates corrupt lines and unreadable inputs without losing valid totals", async (t) => {
  const root = await tempDir(t);
  const transcript = path.join(root, "01-mixed.jsonl");
  const unreadable = path.join(root, "02-unreadable.jsonl");
  await fs.writeFile(
    transcript,
    [
      JSON.stringify({
        type: "user",
        message: { content: "Use /kramme:pr:create" },
        session_id: "session-1",
      }),
      "{malformed",
      '{"type":"user","message":',
      "",
    ].join("\n"),
  );
  await fs.writeFile(
    unreadable,
    `${JSON.stringify({
      type: "user",
      message: { content: "Use /kramme:should-not-read" },
    })}\n`,
  );
  await fs.chmod(unreadable, 0o000);

  const permissionChecksWork =
    typeof process.getuid !== "function" || process.getuid() !== 0;
  const failedInput = permissionChecksWork
    ? unreadable
    : path.join(root, "02-missing.jsonl");
  const failureReason = permissionChecksWork ? "EACCES" : "ENOENT";
  const result = runUsage(["scan", transcript, failedInput, "--json"]);

  assert.equal(result.status, 0);
  assert.deepEqual(JSON.parse(result.stdout), {
    summary: [
      {
        skill: "kramme:pr:create",
        total: 1,
        explicit: 1,
        tool: 0,
        firstUsedAt: null,
        lastUsedAt: null,
        sessions: 1,
      },
    ],
    diagnostics: {
      skippedLines: 2,
      readFailures: 1,
    },
  });
  assert.equal(
    result.stderr,
    [
      `skill-usage: skipped 2 malformed JSONL lines file=${transcript}`,
      `skill-usage: read failure file=${failedInput} reason=${failureReason}`,
      "",
    ].join("\n"),
  );
});

test("scan keeps the bounded non-JSONL compatibility fallback", async (t) => {
  const root = await tempDir(t);
  const notes = path.join(root, "notes.txt");
  await fs.writeFile(notes, "Please run /kramme:qa before wrapping up.\n");

  const result = runUsage(["scan", notes, "--json"]);

  assert.equal(result.status, 0);
  assert.equal(result.stderr, "");
  assert.equal(JSON.parse(result.stdout)[0].skill, "kramme:qa");
});

test("scan reads a complete JSON document before classifying JSONL", async (t) => {
  const root = await tempDir(t);
  const transcript = path.join(root, "transcript.json");
  const entries = [
    {
      type: "user",
      message: { content: "Use /kramme:first" },
      session_id: "session-1",
    },
    {
      type: "user",
      message: { content: "Use /kramme:second" },
      session_id: "session-2",
    },
  ];
  await fs.writeFile(
    transcript,
    `[\n${entries.map((entry) => JSON.stringify(entry)).join(",\n")}\n]\n`,
  );

  const result = runUsage(["scan", transcript, "--json"]);

  assert.equal(result.status, 0);
  assert.equal(result.stderr, "");
  const summary = /** @type {Array<{ skill: string }>} */ (
    JSON.parse(result.stdout)
  );
  assert.deepEqual(
    summary.map((row) => row.skill),
    ["kramme:first", "kramme:second"],
  );
});

test("scan rejects an oversized minified top-level JSON array", async (t) => {
  const root = await tempDir(t);
  const transcript = path.join(root, "oversized-array.json");
  const entry = {
    type: "user",
    message: { content: "Use /kramme:array" },
    session_id: "shared-session",
  };
  await fs.writeFile(transcript, JSON.stringify(Array(16_000).fill(entry)));

  const result = runUsage(["scan", transcript, "--json", "--strict"]);

  assert.ok((await fs.stat(transcript)).size > MIB);
  assert.equal(result.status, 1);
  assert.deepEqual(JSON.parse(result.stdout), {
    summary: [],
    diagnostics: {
      skippedLines: 1,
      readFailures: 0,
    },
  });
  assert.equal(
    result.stderr,
    `skill-usage: skipped 1 non-JSONL input beyond the compatibility limit line file=${transcript}\n`,
  );
});

test("scan accepts non-JSONL input exactly at the compatibility limit", async (t) => {
  const root = await tempDir(t);
  const notes = path.join(root, "exact-notes.txt");
  const prefix = "Please run /kramme:qa before wrapping up. ";
  await fs.writeFile(notes, prefix + "x".repeat(MIB - prefix.length));

  const result = runUsage(["scan", notes, "--json", "--strict"]);

  assert.equal((await fs.stat(notes)).size, MIB);
  assert.equal(result.status, 0);
  assert.equal(result.stderr, "");
  assert.equal(JSON.parse(result.stdout)[0].skill, "kramme:qa");
});

test("scan measures CRLF compatibility input by actual file size", async (t) => {
  const root = await tempDir(t);
  const notes = path.join(root, "large-crlf-notes.txt");
  const prefix = "Please run /kramme:qa ";
  const lineLength = 510;
  const firstLine = prefix + "x".repeat(lineLength - prefix.length);
  const otherLine = "x".repeat(lineLength);
  const content = [firstLine, ...Array(2048).fill(otherLine)].join("\r\n");
  await fs.writeFile(notes, content);

  const result = runUsage(["scan", notes, "--json", "--strict"]);

  assert.ok((await fs.stat(notes)).size > MIB);
  assert.equal(result.status, 1);
  assert.deepEqual(JSON.parse(result.stdout), {
    summary: [],
    diagnostics: {
      skippedLines: 2049,
      readFailures: 0,
    },
  });
  assert.equal(
    result.stderr,
    `skill-usage: skipped 2049 non-JSONL input beyond the compatibility limit lines file=${notes}\n`,
  );
});

test("scan diagnoses non-JSONL input beyond the compatibility limit", async (t) => {
  const root = await tempDir(t);
  const notes = path.join(root, "large-notes.txt");
  await fs.writeFile(
    notes,
    `Please run /kramme:qa before wrapping up. ${"x".repeat(MIB)}\n`,
  );

  const tolerant = runUsage(["scan", notes, "--json"]);
  const expected = {
    summary: [],
    diagnostics: {
      skippedLines: 1,
      readFailures: 0,
    },
  };
  const stderr = `skill-usage: skipped 1 non-JSONL input beyond the compatibility limit line file=${notes}\n`;

  assert.equal(tolerant.status, 0);
  assert.deepEqual(JSON.parse(tolerant.stdout), expected);
  assert.equal(tolerant.stderr, stderr);

  const strict = runUsage(["scan", notes, "--json", "--strict"]);
  assert.equal(strict.status, 1);
  assert.deepEqual(JSON.parse(strict.stdout), expected);
  assert.equal(strict.stderr, stderr);
});

test("scan stops compatibility parsing when a file grows beyond the limit", async (t) => {
  const root = await tempDir(t);
  const transcript = path.join(root, "growing-notes.txt");
  const initialLine = `${"x".repeat(1023)}\n`;
  await fs.writeFile(transcript, initialLine.repeat(1024));

  const result = runUsageWithGrowingFile(transcript);

  assert.ok((await fs.stat(transcript)).size > 7 * MIB);
  assert.equal(result.status, 1);
  assert.deepEqual(JSON.parse(result.stdout), {
    summary: [],
    diagnostics: {
      skippedLines: 1025,
      readFailures: 0,
    },
  });
  assert.equal(
    result.stderr,
    `skill-usage: skipped 1025 non-JSONL input beyond the compatibility limit lines file=${transcript}\n`,
  );
});

test(
  "scan keeps RSS bounded while aggregating a large JSONL transcript",
  { timeout: 30_000 },
  async (t) => {
    const root = await tempDir(t);
    const transcript = path.join(root, "large.jsonl");
    const line = `${JSON.stringify({
      type: "user",
      message: { content: "Use /kramme:qa" },
      session_id: "shared-session",
    })}\n`;
    await writeRepeatedFile(transcript, line, 48 * MIB);

    assertBoundedRss(runUsageWithRss(["scan", transcript, "--json"]));
  },
);

test(
  "report keeps RSS bounded while aggregating a large JSONL usage file",
  { timeout: 30_000 },
  async (t) => {
    const root = await tempDir(t);
    const usageFile = path.join(root, "large.jsonl");
    const line = `${JSON.stringify({
      recordedAt: "2026-07-01T10:00:00.000Z",
      sessionId: "shared-session",
      skill: "kramme:qa",
      kind: "explicit",
    })}\n`;
    await writeRepeatedFile(usageFile, line, 48 * MIB);

    assertBoundedRss(
      runUsageWithRss(["report", "--file", usageFile, "--json"]),
    );
  },
);
