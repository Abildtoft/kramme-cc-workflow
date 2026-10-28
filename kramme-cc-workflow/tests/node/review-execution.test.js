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

/** @param {import('node:test').TestContext} t @param {string[]} aspects @param {string[]} active @param {{noCleanup?: boolean, emphasizedDimensions?: string[]}} options */
function fixture(t, aspects = ["all"], active = [], options = {}) {
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
    ...options,
    context: "base; source.txt changed; no PR metadata; no previous findings",
    applicability: {},
  };
  for (const dimension of [
    "tests",
    "comments",
    "types",
    "architecture",
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
      // The convergence check can exceed ten seconds on shared macOS runners.
      timeout: 30000,
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

test("default inventory cannot omit always-on and cleanup reviewers; one job per merged reviewer", () => {
  /** @type {{aspects: string[], applicability: Record<string, {applicable: boolean, reason: string}>}} */
  const plan = { aspects: ["all"], applicability: {} };
  assert.throws(() => jobsFor(plan), /applicability/);
  for (const dimension of [
    "tests",
    "comments",
    "types",
    "architecture",
    "removal",
    "performance",
    "security",
  ])
    plan.applicability[dimension] = {
      applicable: dimension === "security",
      reason: "diff evidence",
    };
  const { jobs } = jobsFor(plan);
  for (const noCleanup of [undefined, false]) {
    const { coverage } = jobsFor({
      ...plan,
      ...(noCleanup === undefined ? {} : { noCleanup }),
    });
    for (const dimension of ["lean", "refactor", "simplify"])
      assert.equal(coverage[dimension].active, true);
  }
  for (const id of [
    "code-reviewer",
    "silent-failure-hunter",
    "deslop-reviewer",
    "cleanup-reviewer",
    "security-reviewer",
    "relevance",
    "slop-meta",
  ])
    assert.ok(jobs[id]);
  assert.throws(() => jobsFor({ aspects: ["quick"] }), /Unknown/);
  assert.deepEqual(
    Object.keys(
      jobsFor({
        aspects: ["lean", "refactor", "simplify", "removal"],
        applicability: { removal: { applicable: true, reason: "deletion" } },
      }).jobs,
    ).filter((id) => id === "cleanup-reviewer"),
    ["cleanup-reviewer"],
  );
});

test("architecture is a conditional dimension owned by architecture-strategist", () => {
  const applicability = Object.fromEntries(
    ["tests", "comments", "types", "removal", "performance", "security"].map(
      (dimension) => [dimension, { applicable: false, reason: "not touched" }],
    ),
  );
  assert.throws(
    () => jobsFor({ aspects: ["all"], applicability }),
    /Missing applicability evidence: architecture/,
  );
  const { jobs, coverage } = jobsFor({
    aspects: ["all"],
    applicability: {
      ...applicability,
      architecture: {
        applicable: true,
        reason: "src/billing/index.ts exports changed",
      },
    },
  });
  assert.equal(
    jobs["architecture-strategist"].agent,
    "kramme:architecture-strategist",
  );
  assert.deepEqual(coverage.architecture.reviewers, [
    "architecture-strategist",
  ]);
  const { jobs: filtered } = jobsFor({
    aspects: ["architecture"],
    applicability: {
      architecture: { applicable: true, reason: "new cross-module import" },
    },
  });
  assert.deepEqual(
    Object.keys(filtered).filter((id) => filtered[id].kind === "reviewer"),
    ["architecture-strategist"],
  );
});

test("no-cleanup excludes advisory dimensions and preserves independent removal", () => {
  for (const removal of [false, true]) {
    const plan = {
      aspects: ["all"],
      noCleanup: true,
      emphasizedDimensions: ["code"],
      applicability: Object.fromEntries(
        [
          "tests",
          "comments",
          "types",
          "architecture",
          "removal",
          "performance",
          "security",
        ].map((dimension) => [
          dimension,
          {
            applicable: dimension === "removal" && removal,
            reason: `${dimension} inspected in diff`,
          },
        ]),
      ),
    };
    const { jobs, coverage } = jobsFor(plan);
    assert.deepEqual(plan.aspects, ["all"]);
    for (const dimension of ["lean", "refactor", "simplify"]) {
      assert.equal(coverage[dimension].active, false);
      assert.match(coverage[dimension].reason, /--no-cleanup/);
    }
    assert.equal(coverage.removal.active, removal);
    assert.equal(Object.hasOwn(jobs, "cleanup-reviewer"), removal);
    for (const id of [
      "code-reviewer",
      "silent-failure-hunter",
      "deslop-reviewer",
    ])
      assert.ok(jobs[id]);
  }
  const { coverage } = jobsFor({ aspects: ["code"], noCleanup: true });
  assert.equal(coverage.lean.reason, "excluded by explicit aspect filter");
});

test("no-cleanup rejects explicitly requested cleanup aspects and emphasis", () => {
  for (const dimension of ["lean", "refactor", "simplify"]) {
    for (const aspects of [[dimension], ["all", dimension]])
      assert.throws(
        () => jobsFor({ aspects, noCleanup: true }),
        /--no-cleanup.*explicit/i,
      );
    assert.throws(
      () =>
        jobsFor({
          aspects: ["all"],
          noCleanup: true,
          emphasizedDimensions: [dimension],
        }),
      /--no-cleanup.*emphas/i,
    );
  }
  const { jobs } = jobsFor({
    aspects: ["removal"],
    noCleanup: true,
    emphasizedDimensions: ["removal"],
    applicability: { removal: { applicable: true, reason: "deletion" } },
  });
  assert.ok(jobs["cleanup-reviewer"]);
});

test("normalized cleanup and emphasis options reject malformed values", () => {
  for (const noCleanup of ["true", "false", 0, null])
    assert.throws(
      () => jobsFor({ aspects: ["code"], noCleanup }),
      /noCleanup.*boolean/,
    );
  for (const emphasizedDimensions of [
    "code",
    null,
    ["all"],
    ["quick"],
    [["code"]],
  ])
    assert.throws(
      () => jobsFor({ aspects: ["code"], emphasizedDimensions }),
      /emphasizedDimensions/,
    );
  assert.throws(
    () => jobsFor({ aspects: ["code"], emphasizedDimensions: ["lean"] }),
    /emphasized.*aspect filter/i,
  );
});

for (const removal of [false, true]) {
  test(`no-cleanup all run reloads, seals and passes convergence check (removal=${removal})`, (t) => {
    const f = fixture(t, ["all"], removal ? ["removal"] : [], {
      noCleanup: true,
      emphasizedDimensions: [],
    });
    f.complete();
    f.draft();
    f.ok("seal", "--report", f.report);
    const receipt = JSON.parse(
      f.ok("check", "--report", f.report, "--aspects", "all").stdout,
    );
    assert.equal(receipt.status, "COMPLETE");
    assert.equal(Object.hasOwn(receipt.jobs, "cleanup-reviewer"), removal);
    assert.equal(receipt.coverage.removal.active, removal);
    for (const dimension of ["lean", "refactor", "simplify"]) {
      assert.equal(receipt.coverage[dimension].active, false);
      assert.match(receipt.coverage[dimension].reason, /--no-cleanup/);
    }
  });
}

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

test("unfinished downstream stages block sealing; skips must be explicit", (t) => {
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

/** @param {ReturnType<typeof fixture>} f @param {string} name @param {string} text */
function saveOutput(f, name, text) {
  const file = path.join(f.temp, `${name}.txt`);
  fs.writeFileSync(file, text);
  return file;
}

/** @param {ReturnType<typeof fixture>} f */
function finishPrimaryAndIntegrity(f) {
  for (const [id, job] of Object.entries(f.ledger().jobs))
    if (job.kind === "reviewer" || id === "integrity") f.finish(id);
}

test("zero-finding runs skip the relevance and slop agents and state it in the report", (t) => {
  const f = fixture(t);
  finishPrimaryAndIntegrity(f);
  const skip = saveOutput(
    f,
    "skip",
    "Skipped: every primary reviewer returned zero findings\n",
  );
  f.ok("finish", "--job", "relevance", "--status", "skipped", "--output", skip);
  f.ok("finish", "--job", "slop-meta", "--status", "skipped", "--output", skip);
  for (const id of ["previous-context", "aggregation", "final-check"])
    f.finish(id);
  assert.equal(f.ledger().jobs.relevance.agentId, undefined);
  f.draft();
  assert.match(
    f.command("seal", "--report", f.report).stderr,
    /Report must state: Relevance validation: skipped \(no findings\)/,
  );
  fs.appendFileSync(
    f.report,
    "Relevance validation: skipped (no findings)\nSlop meta-review: skipped (no findings)\n",
  );
  f.ok("seal", "--report", f.report);
  f.ok("check", "--report", f.report, "--aspects", "all");
});

test("only empty downstream agent stages may be skipped, with explicit evidence", (t) => {
  const f = fixture(t);
  const skip = saveOutput(f, "skip", "Skipped: nothing to process\n");
  assert.match(
    f.command(
      "finish",
      "--job",
      "code-reviewer",
      "--status",
      "skipped",
      "--output",
      skip,
    ).stderr,
    /Only relevance and slop-meta may be skipped/,
  );
  assert.match(
    f.command(
      "finish",
      "--job",
      "relevance",
      "--status",
      "skipped",
      "--output",
      skip,
    ).stderr,
    /Incomplete dependency/,
  );
  finishPrimaryAndIntegrity(f);
  const vague = saveOutput(f, "vague", "nothing to see\n");
  assert.match(
    f.command(
      "finish",
      "--job",
      "relevance",
      "--status",
      "skipped",
      "--output",
      vague,
    ).stderr,
    /must start with `Skipped:`/,
  );
  f.ok("finish", "--job", "relevance", "--status", "skipped", "--output", skip);
  f.finish("slop-meta");
  for (const id of ["previous-context", "aggregation", "final-check"])
    f.finish(id);
  f.draft();
  fs.appendFileSync(f.report, "Relevance validation: skipped (no findings)\n");
  assert.match(f.command("seal", "--report", f.report).stderr, /skip it too/);
});

test("a running agent stage cannot be relabeled as skipped", (t) => {
  const f = fixture(t);
  finishPrimaryAndIntegrity(f);
  f.ok("start", "--job", "relevance", "--agent-id", "validator-1");
  const skip = saveOutput(f, "skip", "Skipped: nothing to process\n");
  assert.notEqual(
    f.command(
      "finish",
      "--job",
      "relevance",
      "--status",
      "skipped",
      "--output",
      skip,
    ).status,
    0,
  );
});

test("record applies a whole manifest in one call and seals", (t) => {
  const f = fixture(t);
  const done = saveOutput(
    f,
    "done",
    "Completed: zero findings after full inspection\n",
  );
  const skip = saveOutput(
    f,
    "skip",
    "Skipped: every primary reviewer returned zero findings\n",
  );
  const reviewers = Object.entries(f.ledger().jobs)
    .filter(([, job]) => job.kind === "reviewer")
    .map(([id]) => ({
      job: id,
      status: "succeeded",
      output: done,
      agentId: `host-${id}`,
    }));
  const manifest = path.join(f.temp, "manifest.json");
  fs.writeFileSync(
    manifest,
    JSON.stringify([
      ...reviewers,
      { job: "integrity", status: "succeeded", output: done },
      { job: "relevance", status: "skipped", output: skip },
      { job: "slop-meta", status: "skipped", output: skip },
      { job: "previous-context", status: "succeeded", output: done },
      { job: "aggregation", status: "succeeded", output: done },
      { job: "final-check", status: "succeeded", output: done },
    ]),
  );
  f.ok("record", "--manifest", manifest);
  f.draft();
  fs.appendFileSync(
    f.report,
    "Relevance validation: skipped (no findings)\nSlop meta-review: skipped (no findings)\n",
  );
  f.ok("seal", "--report", f.report);
  f.ok("check", "--report", f.report, "--aspects", "all");
});

test("record writes nothing when any manifest entry is invalid", (t) => {
  const f = fixture(t);
  const done = saveOutput(f, "done", "Completed: zero findings\n");
  const manifest = path.join(f.temp, "manifest.json");
  fs.writeFileSync(
    manifest,
    JSON.stringify([
      {
        job: "code-reviewer",
        status: "succeeded",
        output: done,
        agentId: "host-1",
      },
      { job: "silent-failure-hunter", status: "succeeded", output: done },
    ]),
  );
  assert.match(
    f.command("record", "--manifest", manifest).stderr,
    /Actual host agent ID required/,
  );
  assert.equal(f.ledger().jobs["code-reviewer"].status, "pending");
  assert.equal(fs.existsSync(path.join(f.run, "code-reviewer.txt")), false);
  fs.writeFileSync(
    manifest,
    JSON.stringify([
      { job: "code-reviewer", status: "succeeded", output: done, extra: 1 },
    ]),
  );
  assert.match(
    f.command("record", "--manifest", manifest).stderr,
    /optional agentId/,
  );
  fs.writeFileSync(manifest, "[]");
  assert.match(
    f.command("record", "--manifest", manifest).stderr,
    /non-empty JSON array/,
  );
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

/** @param {ReturnType<typeof fixture>} f */
function status(f) {
  return JSON.parse(f.ok("status").stdout);
}

test("status reports pending jobs and scope freshness without writing", (t) => {
  const f = fixture(t);
  const before = fs.readFileSync(path.join(f.run, "ledger.json"), "utf8");
  const fresh = status(f);
  assert.equal(fresh.sealed, false);
  assert.equal(fresh.scopeFresh, true);
  assert.deepEqual(fresh.aspects, ["all"]);
  assert.equal(fresh.root, fs.realpathSync(f.root));
  assert.match(fresh.created, /^\d{4}-\d{2}-\d{2}T/);
  assert.deepEqual(fresh.jobs["code-reviewer"], {
    status: "pending",
    interrupted: 0,
  });
  fs.writeFileSync(path.join(f.root, "source.txt"), "later\n");
  assert.equal(status(f).scopeFresh, false);
  assert.equal(
    fs.readFileSync(path.join(f.run, "ledger.json"), "utf8"),
    before,
  );
});

test("status reports a sealed run", (t) => {
  const f = fixture(t);
  f.complete();
  f.draft();
  f.ok("seal", "--report", f.report);
  assert.equal(status(f).sealed, true);
});

test("requeued interrupted reviewer relaunches with a new ID, seals and passes check", (t) => {
  const f = fixture(t);
  f.ok("start", "--job", "code-reviewer", "--agent-id", "host-old");
  f.ok("requeue", "--job", "code-reviewer", "--reason", "session limit");
  const job = f.ledger().jobs["code-reviewer"];
  assert.equal(job.status, "pending");
  assert.equal(job.agentId, undefined);
  assert.equal(job.interrupted[0].agentId, "host-old");
  assert.deepEqual(status(f).jobs["code-reviewer"], {
    status: "pending",
    interrupted: 1,
  });
  assert.match(
    f.command("start", "--job", "code-reviewer", "--agent-id", "host-old")
      .stderr,
    /distinct invocation ID/,
  );
  f.complete();
  f.draft();
  f.ok("seal", "--report", f.report);
  f.ok("check", "--report", f.report, "--aspects", "all");
});

test("completion rejects a final agent ID equal to an interrupted one", (t) => {
  const f = fixture(t);
  f.ok("start", "--job", "code-reviewer", "--agent-id", "host-old");
  f.ok("requeue", "--job", "code-reviewer", "--reason", "host restart");
  f.complete();
  const ledger = f.ledger();
  ledger.jobs["code-reviewer"].agentId = "host-old";
  fs.writeFileSync(path.join(f.run, "ledger.json"), JSON.stringify(ledger));
  f.draft();
  assert.match(
    f.command("seal", "--report", f.report).stderr,
    /reused agent ID: code-reviewer/,
  );
});

test("requeue rejects pending, finished, sealed and stale runs", (t) => {
  const f = fixture(t);
  /** @param {string} id */
  const requeue = (id) =>
    f.command("requeue", "--job", id, "--reason", "session limit");
  assert.match(requeue("code-reviewer").stderr, /Only a running job/);
  f.finish("code-reviewer");
  assert.match(requeue("code-reviewer").stderr, /Only a running job/);
  f.finish("silent-failure-hunter", "failed");
  assert.match(requeue("silent-failure-hunter").stderr, /Only a running job/);
  f.ok("start", "--job", "deslop-reviewer", "--agent-id", "host-slop");
  assert.match(
    f.command("requeue", "--job", "deslop-reviewer").stderr,
    /requeue needs --reason/,
  );
  fs.writeFileSync(path.join(f.root, "source.txt"), "later\n");
  assert.match(requeue("deslop-reviewer").stderr, /stale/);

  const sealed = fixture(t);
  sealed.complete();
  sealed.draft();
  sealed.ok("seal", "--report", sealed.report);
  assert.match(
    sealed.command("requeue", "--job", "code-reviewer", "--reason", "late")
      .stderr,
    /Sealed run cannot change/,
  );
});
