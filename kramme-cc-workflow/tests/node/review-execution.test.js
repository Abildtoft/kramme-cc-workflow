"use strict";
const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync, spawnSync } = require("node:child_process");
const helper = path.resolve(
  __dirname,
  "../../skills/kramme:pr:code-review/scripts/review-execution.js",
);
const { jobsFor } = require(helper);

/** @param {import('node:test').TestContext} t @param {string[]} aspects @param {string[]} active */
function fixture(t, aspects = ["all"], active = []) {
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), "review-execution-test-"));
  t.after(() => fs.rmSync(temp, { recursive: true, force: true }));
  const root = path.join(temp, "repo");
  fs.mkdirSync(root);
  /** @param {...string} args */
  const git = (...args) =>
    execFileSync(
      "git",
      [
        "-C",
        root,
        "-c",
        "commit.gpgsign=false",
        "-c",
        "core.hooksPath=/dev/null",
        ...args,
      ],
      { stdio: "pipe", timeout: 10000 },
    )
      .toString()
      .trim();
  git("init", "-b", "main");
  git("config", "user.name", "Review Test");
  git("config", "user.email", "test@example.invalid");
  fs.writeFileSync(path.join(root, "source.txt"), "original\n");
  git("add", ".");
  git("commit", "-m", "Initial source");
  git("branch", "base");
  fs.writeFileSync(path.join(root, "source.txt"), "changed\n");
  /** @type {{aspects: string[], context: string, applicability: Record<string, {applicable: boolean, reason: string}>}} */
  const plan = {
    aspects,
    context: "base; source.txt changed; no PR metadata; no previous findings",
    applicability: {},
  };
  for (const dimension of [
    "tests",
    "comments",
    "types",
    "removal",
    "performance",
    "security",
  ]) {
    plan.applicability[dimension] = {
      applicable: active.includes(dimension),
      reason: `${dimension} inspected in source.txt`,
    };
  }
  const planFile = path.join(temp, "input.json");
  fs.writeFileSync(planFile, JSON.stringify(plan));
  const run = path.join(temp, "run");
  /** @param {string} action @param {...string} args */
  function command(action, ...args) {
    return spawnSync(process.execPath, [helper, action, run, ...args], {
      cwd: root,
      encoding: "utf8",
      timeout: 10000,
    });
  }
  /** @param {string} action @param {...string} args */
  function ok(action, ...args) {
    const result = command(action, ...args);
    assert.equal(result.status, 0, result.stderr);
    return result;
  }
  ok("init", "--plan", planFile, "--base", "base");
  const ledger = () =>
    JSON.parse(fs.readFileSync(path.join(run, "ledger.json"), "utf8"));
  /** @param {string} id */
  function finish(id, status = "succeeded") {
    const job = ledger().jobs[id];
    ok(
      "start",
      "--job",
      id,
      ...(job.agent === "orchestrator" ? [] : ["--agent-id", `host-${id}`]),
    );
    const output = path.join(temp, "result.txt");
    fs.writeFileSync(
      output,
      status === "succeeded"
        ? `Completed ${id}: zero findings after full inspection\n`
        : "Host timeout after attempted review\n",
    );
    ok("finish", "--job", id, "--status", status, "--output", output);
  }
  function complete() {
    for (const id of Object.keys(ledger().jobs)) finish(id);
  }
  const report = path.join(temp, "report.md");
  function draft() {
    const sections = [
      "Relevance Filter",
      "Previous Review Context",
      "Auto-resolution Readiness",
      "Coverage Status",
      "Critical Issues",
      "Important Issues",
      "Suggestions",
      "Slop Warnings",
      "Filtered (Pre-existing/Out-of-scope)",
      "Filtered (Previously Addressed)",
      "Strengths",
      "Approval Standard",
      "Recommended Action",
    ];
    fs.writeFileSync(
      report,
      `# PR Review Summary\nReview status: COMPLETE\nReview execution: ${run}\nReview run: ${ledger().runId}\n${sections.map((title) => `## ${title}\n(0 found)`).join("\n")}\n`,
    );
    return report;
  }
  return {
    temp,
    root,
    run,
    command,
    ok,
    ledger,
    finish,
    complete,
    draft,
    report,
    git,
  };
}

