// @ts-check
"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const {
  predict,
  runSession,
  runTool,
  globPattern,
  retryDelay,
  ENDPOINT,
  SKILL,
} = require("../../evals/skill-review/openai-predict");
const {
  stageCase,
  toolAllowed,
  EvalFailure,
} = require("../../evals/skill-review/review-profile");
const {
  readJson,
  validatePool,
  validateRun,
  runFile,
} = require("../../evals/skill-review/eval-state");
const {
  sandbox,
  jsonResponse,
  completed,
  message,
  functionCall,
  skillCall,
  toolResults,
  fakeOpenAI,
  reviewer,
} = require("../test_helper/live-eval");

/** @param {string} code @param {string} [type] @param {number} [status] @param {Record<string, string>} [headers] */
function apiError(code, type = "insufficient_quota", status = 429, headers) {
  return jsonResponse(
    status,
    { error: { message: "provider text", type, param: null, code } },
    headers,
  );
}

function disconnectedBody() {
  return new Response(
    new ReadableStream({
      start(controller) {
        controller.error(new TypeError("terminated"));
      },
    }),
    { status: 200, headers: { "retry-after-ms": "1" } },
  );
}

/** @returns {import('../../evals/skill-review/live-types').Attempt} */
function attempt() {
  return {
    case_id: "case-1",
    organization: "org-a",
    started_at: 0,
    outcome: "RUNNING",
    model: null,
    cost_usd: null,
    trace: [],
  };
}

/** @param {import('../../evals/skill-review/live-types').Attempt} value */
function sessionConfig(value, timeout = 5000, maxTurns = 12) {
  return {
    key: "sk-proj-test-key-A",
    model: "gpt-test-1",
    timeout,
    maxTurns,
    attempt: value,
    signal: new AbortController().signal,
  };
}

test("A exhausts its credits mid-case; B restarts the case in a fresh conversation", async (t) => {
  const { env, context } = sandbox(t, "openai");
  const keyA = String(env.OPENAI_EVAL_KEY_A);
  const keyB = String(env.OPENAI_EVAL_KEY_B);
  const review = reviewer("No findings found.");
  const { fetch, requests } = fakeOpenAI((request) =>
    request.key === keyA && toolResults(request.body).length
      ? apiError("credit_balance_exhausted")
      : review(request),
  );
  assert.equal(await predict(context, env, { fetch }), "No findings found.");
  assert.deepEqual(
    requests.map((request) => request.key),
    [keyA, keyA, keyB, keyB],
  );
  // B never sees A's partial conversation.
  assert.equal(requests[2].body.input.length, 1);
  for (const request of requests) {
    assert.equal(request.url, ENDPOINT);
    assert.equal(request.body.store, false);
    assert.equal(request.body.model, "gpt-test-1");
    assert.deepEqual(
      request.body.tools.map((/** @type {any} */ tool) => tool.name),
      ["Skill", "Read", "Glob", "Grep"],
    );
    // Keys travel only in the authorization header; answers never leave the harness.
    const sent = JSON.stringify(request.body);
    assert.ok(
      !sent.includes(keyA) &&
        !sent.includes(keyB) &&
        !sent.includes("expected_findings"),
    );
  }
  const directory = String(env.KRAMME_LIVE_EVAL_STATE);
  const run = validateRun(readJson(runFile(directory, "test-run")));
  assert.deepEqual(
    run.attempts.map((a) => a.outcome),
    ["insufficient_credits", "COMPLETE"],
  );
  assert.deepEqual(
    run.attempts.map((a) => a.cost_usd),
    [null, null],
  );
  assert.ok(
    run.attempts[1].trace.some(
      (event) => event.event === "skill_invoked" && event.detail === SKILL,
    ),
  );
  assert.ok(
    run.attempts[1].trace.some(
      (event) =>
        event.event === "usage" &&
        event.detail === "input=20 cached=4 output=10 reasoning=2",
    ),
  );
  assert.deepEqual(run.completed["case-1"], {
    text: "No findings found.",
    organization: "org-b",
    model: "gpt-test-resolved",
  });
  const pool = validatePool(readJson(path.join(directory, "pool-state.json")));
  assert.equal(pool.active, "org-b");
  assert.notEqual(pool.organizations["org-a"].exhausted_at, null);
  // A checkpoint replay does not spend again; the next case stays on B.
  assert.equal(await predict(context, env, { fetch }), "No findings found.");
  await predict({ ...context, item: { ...context.item, id: "case-2" } }, env, {
    fetch,
  });
  assert.deepEqual(
    requests.slice(4).map((request) => request.key),
    [keyB, keyB],
  );
});

