// @ts-check
"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const {
  runLive,
  parseOptions,
} = require("../../evals/skill-review/run-live-eval");
const {
  readJson,
  writeJson,
  runFile,
  validateRun,
} = require("../../evals/skill-review/eval-state");
const { sandbox } = require("../test_helper/live-eval");

test("live entry point validates model, limits, flags, and dry run without creating state", (t) => {
  const { root, env, config } = sandbox(t);
  assert.throws(() => parseOptions([], {}), /explicit Claude model/);
  assert.throws(
    () => parseOptions(["--model", "claude-test", "--max-turns", "0"], {}),
    /positive/,
  );
  assert.throws(
    () => parseOptions(["--model", "claude-test", "--unknown"], {}),
    /Unknown/,
  );
  const options = parseOptions(
    [
      "--organizations",
      config,
      "--model",
      "claude-test",
      "--state-dir",
      path.join(root, "dry"),
      "--dry-run",
    ],
    {},
  );
  const result = runLive(options, { env });
  assert.equal(result.exitCode, 0);
  assert.equal(result.report.status, "DRY_RUN");
  assert.equal(fs.existsSync(options.stateDir), false);
});

test("each provider requires its own model ID and defaults to its own pool and state", () => {
  assert.throws(
    () => parseOptions(["--provider", "openai"], {}),
    /OPENAI_EVAL_MODEL to an explicit OpenAI model/,
  );
  assert.throws(
    () => parseOptions(["--provider", "openai", "--model", "claude-test"], {}),
    /OpenAI model/,
  );
  assert.throws(
    () => parseOptions(["--model", "gpt-test"], {}),
    /explicit Claude model/,
  );
  assert.throws(
    () => parseOptions(["--provider", "gemini", "--model", "x"], {}),
    /Unknown live eval provider/,
  );
  const openai = parseOptions(["--provider", "openai"], {
    OPENAI_EVAL_MODEL: "gpt-test",
    ANTHROPIC_EVAL_MODEL: "claude-test",
  });
  assert.equal(openai.provider.id, "openai");
  assert.equal(openai.model, "gpt-test");
  assert.match(openai.stateDir, /\.context[\\/]openai-evals$/);
  assert.match(openai.organizations, /openai-credit-pool\.example\.json$/);
  const claude = parseOptions([], { ANTHROPIC_EVAL_MODEL: "claude-test" });
  assert.equal(claude.provider.id, "anthropic");
  assert.match(claude.stateDir, /\.context[\\/]claude-evals$/);
});

test("an OpenAI run scores through the same harness and never resumes as another provider's run", (t) => {
  const { root, env, config } = sandbox(t, "openai");
  const adapter = path.join(root, "fake-openai-adapter.js");
  const implementation = path.resolve(
    __dirname,
    "../../evals/skill-review/openai-predict.js",
  );
  const helper = path.resolve(__dirname, "../test_helper/live-eval.js");
  fs.writeFileSync(
    adapter,
    `
const fs = require('node:fs');
const { predict } = require(${JSON.stringify(implementation)});
const { fakeOpenAI, reviewer } = require(${JSON.stringify(helper)});
const context = JSON.parse(fs.readFileSync(0, 'utf8'));
if ('fixture_review_output' in context.item || 'expected_findings' in context.item) process.exit(3);
const { fetch } = fakeOpenAI(reviewer(context.item.id === 'train-good-skill'
  ? 'No findings found. Focused and composable: Pass. Progressively disclosed: Pass.'
  : 'Major: Frontmatter is missing, including disable model invocation. Self describing boundaries: Fail.'));
predict(context, process.env, { fetch }).then(text => process.stdout.write(text), () => {process.exitCode=1});
`,
  );
  const stateDir = path.join(root, "shared-state");
  const options = parseOptions(
    [
      "--provider",
      "openai",
      "--organizations",
      config,
      "--model",
      "gpt-test",
      "--split",
      "train",
      "--state-dir",
      stateDir,
    ],
    {},
  );
  const result = runLive(options, {
    env,
    adapterCommand: `exec '${process.execPath}' '${adapter}'`,
  });
  assert.equal(result.exitCode, 0);
  assert.ok("provider" in result.report && "aggregate" in result.report);
  if (!("aggregate" in result.report)) return;
  assert.equal(result.report.provider, "openai");
  assert.equal(result.report.sdk_version, "openai-responses-1");
  assert.equal(result.report.aggregate?.hard, 1);
  assert.ok(
    result.report.items.every((item) => item.model === "gpt-test-resolved"),
  );
  assert.ok(
    result.report.limitations.some((line) => line.includes("Codex host")),
  );
  const runId = result.report.run_id;
  // The provider is part of the run identity, even with a shared state directory.
  const claudeConfig = path.join(root, "claude-organizations.json");
  writeJson(claudeConfig, [
    { alias: "org-a", key_env: "ANTHROPIC_EVAL_KEY_A" },
  ]);
  assert.throws(
    () =>
      runLive(
        {
          ...parseOptions(
            [
              "--organizations",
              claudeConfig,
              "--model",
              "claude-test",
              "--split",
              "train",
              "--state-dir",
              stateDir,
            ],
            {},
          ),
          runId,
        },
        { env: { ...env, ANTHROPIC_EVAL_KEY_A: "sk-ant-test-key-A" } },
      ),
    /different inputs/,
  );
});