test("default inventory cannot omit always-on and cleanup reviewers; security is a bundle", () => {
  /** @type {{aspects: string[], applicability: Record<string, {applicable: boolean, reason: string}>}} */
  const plan = { aspects: ["all"], applicability: {} };
  assert.throws(() => jobsFor(plan), /applicability/);
  for (const dimension of [
    "tests",
    "comments",
    "types",
    "removal",
    "performance",
    "security",
  ])
    plan.applicability[dimension] = {
      applicable: dimension === "security",
      reason: "diff evidence",
    };
  const { jobs } = jobsFor(plan);
  for (const id of [
    "code-reviewer",
    "silent-failure-hunter",
    "deslop-reviewer",
    "lean-reviewer",
    "code-simplifier",
    "injection-reviewer",
    "auth-reviewer",
    "data-reviewer",
    "logic-reviewer",
    "relevance",
    "slop-meta",
  ])
    assert.ok(jobs[id]);
  assert.throws(() => jobsFor({ aspects: ["quick"] }), /Unknown/);
  assert.deepEqual(
    Object.keys(jobsFor({ aspects: ["refactor", "simplify"] }).jobs).filter(
      (id) => id === "code-simplifier",
    ),
    ["code-simplifier"],
  );
});

test("complete zero-findings run seals and independently rechecks", (t) => {
  const f = fixture(t);
  f.complete();
  f.draft();
  f.ok("seal", "--report", f.report);
  const receipt = JSON.parse(
    f.ok("check", "--report", f.report, "--aspects", "all").stdout,
  );
  assert.equal(receipt.evidence, "self-attested");
  assert.equal(receipt.status, "COMPLETE");
  assert.notEqual(
    f.command("start", "--job", "code-reviewer", "--agent-id", "again").status,
    0,
  );
});

test("shipped report template seals and passes consumer validation", (t) => {
  const f = fixture(t);
  f.complete();
  const template = fs.readFileSync(
    path.resolve(
      __dirname,
      "../../skills/kramme:pr:code-review/references/output-template.md",
    ),
    "utf8",
  );
  const block = template.match(/^```markdown\n([\s\S]*?)\n```/m);
  assert.ok(block, "Shipped report template must contain a Markdown block");
  const report = block[1]
    .replace("COMPLETE | INCOMPLETE", "COMPLETE")
    .replace("{absolute run directory}", f.run)
    .replace("{run ID}", f.ledger().runId);
  fs.writeFileSync(f.report, report);
  f.ok("seal", "--report", f.report);
  f.ok("check", "--report", f.report, "--aspects", "all");
});

test("finding quota and empty primary results cannot skip downstream stages", (t) => {
  const f = fixture(t);
  f.finish("code-reviewer");
  f.draft();
  assert.match(
    f.command("seal", "--report", f.report).stderr,
    /Incomplete job/,
  );
  assert.match(
    f.command("start", "--job", "relevance", "--agent-id", "validator").stderr,
    /Incomplete dependency/,
  );
  for (const [id, job] of Object.entries(f.ledger().jobs))
    if (job.kind === "reviewer" && id !== "code-reviewer") f.finish(id);
  f.finish("integrity");
  f.finish("relevance");
  assert.match(f.command("seal", "--report", f.report).stderr, /slop-meta/);
});

test("timeout leaves partial findings but blocks certification", (t) => {
  const f = fixture(t);
  f.finish("code-reviewer");
  f.finish("silent-failure-hunter", "failed");
  f.draft();
  assert.match(f.command("seal", "--report", f.report).stderr, /failed/);
  assert.ok(fs.existsSync(path.join(f.run, "code-reviewer.txt")));
});

test("filter can complete only its declared scope", (t) => {
  const f = fixture(t, ["code"]);
  f.complete();
  f.draft();
  f.ok("seal", "--report", f.report);
  f.ok("check", "--report", f.report, "--aspects", "code");
  assert.match(
    f.command("check", "--report", f.report, "--aspects", "all").stderr,
    /aspect scope/,
  );
});

