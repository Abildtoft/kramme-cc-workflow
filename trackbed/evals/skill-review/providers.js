// @ts-check
"use strict";

/** @typedef {import('./live-types').Provider} Provider */

/** Each provider has its own key pool, state, and artifacts; a run never falls back to another provider.
 * @type {Record<import('./live-types').ProviderId, Provider>} */
const PROVIDERS = {
  anthropic: {
    id: "anthropic",
    label: "Claude",
    keyPrefix: "ANTHROPIC_EVAL_KEY_",
    keysJsonEnv: "ANTHROPIC_EVAL_KEYS_JSON",
    modelEnv: "ANTHROPIC_EVAL_MODEL",
    model: /^claude-[a-z0-9.-]+$/,
    adapter: "claude-predict.js",
    exampleConfig: "credit-pool.example.json",
    stateDir: ".context/claude-evals",
    artifact: "claude-eval",
  },
  openai: {
    id: "openai",
    label: "OpenAI",
    keyPrefix: "OPENAI_EVAL_KEY_",
    keysJsonEnv: "OPENAI_EVAL_KEYS_JSON",
    modelEnv: "OPENAI_EVAL_MODEL",
    model: /^(gpt|o[0-9])[a-z0-9.-]*$/,
    adapter: "openai-predict.js",
    exampleConfig: "openai-credit-pool.example.json",
    stateDir: ".context/openai-evals",
    artifact: "openai-eval",
  },
};

/** @param {string} id @returns {Provider} */
function providerById(id) {
  if (id !== "anthropic" && id !== "openai")
    throw new Error("Unknown live eval provider. Use anthropic or openai.");
  return PROVIDERS[id];
}

module.exports = { PROVIDERS, providerById };
