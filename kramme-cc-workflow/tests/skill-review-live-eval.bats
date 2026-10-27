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
  [ "$(printf '%s' "$output" | jq '.cases | length')" -eq 2 ]
  [[ "$output" != *sk-ant-bats* ]]
  [ ! -e "$BATS_TEST_TMPDIR/state" ]
}

@test "live adapter reports malformed stdin without echoing it" {
  run bash -c 'printf "%s" "sk-ant-never-echo-this" | node "$1/claude-predict.js"' _ "$LIVE_ROOT"
  [ "$status" -eq 1 ]
  [[ "$output" == *invalid_adapter_context* ]]
  [[ "$output" != *sk-ant-never-echo-this* ]]
}

@test "live workflow uses a serialized trusted branch and explicit checkpoint uploads" {
  run node - "$REPO_ROOT" <<'NODE'
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const YAML = require(path.join(process.argv[2], 'node_modules/yaml'));
const workflow = YAML.parse(fs.readFileSync(path.join(process.argv[2], '.github/workflows/skill-review-live-eval.yml'), 'utf8'));
assert.deepEqual(Object.keys(workflow.on).sort(), ['schedule', 'workflow_dispatch']);
assert.equal(workflow.concurrency['cancel-in-progress'], false);
assert.deepEqual(workflow.permissions, {contents: 'read', actions: 'read'});
const job = workflow.jobs['live-eval'];
assert.ok(job.if.includes("github.ref == 'refs/heads/main'"));
assert.ok(job.if.includes("vars.ANTHROPIC_EVAL_MODEL != ''"));
assert.ok(job.if.includes("vars.ANTHROPIC_EVAL_ORGANIZATIONS != ''"));
assert.equal(job.steps[0].with.ref, 'main');
assert.equal(job.steps[0].with['persist-credentials'], false);
const secretSteps = job.steps.filter(step => JSON.stringify(step.env || {}).includes('secrets.'));
assert.equal(secretSteps.length, 1);
assert.equal(secretSteps[0].id, 'eval');
const uploads = job.steps.filter(step => (step.uses || '').startsWith('actions/upload-artifact@'));
assert.equal(uploads.length, 2);
for (const step of uploads) {
  assert.equal(step.if, '${{ always() }}');
  assert.ok(!step.with.path.includes('.context'));
  assert.equal(step.with['retention-days'], 90);
}
assert.ok(job.steps.find(step => step.id === 'eval').run.includes('"$result" -eq 2'));
NODE
  [ "$status" -eq 0 ]
}