test("unavailable reviewer preserves failure evidence and partial validation without sealing", (t) => {
  const f = fixture(t, ["code", "errors"]);
  f.finish("code-reviewer");
  const failure = path.join(f.temp, "unavailable.txt");
  fs.writeFileSync(
    failure,
    "Host could not launch silent-failure-hunter; tool unavailable\n",
  );
  f.ok(
    "finish",
    "--job",
    "silent-failure-hunter",
    "--status",
    "failed",
    "--output",
    failure,
  );
  assert.equal(f.ledger().jobs["silent-failure-hunter"].agentId, undefined);
  for (const id of [
    "integrity",
    "relevance",
    "slop-meta",
    "previous-context",
    "aggregation",
    "final-check",
  ])
    f.finish(id);
  f.draft();
  assert.match(f.command("seal", "--report", f.report).stderr, /failed/);
});

test("missing ID, duplicate ID and empty results do not count as execution", (t) => {
  const f = fixture(t);
  assert.match(f.command("start", "--job", "code-reviewer").stderr, /agent ID/);
  f.finish("code-reviewer");
  assert.match(
    f.command(
      "start",
      "--job",
      "silent-failure-hunter",
      "--agent-id",
      "host-code-reviewer",
    ).stderr,
    /distinct invocation/,
  );
  f.ok("start", "--job", "silent-failure-hunter", "--agent-id", "unique");
  const empty = path.join(f.temp, "empty.txt");
  fs.writeFileSync(empty, "\n");
  assert.match(
    f.command(
      "finish",
      "--job",
      "silent-failure-hunter",
      "--status",
      "succeeded",
      "--output",
      empty,
    ).stderr,
    /Empty output/,
  );
});

for (const change of [
  "worktree",
  "index",
  "untracked",
  "head",
  "base",
  "output",
  "report",
  "plan",
  "inventory",
]) {
  test(`completion rejects changed ${change}`, (t) => {
    const f = fixture(t);
    f.complete();
    f.draft();
    f.ok("seal", "--report", f.report);
    if (change === "worktree")
      fs.writeFileSync(path.join(f.root, "source.txt"), "later\n");
    if (change === "index") f.git("add", "source.txt");
    if (change === "untracked")
      fs.writeFileSync(path.join(f.root, "new.txt"), "later\n");
    if (change === "head" || change === "base") {
      f.git("add", ".");
      f.git("commit", "-m", "Later source");
      if (change === "base") {
        f.git("branch", "-f", "base", "HEAD");
        f.git("reset", "--soft", "HEAD~1");
      }
    }
    if (change === "output")
      fs.appendFileSync(path.join(f.run, "code-reviewer.txt"), "edited");
    if (change === "report") fs.appendFileSync(f.report, "edited");
    if (change === "plan")
      fs.writeFileSync(
        path.join(f.run, "plan.json"),
        JSON.stringify({ aspects: ["code"] }),
      );
    if (change === "inventory") {
      const ledger = f.ledger();
      delete ledger.jobs["slop-meta"];
      fs.writeFileSync(path.join(f.run, "ledger.json"), JSON.stringify(ledger));
    }
    assert.notEqual(
      f.command("check", "--report", f.report, "--aspects", "all").status,
      0,
    );
  });
}

test("untracked root report publication does not stale evidence", (t) => {
  const f = fixture(t);
  f.complete();
  f.draft();
  f.ok("seal", "--report", f.report);
  fs.copyFileSync(f.report, path.join(f.root, "REVIEW_OVERVIEW.md"));
  f.ok(
    "check",
    "--report",
    path.join(f.root, "REVIEW_OVERVIEW.md"),
    "--aspects",
    "all",
  );
});

test("report fields, required sections and consumer repository must match", (t) => {
  const f = fixture(t, ["code"]);
  f.complete();
  f.draft();
  const original = fs.readFileSync(f.report, "utf8");
  for (const changed of [
    original.replace(
      "Review status: COMPLETE",
      "Review status: COMPLETE | INCOMPLETE",
    ),
    original.replace("## Coverage Status", "## Omitted coverage"),
    original + "Review status: COMPLETE\n",
  ]) {
    fs.writeFileSync(f.report, changed);
    assert.notEqual(f.command("seal", "--report", f.report).status, 0);
  }
  fs.writeFileSync(f.report, original);
  f.ok("seal", "--report", f.report);
  const result = spawnSync(
    process.execPath,
    [helper, "check", f.run, "--report", f.report],
    { cwd: __dirname, encoding: "utf8" },
  );
  assert.match(result.stderr, /different repository/);
  fs.unlinkSync(path.join(f.run, "slop-meta.txt"));
  assert.notEqual(f.command("check", "--report", f.report).status, 0);
});
