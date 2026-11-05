// @ts-check
"use strict";

const crypto = require("node:crypto");

/** @typedef {import('./live-types').Organization} Organization */
/** @typedef {import('./live-types').PoolState} PoolState */
/** @typedef {import('./live-types').Provider} Provider */
const RECHECK_MS = 24 * 60 * 60 * 1000;
const ALIAS = /^[a-z][a-z0-9-]{0,63}$/;
const EMPTY_BALANCE =
  "Your credit balance is too low to access the Anthropic API. Please go to Plans & Billing to upgrade or purchase credits.";
// SDK 0.3.310 / Claude Code 2.1.310's synthetic billing-error message.
const EMPTY_BALANCE_DISPLAY =
  "Credit balance too low · Add funds: https://platform.claude.com/settings/billing";
const EMPTY_BALANCE_SDK = "Credit balance is too low";

/** @param {unknown} value @returns {Record<string, unknown>} */
function record(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return /** @type {Record<string, unknown>} */ (value);
}

/** @param {unknown} config @param {NodeJS.ProcessEnv} env @param {Provider} provider @returns {Organization[]} */
function organizationsFromConfig(config, env, provider) {
  if (!Array.isArray(config) || !config.length)
    throw new Error("Configure at least one organization.");
  /** @type {Record<string, unknown>} */
  let keys = {};
  const bundle = env[provider.keysJsonEnv];
  if (bundle) {
    try {
      keys = record(JSON.parse(bundle));
    } catch {
      throw new Error(`${provider.keysJsonEnv} must be a JSON object.`);
    }
    if (!Object.keys(keys).length)
      throw new Error(
        `${provider.keysJsonEnv} must be a nonempty JSON object.`,
      );
  }
  const keyEnvName = new RegExp(`^${provider.keyPrefix}[A-Z0-9_]+$`);
  const aliases = new Set();
  const credentials = new Set();
  return config.map((value) => {
    const entry = record(value);
    const { alias, key_env: keyEnv } = entry;
    if (typeof alias !== "string" || !ALIAS.test(alias) || aliases.has(alias))
      throw new Error("Organization aliases must be unique lowercase names.");
    if (typeof keyEnv !== "string" || !keyEnvName.test(keyEnv))
      throw new Error(
        `Each organization needs an ${provider.keyPrefix}* variable name.`,
      );
    if (Object.keys(entry).some((name) => !["alias", "key_env"].includes(name)))
      throw new Error("Organization entries accept only alias and key_env.");
    const key = env[keyEnv] || keys[keyEnv];
    if (typeof key !== "string" || !key.trim() || key.trim() !== key)
      throw new Error(`Missing or invalid credential for ${alias}.`);
    if (credentials.has(key))
      throw new Error("Each organization must have a distinct API key.");
    aliases.add(alias);
    credentials.add(key);
    return {
      alias,
      key,
      fingerprint: crypto.createHash("sha256").update(key).digest("hex"),
    };
  });
}

/** @param {Organization[]} organizations @param {PoolState | null} previous @returns {PoolState} */
function reconcilePool(organizations, previous) {
  const entries = Object.fromEntries(
    organizations.map((org) => {
      const old = previous?.organizations[org.alias];
      return [
        org.alias,
        old?.fingerprint === org.fingerprint
          ? old
          : {
              fingerprint: org.fingerprint,
              exhausted_at: null,
              recheck_after: null,
            },
      ];
    }),
  );
  return {
    schema_version: 1,
    active: organizations.some((org) => org.alias === previous?.active)
      ? previous?.active || null
      : null,
    organizations: entries,
  };
}

/** @param {Organization[]} organizations @param {PoolState} pool @param {number} now @returns {Organization | undefined} */
function selectOrganization(organizations, pool, now) {
  // Configured order is consumption order: a due recheck never preempts an earlier usable key.
  return organizations.find((org) => {
    const entry = pool.organizations[org.alias];
    return (
      entry.exhausted_at === null ||
      (entry.recheck_after !== null && entry.recheck_after <= now)
    );
  });
}

/** @param {PoolState} pool @param {string} alias @param {number} now */
function markExhausted(pool, alias, now) {
  Object.assign(pool.organizations[alias], {
    exhausted_at: now,
    recheck_after: now + RECHECK_MS,
  });
  if (pool.active === alias) pool.active = null;
}

/** @param {PoolState} pool @param {string} alias */
function markAvailable(pool, alias) {
  Object.assign(pool.organizations[alias], {
    exhausted_at: null,
    recheck_after: null,
  });
  pool.active = alias;
}

/** Only call for an SDK-generated assistant event with its outer error field set.
 * @param {string} kind @param {string} text @param {unknown} [status] */
function classifyAssistantError(kind, text, status) {
  if (
    ["billing_error", "invalid_request"].includes(kind) &&
    ([EMPTY_BALANCE, EMPTY_BALANCE_DISPLAY].includes(text.trim()) ||
      (text.trim() === EMPTY_BALANCE_SDK && status === 400))
  )
    return "insufficient_credits";
  if (["rate_limit", "overloaded", "server_error"].includes(kind))
    return "retry_exhausted";
  return "runtime_error";
}

/** Typed API exceptions can carry the original structured API error.
 * Never infer depletion from status alone or arbitrary model text.
 * @param {unknown} value */
function classifyApiError(value) {
  const error = record(value);
  const payload = record(error.error);
  const detail = record(payload.error || payload);
  if (
    [400, 402].includes(Number(error.status)) &&
    ["invalid_request_error", "billing_error"].includes(String(detail.type)) &&
    detail.message === EMPTY_BALANCE
  )
    return "insufficient_credits";
  return "runtime_error";
}

/** OpenAI documents a distinct `error.code` for each billing condition; only an
 * exhausted prepaid balance rotates. The broader `insufficient_quota` type or
 * legacy code cannot tell credits from limits, so it stops for diagnosis.
 * @param {number | null} status HTTP status, or null for an in-band failed response
 * @param {unknown} code @param {unknown} type */
function classifyOpenAIError(status, code, type) {
  if (
    code === "credit_balance_exhausted" &&
    (status === 429 || status === null)
  )
    return "insufficient_credits";
  if (
    code === "organization_spend_limit_exceeded" ||
    code === "project_spend_limit_exceeded"
  )
    return "spend_limit";
  if (code === "organization_usage_limit_exceeded") return "usage_limit";
  if (code === "insufficient_quota" || type === "insufficient_quota")
    return "billing_error";
  if (status === 401) return "authentication_failed";
  if (status === 403) return "permission_denied";
  if (
    status === 408 ||
    status === 409 ||
    status === 429 ||
    (status !== null && status >= 500)
  )
    return "retryable";
  return "runtime_error";
}

/** @param {string} value @param {Organization[]} organizations */
function redact(value, organizations) {
  let result = value;
  for (const org of organizations)
    result = result.split(org.key).join("[REDACTED]");
  return result.replace(
    /sk-(?:ant|proj|svcacct|admin)-[A-Za-z0-9_-]+|sk-[A-Za-z0-9]{32,}/g,
    "[REDACTED]",
  );
}

module.exports = {
  organizationsFromConfig,
  reconcilePool,
  selectOrganization,
  markExhausted,
  markAvailable,
  classifyAssistantError,
  classifyApiError,
  classifyOpenAIError,
  redact,
  record,
};
