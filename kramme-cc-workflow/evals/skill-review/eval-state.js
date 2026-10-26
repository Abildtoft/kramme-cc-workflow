// @ts-check
"use strict";

const crypto = require("node:crypto");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { record } = require("./credit-pool");

/** @typedef {import('./live-types').PoolState} PoolState */
/** @typedef {import('./live-types').RunState} RunState */
const SAFE_ID = /^[a-zA-Z0-9][a-zA-Z0-9_-]{0,100}$/;

/** @param {string} file @returns {unknown | null} */
function readJson(file) {
  if (!fs.existsSync(file)) return null;
  try {
    if (
      !fs.lstatSync(file).isFile() ||
      fs.statSync(file).size > 20 * 1024 * 1024
    )
      throw new Error();
    const value = JSON.parse(fs.readFileSync(file, "utf8"));
    if (value === null) throw new Error();
    return value;
  } catch {
    throw new Error(
      `Invalid checkpoint/configuration: ${path.basename(file)}. Restore a valid copy or move the file aside.`,
    );
  }
}

/** @param {string} file @param {unknown} value */
function writeJson(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true, mode: 0o700 });
  const temporary = `${file}.${crypto.randomUUID()}.tmp`;
  try {
    fs.writeFileSync(temporary, `${JSON.stringify(value, null, 2)}\n`, {
      mode: 0o600,
      flag: "wx",
    });
    fs.renameSync(temporary, file);
  } finally {
    fs.rmSync(temporary, { force: true });
  }
}

/** @param {unknown} value */
function finiteTime(value) {
  return typeof value === "number" && Number.isSafeInteger(value) && value >= 0;
}
/** @param {unknown} value */
function hash(value) {
  return typeof value === "string" && /^[a-f0-9]{64}$/.test(value);
}
/** @param {unknown} value @param {string[]} keys */
function onlyKeys(value, keys) {
  return Object.keys(record(value)).every((key) => keys.includes(key));
}

/** @param {unknown} value @returns {PoolState} */
function validatePool(value) {
  const pool = record(value);
  const entries = record(pool.organizations);
  const valid =
    pool.schema_version === 1 &&
    onlyKeys(pool, ["schema_version", "active", "organizations"]) &&
    (pool.active === null ||
      (typeof pool.active === "string" &&
        Object.hasOwn(entries, pool.active))) &&
    Object.entries(entries).every(([alias, entry]) => {
      const e = record(entry);
      return (
        /^[a-z][a-z0-9-]{0,63}$/.test(alias) &&
        hash(e.fingerprint) &&
        onlyKeys(e, ["fingerprint", "exhausted_at", "recheck_after"]) &&
        ((e.exhausted_at === null && e.recheck_after === null) ||
          (finiteTime(e.exhausted_at) &&
            finiteTime(e.recheck_after) &&
            Number(e.recheck_after) > Number(e.exhausted_at)))
      );
    });
  if (
    !valid ||
    !pool.organizations ||
    typeof pool.organizations !== "object" ||
    Array.isArray(pool.organizations)
  )
    throw new Error(
      "Invalid pool checkpoint. Restore a valid pool-state.json or move it aside.",
    );
  return /** @type {PoolState} */ (value);
}

/** @param {unknown} value @returns {RunState} */
function validateRun(value) {
  const run = record(value);
  const cases = run.case_ids;
  const completed = record(run.completed);
  const valid =
    run.schema_version === 1 &&
    typeof run.id === "string" &&
    SAFE_ID.test(run.id) &&
    hash(run.fingerprint) &&
    typeof run.model === "string" &&
    typeof run.sdk_version === "string" &&
    typeof run.commit === "string" &&
    finiteTime(run.created_at) &&
    finiteTime(run.updated_at) &&
    ["RUNNING", "COMPLETE", "PAUSED_NO_CREDITS", "ERROR"].includes(
      String(run.status),
    ) &&
    Array.isArray(cases) &&
    cases.length > 0 &&
    new Set(cases).size === cases.length &&
    cases.every((id) => typeof id === "string" && SAFE_ID.test(id)) &&
    run.completed &&
    typeof run.completed === "object" &&
    !Array.isArray(run.completed) &&
    Object.entries(completed).every(([id, value]) => {
      const prediction = record(value);
      return (
        cases.includes(id) &&
        onlyKeys(prediction, ["text", "organization", "model"]) &&
        typeof prediction.text === "string" &&
        !!prediction.text.trim() &&
        typeof prediction.organization === "string" &&
        typeof prediction.model === "string"
      );
    }) &&
    Array.isArray(run.attempts) &&
    run.attempts.every((value) => {
      const attempt = record(value);
      return (
        cases.includes(attempt.case_id) &&
        typeof attempt.organization === "string" &&
        finiteTime(attempt.started_at) &&
        typeof attempt.outcome === "string" &&
        (attempt.model === null || typeof attempt.model === "string") &&
        (attempt.cost_usd === null ||
          (typeof attempt.cost_usd === "number" &&
            Number.isFinite(attempt.cost_usd) &&
            attempt.cost_usd >= 0)) &&
        onlyKeys(attempt, [
          "case_id",
          "organization",
          "started_at",
          "outcome",
          "model",
          "cost_usd",
          "trace",
        ]) &&
        Array.isArray(attempt.trace) &&
        attempt.trace.every(
          (event) =>
            typeof record(event).event === "string" &&
            typeof record(event).detail === "string" &&
            onlyKeys(event, ["event", "detail"]),
        )
      );
    }) &&
    onlyKeys(run, [
      "schema_version",
      "id",
      "fingerprint",
      "model",
      "sdk_version",
      "commit",
      "created_at",
      "updated_at",
      "case_ids",
      "status",
      "completed",
      "attempts",
    ]);
  if (
    !valid ||
    (run.status === "COMPLETE" &&
      Object.keys(completed).length !==
        (Array.isArray(cases) ? cases.length : 0))
  )
    throw new Error(
      "Invalid run checkpoint. Restore a valid run.json or move its run directory aside.",
    );
  return /** @type {RunState} */ (value);
}

