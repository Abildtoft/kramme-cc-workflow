#!/usr/bin/env node
// @ts-check
"use strict";

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const { record } = require("./credit-pool");
const {
  readJson,
  writeJson,
  treeFiles,
  validatePool,
  validateRun,
} = require("./eval-state");

const WORKFLOW = "skill-review-live-eval.yml";
const ARTIFACT = "claude-eval-checkpoint";
const DEFAULT_STATE = path.resolve(__dirname, "../../../.context/claude-evals");
const ALIAS = /^[a-z][a-z0-9-]{0,63}$/;
const CASE_ID = /^[a-zA-Z0-9][a-zA-Z0-9_-]{0,100}$/;

/** @param {string} file */
function checkpointPath(file) {
  return (
    file === "pool-state.json" ||
    /^runs\/[A-Za-z0-9][A-Za-z0-9_-]{0,100}\/run\.json$/.test(file)
  );
}

/** @param {string} file @param {unknown} value */
function validateFile(file, value) {
  if (file === "pool-state.json") return validatePool(value);
  if (!checkpointPath(file))
    throw new Error("Unexpected file in checkpoint artifact.");
  const run = validateRun(value);
  if (file !== `runs/${run.id}/run.json`)
    throw new Error("Checkpoint run identity mismatch.");
  return run;
}

/** Export only data we own, never the hidden state directory wholesale.
 * Completed and superseded runs live in earlier report artifacts; carrying
 * them forward would defeat artifact retention. The most recently updated run
 * carries the current invocation's input fingerprint; unfinished runs with any
 * other fingerprint can never resume automatically.
 * @param {string} source @param {string} destination */
function stageCheckpoint(source, destination) {
  if (!fs.existsSync(path.join(source, "pool-state.json"))) return false;
  if (fs.existsSync(destination))
    throw new Error("Checkpoint staging destination already exists.");
  const files = treeFiles(source)
    .map((file) => ({
      file,
      relative: path.relative(source, file).split(path.sep).join("/"),
    }))
    .filter((entry) => checkpointPath(entry.relative));
  const validated = files.map((entry) => ({
    ...entry,
    value: validateFile(entry.relative, readJson(entry.file)),
  }));
  const runs = validated
    .map((entry) => record(entry.value))
    .filter((value) => typeof value.fingerprint === "string");
  const current = runs.reduce(
    (latest, run) =>
      !latest || Number(run.updated_at) > Number(latest.updated_at)
        ? run
        : latest,
    /** @type {Record<string, unknown> | null} */ (null),
  )?.fingerprint;
  const payloads = validated.filter((entry) => {
    const value = record(entry.value);
    return (
      typeof value.fingerprint !== "string" ||
      (value.status !== "COMPLETE" && value.fingerprint === current)
    );
  });
  for (const payload of payloads)
    writeJson(path.join(destination, payload.relative), payload.value);
  return true;
}

/** @param {unknown} value @param {string} repository @param {number} currentRun */
function trustedRun(value, repository, currentRun) {
  const run = record(value);
  return (
    Number.isSafeInteger(run.id) &&
    run.id !== currentRun &&
    run.status === "completed" &&
    run.head_branch === "main" &&
    ["schedule", "workflow_dispatch"].includes(String(run.event)) &&
    run.path === `.github/workflows/${WORKFLOW}` &&
    record(run.head_repository).full_name === repository
  );
}

/** GitHub CLI supplies the token only for this restore step; no token is passed to an agent.
 * @param {string} endpoint @returns {Record<string, unknown>} */
function githubJson(endpoint) {
  try {
    return record(
      JSON.parse(
        execFileSync("gh", ["api", endpoint], {
          encoding: "utf8",
          maxBuffer: 5 * 1024 * 1024,
          stdio: ["ignore", "pipe", "pipe"],
        }),
      ),
    );
  } catch {
    throw new Error("Could not read GitHub checkpoint metadata.");
  }
}

/** @param {string} archive @param {string} destination */
function restoreArchive(archive, destination) {
  if (fs.existsSync(destination) && fs.readdirSync(destination).length)
    throw new Error("Refusing to overwrite existing local eval state.");
  const files = execFileSync("unzip", ["-Z1", archive], {
    encoding: "utf8",
    maxBuffer: 1024 * 1024,
  })
    .trim()
    .split(/\r?\n/)
    .filter((file) => !file.endsWith("/"));
  if (
    !files.includes("pool-state.json") ||
    new Set(files).size !== files.length ||
    !files.every(checkpointPath)
  )
    throw new Error("Unexpected checkpoint archive layout.");
  // Validate the entire payload before writing any state; never extract zip paths.
  const payloads = files.map((file) => {
    const raw = execFileSync("unzip", ["-p", archive, file], {
      encoding: "utf8",
      maxBuffer: 20 * 1024 * 1024,
    });
    let value;
    try {
      value = JSON.parse(raw);
    } catch {
      throw new Error("Invalid JSON in checkpoint archive.");
    }
    return { file, value: validateFile(file, value) };
  });
  for (const payload of payloads)
    writeJson(path.join(destination, payload.file), payload.value);
}

