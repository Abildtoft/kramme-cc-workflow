#!/usr/bin/env node
// @ts-check
"use strict";

const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const claude = require("./claude-predict");
const {
  organizationsFromConfig,
  reconcilePool,
  redact,
  record,
} = require("./credit-pool");
const {
  SAFE_ID,
  readJson,
  writeJson,
  validatePool,
  validateRun,
  runFile,
  saveRun,
  acquireLock,
  digestFiles,
  treeFiles,
} = require("./eval-state");
const openai = require("./openai-predict");
const { providerById } = require("./providers");
const { PROFILE } = require("./review-profile");
const { loadItemsForSplit } = require("./run-eval");
const { scoreItem, aggregateScores } = require("./scorer");

/** @typedef {import('./live-types').LiveOptions} LiveOptions */
/** @typedef {import('./live-types').Organization} Organization */
/** @typedef {import('./live-types').Provider} Provider */
/** @typedef {import('./live-types').RunState} RunState */
const REPO = path.resolve(__dirname, "../../..");
const RUNTIME_VERSIONS = {
  anthropic: claude.runtimeVersion,
  openai: openai.runtimeVersion,
};
const REVIEWER = path.join(
  REPO,
  "kramme-cc-workflow/skills/kramme:skill:review",
);

/** @param {string} value */
function shellQuote(value) {
  return `'${value.replace(/'/g, `'"'"'`)}'`;
}

/** @param {string[]} argv @param {NodeJS.ProcessEnv} env @returns {LiveOptions & {help?: boolean}} */
function parseOptions(argv, env) {
  const values = new Map();
  const switches = new Set(["--dry-run", "--help"]);
  const named = new Set([
    "--provider",
    "--organizations",
    "--model",
    "--split",
    "--state-dir",
    "--run-id",
    "--attempt-timeout-ms",
    "--case-timeout-ms",
    "--max-turns",
  ]);
  for (let i = 0; i < argv.length; i++) {
    const name = argv[i];
    if (values.has(name) || (!switches.has(name) && !named.has(name)))
      throw new Error("Unknown or duplicate live eval option. Use --help.");
    if (switches.has(name)) values.set(name, "true");
    else {
      const value = argv[++i];
      if (!value || value.startsWith("--"))
        throw new Error("Live eval option requires a value. Use --help.");
      values.set(name, value);
    }
  }
  const provider = providerById(values.get("--provider") || "anthropic");
  const model = values.get("--model") || env[provider.modelEnv] || "";
  if (!values.has("--help") && !provider.model.test(model))
    throw new Error(
      `Set --model or ${provider.modelEnv} to an explicit ${provider.label} model ID.`,
    );
  const split = values.get("--split") || "all";
  if (!["train", "val", "test", "all"].includes(split))
    throw new Error("Invalid eval split.");
  const attemptTimeout = Number(values.get("--attempt-timeout-ms") || 120000);
  const caseTimeout = Number(values.get("--case-timeout-ms") || 600000);
  const maxTurns = Number(values.get("--max-turns") || 12);
  if (
    ![attemptTimeout, caseTimeout, maxTurns].every(
      (n) => Number.isSafeInteger(n) && n > 0,
    ) ||
    attemptTimeout > caseTimeout ||
    caseTimeout > 600000 ||
    maxTurns > 100
  )
    throw new Error(
      "Use positive integer limits: attempt <= case <= 600000ms, max turns <= 100.",
    );
  return {
    provider,
    organizations: path.resolve(
      values.get("--organizations") ||
        path.join(__dirname, provider.exampleConfig),
    ),
    model,
    split,
    stateDir: path.resolve(
      values.get("--state-dir") || path.join(REPO, provider.stateDir),
    ),
    runId: values.get("--run-id"),
    dryRun: values.has("--dry-run"),
    attemptTimeout,
    caseTimeout,
    maxTurns,
    help: values.has("--help"),
  };
}

// Only inputs that change predictions or scores; docs and CI helpers must not orphan a paused run.
// Each provider adds its own adapter, so changing one adapter never orphans another provider's run.
const IDENTITY_INPUTS = [
  "credit-pool.js",
  "eval-state.js",
  "live-predict.js",
  "providers.js",
  "review-profile.js",
  "run-eval.js",
  "scorer.js",
  "fixtures",
  "items",
];

/** @param {LiveOptions} options @param {string} version */
function runIdentity(options, version) {
  const files = [
    ...[...IDENTITY_INPUTS, options.provider.adapter].flatMap((name) =>
      treeFiles(path.join(__dirname, name)),
    ),
    ...treeFiles(REVIEWER),
  ];
  return crypto
    .createHash("sha256")
    .update(digestFiles(files, REPO))
    .update(
      JSON.stringify({
        provider: options.provider.id,
        profile: PROFILE,
        sdk: version,
        model: options.model,
        split: options.split,
        attemptTimeout: options.attemptTimeout,
        caseTimeout: options.caseTimeout,
        maxTurns: options.maxTurns,
        repetition: 1,
      }),
    )
    .digest("hex");
}

