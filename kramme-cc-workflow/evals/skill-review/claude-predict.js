#!/usr/bin/env node
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
  classifyAssistantError,
  classifyApiError,
  redact,
  record,
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

/** @typedef {import('./live-types').AdapterContext} AdapterContext */
/** @typedef {import('./live-types').Attempt} Attempt */
/** @typedef {import('@anthropic-ai/claude-agent-sdk').Options} SDKOptions */
/** @typedef {AsyncIterable<unknown> & {close: () => void}} Query */
/** @typedef {(args: {prompt: string, options: SDKOptions}) => Query} QueryFunction */
const {
  PROFILE,
  SKILL,
  EvalFailure,
  stageCase,
  toolAllowed,
  childEnvironment,
} = require("./claude-profile");

/** @param {AdapterContext} context
 * @param {{key: string, model: string, timeout: number, maxTurns: number, attempt: Attempt, signal: AbortSignal, query?: QueryFunction}} config */
async function runSession(context, config) {
  const staged = stageCase(context);
  const controller = new AbortController();
  const abort = () => controller.abort();
  config.signal.addEventListener("abort", abort, { once: true });
  const timer = setTimeout(abort, config.timeout);
  let invoked = false;
  let initialized = false;
  /** @type {string | null} */ let failure = null;
  /** @type {string | null} */ let prediction = null;
  /** @type {Query | undefined} */ let session;
  try {
    if (config.signal.aborted) throw new EvalFailure("interrupted");
    const query =
      config.query || (await import("@anthropic-ai/claude-agent-sdk")).query;
    /** @type {SDKOptions} */
    const options = {
      cwd: staged.workspace,
      env: childEnvironment(config.key, staged.auth, process.env),
      model: config.model,
      plugins: [{ type: "local", path: staged.plugin }],
      skills: [SKILL],
      tools: ["Skill", "Read", "Glob", "Grep"],
      allowedTools: ["Read", "Glob", "Grep"],
      settingSources: [],
      settings: {
        disableBundledSkills: true,
        disableSkillShellExecution: true,
        disableClaudeAiConnectors: true,
        skillOverrides: { doctor: "off" },
        enabledPlugins: {
          "agents-md@builtin": false,
          "cc-plugin-agents-md@builtin": false,
          "plugin-authoring@builtin": false,
          "cc-plugin-plugin-authoring@builtin": false,
        },
      },
      mcpServers: {},
      strictMcpConfig: true,
      persistSession: false,
      permissionMode: "dontAsk",
      permissionPrompts: "none",
      maxTurns: config.maxTurns,
      abortController: controller,
      promptSuggestions: false,
      stderr: () => {},
      systemPrompt: {
        type: "preset",
        preset: "claude_code",
        append:
          "This is a read-only fixture review. SkillSpector and ecosystem analyzers are unavailable in this eval profile; mark their evidence N/A. Use only the specified reviewer skill and fixture. Return the final review as text.",
      },
      hooks: {
        PreToolUse: [
          {
            hooks: [
              async (input) => {
                if (input.hook_event_name !== "PreToolUse") return {};
                const allowed = toolAllowed(
                  staged.workspace,
                  input.tool_name,
                  input.tool_input,
                );
                config.attempt.trace.push({
                  event: "tool",
                  detail: `${["Skill", "Read", "Glob", "Grep"].includes(input.tool_name) ? input.tool_name : "other"}:${allowed ? "allow" : "deny"}`,
                });
                return {
                  hookSpecificOutput: {
                    hookEventName: "PreToolUse",
                    permissionDecision: allowed ? "allow" : "deny",
                    permissionDecisionReason: "Read-only eval input boundary.",
                  },
                };
              },
            ],
          },
        ],
        PostToolUse: [
          {
            matcher: "Skill",
            hooks: [
              async (input) => {
                if (
                  input.hook_event_name === "PostToolUse" &&
                  toolAllowed(
                    staged.workspace,
                    input.tool_name,
                    input.tool_input,
                  ) &&
                  !record(input.tool_response).is_error
                ) {
                  invoked = true;
                  config.attempt.trace.push({
                    event: "skill_invoked",
                    detail: SKILL,
                  });
                }
                return {};
              },
            ],
          },
        ],
      },
    };
    session = query({
      prompt: `Use the Skill tool to invoke ${SKILL} with args exactly ${staged.fixture}. Review that fixture and return the final findings and rubric snapshot.`,
      options,
    });
    for await (const raw of session) {
      const event = record(raw);
      if (event.type === "system" && event.subtype === "init") {
        if (
          event.apiKeySource !== "ANTHROPIC_API_KEY" ||
          (Array.isArray(event.plugin_errors) &&
            event.plugin_errors.length > 0) ||
          !Array.isArray(event.skills) ||
          event.skills.length !== 1 ||
          event.skills[0] !== SKILL ||
          !Array.isArray(event.plugins) ||
          event.plugins.length !== 1 ||
          record(event.plugins[0]).name !== "eval-review"
        )
          throw new EvalFailure("session_configuration");
        initialized = true;
        config.attempt.model =
          typeof event.model === "string" ? event.model : null;
        config.attempt.trace.push({ event: "init", detail: SKILL });
      } else if (
        event.type === "assistant" &&
        typeof event.error === "string"
      ) {
        const content = record(event.message).content;
        const text = Array.isArray(content)
          ? content
              .filter((part) => record(part).type === "text")
              .map((part) => record(part).text)
              .join("\n")
          : "";
        failure = classifyAssistantError(
          event.error,
          text,
          event.api_error_status,
        );
        config.attempt.trace.push({
          event: "api_error",
          detail: /^[a-z_]{1,40}$/.test(event.error) ? event.error : "unknown",
        });
      } else if (event.type === "assistant") {
        const model = record(event.message).model;
        if (typeof model === "string" && model !== "<synthetic>")
          config.attempt.model = model;
      } else if (event.type === "system" && event.subtype === "api_retry") {
        config.attempt.trace.push({
          event: "api_retry",
          detail: `attempt=${Number(event.attempt)} delay_ms=${Number(event.retry_delay_ms)}`,
        });
      } else if (event.type === "result") {
        config.attempt.trace.push({
          event: "result",
          detail: [
            "success",
            "error_during_execution",
            "error_max_turns",
            "error_max_budget_usd",
            "error_max_structured_output_retries",
          ].includes(String(event.subtype))
            ? String(event.subtype)
            : "unknown",
        });
        config.attempt.cost_usd =
          typeof event.total_cost_usd === "number" &&
          Number.isFinite(event.total_cost_usd) &&
          event.total_cost_usd >= 0
            ? event.total_cost_usd
            : null;
        if (event.is_error || event.subtype !== "success")
          failure ||= "incomplete_result";
        else if (typeof event.result === "string" && event.result.trim())
          prediction = event.result;
      }
    }
    if (controller.signal.aborted)
      throw new EvalFailure(
        config.signal.aborted ? "interrupted" : "attempt_timeout",
      );
    if (failure) throw new EvalFailure(failure);
    if (!initialized || !invoked || !prediction || !config.attempt.model)
      throw new EvalFailure("missing_review_evidence");
    return prediction;
  } catch (error) {
    if (error instanceof EvalFailure) throw error;
    if (controller.signal.aborted)
      throw new EvalFailure(
        config.signal.aborted ? "interrupted" : "attempt_timeout",
      );
    if (failure) throw new EvalFailure(failure);
    throw new EvalFailure(classifyApiError(error));
  } finally {
    clearTimeout(timer);
    config.signal.removeEventListener("abort", abort);
    try {
      session?.close();
    } finally {
      fs.rmSync(staged.temporary, { recursive: true, force: true });
    }
  }
}