/** @param {string} destination @param {NodeJS.ProcessEnv} env */
function restoreCheckpoint(destination, env) {
  const repository = env.GITHUB_REPOSITORY;
  const currentRun = Number(env.GITHUB_RUN_ID);
  if (
    !repository ||
    !/^[\w.-]+\/[\w.-]+$/.test(repository) ||
    !Number.isSafeInteger(currentRun) ||
    currentRun <= 0
  )
    throw new Error(
      "GitHub repository/run identity is required to restore checkpoints.",
    );
  // Include failed and paused runs; they often contain the most recent progress.
  for (let page = 1; page <= 10; page++) {
    const response = githubJson(
      `repos/${repository}/actions/workflows/${WORKFLOW}/runs?branch=main&status=completed&per_page=100&page=${page}`,
    );
    if (!Array.isArray(response.workflow_runs))
      throw new Error("Invalid GitHub workflow-run metadata.");
    for (const raw of response.workflow_runs) {
      if (!trustedRun(raw, repository, currentRun)) continue;
      const run = record(raw);
      const response = githubJson(
        `repos/${repository}/actions/runs/${run.id}/artifacts?per_page=100`,
      );
      if (!Array.isArray(response.artifacts))
        throw new Error("Invalid GitHub artifact metadata.");
      const artifact = response.artifacts
        .map(record)
        .find(
          (item) =>
            item.name === ARTIFACT &&
            item.expired === false &&
            Number.isSafeInteger(item.id),
        );
      if (!artifact) continue;
      const temporary = fs.mkdtempSync(
        path.join(os.tmpdir(), "eval-checkpoint-"),
      );
      try {
        const archive = path.join(temporary, "checkpoint.zip");
        const bytes = execFileSync(
          "gh",
          ["api", `repos/${repository}/actions/artifacts/${artifact.id}/zip`],
          { maxBuffer: 25 * 1024 * 1024, stdio: ["ignore", "pipe", "pipe"] },
        );
        fs.writeFileSync(archive, bytes, { mode: 0o600 });
        restoreArchive(archive, destination);
        console.log(
          `Restored checkpoint from trusted main workflow run ${run.id}.`,
        );
        return;
      } finally {
        fs.rmSync(temporary, { recursive: true, force: true });
      }
    }
    if (response.workflow_runs.length < 100) break;
  }
  console.log(
    "No retained checkpoint found in recent trusted runs; starting fresh. Cases after a lost checkpoint may repeat.",
  );
}

/** @param {unknown} value */
function summary(value) {
  const report = record(value);
  const counts = record(report.counts);
  const status = ["COMPLETE", "PAUSED_NO_CREDITS", "ERROR"].includes(
    String(report.status),
  )
    ? String(report.status)
    : "ERROR";
  const completed = Number.isSafeInteger(counts.completed)
    ? counts.completed
    : "?";
  const total = Number.isSafeInteger(counts.total) ? counts.total : "?";
  const aggregate = record(report.aggregate);
  const organizations = (Array.isArray(report.attempts) ? report.attempts : [])
    .map((attempt) => record(attempt).organization)
    .filter((alias) => typeof alias === "string" && ALIAS.test(alias))
    .filter((alias, index, all) => index === 0 || alias !== all[index - 1]);
  const pending = (Array.isArray(report.pending) ? report.pending : []).filter(
    (id) => typeof id === "string" && CASE_ID.test(id),
  );
  const cost = report.estimated_cost_usd;
  const lines = [
    `Claude skill-review eval: **${status}**${status === "COMPLETE" ? (report.passed === true ? " (checks passed)" : " (checks failed)") : " (incomplete)"}`,
    `Cases completed: ${completed}/${total}.`,
    ...(Number.isFinite(aggregate.hard) && Number.isFinite(aggregate.soft)
      ? [`Scores: hard ${aggregate.hard}, soft ${aggregate.soft}.`]
      : []),
    `Organizations used: ${organizations.length ? organizations.join(" → ") : "none"}.`,
    `Estimated cost: ${typeof cost === "number" && Number.isFinite(cost) ? `$${cost.toFixed(4)}` : "unknown"}.`,
    ...(pending.length ? [`Pending cases: ${pending.join(", ")}.`] : []),
    ...(status === "ERROR" && typeof report.error === "string"
      ? [
          `Error: \`${report.error
            .replace(/[`\s]+/g, " ")
            .trim()
            .slice(0, 500)}\``,
        ]
      : []),
    status === "PAUSED_NO_CREDITS"
      ? "All organizations are exhausted. Pending work is saved; future scheduled runs recheck eligible organizations."
      : "See the report artifact for findings, organization attribution, attempt traces, and estimated costs.",
  ];
  return `${lines.join("\n\n")}\n`;
}

if (require.main === module) {
  try {
    const [command, argument] = process.argv.slice(2);
    if (command === "restore") restoreCheckpoint(DEFAULT_STATE, process.env);
    else if (command === "stage" && argument)
      stageCheckpoint(DEFAULT_STATE, path.resolve(argument));
    else if (
      command === "summary" &&
      argument &&
      process.env.GITHUB_STEP_SUMMARY
    )
      fs.appendFileSync(
        process.env.GITHUB_STEP_SUMMARY,
        summary(readJson(argument)),
      );
    else
      throw new Error(
        "Usage: ci-checkpoint.js restore | stage <destination> | summary <report.json>",
      );
  } catch {
    console.error(
      "Checkpoint operation failed. Check artifact validity, GitHub read permissions, and local state before retrying.",
    );
    process.exitCode = 1;
  }
}

module.exports = {
  checkpointPath,
  stageCheckpoint,
  trustedRun,
  restoreArchive,
  summary,
};