/** @param {LiveOptions} options @param {string} fingerprint @param {string} version @param {string[]} caseIds @returns {RunState} */
function selectRun(options, fingerprint, version, caseIds) {
  if (options.runId) {
    const previous = readJson(runFile(options.stateDir, options.runId));
    if (previous !== null) {
      const run = validateRun(previous);
      if (run.id !== options.runId)
        throw new Error("Named run checkpoint identity mismatch.");
      if (run.fingerprint !== fingerprint)
        throw new Error("Named run has different inputs. Use a new run ID.");
      return run;
    }
  } else {
    const runs = path.join(options.stateDir, "runs");
    const pending = fs.existsSync(runs)
      ? fs
          .readdirSync(runs, { withFileTypes: true })
          // Skip entries such as .DS_Store or a run directory renamed aside.
          .filter((entry) => entry.isDirectory() && SAFE_ID.test(entry.name))
          .map((entry) =>
            validateRun(readJson(runFile(options.stateDir, entry.name))),
          )
          .filter(
            (run) =>
              run.fingerprint === fingerprint && run.status !== "COMPLETE",
          )
          .sort((a, b) => b.updated_at - a.updated_at)
      : [];
    if (pending[0]) return pending[0];
  }
  const id =
    options.runId ||
    `${new Date().toISOString().replace(/[^0-9]/g, "")}-${crypto.randomUUID().slice(0, 8)}`;
  const commit =
    spawnSync("git", ["rev-parse", "HEAD"], {
      cwd: REPO,
      encoding: "utf8",
    }).stdout?.trim() || "unknown";
  return {
    schema_version: 1,
    id,
    fingerprint,
    model: options.model,
    sdk_version: version,
    commit,
    created_at: Date.now(),
    updated_at: Date.now(),
    case_ids: caseIds,
    status: "RUNNING",
    completed: {},
    attempts: [],
  };
}

/** Keep the nested runner's local diagnostic; the adapter never forwards provider output.
 * @param {import('node:child_process').SpawnSyncReturns<string>} result @param {Organization[]} organizations */
function runnerDiagnostic(result, organizations) {
  if (result.error)
    return `Eval runner failed: ${String(record(result.error).code || "spawn_error")}.`;
  if (result.signal) return `Eval runner stopped by ${result.signal}.`;
  let message;
  try {
    message = record(JSON.parse(result.stdout)).error;
  } catch {
    message = null;
  }
  return typeof message === "string" && message.trim()
    ? redact(message.trim(), organizations).slice(0, 2000)
    : `Eval runner exited ${result.status} without a diagnostic.`;
}

/** @param {Provider} provider @param {RunState} run @param {ReturnType<typeof loadItemsForSplit>} items @param {import('./live-types').PoolState} pool @param {string | null} [error] */
function reportForRun(provider, run, items, pool, error = null) {
  const results = items
    .filter((item) => Object.hasOwn(run.completed, item.id))
    .map((item) => ({
      ...scoreItem(item, run.completed[item.id].text, {
        predictionSource: "prediction_command",
      }),
      organization: run.completed[item.id].organization,
      model: run.completed[item.id].model,
      split: item.split,
    }));
  const complete = run.status === "COMPLETE" && results.length === items.length;
  const counts = { completed: results.length, total: items.length };
  const aggregate = complete ? aggregateScores(results) : null;
  return {
    schema_version: 1,
    provider: provider.id,
    run_id: run.id,
    status: run.status,
    error: run.status === "ERROR" ? error : null,
    passed: complete ? results.every((item) => item.hard === 1) : null,
    profile: PROFILE,
    requested_model: run.model,
    sdk_version: run.sdk_version,
    commit: run.commit,
    counts,
    aggregate,
    items: results,
    pending: run.case_ids.filter((id) => !Object.hasOwn(run.completed, id)),
    attempts: run.attempts,
    estimated_cost_usd: run.attempts.some((a) => a.cost_usd !== null)
      ? run.attempts.reduce((sum, a) => sum + (a.cost_usd || 0), 0)
      : null,
    next_recheck_at:
      run.status === "PAUSED_NO_CREDITS"
        ? Math.min(
            ...Object.values(pool.organizations).map(
              (entry) => entry.recheck_after ?? Infinity,
            ),
          )
        : null,
    limitations: [
      "Phrase matching is an initial regression signal, not a comprehensive review-quality measure.",
      "SkillSpector and ecosystem analyzers are unavailable in this read-only profile.",
      "Cost is estimated; missing attempt costs are unknown, not zero.",
      "Hard interruption can repeat cases since the last durable checkpoint artifact.",
      ...(provider.id === "openai"
        ? [
            "OpenAI attempts record token usage in their traces instead of a cost estimate.",
            "The OpenAI profile runs the reviewer through a local Responses API tool loop, not the Codex host.",
          ]
        : []),
    ],
  };
}