test("spend limits, usage limits, ambiguous quota, and auth failures stop without rotating", async (t) => {
  const { env, context } = sandbox(t, "openai");
  for (const [response, outcome] of [
    [() => apiError("project_spend_limit_exceeded"), "spend_limit"],
    [() => apiError("organization_spend_limit_exceeded"), "spend_limit"],
    [() => apiError("organization_usage_limit_exceeded"), "usage_limit"],
    [() => apiError("insufficient_quota"), "billing_error"],
    [
      () => apiError("invalid_api_key", "invalid_request_error", 401),
      "authentication_failed",
    ],
  ]) {
    const { fetch, requests } = fakeOpenAI(
      /** @type {() => Response} */ (response),
    );
    await assert.rejects(
      predict(context, env, { fetch }),
      new RegExp(`org-a:${outcome}$`),
    );
    assert.equal(requests.length, 1);
  }
  const directory = String(env.KRAMME_LIVE_EVAL_STATE);
  const run = validateRun(readJson(runFile(directory, "test-run")));
  assert.deepEqual(run.completed, {});
  assert.equal(run.status, "ERROR");
  const pool = validatePool(readJson(path.join(directory, "pool-state.json")));
  assert.equal(pool.organizations["org-a"].exhausted_at, null);
});

test("rate limits retry on the same key, then stop resumably instead of rotating", async (t) => {
  const { env, context } = sandbox(t, "openai");
  const review = reviewer("Recovered review");
  const limited = () =>
    apiError("rate_limit_exceeded", "rate_limit_error", 429, {
      "retry-after-ms": "1",
    });
  const flaky = fakeOpenAI((request) =>
    flaky.requests.length <= 2 ? limited() : review(request),
  );
  assert.equal(
    await predict(context, env, { fetch: flaky.fetch }),
    "Recovered review",
  );
  assert.equal(new Set(flaky.requests.map((request) => request.key)).size, 1);
  const directory = String(env.KRAMME_LIVE_EVAL_STATE);
  const saved = validateRun(readJson(runFile(directory, "test-run")));
  assert.equal(
    saved.attempts[0].trace.filter((event) => event.event === "api_retry")
      .length,
    2,
  );
  const throttled = fakeOpenAI(limited);
  await assert.rejects(
    predict({ ...context, item: { ...context.item, id: "case-2" } }, env, {
      fetch: throttled.fetch,
    }),
    /org-a:retry_exhausted$/,
  );
  assert.equal(throttled.requests.length, 3);
  assert.ok(
    throttled.requests.every(
      (request) => request.key === env.OPENAI_EVAL_KEY_A,
    ),
  );
});

test("response-body connection failures retry on the same key within the retry budget", async (t) => {
  const { env, context } = sandbox(t, "openai");
  const review = reviewer("Recovered review");
  const flaky = fakeOpenAI((request) =>
    flaky.requests.length <= 2 ? disconnectedBody() : review(request),
  );
  assert.equal(
    await predict(context, env, { fetch: flaky.fetch }),
    "Recovered review",
  );
  assert.equal(flaky.requests.length, 4);
  const directory = String(env.KRAMME_LIVE_EVAL_STATE);
  const saved = validateRun(readJson(runFile(directory, "test-run")));
  assert.equal(
    saved.attempts[0].trace.filter((event) => event.event === "api_retry")
      .length,
    2,
  );
  const disconnected = fakeOpenAI(disconnectedBody);
  await assert.rejects(
    predict({ ...context, item: { ...context.item, id: "case-2" } }, env, {
      fetch: disconnected.fetch,
    }),
    /org-a:retry_exhausted$/,
  );
  assert.equal(disconnected.requests.length, 3);
  assert.ok(
    [...flaky.requests, ...disconnected.requests].every(
      (request) => request.key === env.OPENAI_EVAL_KEY_A,
    ),
  );
  const pool = validatePool(readJson(path.join(directory, "pool-state.json")));
  assert.equal(pool.organizations["org-a"].exhausted_at, null);
});

