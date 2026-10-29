#!/usr/bin/env node
// @ts-check
"use strict";

const fs = require("node:fs");
const path = require("node:path");
const {
  classifyAssistantError,
  classifyApiError,
  record,
} = require("./credit-pool");
const { readJson } = require("./eval-state");
const { predictWithPool, runAdapter } = require("./live-predict");
const { PROVIDERS } = require("./providers");
const {
  PROFILE,
  TOOLS,
  EvalFailure,
  stageCase,
  toolAllowed,
} = require("./review-profile");

/** @typedef {import('./live-types').AdapterContext} AdapterContext */
/** @typedef {import('./live-predict').SessionConfig} SessionConfig */
/** @typedef {import('@anthropic-ai/claude-agent-sdk').Options} SDKOptions */
/** @typedef {AsyncIterable<unknown> & {close: () => void}} Query */
/** @typedef {(args: {prompt: string, options: SDKOptions}) => Query} QueryFunction */
/** @typedef {{query?: QueryFunction, now?: () => number}} Dependencies */
// This SDK normalizes ':' within a skill name to '-' when qualifying a plugin skill.
const SKILL = "eval-review:kramme-skill-review";

function runtimeVersion() {
  return String(
    record(
      readJson(
        path.join(
          path.dirname(require.resolve("@anthropic-ai/claude-agent-sdk")),
          "package.json",
        ),
      ),
    ).version,
  );
}

/** @param {string} key @param {string} auth @param {NodeJS.ProcessEnv} parent */
function childEnvironment(key, auth, parent) {
  // SDK 0.3.310 replaces (rather than merges) its subprocess environment.
  return {
    PATH: parent.PATH || "/usr/bin:/bin",
    LANG: "en_US.UTF-8",
    ANTHROPIC_API_KEY: key,
    CLAUDE_CONFIG_DIR: auth,
    CLAUDE_AGENT_SDK_CLIENT_APP: "kramme-skill-review-evals/1.0.0",
    CLAUDE_CODE_MAX_RETRIES: "2",
    CLAUDE_CODE_NONSTREAMING_TIMEOUT_RETRIES: "0",
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC: "1",
    ...(parent.RUNNER_TRACKING_ID
      ? { RUNNER_TRACKING_ID: parent.RUNNER_TRACKING_ID }
      : {}),
  };
}

/** @param {AdapterContext} context @param {SessionConfig} config @param {Dependencies} [dependencies] */
async function runSession(context, config, dependencies = {}) {
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
      dependencies.query ||
      (await import("@anthropic-ai/claude-agent-sdk")).query;
    /** @type {SDKOptions} */
    const options = {
      cwd: staged.workspace,
      env: childEnvironment(config.key, staged.auth, process.env),
      model: config.model,
      plugins: [{ type: "local", path: staged.plugin }],
      skills: [SKILL],
      tools: TOOLS,
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
                  SKILL,
                );
                config.attempt.trace.push({
                  event: "tool",
                  detail: `${TOOLS.includes(input.tool_name) ? input.tool_name : "other"}:${allowed ? "allow" : "deny"}`,
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
                    SKILL,
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

/** @param {AdapterContext} context @param {NodeJS.ProcessEnv} env @param {Dependencies} [dependencies] */
function predict(context, env, dependencies = {}) {
  return predictWithPool(
    context,
    env,
    PROVIDERS.anthropic,
    runSession,
    dependencies,
  );
}

if (require.main === module) runAdapter(predict);

module.exports = {
  PROFILE,
  SKILL,
  EvalFailure,
  stageCase,
  toolAllowed,
  childEnvironment,
  runtimeVersion,
  runSession,
  predict,
};