/** @param {string} directory @param {string} id */
function runFile(directory, id) {
  if (!SAFE_ID.test(id)) throw new Error("Invalid run ID.");
  return path.join(directory, "runs", id, "run.json");
}

/** @param {string} directory @param {RunState} run */
function saveRun(directory, run) {
  run.updated_at = Date.now();
  writeJson(runFile(directory, run.id), validateRun(run));
}

/** Serialize stale-lock recovery and worker registration as well as acquisition.
 * A crash inside this short critical section leaves a guard requiring inspection.
 * @template T @param {string} directory @param {() => T} action @returns {T} */
function withLockGuard(directory, action) {
  fs.mkdirSync(directory, { recursive: true, mode: 0o700 });
  const guard = path.join(directory, "writer.guard");
  try {
    fs.closeSync(fs.openSync(guard, "wx", 0o600));
  } catch {
    throw new Error(
      "Eval writer guard exists. Check writers before removing writer.guard.",
    );
  }
  try {
    return action();
  } finally {
    fs.unlinkSync(guard);
  }
}

/** @param {number} pid */
function processAlive(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch (error) {
    if (record(error).code === "ESRCH") return false;
    throw error;
  }
}

/** @param {string} directory @returns {() => void} */
function acquireLock(directory) {
  const file = path.join(directory, "writer.lock");
  const token = crypto.randomUUID();
  withLockGuard(directory, () => {
    if (fs.existsSync(file)) {
      const old = record(readJson(file));
      if (
        old.host !== os.hostname() ||
        !Number.isInteger(old.pid) ||
        Number(old.pid) <= 0
      )
        throw new Error(
          "Eval writer lock exists. Check writers before removing writer.lock.",
        );
      if (
        processAlive(Number(old.pid)) ||
        (typeof old.worker_pid === "number" && processAlive(old.worker_pid))
      )
        throw new Error("Another live eval writer is running.");
      fs.unlinkSync(file);
    }
    fs.writeFileSync(
      file,
      JSON.stringify({
        token,
        pid: process.pid,
        host: os.hostname(),
        worker_pid: null,
      }),
      { flag: "wx", mode: 0o600 },
    );
  });
  return () =>
    withLockGuard(directory, () => {
      const lock = record(readJson(file));
      if (
        lock.token === token &&
        !(typeof lock.worker_pid === "number" && processAlive(lock.worker_pid))
      )
        fs.unlinkSync(file);
    });
}

/** Keep a still-running adapter protected if its outer runner dies.
 * @param {string} directory @param {string | undefined} token */
function registerWorker(directory, token) {
  const file = path.join(directory, "writer.lock");
  const owner = withLockGuard(directory, () => {
    const lock = record(readJson(file));
    if (
      !token ||
      lock.token !== token ||
      lock.host !== os.hostname() ||
      !Number.isInteger(lock.pid) ||
      Number(lock.pid) <= 0 ||
      !processAlive(Number(lock.pid))
    )
      throw new Error("Live adapter requires its active owning runner.");
    if (typeof lock.worker_pid === "number" && processAlive(lock.worker_pid))
      throw new Error("Another live eval adapter is running.");
    writeJson(file, { ...lock, worker_pid: process.pid });
    return Number(lock.pid);
  });
  return {
    owner,
    release: () =>
      withLockGuard(directory, () => {
        const lock = record(readJson(file));
        if (lock.token === token && lock.worker_pid === process.pid)
          writeJson(file, { ...lock, worker_pid: null });
      }),
  };
}

/** @param {string[]} files @param {string} root */
function digestFiles(files, root) {
  const digest = crypto.createHash("sha256");
  for (const file of [...files].sort()) {
    digest
      .update(path.relative(root, file))
      .update("\0")
      .update(fs.readFileSync(file))
      .update("\0");
  }
  return digest.digest("hex");
}

/** Reject symlinks so a staged tree never acquires files outside the declared input.
 * @param {string} directory @returns {string[]} */
function treeFiles(directory) {
  const stat = fs.lstatSync(directory);
  if (stat.isSymbolicLink())
    throw new Error("Eval inputs and checkpoints must not contain symlinks.");
  if (stat.isFile()) return [directory];
  if (!stat.isDirectory()) throw new Error("Unsupported eval input file type.");
  return fs
    .readdirSync(directory)
    .sort()
    .flatMap((name) => treeFiles(path.join(directory, name)));
}

module.exports = {
  SAFE_ID,
  readJson,
  writeJson,
  validatePool,
  validateRun,
  runFile,
  saveRun,
  acquireLock,
  registerWorker,
  processAlive,
  digestFiles,
  treeFiles,
};