test("malformed JSON in a successful response stops without retrying", async (t) => {
  const { context } = sandbox(t, "openai");
  const invalid = fakeOpenAI(() => new Response("not json", { status: 200 }));
  await assert.rejects(
    runSession(context, sessionConfig(attempt()), { fetch: invalid.fetch }),
    (error) => error instanceof EvalFailure && error.code === "runtime_error",
  );
  assert.equal(invalid.requests.length, 1);
});

test("response-body aborts preserve timeout and interruption outcomes without retrying", async (t) => {
  const { context } = sandbox(t, "openai");
  for (const interrupted of [false, true]) {
    const controller = new AbortController();
    const value = attempt();
    const pending = fakeOpenAI(
      (request) =>
        new Response(
          new ReadableStream({
            start(stream) {
              request.signal.addEventListener(
                "abort",
                () => stream.error(new DOMException("aborted", "AbortError")),
                { once: true },
              );
              if (interrupted) controller.abort();
            },
          }),
          { status: 200 },
        ),
    );
    await assert.rejects(
      runSession(
        context,
        { ...sessionConfig(value, 20), signal: controller.signal },
        { fetch: pending.fetch },
      ),
      (error) =>
        error instanceof EvalFailure &&
        error.code === (interrupted ? "interrupted" : "attempt_timeout"),
    );
    assert.equal(pending.requests.length, 1);
    assert.ok(!value.trace.some((event) => event.event === "api_retry"));
  }
});

test("model-authored billing text is a prediction; a review without the skill call is not", async (t) => {
  const { env, context } = sandbox(t, "openai");
  const text =
    "You exceeded your current quota. credit_balance_exhausted is a finding here.";
  const { fetch } = fakeOpenAI(reviewer(text));
  assert.equal(await predict(context, env, { fetch }), text);
  const uninvoked = fakeOpenAI(() => completed([message("Made-up review")]));
  await assert.rejects(
    predict({ ...context, item: { ...context.item, id: "case-2" } }, env, {
      fetch: uninvoked.fetch,
    }),
    /org-a:missing_review_evidence$/,
  );
});

test("tool calls stay inside the staged workspace", async (t) => {
  const { context } = sandbox(t, "openai");
  const value = attempt();
  /** @type {any[]} */
  let results = [];
  const { fetch } = fakeOpenAI((request) => {
    results = toolResults(request.body);
    return results.length
      ? completed([message("Reviewed.")])
      : completed([
          functionCall("Read", { file_path: __filename }, "outside"),
          functionCall("Bash", { command: "env" }, "shell"),
          { ...functionCall("Read", {}, "garbled"), arguments: "not json" },
          functionCall("Grep", { pattern: "(", path: null }, "regex"),
          functionCall("Glob", { pattern: "**/*.md", path: null }, "glob"),
          skillCall(request.body),
        ]);
  });
  assert.equal(
    await runSession(context, sessionConfig(value), { fetch }),
    "Reviewed.",
  );
  assert.match(results[0].output, /^Error: Denied/);
  assert.match(results[1].output, /^Error: Denied/);
  assert.match(results[2].output, /^Error: Denied/);
  assert.match(results[3].output, /^Error: Invalid regular expression/);
  assert.match(results[4].output, /\/fixture\/SKILL\.md/);
  assert.match(results[5].output, /^Base directory for this skill: /);
  assert.match(results[5].output, /name: kramme:skill:review/);
  assert.deepEqual(
    value.trace
      .filter((event) => event.event === "tool")
      .map((event) => event.detail),
    [
      "Read:deny",
      "other:deny",
      "Read:deny",
      "Grep:allow",
      "Glob:allow",
      "Skill:allow",
    ],
  );
  // Direct checks of each tool against the same staged layout.
  const stage = stageCase(context);
  t.after(() => fs.rmSync(stage.temporary, { recursive: true, force: true }));
  const skillFile = path.join(stage.fixture, "SKILL.md");
  assert.equal(
    toolAllowed(stage.workspace, "Read", { file_path: skillFile }, SKILL),
    true,
  );
  assert.match(
    runTool(stage.workspace, "Read", {
      file_path: skillFile,
      offset: 2,
      limit: 1,
    }),
    /^ {5}2\t/,
  );
  assert.match(
    runTool(stage.workspace, "Grep", {
      pattern: "^name:",
      path: null,
      glob: "*.md",
      output_mode: "content",
      case_insensitive: null,
    }),
    /fixture\/SKILL\.md:2:name:/,
  );
  const grep = { pattern: "^NAME:", path: stage.fixture, glob: null };
  assert.equal(
    runTool(stage.workspace, "Grep", { ...grep, case_insensitive: true }),
    skillFile,
  );
  assert.equal(
    runTool(stage.workspace, "Grep", {
      ...grep,
      case_insensitive: true,
      output_mode: "count",
    }),
    `${skillFile}:1`,
  );
  assert.equal(runTool(stage.workspace, "Grep", grep), "No matches found.");
  for (const [name, args] of [
    ["Glob", { pattern: "../**", path: null }],
    ["Grep", { pattern: "x", path: stage.auth, glob: null }],
    ["Skill", { skill: SKILL, args: stage.workspace }],
    [
      "Skill",
      { skill: "eval-review:kramme-skill-review", args: stage.fixture },
    ],
  ])
    assert.equal(
      toolAllowed(
        stage.workspace,
        String(name),
        /** @type {Record<string, unknown>} */ (args),
        SKILL,
      ),
      false,
    );
  assert.equal(fs.existsSync(path.join(stage.workspace, "items")), false);
});

