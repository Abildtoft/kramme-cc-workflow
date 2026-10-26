// @ts-check
"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const { spawn, execFileSync } = require("node:child_process");
const { once } = require("node:events");
const {
  readJson,
  writeJson,
  validateRun,
  validatePool,
  runFile,
  acquireLock,
  registerWorker,
  treeFiles,
  digestFiles,
} = require("../../evals/skill-review/eval-state");
const { sandbox } = require("../test_helper/live-eval");

test("an adapter remains locked if its owner dies; recovery waits for the worker", async (t) => {
  const { root } = sandbox(t);
  const directory = path.join(root, "worker-lock");
  const release = acquireLock(directory);
  const file = path.join(directory, "writer.lock");
  const lock =
    /** @type {{token: string, pid: number, host: string, worker_pid: number | null}} */ (
      readJson(file)
    );
  const registration = registerWorker(directory, lock.token);
  assert.throws(() => registerWorker(directory, lock.token), /adapter/);
  registration.release();
  const child = spawn(process.execPath, ["-e", "setTimeout(() => {}, 30000)"]);
  t.after(() => child.kill());
  const deadPid = Number(
    execFileSync(
      process.execPath,
      ["-e", "process.stdout.write(String(process.pid))"],
      { encoding: "utf8" },
    ),
  );
  writeJson(file, { ...lock, pid: deadPid, worker_pid: child.pid });
  assert.throws(() => acquireLock(directory), /writer/);
  const stopped = once(child, "exit");
  child.kill();
  await stopped;
  const recovered = acquireLock(directory);
  recovered();
  release();
});

test("checkpoints preserve progress with private, atomic writes and reject a concurrent writer", (t) => {
  const { root, run, env } = sandbox(t);
  const file = runFile(env.KRAMME_LIVE_EVAL_STATE, run.id);
  assert.deepEqual(validateRun(readJson(file)), run);
  writeJson(file, { ...run, status: "PAUSED_NO_CREDITS" });
  assert.equal(validateRun(readJson(file)).status, "PAUSED_NO_CREDITS");
  assert.equal(fs.statSync(file).mode & 0o777, 0o600);
  const release = acquireLock(root);
  assert.throws(() => acquireLock(root), /writer/);
  release();
  acquireLock(root)();
  assert.deepEqual(fs.readdirSync(path.dirname(file)), ["run.json"]);
});

test("malformed, incompatible, and extra-field checkpoints do not silently reset", (t) => {
  const { root, run } = sandbox(t);
  assert.equal(readJson(path.join(root, "missing")), null);
  fs.writeFileSync(path.join(root, "bad.json"), "not-json");
  assert.throws(
    () => readJson(path.join(root, "bad.json")),
    /Invalid checkpoint/,
  );
  for (const invalid of [
    null,
    { ...run, schema_version: 2 },
    { ...run, case_ids: [] },
    {
      ...run,
      completed: {
        wrong: { text: "review", organization: "org-a", model: "claude-test" },
      },
    },
    { ...run, secret: "unexpected" },
  ])
    assert.throws(() => validateRun(invalid));
  assert.throws(() =>
    validatePool({
      schema_version: 1,
      active: null,
      organizations: {
        "org-a": {
          fingerprint: "a".repeat(64),
          exhausted_at: 10,
          recheck_after: 9,
        },
      },
    }),
  );
  assert.throws(() => runFile(root, "../escape"));
});

test("input fingerprints reflect both content and file names; symlinks are rejected", (t) => {
  const { root } = sandbox(t);
  const directory = path.join(root, "inputs");
  fs.mkdirSync(directory);
  const file = path.join(directory, "a");
  fs.writeFileSync(file, "first");
  const first = digestFiles(treeFiles(directory), root);
  fs.writeFileSync(file, "second");
  assert.notEqual(digestFiles(treeFiles(directory), root), first);
  fs.symlinkSync(file, path.join(directory, "alias"));
  assert.throws(() => treeFiles(directory), /symlinks/);
});
