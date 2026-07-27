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

/** @param {import("node:test").TestContext} t */
async function tempDir(t) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "skill-usage-test-"));
  t.after(() => fs.rm(root, { recursive: true, force: true }));
  return root;
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

test("strict reports reject an explicitly missing usage file", async (t) => {
  const root = await tempDir(t);
  const missingFile = path.join(root, "missing.jsonl");

  const result = runUsage([
    "report",
    "--file",
    missingFile,
    "--json",
    "--strict",
  ]);

  assert.equal(result.status, 1);
  assert.deepEqual(JSON.parse(result.stdout), {
    summary: [],
    diagnostics: {
      skippedLines: 0,
      readFailures: 1,
    },
  });
  assert.equal(
    result.stderr,
    `skill-usage: read failure file=${missingFile} reason=ENOENT\n`,
  );
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
  const stderr =
    `skill-usage: skipped 1 non-JSONL input beyond the compatibility limit line file=${notes}\n`;

  assert.equal(tolerant.status, 0);
  assert.deepEqual(JSON.parse(tolerant.stdout), expected);
  assert.equal(tolerant.stderr, stderr);

  const strict = runUsage(["scan", notes, "--json", "--strict"]);
  assert.equal(strict.status, 1);
  assert.deepEqual(JSON.parse(strict.stdout), expected);
  assert.equal(strict.stderr, stderr);
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
    const chunk = line.repeat(Math.ceil((256 * 1024) / line.length));
    const targetBytes = 48 * MIB;
    const handle = await fs.open(transcript, "w");
    try {
      let written = 0;
      while (written < targetBytes) {
        await handle.write(chunk);
        written += Buffer.byteLength(chunk);
      }
    } finally {
      await handle.close();
    }

    const wrapper = [
      `process.argv = [process.execPath, ${JSON.stringify(SCRIPT)}, "scan", ${JSON.stringify(transcript)}, "--json"];`,
      `const { runCli } = require(${JSON.stringify(SCRIPT)});`,
      "Promise.resolve(runCli()).then(() => {",
      "  process.stderr.write(`FINAL_RSS=${process.memoryUsage().rss}\\n`);",
      "});",
    ].join("\n");
    const result = spawnSync(process.execPath, ["-e", wrapper], {
      encoding: "utf8",
      maxBuffer: 5 * MIB,
      timeout: 25_000,
    });

    assert.equal(result.status, 0, result.stderr);
    const match = result.stderr.match(/FINAL_RSS=(\d+)/);
    assert.ok(match, `missing RSS sample in stderr: ${result.stderr}`);
    assert.ok(
      Number(match[1]) < 256 * MIB,
      `expected RSS below 256 MiB, got ${Number(match[1]) / MIB} MiB`,
    );
  },
);
