// @ts-check
"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const test = require("node:test");
const {
  stageCheckpoint,
  trustedRun,
  restoreArchive,
  summary,
} = require("../../evals/skill-review/ci-checkpoint");
const { writeJson, readJson } = require("../../evals/skill-review/eval-state");
const {
  organizationsFromConfig,
  reconcilePool,
} = require("../../evals/skill-review/credit-pool");
const { PROVIDERS } = require("../../evals/skill-review/providers");
const { sandbox } = require("../test_helper/live-eval");

test("only completed runs of this workflow on the original main branch are trusted", () => {
  const run = {
    id: 1,
    status: "completed",
    head_branch: "main",
    event: "schedule",
    path: ".github/workflows/skill-review-live-eval.yml",
    head_repository: { full_name: "owner/repo" },
  };
  assert.equal(trustedRun(run, "owner/repo", 2), true);
  for (const changed of [
    { id: 2 },
    { head_branch: "feature" },
    { event: "pull_request" },
    { path: ".github/workflows/other.yml" },
    { head_repository: { full_name: "fork/repo" } },
    { status: "in_progress" },
  ])
    assert.equal(trustedRun({ ...run, ...changed }, "owner/repo", 2), false);
});

test("checkpoint export and zip restore include validated progress but no runtime/auth files", (t) => {
  const { root, env, config, run } = sandbox(t);
  const source = env.KRAMME_LIVE_EVAL_STATE;
  writeJson(
    path.join(source, "pool-state.json"),
    reconcilePool(
      organizationsFromConfig(readJson(config), env, PROVIDERS.anthropic),
      null,
    ),
  );
  fs.writeFileSync(path.join(source, "auth.json"), "secret auth");
  const destination = path.join(root, "export");
  assert.equal(stageCheckpoint(source, destination), true);
  assert.equal(fs.existsSync(path.join(destination, "auth.json")), false);
  assert.equal(fs.existsSync(path.join(destination, "writer.lock")), false);
  const archive = path.join(root, "state.zip");
  execFileSync("zip", ["-qr", archive, "."], { cwd: destination });
  const restored = path.join(root, "restored");
  restoreArchive(archive, restored);
  assert.deepEqual(
    readJson(path.join(restored, "runs", run.id, "run.json")),
    run,
  );
  assert.throws(() => restoreArchive(archive, restored), /overwrite/);
  writeJson(path.join(source, "runs", "finished", "run.json"), {
    ...run,
    id: "finished",
    status: "COMPLETE",
    completed: Object.fromEntries(
      run.case_ids.map((id) => [
        id,
        { text: "Review.", organization: "org-a", model: "claude-test" },
      ]),
    ),
  });
  // An unfinished run from older inputs can never resume, so it is not carried forward.
  writeJson(path.join(source, "runs", "superseded", "run.json"), {
    ...run,
    id: "superseded",
    fingerprint: "b".repeat(64),
    status: "PAUSED_NO_CREDITS",
    updated_at: 0,
  });
  const pruned = path.join(root, "pruned");
  assert.equal(stageCheckpoint(source, pruned), true);
  assert.equal(
    fs.existsSync(path.join(pruned, "runs", "finished", "run.json")),
    false,
  );
  assert.equal(
    fs.existsSync(path.join(pruned, "runs", "superseded", "run.json")),
    false,
  );
  assert.equal(fs.existsSync(path.join(pruned, "pool-state.json")), true);
  assert.equal(
    fs.existsSync(path.join(pruned, "runs", run.id, "run.json")),
    true,
  );
  fs.writeFileSync(path.join(destination, "unexpected.txt"), "never extract");
  const bad = path.join(root, "bad.zip");
  execFileSync("zip", ["-qr", bad, "."], { cwd: destination });
  assert.throws(
    () => restoreArchive(bad, path.join(root, "bad-restore")),
    /layout/,
  );
  assert.equal(fs.existsSync(path.join(root, "bad-restore")), false);
});

test("CI summary never labels credit pause as a passing evaluation", () => {
  const output = summary({
    provider: "openai",
    status: "PAUSED_NO_CREDITS",
    counts: { completed: 1, total: 7 },
    error: "secret",
  });
  assert.match(output, /^OpenAI skill-review eval: \*\*PAUSED_NO_CREDITS\*\*/);
  assert.match(output, /incomplete/);
  assert.match(output, /1\/7/);
  assert.ok(!output.includes("secret"));
  assert.match(
    summary({
      status: "COMPLETE",
      passed: false,
      counts: { completed: 7, total: 7 },
    }),
    /checks failed/,
  );
});

test("CI summary shows scores, organization switches, cost, pending work, and errors", () => {
  const complete = summary({
    provider: "anthropic",
    status: "COMPLETE",
    passed: true,
    counts: { completed: 2, total: 2 },
    aggregate: { hard: 1, soft: 0.75 },
    attempts: [
      { organization: "org-a" },
      { organization: "org-a" },
      { organization: "org-b" },
    ],
    estimated_cost_usd: 0.12345,
    pending: [],
  });
  assert.match(complete, /^Claude skill-review eval/);
  assert.match(complete, /hard 1, soft 0\.75/);
  assert.match(complete, /org-a → org-b\./);
  assert.match(complete, /\$0\.1235/);
  assert.ok(!complete.includes("Pending"));
  const paused = summary({
    status: "PAUSED_NO_CREDITS",
    counts: { completed: 1, total: 3 },
    aggregate: null,
    attempts: [],
    estimated_cost_usd: null,
    pending: ["case-2", "case-3"],
  });
  assert.ok(!paused.includes("Scores"));
  assert.match(paused, /Organizations used: none/);
  assert.match(paused, /Estimated cost: unknown/);
  assert.match(paused, /Pending cases: case-2, case-3\./);
  assert.match(
    summary({
      status: "ERROR",
      counts: { completed: 0, total: 3 },
      error: "prediction command failed:\n`org-a:runtime_error`",
    }),
    /Error: `prediction command failed: org-a:runtime_error`/,
  );
});
