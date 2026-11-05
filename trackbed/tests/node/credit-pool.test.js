// @ts-check
"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  organizationsFromConfig,
  reconcilePool,
  selectOrganization,
  markExhausted,
  markAvailable,
  classifyApiError,
  classifyAssistantError,
  classifyOpenAIError,
  redact,
} = require("../../evals/skill-review/credit-pool");
const { PROVIDERS } = require("../../evals/skill-review/providers");

const anthropic = PROVIDERS.anthropic;

const config = [
  { alias: "org-a", key_env: "ANTHROPIC_EVAL_KEY_A" },
  { alias: "org-b", key_env: "ANTHROPIC_EVAL_KEY_B" },
];
const keys = {
  ANTHROPIC_EVAL_KEY_A: "sk-ant-unit-a",
  ANTHROPIC_EVAL_KEY_B: "sk-ant-unit-b",
};

test("pool consumes A before B, remains on B, and rechecks A after 24 hours", () => {
  const orgs = organizationsFromConfig(config, keys, anthropic);
  const pool = reconcilePool(orgs, null);
  assert.equal(selectOrganization(orgs, pool, 100)?.alias, "org-a");
  markExhausted(pool, "org-a", 100);
  assert.equal(selectOrganization(orgs, pool, 101)?.alias, "org-b");
  markAvailable(pool, "org-b");
  assert.equal(selectOrganization(orgs, pool, 102)?.alias, "org-b");
  assert.equal(selectOrganization(orgs, pool, 86400100)?.alias, "org-a");
  markExhausted(pool, "org-a", 86400100);
  markExhausted(pool, "org-b", 86400101);
  assert.equal(selectOrganization(orgs, pool, 86400102), undefined);
  assert.equal(selectOrganization(orgs, pool, 172800100)?.alias, "org-a");
  markAvailable(pool, "org-a");
  assert.equal(pool.organizations["org-a"].recheck_after, null);
  // B's later recheck must not take over while A still has credits.
  assert.equal(selectOrganization(orgs, pool, 172800102)?.alias, "org-a");
});

test("reconciliation resets only changed credentials and removes deleted organizations", () => {
  const orgs = organizationsFromConfig(config, keys, anthropic);
  const previous = reconcilePool(orgs, null);
  markExhausted(previous, "org-a", 10);
  markExhausted(previous, "org-b", 10);
  const replaced = organizationsFromConfig(
    config,
    { ...keys, ANTHROPIC_EVAL_KEY_A: "replacement-key" },
    anthropic,
  );
  const next = reconcilePool(replaced, previous);
  assert.equal(next.organizations["org-a"].exhausted_at, null);
  assert.equal(next.organizations["org-b"].exhausted_at, 10);
  assert.deepEqual(
    Object.keys(reconcilePool(replaced.slice(0, 1), next).organizations),
    ["org-a"],
  );
  assert.ok(!JSON.stringify(next).includes("replacement-key"));
});

test("configuration accepts the CI key bundle and rejects invalid or repeated credentials", () => {
  assert.equal(
    organizationsFromConfig(
      config,
      { ANTHROPIC_EVAL_KEYS_JSON: JSON.stringify(keys) },
      anthropic,
    ).length,
    2,
  );
  for (const invalid of [
    [],
    null,
    [{ alias: "bad alias", key_env: "ANTHROPIC_EVAL_KEY_A" }],
    [config[0], config[0]],
    [{ ...config[0], key: "never-here" }],
    [{ alias: "org-a", key_env: "HOME" }],
  ])
    assert.throws(() => organizationsFromConfig(invalid, keys, anthropic));
  assert.throws(
    () => organizationsFromConfig(config, {}, anthropic),
    /Missing/,
  );
  assert.throws(
    () =>
      organizationsFromConfig(
        config,
        { ANTHROPIC_EVAL_KEY_A: "same", ANTHROPIC_EVAL_KEY_B: "same" },
        anthropic,
      ),
    /distinct/,
  );
  assert.throws(
    () =>
      organizationsFromConfig(
        config,
        { ANTHROPIC_EVAL_KEYS_JSON: "secret-invalid-json" },
        anthropic,
      ),
    /JSON object/,
  );
  assert.throws(
    () =>
      organizationsFromConfig(
        config,
        { ANTHROPIC_EVAL_KEYS_JSON: "[]" },
        anthropic,
      ),
    /JSON object/,
  );
});

test("only recognized credit depletion payloads cause rotation", () => {
  const message =
    "Your credit balance is too low to access the Anthropic API. Please go to Plans & Billing to upgrade or purchase credits.";
  assert.equal(
    classifyApiError({
      status: 400,
      error: {
        type: "error",
        error: { type: "invalid_request_error", message },
      },
    }),
    "insufficient_credits",
  );
  assert.equal(
    classifyApiError({
      status: 402,
      error: { type: "billing_error", message },
    }),
    "insufficient_credits",
  );
  for (const value of [
    { status: 400 },
    {
      status: 402,
      error: { type: "billing_error", message: "Invalid payment details" },
    },
    { status: 429, error: { type: "rate_limit_error", message } },
    new Error(message),
    {
      status: 400,
      error: {
        type: "invalid_request_error",
        message: "You have reached your specified API usage limits",
      },
    },
  ])
    assert.equal(classifyApiError(value), "runtime_error");
  assert.equal(
    classifyAssistantError(
      "billing_error",
      "Credit balance too low · Add funds: https://platform.claude.com/settings/billing",
    ),
    "insufficient_credits",
  );
  assert.equal(
    classifyAssistantError("invalid_request", message),
    "insufficient_credits",
  );
  assert.equal(
    classifyAssistantError("billing_error", "Some other billing error"),
    "runtime_error",
  );
  assert.equal(classifyAssistantError("unknown", message), "runtime_error");
  for (const kind of ["rate_limit", "overloaded", "server_error"])
    assert.equal(classifyAssistantError(kind, ""), "retry_exhausted");
});