/** @param {AdapterContext} context @param {NodeJS.ProcessEnv} env @param {{query?: QueryFunction, now?: () => number}} [dependencies] */
async function predictLocked(
  context,
  env,
  dependencies = {},
  owner = process.pid,
) {
  const directory = env.KRAMME_LIVE_EVAL_STATE;
  const id = env.KRAMME_LIVE_EVAL_RUN;
  if (!directory || !id || !env.KRAMME_LIVE_EVAL_CONFIG)
    throw new EvalFailure("use_live_eval_entrypoint");
  const organizations = organizationsFromConfig(
    readJson(env.KRAMME_LIVE_EVAL_CONFIG),
    env,
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
        const text = await runSession(context, {
          key: org.key,
          model: run.model,
          timeout: Math.min(
            Number(env.KRAMME_LIVE_EVAL_ATTEMPT_TIMEOUT || 120000),
            deadline - now(),
          ),
          maxTurns: Number(env.KRAMME_LIVE_EVAL_MAX_TURNS || 12),
          attempt,
          signal: controller.signal,
          query: dependencies.query,
        });
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

/** @param {AdapterContext} context @param {NodeJS.ProcessEnv} env @param {{query?: QueryFunction, now?: () => number}} [dependencies] */
async function predict(context, env, dependencies = {}) {
  if (!env.KRAMME_LIVE_EVAL_STATE)
    throw new EvalFailure("use_live_eval_entrypoint");
  const worker = registerWorker(
    env.KRAMME_LIVE_EVAL_STATE,
    env.KRAMME_LIVE_EVAL_OWNER_TOKEN,
  );
  try {
    return await predictLocked(context, env, dependencies, worker.owner);
  } finally {
    worker.release();
  }
}

if (require.main === module) {
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
        // Do not forward SDK errors, input JSON, or the inherited environment.
        process.stderr.write(
          `Live prediction failed: ${error instanceof EvalFailure ? error.code : "configuration_or_checkpoint_error"}\n`,
        );
        process.exitCode = 1;
      },
    );
}

module.exports = {
  PROFILE,
  SKILL,
  EvalFailure,
  stageCase,
  toolAllowed,
  childEnvironment,
  runSession,
  predict,
};
