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

/** @param {import('node:test').TestContext} t */
function sandbox(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "live-eval-test-"));
  let unlock = () => {};
  t.after(() => {
    unlock();
    fs.rmSync(root, { recursive: true, force: true });
  });
  const config = path.join(root, "organizations.json");
  writeJson(config, [
    { alias: "org-a", key_env: "ANTHROPIC_EVAL_KEY_A" },
    { alias: "org-b", key_env: "ANTHROPIC_EVAL_KEY_B" },
  ]);
  const env = {
    ...process.env,
    ANTHROPIC_EVAL_KEY_A: "sk-ant-test-key-A",
    ANTHROPIC_EVAL_KEY_B: "sk-ant-test-key-B",
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
    model: "claude-test-1",
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
    env: { ...env, KRAMME_LIVE_EVAL_OWNER_TOKEN: token },
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

module.exports = { sandbox, invokeSkill, init };