test("redaction covers configured keys and unexpected Anthropic key strings", () => {
  assert.equal(
    redact(
      "sk-ant-unit-a sk-ant-accidental",
      organizationsFromConfig(config, keys, anthropic),
    ),
    "[REDACTED] [REDACTED]",
  );
});

test("the SDK's abbreviated billing text requires the observed 400 credit-error status", () => {
  assert.equal(
    classifyAssistantError("billing_error", "Credit balance is too low", 400),
    "insufficient_credits",
  );
  assert.equal(
    classifyAssistantError("billing_error", "Credit balance is too low", 402),
    "runtime_error",
  );
  assert.equal(
    classifyAssistantError("billing_error", "Credit balance is too low"),
    "runtime_error",
  );
});

test("OpenAI pools use only their own key variables", () => {
  const openai = PROVIDERS.openai;
  const openaiConfig = [
    { alias: "org-a", key_env: "OPENAI_EVAL_KEY_A" },
    { alias: "org-b", key_env: "OPENAI_EVAL_KEY_B" },
  ];
  const openaiKeys = {
    OPENAI_EVAL_KEY_A: "sk-proj-unit-a",
    OPENAI_EVAL_KEY_B: "sk-proj-unit-b",
  };
  assert.deepEqual(
    organizationsFromConfig(openaiConfig, openaiKeys, openai).map(
      (org) => org.alias,
    ),
    ["org-a", "org-b"],
  );
  assert.equal(
    organizationsFromConfig(
      openaiConfig,
      { OPENAI_EVAL_KEYS_JSON: JSON.stringify(openaiKeys) },
      openai,
    ).length,
    2,
  );
  // A configuration for one provider fails before any request to the other.
  assert.throws(
    () => organizationsFromConfig(config, { ...keys, ...openaiKeys }, openai),
    /OPENAI_EVAL_KEY_\*/,
  );
  assert.throws(
    () =>
      organizationsFromConfig(
        openaiConfig,
        { ...keys, ...openaiKeys },
        anthropic,
      ),
    /ANTHROPIC_EVAL_KEY_\*/,
  );
  assert.throws(
    () =>
      organizationsFromConfig(
        openaiConfig,
        { ANTHROPIC_EVAL_KEYS_JSON: JSON.stringify(openaiKeys) },
        openai,
      ),
    /Missing/,
  );
});

test("only OpenAI's exhausted-credit code rotates; limits, ambiguous quota, and auth errors stop", () => {
  assert.equal(
    classifyOpenAIError(429, "credit_balance_exhausted", "insufficient_quota"),
    "insufficient_credits",
  );
  assert.equal(
    classifyOpenAIError(null, "credit_balance_exhausted", undefined),
    "insufficient_credits",
  );
  assert.equal(
    classifyOpenAIError(400, "credit_balance_exhausted", undefined),
    "runtime_error",
  );
  for (const code of [
    "organization_spend_limit_exceeded",
    "project_spend_limit_exceeded",
  ])
    assert.equal(
      classifyOpenAIError(429, code, "insufficient_quota"),
      "spend_limit",
    );
  assert.equal(
    classifyOpenAIError(429, "organization_usage_limit_exceeded", undefined),
    "usage_limit",
  );
  // The broad type or legacy code cannot tell an empty balance from a limit.
  assert.equal(
    classifyOpenAIError(429, "insufficient_quota", "insufficient_quota"),
    "billing_error",
  );
  assert.equal(
    classifyOpenAIError(429, null, "insufficient_quota"),
    "billing_error",
  );
  for (const code of ["rate_limit_exceeded", "slow_down", undefined])
    assert.equal(
      classifyOpenAIError(429, code, "rate_limit_error"),
      "retryable",
    );
  assert.equal(classifyOpenAIError(503, undefined, undefined), "retryable");
  assert.equal(
    classifyOpenAIError(401, "invalid_api_key", "invalid_request_error"),
    "authentication_failed",
  );
  assert.equal(
    classifyOpenAIError(403, undefined, undefined),
    "permission_denied",
  );
  assert.equal(
    classifyOpenAIError(404, "model_not_found", "invalid_request_error"),
    "runtime_error",
  );
  assert.equal(
    classifyOpenAIError(null, "server_error", undefined),
    "runtime_error",
  );
});

test("redaction also covers OpenAI key formats", () => {
  assert.equal(
    redact(
      `sk-proj-abc_DEF-123 sk-svcacct-x1 sk-${"a".repeat(48)} sk-short`,
      [],
    ),
    "[REDACTED] [REDACTED] [REDACTED] sk-short",
  );
});
