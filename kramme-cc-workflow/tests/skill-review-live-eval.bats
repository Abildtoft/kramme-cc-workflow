#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  LIVE_ROOT="$REPO_ROOT/kramme-cc-workflow/evals/skill-review"
}

@test "live eval dry run exposes aliases and case IDs without credentials or state writes" {
  run env ANTHROPIC_EVAL_KEY_A=sk-ant-bats-key-a ANTHROPIC_EVAL_KEY_B=sk-ant-bats-key-b ANTHROPIC_EVAL_KEY_C=sk-ant-bats-key-c \
    node "$LIVE_ROOT/run-live-eval.js" --model claude-test --split train --state-dir "$BATS_TEST_TMPDIR/state" --dry-run
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r .status)" = DRY_RUN ]
  [ "$(printf '%s' "$output" | jq -r .provider)" = anthropic ]
  [ "$(printf '%s' "$output" | jq '.cases | length')" -eq 2 ]
  [[ "$output" != *sk-ant-bats* ]]
  [ ! -e "$BATS_TEST_TMPDIR/state" ]
}

@test "OpenAI dry run uses its own example pool and never prints keys" {
  run env OPENAI_EVAL_KEY_A=sk-proj-bats-key-a OPENAI_EVAL_KEY_B=sk-proj-bats-key-b OPENAI_EVAL_KEY_C=sk-proj-bats-key-c \
    node "$LIVE_ROOT/run-live-eval.js" --provider openai --model gpt-test --split train --state-dir "$BATS_TEST_TMPDIR/state" --dry-run
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r .provider)" = openai ]
  [ "$(printf '%s' "$output" | jq -c .organizations)" = '["org-a","org-b","org-c"]' ]
  [[ "$output" != *sk-proj-bats* ]]
  [ ! -e "$BATS_TEST_TMPDIR/state" ]
}

@test "live adapters report malformed stdin without echoing it" {
  for adapter in claude-predict.js openai-predict.js; do
    run bash -c 'printf "%s" "sk-ant-never-echo-this" | node "$1/$2"' _ "$LIVE_ROOT" "$adapter"
    [ "$status" -eq 1 ]
    [[ "$output" == *invalid_adapter_context* ]]
    [[ "$output" != *sk-ant-never-echo-this* ]]
  done
}

@test "live workflow uses a serialized trusted branch and explicit checkpoint uploads per provider" {
  run node - "$REPO_ROOT" <<'NODE'
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const YAML = require(path.join(process.argv[2], 'node_modules/yaml'));
const workflow = YAML.parse(fs.readFileSync(path.join(process.argv[2], '.github/workflows/skill-review-live-eval.yml'), 'utf8'));
assert.deepEqual(Object.keys(workflow.on).sort(), ['schedule', 'workflow_dispatch']);
assert.equal(workflow.concurrency['cancel-in-progress'], false);
assert.deepEqual(workflow.permissions, {contents: 'read', actions: 'read'});
const providers = {
  'claude-live-eval': {provider: 'anthropic', prefix: 'ANTHROPIC', artifact: 'claude-eval'},
  'openai-live-eval': {provider: 'openai', prefix: 'OPENAI', artifact: 'openai-eval'},
};
assert.deepEqual(Object.keys(workflow.jobs).sort(), Object.keys(providers).sort());
for (const [name, expected] of Object.entries(providers)) {
  const job = workflow.jobs[name];
  assert.ok(job.if.includes("github.ref == 'refs/heads/main'"));
  assert.ok(job.if.includes(`vars.${expected.prefix}_EVAL_MODEL != ''`));
  assert.ok(job.if.includes(`vars.${expected.prefix}_EVAL_ORGANIZATIONS != ''`));
  assert.equal(job.steps[0].with.ref, 'main');
  assert.equal(job.steps[0].with['persist-credentials'], false);
  const secretSteps = job.steps.filter(step => JSON.stringify(step.env || {}).includes('secrets.'));
  assert.equal(secretSteps.length, 1);
  assert.equal(secretSteps[0].id, 'eval');
  // Each job receives only its own provider's key bundle.
  assert.deepEqual(
    Object.entries(secretSteps[0].env).filter(([, value]) => value.includes('secrets.')),
    [[`${expected.prefix}_EVAL_KEYS_JSON`, `\${{ secrets.${expected.prefix}_EVAL_KEYS_JSON }}`]],
  );
  const run = secretSteps[0].run;
  assert.ok(run.includes(`--provider ${expected.provider}`));
  assert.ok(run.includes('"$result" -eq 2'));
  const scripts = job.steps.map(step => step.run || '').join('\n');
  assert.ok(scripts.includes(`ci-checkpoint.js restore ${expected.provider}`));
  assert.ok(scripts.includes(`ci-checkpoint.js stage ${expected.provider} `));
  const uploads = job.steps.filter(step => (step.uses || '').startsWith('actions/upload-artifact@'));
  assert.deepEqual(uploads.map(step => step.with.name), [`${expected.artifact}-checkpoint`, `${expected.artifact}-report`]);
  for (const step of uploads) {
    assert.equal(step.if, '${{ always() }}');
    assert.ok(!step.with.path.includes('.context'));
    assert.equal(step.with['retention-days'], 90);
  }
}
NODE
  [ "$status" -eq 0 ]
}
