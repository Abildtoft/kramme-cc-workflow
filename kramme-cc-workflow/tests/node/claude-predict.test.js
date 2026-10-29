// @ts-check
"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const {
  predict,
  runSession,
  stageCase,
  toolAllowed,
  childEnvironment,
  EvalFailure,
  SKILL,
} = require("../../evals/skill-review/claude-predict");
const {
  readJson,
  validateRun,
  runFile,
} = require("../../evals/skill-review/eval-state");
const { sandbox, init, invokeSkill } = require("../test_helper/live-eval");

test("A exhausts mid-case, the partial response is discarded, and B supplies a saved review", async (t) => {
  const { env, context } = sandbox(t);
  /** @type {string[]} */ const called = [];
  let closed = 0;
  /** @type {import('../../evals/skill-review/claude-predict').QueryFunction} */
  const query = ({ options }) =>
    Object.assign(
      (async function* () {
        const key = options.env?.ANTHROPIC_API_KEY || "";
        called.push(key);
        assert.equal(options.env?.ANTHROPIC_EVAL_KEY_B, undefined);
        assert.equal(options.env?.GH_TOKEN, undefined);
        assert.deepEqual(options.settingSources, []);
        yield init(options);
        await invokeSkill(options);
        if (key === env.ANTHROPIC_EVAL_KEY_A) {
          yield {
            type: "assistant",
            message: {
              content: [{ type: "text", text: "discard this partial review" }],
            },
          };
          yield {
            type: "assistant",
            error: "billing_error",
            api_error_status: 400,
            message: {
              content: [
                {
                  type: "text",
                  text: "Credit balance is too low",
                },
              ],
            },
          };
          yield {
            type: "result",
            subtype: "success",
            is_error: true,
            total_cost_usd: 0.01,
            result: "discard me",
          };
          // The real SDK emits its error result and then rejects the iterator.
          throw new Error(
            "Claude Code returned an error result: Credit balance is too low",
          );
        } else
          yield {
            type: "result",
            subtype: "success",
            is_error: false,
            total_cost_usd: 0.02,
            result: "No findings found.",
          };
      })(),
      {
        close() {
          closed++;
        },
      },
    );
  assert.equal(await predict(context, env, { query }), "No findings found.");
  assert.deepEqual(called, [
    env.ANTHROPIC_EVAL_KEY_A,
    env.ANTHROPIC_EVAL_KEY_B,
  ]);
  assert.equal(closed, 2);
  const run = validateRun(
    readJson(runFile(env.KRAMME_LIVE_EVAL_STATE, "test-run")),
  );
  assert.deepEqual(
    run.attempts.map((a) => a.outcome),
    ["insufficient_credits", "COMPLETE"],
  );
  assert.deepEqual(
    run.attempts.map((a) => a.cost_usd),
    [0.01, 0.02],
  );
  assert.equal(run.completed["case-1"].organization, "org-b");
  assert.ok(!JSON.stringify(run).includes("discard"));
  // A checkpoint replay does not spend again; the next case stays on B.
  assert.equal(await predict(context, env, { query }), "No findings found.");
  await predict({ ...context, item: { ...context.item, id: "case-2" } }, env, {
    query,
  });
  assert.deepEqual(called, [
    env.ANTHROPIC_EVAL_KEY_A,
    env.ANTHROPIC_EVAL_KEY_B,
    env.ANTHROPIC_EVAL_KEY_B,
  ]);
});

test("all empty organizations pause; a due organization recovers without a calendar reset", async (t) => {
  const { env, context } = sandbox(t);
  let time = 1000;
  let refreshed = false;
  /** @type {import('../../evals/skill-review/claude-predict').QueryFunction} */
  const query = ({ options }) =>
    Object.assign(
      (async function* () {
        yield init(options);
        if (!refreshed)
          yield {
            type: "assistant",
            error: "invalid_request",
            message: {
              content: [
                {
                  type: "text",
                  text: "Your credit balance is too low to access the Anthropic API. Please go to Plans & Billing to upgrade or purchase credits.",
                },
              ],
            },
          };
        else {
          await invokeSkill(options);
          yield {
            type: "result",
            subtype: "success",
            result: "Refreshed review",
          };
        }
      })(),
      { close() {} },
    );
  await assert.rejects(
    predict(context, env, { query, now: () => time }),
    /no_credits/,
  );
  assert.equal(
    validateRun(readJson(runFile(env.KRAMME_LIVE_EVAL_STATE, "test-run")))
      .status,
    "PAUSED_NO_CREDITS",
  );
  await assert.rejects(
    predict(context, env, {
      query: () => {
        throw new Error("must not probe early");
      },
      now: () => time + 1,
    }),
    /no_credits/,
  );
  time += 86400000;
  refreshed = true;
  assert.equal(
    await predict(context, env, { query, now: () => time }),
    "Refreshed review",
  );
});

test("rate limits, malformed billing errors, and uninvoked reviews never rotate or score", async (t) => {
  const { env, context } = sandbox(t);
  for (const error of [
    "rate_limit",
    "billing_error",
    "authentication_failed",
  ]) {
    let attempts = 0;
    /** @type {import('../../evals/skill-review/claude-predict').QueryFunction} */
    const query = ({ options }) =>
      Object.assign(
        (async function* () {
          attempts++;
          yield init(options);
          yield {
            type: "assistant",
            error,
            message: {
              content: [{ type: "text", text: "unrecognized error" }],
            },
          };
        })(),
        { close() {} },
      );
    await assert.rejects(predict(context, env, { query }), /org-a:/);
    assert.equal(attempts, 1);
    assert.deepEqual(
      validateRun(readJson(runFile(env.KRAMME_LIVE_EVAL_STATE, "test-run")))
        .completed,
      {},
    );
  }
  /** @type {import('../../evals/skill-review/claude-predict').QueryFunction} */
  const uninvoked = ({ options }) =>
    Object.assign(
      (async function* () {
        yield init(options);
        yield { type: "result", subtype: "success", result: "Made-up review" };
      })(),
      { close() {} },
    );
  await assert.rejects(
    predict(context, env, { query: uninvoked }),
    /missing_review_evidence/,
  );
});