test("retries honor provider delay headers, else back off, and never wait over a minute", () => {
  assert.equal(retryDelay(0, new Headers({ "retry-after-ms": "5" })), 5);
  assert.equal(retryDelay(0, new Headers({ "retry-after": "3" })), 3000);
  assert.equal(retryDelay(1, new Headers({ "retry-after": "soon" })), 2000);
  assert.equal(retryDelay(0, null), 1000);
  assert.equal(retryDelay(0, new Headers({ "retry-after": "3600" })), 60000);
});

test("glob patterns match the workspace-relative path", () => {
  const markdown = globPattern("**/*.md");
  assert.ok(markdown.test("SKILL.md") && markdown.test("references/a.md"));
  assert.ok(!markdown.test("SKILL.mdx"));
  assert.ok(globPattern("*.{md,yaml}").test("sources.yaml"));
  assert.ok(!globPattern("*.md").test("references/a.md"));
  assert.ok(globPattern("references/?.md").test("references/a.md"));
});

test("timeouts, turn limits, and failed responses never score partial output", async (t) => {
  const { context } = sandbox(t, "openai");
  const hanging = fakeOpenAI(
    (request) =>
      new Promise((_, reject) =>
        request.signal.addEventListener("abort", () =>
          reject(new DOMException("aborted", "AbortError")),
        ),
      ),
  );
  await assert.rejects(
    runSession(context, sessionConfig(attempt(), 20), {
      fetch: hanging.fetch,
    }),
    (error) => error instanceof EvalFailure && error.code === "attempt_timeout",
  );
  const looping = fakeOpenAI((request) =>
    completed([
      message("partial review"),
      functionCall("Glob", { pattern: "*", path: null }),
      ...(toolResults(request.body).length ? [] : [skillCall(request.body)]),
    ]),
  );
  const limited = attempt();
  await assert.rejects(
    runSession(context, sessionConfig(limited, 5000, 2), {
      fetch: looping.fetch,
    }),
    (error) =>
      error instanceof EvalFailure && error.code === "incomplete_result",
  );
  assert.equal(looping.requests.length, 2);
  assert.ok(
    limited.trace.some(
      (event) => event.event === "result" && event.detail === "error_max_turns",
    ),
  );
  const failed = fakeOpenAI(() =>
    jsonResponse(200, {
      status: "failed",
      model: "gpt-test-resolved",
      error: { code: "credit_balance_exhausted", message: "provider text" },
      output: [],
    }),
  );
  await assert.rejects(
    runSession(context, sessionConfig(attempt()), { fetch: failed.fetch }),
    (error) =>
      error instanceof EvalFailure && error.code === "insufficient_credits",
  );
  const incomplete = fakeOpenAI(() =>
    jsonResponse(200, {
      status: "incomplete",
      model: "gpt-test-resolved",
      incomplete_details: { reason: "max_output_tokens" },
      output: [message("truncated")],
    }),
  );
  await assert.rejects(
    runSession(context, sessionConfig(attempt()), {
      fetch: incomplete.fetch,
    }),
    (error) =>
      error instanceof EvalFailure && error.code === "incomplete_result",
  );
});
