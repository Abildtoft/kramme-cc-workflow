// @ts-check
"use strict";

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const {
  writeJson,
  runFile,
  acquireLock,
  readJson,
} = require("../../evals/skill-review/eval-state");
const { record } = require("../../evals/skill-review/credit-pool");
const { SKILL } = require("../../evals/skill-review/claude-predict");
const openai = require("../../evals/skill-review/openai-predict");
const { PROVIDERS } = require("../../evals/skill-review/providers");

/** @param {import('node:test').TestContext} t @param {import('../../evals/skill-review/live-types').ProviderId} [providerId] */
function sandbox(t, providerId = "anthropic") {
  const prefix = PROVIDERS[providerId].keyPrefix;
  const secret =
    providerId === "openai" ? "sk-proj-test-key" : "sk-ant-test-key";
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "live-eval-test-"));
  let unlock = () => {};
  t.after(() => {
    unlock();
    fs.rmSync(root, { recursive: true, force: true });
  });
  const config = path.join(root, "organizations.json");
  writeJson(config, [
    { alias: "org-a", key_env: `${prefix}A` },
    { alias: "org-b", key_env: `${prefix}B` },
  ]);
  const env = {
    ...process.env,
    [`${prefix}A`]: `${secret}-A`,
    [`${prefix}B`]: `${secret}-B`,
    KRAMME_LIVE_EVAL_CONFIG: config,
    KRAMME_LIVE_EVAL_STATE: path.join(root, "state"),
    KRAMME_LIVE_EVAL_RUN: "test-run",
  };
  const reviewer = path.resolve(__dirname, "../../skills/kramme:skill:review");
  const fixture = path.resolve(
    __dirname,
    "../../evals/skill-review/fixtures/good-skill",
  );
  /** @type {import('../../evals/skill-review/live-types').AdapterContext} */
  const context = {
    adapter_version: 1,
    skill_path: reviewer,
    item: { id: "case-1", input_skill_path: fixture },
  };
  /** @type {import('../../evals/skill-review/live-types').RunState} */
  const run = {
    schema_version: 1,
    id: "test-run",
    fingerprint: "a".repeat(64),
    model: providerId === "openai" ? "gpt-test-1" : "claude-test-1",
    sdk_version: "test",
    commit: "test",
    created_at: 1,
    updated_at: 1,
    case_ids: ["case-1", "case-2"],
    status: "RUNNING",
    completed: {},
    attempts: [],
  };
  writeJson(runFile(env.KRAMME_LIVE_EVAL_STATE, run.id), run);
  unlock = acquireLock(env.KRAMME_LIVE_EVAL_STATE);
  const token = String(
    record(readJson(path.join(env.KRAMME_LIVE_EVAL_STATE, "writer.lock")))
      .token,
  );
  return {
    root,
    config,
    // The provider's key variables are dynamic; keep them reachable by name.
    env: /** @type {NodeJS.ProcessEnv & typeof env & {KRAMME_LIVE_EVAL_OWNER_TOKEN: string}} */ ({
      ...env,
      KRAMME_LIVE_EVAL_OWNER_TOKEN: token,
    }),
    context,
    run,
  };
}

/** @param {import('@anthropic-ai/claude-agent-sdk').Options} options */
async function invokeSkill(options) {
  const input = {
    session_id: "test",
    transcript_path: "unused",
    cwd: options.cwd || "/",
    tool_name: "Skill",
    tool_input: {
      skill: SKILL,
      args: path.join(options.cwd || "/", "fixture"),
    },
    tool_use_id: "tool-1",
  };
  const signal = new AbortController().signal;
  for (const group of options.hooks?.PreToolUse || [])
    for (const callback of group.hooks)
      await callback({ ...input, hook_event_name: "PreToolUse" }, "tool-1", {
        signal,
      });
  for (const group of options.hooks?.PostToolUse || [])
    for (const callback of group.hooks)
      await callback(
        {
          ...input,
          hook_event_name: "PostToolUse",
          tool_response: { success: true },
        },
        "tool-1",
        { signal },
      );
}

/** @param {import('@anthropic-ai/claude-agent-sdk').Options} options */
function init(options) {
  return {
    type: "system",
    subtype: "init",
    apiKeySource: "ANTHROPIC_API_KEY",
    skills: [SKILL],
    plugins: [{ name: "eval-review" }],
    model: options.model,
  };
}

/** @param {number} status @param {unknown} body @param {Record<string, string>} [headers] */
function jsonResponse(status, body, headers = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", ...headers },
  });
}

/** A completed Responses API reply. @param {unknown[]} output */
function completed(output, model = "gpt-test-resolved") {
  return jsonResponse(200, {
    id: "resp_test",
    object: "response",
    status: "completed",
    model,
    output,
    usage: {
      input_tokens: 10,
      input_tokens_details: { cached_tokens: 2 },
      output_tokens: 5,
      output_tokens_details: { reasoning_tokens: 1 },
    },
  });
}

/** @param {string} text */
function message(text) {
  return {
    type: "message",
    id: "msg_test",
    role: "assistant",
    status: "completed",
    content: [{ type: "output_text", text, annotations: [] }],
  };
}

/** @param {string} name @param {Record<string, unknown>} args @param {string} [id] */
function functionCall(name, args, id = `call_${name}`) {
  return {
    type: "function_call",
    id: `fc_${id}`,
    call_id: id,
    name,
    arguments: JSON.stringify(args),
    status: "completed",
  };
}

/** The adapter's first message names the staged fixture path. @param {any} body */
function skillCall(body) {
  const fixture = /args exactly (\S+)\. Review/.exec(body.input[0].content);
  return functionCall("Skill", { skill: openai.SKILL, args: fixture?.[1] });
}

/** @param {any} body */
function toolResults(body) {
  return body.input.filter(
    (/** @type {any} */ item) => item.type === "function_call_output",
  );
}

/** @typedef {{url: string, key: string, body: any, signal: AbortSignal}} FakeRequest */
/** A fake Responses endpoint that records each request's key and body.
 * @param {(request: FakeRequest) => Response | Promise<Response>} respond */
function fakeOpenAI(respond) {
  /** @type {FakeRequest[]} */
  const requests = [];
  /** @type {import('../../evals/skill-review/openai-predict').FetchFunction} */
  const fetch = async (url, init) => {
    const request = {
      url,
      key: init.headers.authorization.replace(/^Bearer /, ""),
      body: JSON.parse(init.body),
      signal: init.signal,
    };
    requests.push(request);
    return respond(request);
  };
  return { fetch, requests };
}

/** Invoke the reviewer skill, then return the review. @param {string} review */
function reviewer(review) {
  /** @param {FakeRequest} request */
  return (request) =>
    toolResults(request.body).length
      ? completed([message(review)])
      : completed([skillCall(request.body)]);
}

module.exports = {
  sandbox,
  invokeSkill,
  init,
  jsonResponse,
  completed,
  message,
  functionCall,
  skillCall,
  toolResults,
  fakeOpenAI,
  reviewer,
};