test("staged input and tool boundaries exclude the answer key, runtime auth, and symlink escapes", (t) => {
  const { context } = sandbox(t);
  const stage = stageCase(context);
  t.after(() => fs.rmSync(stage.temporary, { recursive: true, force: true }));
  const read = path.join(stage.fixture, "SKILL.md");
  assert.equal(
    toolAllowed(stage.workspace, "Read", { file_path: read }, SKILL),
    true,
  );
  assert.equal(
    toolAllowed(stage.workspace, "Grep", { pattern: "frontmatter" }, SKILL),
    true,
  );
  assert.equal(
    toolAllowed(stage.workspace, "Glob", { pattern: "**/*.md" }, SKILL),
    true,
  );
  assert.equal(
    toolAllowed(stage.workspace, "Glob", { pattern: "../**" }, SKILL),
    false,
  );
  assert.equal(
    toolAllowed(stage.workspace, "Read", { file_path: stage.auth }, SKILL),
    false,
  );
  assert.equal(
    toolAllowed(stage.workspace, "Read", { file_path: __filename }, SKILL),
    false,
  );
  assert.equal(
    toolAllowed(stage.workspace, "Bash", { command: "env" }, SKILL),
    false,
  );
  for (const name of ["Write", "Edit", "Agent", "WebFetch", "mcp__anything"])
    assert.equal(toolAllowed(stage.workspace, name, {}, SKILL), false);
  assert.equal(
    toolAllowed(
      stage.workspace,
      "Skill",
      {
        skill: SKILL,
        args: stage.fixture,
      },
      SKILL,
    ),
    true,
  );
  assert.equal(
    toolAllowed(
      stage.workspace,
      "Skill",
      {
        skill: "other",
        args: stage.fixture,
      },
      SKILL,
    ),
    false,
  );
  fs.symlinkSync(__filename, path.join(stage.workspace, "escape"));
  assert.equal(
    toolAllowed(
      stage.workspace,
      "Read",
      {
        file_path: path.join(stage.workspace, "escape"),
      },
      SKILL,
    ),
    false,
  );
  assert.equal(fs.existsSync(path.join(stage.workspace, "items")), false);
  const env = childEnvironment("selected-key", stage.auth, {
    PATH: "/bin",
    GH_TOKEN: "secret",
    ANTHROPIC_AUTH_TOKEN: "oauth",
    ANTHROPIC_EVAL_KEY_A: "other",
    NODE_OPTIONS: "untrusted",
  });
  assert.equal(env.ANTHROPIC_API_KEY, "selected-key");
  assert.ok(
    !Object.values(env).includes("secret") &&
      !Object.values(env).includes("oauth") &&
      !Object.values(env).includes("other") &&
      !Object.values(env).includes("untrusted"),
  );
});

test("timeout aborts and closes the SDK session without accepting a partial result", async (t) => {
  const { context } = sandbox(t);
  let closed = false;
  /** @type {import('../../evals/skill-review/live-types').Attempt} */
  const attempt = {
    case_id: "case-1",
    organization: "org-a",
    started_at: 0,
    outcome: "RUNNING",
    model: null,
    cost_usd: null,
    trace: [],
  };
  /** @type {import('../../evals/skill-review/claude-predict').QueryFunction} */
  const query = ({ options }) =>
    Object.assign(
      (async function* () {
        yield init(options);
        await new Promise((resolve) =>
          options.abortController?.signal.addEventListener("abort", resolve, {
            once: true,
          }),
        );
      })(),
      {
        close() {
          closed = true;
        },
      },
    );
  await assert.rejects(
    runSession(
      context,
      {
        key: "test-key",
        model: "claude-test-1",
        timeout: 20,
        maxTurns: 12,
        attempt,
        signal: new AbortController().signal,
      },
      { query },
    ),
    (error) => error instanceof EvalFailure && error.code === "attempt_timeout",
  );
  assert.equal(closed, true);
});

test("model-authored billing text is a prediction; actual response model and run deadlines are preserved", async (t) => {
  const { env, context } = sandbox(t);
  let calls = 0;
  /** @type {import('../../evals/skill-review/claude-predict').QueryFunction} */
  const query = ({ options }) =>
    Object.assign(
      (async function* () {
        calls++;
        yield init(options);
        await invokeSkill(options);
        yield {
          type: "assistant",
          message: {
            model: "claude-test-resolved",
            content: [{ type: "text", text: "Credit balance is too low" }],
          },
        };
        yield {
          type: "result",
          subtype: "success",
          is_error: false,
          result: "Credit balance is too low",
        };
      })(),
      { close() {} },
    );
  assert.equal(
    await predict(context, env, { query }),
    "Credit balance is too low",
  );
  const saved = validateRun(
    readJson(runFile(env.KRAMME_LIVE_EVAL_STATE, "test-run")),
  );
  assert.equal(saved.completed["case-1"].model, "claude-test-resolved");
  assert.equal(calls, 1);
  await assert.rejects(
    predict(
      { ...context, item: { ...context.item, id: "case-2" } },
      { ...env, KRAMME_LIVE_EVAL_DEADLINE: "999" },
      { query, now: () => 1000 },
    ),
    /case_timeout/,
  );
  assert.equal(calls, 1);
});