/** @param {LiveOptions} options @param {{env?: NodeJS.ProcessEnv, adapterCommand?: string}} [dependencies] */
function runLive(options, dependencies = {}) {
  const env = dependencies.env || process.env;
  const organizations = organizationsFromConfig(
    readJson(options.organizations),
    env,
    options.provider,
  );
  const items = loadItemsForSplit(options.split, __dirname);
  const version = RUNTIME_VERSIONS[options.provider.id]();
  const fingerprint = runIdentity(options, version);
  if (options.dryRun)
    return {
      exitCode: 0,
      report: {
        status: "DRY_RUN",
        provider: options.provider.id,
        model: options.model,
        sdk_version: version,
        organizations: organizations.map((org) => org.alias),
        cases: items.map((item) => item.id),
        profile: PROFILE,
      },
    };
  const release = acquireLock(options.stateDir);
  try {
    const previous = readJson(path.join(options.stateDir, "pool-state.json"));
    const pool = reconcilePool(
      organizations,
      previous === null ? null : validatePool(previous),
    );
    writeJson(path.join(options.stateDir, "pool-state.json"), pool);
    let run = selectRun(
      options,
      fingerprint,
      version,
      items.map((item) => item.id),
    );
    for (const attempt of run.attempts)
      if (attempt.outcome === "RUNNING") attempt.outcome = "interrupted";
    run.status = "RUNNING";
    saveRun(options.stateDir, run);
    const command =
      dependencies.adapterCommand ||
      `exec ${shellQuote(process.execPath)} ${shellQuote(path.join(__dirname, options.provider.adapter))}`;
    const result = spawnSync(
      process.execPath,
      [
        path.join(__dirname, "run-eval.js"),
        "--split",
        options.split,
        "--skill",
        REVIEWER,
        "--prediction-command",
        command,
        "--json",
      ],
      {
        cwd: REPO,
        encoding: "utf8",
        maxBuffer: 20 * 1024 * 1024,
        timeout: 25 * 60 * 1000,
        env: {
          ...env,
          KRAMME_LIVE_EVAL_STATE: options.stateDir,
          KRAMME_LIVE_EVAL_OWNER_TOKEN: String(
            record(readJson(path.join(options.stateDir, "writer.lock"))).token,
          ),
          KRAMME_LIVE_EVAL_RUN: run.id,
          KRAMME_LIVE_EVAL_CONFIG: options.organizations,
          KRAMME_LIVE_EVAL_ATTEMPT_TIMEOUT: String(options.attemptTimeout),
          KRAMME_LIVE_EVAL_CASE_TIMEOUT: String(options.caseTimeout),
          KRAMME_LIVE_EVAL_MAX_TURNS: String(options.maxTurns),
          KRAMME_LIVE_EVAL_DEADLINE: String(Date.now() + 24 * 60 * 1000),
          SKILL_REVIEW_EVAL_PREDICTION_TIMEOUT_MS: String(
            options.caseTimeout + 15000,
          ),
        },
      },
    );
    run = validateRun(readJson(runFile(options.stateDir, run.id)));
    if (
      result.status === 0 &&
      Object.keys(run.completed).length === items.length
    )
      run.status = "COMPLETE";
    else if (run.status !== "PAUSED_NO_CREDITS") run.status = "ERROR";
    saveRun(options.stateDir, run);
    const finalPool = validatePool(
      readJson(path.join(options.stateDir, "pool-state.json")),
    );
    const report = reportForRun(
      options.provider,
      run,
      items,
      finalPool,
      run.status === "ERROR" ? runnerDiagnostic(result, organizations) : null,
    );
    writeJson(
      path.join(path.dirname(runFile(options.stateDir, run.id)), "report.json"),
      report,
    );
    return {
      exitCode: run.status === "PAUSED_NO_CREDITS" ? 2 : report.passed ? 0 : 1,
      report,
    };
  } finally {
    release();
  }
}

function main() {
  try {
    const options = parseOptions(process.argv.slice(2), process.env);
    if (options.help) {
      console.log(
        "Usage: node evals/skill-review/run-live-eval.js [--provider anthropic|openai] --organizations <config.json> --model <model-id> [--split train|val|test|all] [--run-id <id>] [--state-dir <dir>] [--dry-run] [--attempt-timeout-ms <ms>] [--case-timeout-ms <ms>] [--max-turns <n>]",
      );
      return;
    }
    const result = runLive(options);
    console.log(JSON.stringify(result.report, null, 2));
    process.exitCode = result.exitCode;
  } catch (error) {
    // All local validation diagnostics are ours; never include provider output.
    console.log(
      JSON.stringify({
        status: "ERROR",
        error:
          error instanceof Error && !record(error).code
            ? error.message
            : "Live eval configuration or filesystem error.",
      }),
    );
    process.exitCode = 1;
  }
}
if (require.main === module) main();

module.exports = { parseOptions, runLive, reportForRun };