test("the existing stdin/stdout harness scores real adapter output, resumes, and starts fresh sweeps", (t) => {
  const { root, env, config } = sandbox(t);
  const adapter = path.join(root, "fake-sdk-adapter.js");
  const implementation = path.resolve(
    __dirname,
    "../../evals/skill-review/claude-predict.js",
  );
  const helper = path.resolve(__dirname, "../test_helper/live-eval.js");
  fs.writeFileSync(
    adapter,
    `
const fs = require('node:fs');
const { predict } = require(${JSON.stringify(implementation)});
const { init, invokeSkill } = require(${JSON.stringify(helper)});
const context = JSON.parse(fs.readFileSync(0, 'utf8'));
if ('fixture_review_output' in context.item || 'expected_findings' in context.item) process.exit(3);
const query = ({options}) => Object.assign((async function* () {
  yield init(options);
  await invokeSkill(options);
  const result = context.item.id === 'train-good-skill'
    ? 'No findings found. Focused and composable: Pass. Progressively disclosed: Pass.'
    : 'Major: Frontmatter is missing, including disable model invocation. Self describing boundaries: Fail.';
  yield {type:'result', subtype:'success', is_error:false, result};
})(), {close(){}});
predict(context, process.env, {query}).then(text => process.stdout.write(text), () => {process.exitCode=1});
`,
  );
  const options = parseOptions(
    [
      "--organizations",
      config,
      "--model",
      "claude-test",
      "--split",
      "train",
      "--state-dir",
      path.join(root, "live"),
    ],
    {},
  );
  const dependencies = {
    env,
    adapterCommand: `exec '${process.execPath}' '${adapter}'`,
  };
  const first = runLive(options, dependencies);
  assert.equal(first.exitCode, 0);
  assert.equal(first.report.status, "COMPLETE");
  assert.ok("aggregate" in first.report);
  if (!("aggregate" in first.report)) return;
  assert.equal(first.report.aggregate?.hard, 1);
  const id = first.report.run_id;
  const before = validateRun(readJson(runFile(options.stateDir, id))).attempts
    .length;
  const replay = runLive({ ...options, runId: id }, dependencies);
  assert.equal(replay.exitCode, 0);
  assert.equal(
    validateRun(readJson(runFile(options.stateDir, id))).attempts.length,
    before,
  );
  const fresh = runLive(options, dependencies);
  assert.ok("run_id" in fresh.report && fresh.report.run_id !== id);
  const original = fs.readFileSync(adapter, "utf8");
  fs.writeFileSync(
    adapter,
    original.replace(
      "No findings found. Focused and composable: Pass. Progressively disclosed: Pass.",
      "Incomplete review",
    ),
  );
  const failed = runLive(options, dependencies);
  assert.equal(failed.report.status, "COMPLETE");
  assert.equal(failed.exitCode, 1);
  // Changed inputs can never reuse an explicitly selected old run.
  assert.throws(
    () =>
      runLive({ ...options, model: "claude-other", runId: id }, dependencies),
    /different inputs/,
  );
});

test("all-empty subprocess leaves a pause with no aggregate and resumes the same unfinished run", (t) => {
  const { root, env, config } = sandbox(t);
  const adapter = path.join(root, "empty-sdk-adapter.js");
  const implementation = path.resolve(
    __dirname,
    "../../evals/skill-review/claude-predict.js",
  );
  fs.writeFileSync(
    adapter,
    `
const fs = require('node:fs');
const { predict } = require(${JSON.stringify(implementation)});
const query = () => Object.assign((async function* () {
  yield {type:'assistant', error:'billing_error', message:{content:[{type:'text', text:'Credit balance too low · Add funds: https://platform.claude.com/settings/billing'}]}};
})(), {close(){}});
predict(JSON.parse(fs.readFileSync(0,'utf8')),process.env,{query}).catch(()=>{process.exitCode=1});
`,
  );
  const options = parseOptions(
    [
      "--organizations",
      config,
      "--model",
      "claude-test",
      "--split",
      "train",
      "--state-dir",
      path.join(root, "empty"),
    ],
    {},
  );
  const deps = {
    env,
    adapterCommand: `exec '${process.execPath}' '${adapter}'`,
  };
  const first = runLive(options, deps);
  assert.equal(first.exitCode, 2);
  assert.equal(first.report.status, "PAUSED_NO_CREDITS");
  assert.ok("aggregate" in first.report && first.report.aggregate === null);
  if (!("run_id" in first.report)) return;
  // Stray entries and run directories renamed aside never block resumption.
  const runs = path.join(options.stateDir, "runs");
  fs.writeFileSync(path.join(runs, ".DS_Store"), "");
  fs.cpSync(
    path.join(runs, first.report.run_id),
    path.join(runs, `${first.report.run_id}.broken`),
    { recursive: true },
  );
  const second = runLive(options, deps);
  assert.equal(second.exitCode, 2);
  if (!("run_id" in first.report) || !("run_id" in second.report)) return;
  assert.equal(second.report.run_id, first.report.run_id);
  assert.equal(
    validateRun(readJson(runFile(options.stateDir, first.report.run_id)))
      .attempts.length,
    2,
  );
  // Corrupt existing pool state must not be treated as a fresh balance.
  writeJson(path.join(options.stateDir, "pool-state.json"), { broken: true });
  assert.throws(() => runLive(options, deps), /Invalid pool checkpoint/);
});

test("runner failures keep a redacted diagnostic in the error report", (t) => {
  const { root, env, config } = sandbox(t);
  const options = parseOptions(
    [
      "--organizations",
      config,
      "--model",
      "claude-test",
      "--split",
      "train",
      "--state-dir",
      path.join(root, "failed"),
    ],
    {},
  );
  const result = runLive(options, {
    env,
    adapterCommand:
      "echo 'Live prediction failed: org-a:runtime_error sk-ant-test-key-A' >&2; exit 1",
  });
  assert.equal(result.exitCode, 1);
  assert.equal(result.report.status, "ERROR");
  assert.ok("error" in result.report);
  assert.match(String(result.report.error), /org-a:runtime_error/);
  assert.ok(!String(result.report.error).includes("sk-ant-test-key-A"));
});
