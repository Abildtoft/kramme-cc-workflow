// @ts-check
"use strict";

const fs = require("node:fs");
const path = require("node:path");
const {
  organizationsFromConfig,
  reconcilePool,
  selectOrganization,
  markExhausted,
  markAvailable,
  redact,
} = require("./credit-pool");
const {
  readJson,
  writeJson,
  validatePool,
  validateRun,
  runFile,
  saveRun,
  registerWorker,
  processAlive,
} = require("./eval-state");
const { EvalFailure } = require("./review-profile");

/** @typedef {import('./live-types').AdapterContext} AdapterContext */
/** @typedef {import('./live-types').Attempt} Attempt */
/** @typedef {import('./live-types').Provider} Provider */
/** @typedef {{key: string, model: string, timeout: number, maxTurns: number, attempt: Attempt, signal: AbortSignal}} SessionConfig */

/** Shared organization rotation for every provider adapter.
 * @template {{now?: () => number}} D
 * @param {AdapterContext} context @param {NodeJS.ProcessEnv} env @param {Provider} provider
 * @param {(context: AdapterContext, config: SessionConfig, dependencies: D) => Promise<string>} runSession
 * @param {D} dependencies @param {number} owner */
async function predictLocked(
  context,
  env,
  provider,
  runSession,
  dependencies,
  owner,
) {
  const directory = env.KRAMME_LIVE_EVAL_STATE;
  const id = env.KRAMME_LIVE_EVAL_RUN;
  if (!directory || !id || !env.KRAMME_LIVE_EVAL_CONFIG)
    throw new EvalFailure("use_live_eval_entrypoint");
  const organizations = organizationsFromConfig(
    readJson(env.KRAMME_LIVE_EVAL_CONFIG),
    env,
    provider,
  );
  const run = validateRun(readJson(runFile(directory, id)));
  if (!run.case_ids.includes(context.item.id))
    throw new EvalFailure("unexpected_case");
  if (Object.hasOwn(run.completed, context.item.id))
    return run.completed[context.item.id].text;
  const poolPath = path.join(directory, "pool-state.json");
  const previous = readJson(poolPath);
  const pool = reconcilePool(
    organizations,
    previous === null ? null : validatePool(previous),
  );
  const now = dependencies.now || Date.now;
  const runDeadline = Number(env.KRAMME_LIVE_EVAL_DEADLINE || Infinity);
  const deadline = Math.min(
    now() + Number(env.KRAMME_LIVE_EVAL_CASE_TIMEOUT || 600000),
    runDeadline,
  );
  const controller = new AbortController();
  const interrupt = () => controller.abort();
  const ownerCheck = setInterval(() => {
    if (!processAlive(owner) || now() >= runDeadline) interrupt();
  }, 1000);
  ownerCheck.unref();
  process.on("SIGINT", interrupt);
  process.on("SIGTERM", interrupt);
  try {
    while (!controller.signal.aborted) {
      const org = selectOrganization(organizations, pool, now());
      if (!org) {
        run.status = "PAUSED_NO_CREDITS";
        saveRun(directory, run);
        throw new EvalFailure("no_credits");
      }
      if (now() >= deadline) throw new EvalFailure("case_timeout");
      /** @type {Attempt} */
      const attempt = {
        case_id: context.item.id,
        organization: org.alias,
        started_at: now(),
        outcome: "RUNNING",
        model: null,
        cost_usd: null,
        trace: [],
      };
      run.attempts.push(attempt);
      saveRun(directory, run);
      try {
        const text = await runSession(
          context,
          {
            key: org.key,
            model: run.model,
            timeout: Math.min(
              Number(env.KRAMME_LIVE_EVAL_ATTEMPT_TIMEOUT || 120000),
              deadline - now(),
            ),
            maxTurns: Number(env.KRAMME_LIVE_EVAL_MAX_TURNS || 12),
            attempt,
            signal: controller.signal,
          },
          dependencies,
        );
        attempt.outcome = "COMPLETE";
        markAvailable(pool, org.alias);
        run.completed[context.item.id] = {
          text: redact(text, organizations),
          organization: org.alias,
          model: /** @type {string} */ (attempt.model),
        };
        writeJson(poolPath, pool);
        saveRun(directory, run);
        return run.completed[context.item.id].text;
      } catch (error) {
        attempt.outcome =
          error instanceof EvalFailure ? error.code : "runtime_error";
        if (attempt.outcome === "insufficient_credits")
          markExhausted(pool, org.alias, now());
        else run.status = "ERROR";
        writeJson(poolPath, pool);
        saveRun(directory, run);
        if (attempt.outcome !== "insufficient_credits")
          throw new EvalFailure(`${org.alias}:${attempt.outcome}`);
      }
    }
    throw new EvalFailure("interrupted");
  } finally {
    clearInterval(ownerCheck);
    process.removeListener("SIGINT", interrupt);
    process.removeListener("SIGTERM", interrupt);
  }
}

/** @template {{now?: () => number}} D
 * @param {AdapterContext} context @param {NodeJS.ProcessEnv} env @param {Provider} provider
 * @param {(context: AdapterContext, config: SessionConfig, dependencies: D) => Promise<string>} runSession
 * @param {D} dependencies */
async function predictWithPool(
  context,
  env,
  provider,
  runSession,
  dependencies,
) {
  if (!env.KRAMME_LIVE_EVAL_STATE)
    throw new EvalFailure("use_live_eval_entrypoint");
  const worker = registerWorker(
    env.KRAMME_LIVE_EVAL_STATE,
    env.KRAMME_LIVE_EVAL_OWNER_TOKEN,
  );
  try {
    return await predictLocked(
      context,
      env,
      provider,
      runSession,
      dependencies,
      worker.owner,
    );
  } finally {
    worker.release();
  }
}

/** Version-1 prediction command: context JSON on stdin, the completed review on stdout.
 * @param {(context: AdapterContext, env: NodeJS.ProcessEnv) => Promise<string>} predict */
function runAdapter(predict) {
  Promise.resolve()
    .then(() => {
      let context;
      try {
        context = JSON.parse(fs.readFileSync(0, "utf8"));
      } catch {
        throw new EvalFailure("invalid_adapter_context");
      }
      return predict(context, process.env);
    })
    .then(
      (text) => process.stdout.write(text),
      (error) => {
        // Do not forward provider errors, input JSON, or the inherited environment.
        process.stderr.write(
          `Live prediction failed: ${error instanceof EvalFailure ? error.code : "configuration_or_checkpoint_error"}\n`,
        );
        process.exitCode = 1;
      },
    );
}

module.exports = { predictWithPool, runAdapter };
