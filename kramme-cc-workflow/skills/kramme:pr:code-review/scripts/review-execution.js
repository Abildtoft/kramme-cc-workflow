#!/usr/bin/env node
/* Local execution evidence, not a trusted host attestation. No shell evaluation. */
"use strict";
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const { execFileSync } = require("node:child_process");

const REVIEWERS = {
  code: ["code-reviewer"],
  errors: ["silent-failure-hunter"],
  slop: ["deslop-reviewer"],
  tests: ["pr-test-analyzer"],
  comments: ["comment-analyzer"],
  types: ["type-design-analyzer"],
  removal: ["removal-planner"],
  lean: ["lean-reviewer"],
  refactor: ["code-simplifier"],
  simplify: ["code-simplifier"],
  performance: ["performance-oracle"],
  security: [
    "injection-reviewer",
    "auth-reviewer",
    "data-reviewer",
    "logic-reviewer",
  ],
};
const CONDITIONAL = [
  "tests",
  "comments",
  "types",
  "removal",
  "performance",
  "security",
];
const STAGES = [
  "integrity",
  "relevance",
  "slop-meta",
  "previous-context",
  "aggregation",
  "final-check",
];
const hash = (value) => crypto.createHash("sha256").update(value).digest("hex");
const jsonHash = (value) => hash(JSON.stringify(value));
function requireValue(condition, message) {
  if (!condition) throw new Error(message);
}
function git(root, ...args) {
  return execFileSync("git", ["-C", root, ...args], {
    maxBuffer: 64 * 1024 * 1024,
  });
}
function snapshot(root, base) {
  const head = git(root, "rev-parse", "HEAD").toString().trim();
  const baseOid = git(root, "rev-parse", "--verify", `${base}^{commit}`)
    .toString()
    .trim();
  const tracked = git(root, "ls-files", "-z")
    .toString()
    .split("\0")
    .filter(Boolean);
  const untracked = git(
    root,
    "ls-files",
    "--others",
    "--exclude-standard",
    "-z",
  )
    .toString()
    .split("\0")
    .filter((name) => name && name !== "REVIEW_OVERVIEW.md");
  const files = [...new Set([...tracked, ...untracked])].sort().map((name) => {
    const file = path.join(root, name);
    let state;
    try {
      const stat = fs.lstatSync(file);
      if (stat.isSymbolicLink()) state = `link:${fs.readlinkSync(file)}`;
      else if (stat.isFile())
        state = `${stat.mode & 0o111}:${hash(fs.readFileSync(file))}`;
      else if (stat.isDirectory()) {
        // Gitlinks need their own HEAD and dirty-state evidence.
        state = `gitlink:${git(file, "rev-parse", "HEAD")}:${git(file, "status", "--porcelain")}`;
        requireValue(
          !git(file, "status", "--porcelain").toString().trim(),
          `Dirty submodule: ${name}`,
        );
      } else throw new Error(`Unsupported review path: ${name}`);
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
      state = "absent";
    }
    return [name, state];
  });
  requireValue(
    head === git(root, "rev-parse", "HEAD").toString().trim(),
    "HEAD changed during capture",
  );
  return {
    head,
    baseOid,
    index: hash(git(root, "ls-files", "--stage", "-z")),
    files: jsonHash(files),
  };
}
function jobsFor(plan) {
  requireValue(
    Array.isArray(plan.aspects) && plan.aspects.length > 0,
    "Plan needs normalized aspects",
  );
  requireValue(
    plan.aspects.every((a) => a === "all" || Object.hasOwn(REVIEWERS, a)),
    "Unknown aspect",
  );
  const all = plan.aspects.includes("all");
  const jobs = {};
  const coverage = {};
  for (const [dimension, reviewers] of Object.entries(REVIEWERS)) {
    const selected = all || plan.aspects.includes(dimension);
    let active = selected;
    let reason = selected
      ? "required by selected scope"
      : "excluded by explicit aspect filter";
    if (selected && CONDITIONAL.includes(dimension)) {
      const decision = plan.applicability?.[dimension];
      requireValue(
        typeof decision?.applicable === "boolean" &&
          typeof decision.reason === "string" &&
          decision.reason.trim(),
        `Missing applicability evidence: ${dimension}`,
      );
      active = decision.applicable;
      reason = decision.reason;
    }
    coverage[dimension] = { active, reason, reviewers };
    if (active)
      for (const reviewer of reviewers)
        jobs[reviewer] = { kind: "reviewer", agent: `kramme:${reviewer}` };
  }
  requireValue(Object.keys(jobs).length > 0, "No applicable reviewers");
  for (const stage of STAGES)
    jobs[stage] = {
      kind: "stage",
      agent:
        stage === "relevance"
          ? "kramme:pr-relevance-validator"
          : stage === "slop-meta"
            ? "kramme:deslop-reviewer"
            : "orchestrator",
    };
  return { jobs, coverage };
}
function dependencies(id, jobs) {
  if (!STAGES.includes(id)) return [];
  const index = STAGES.indexOf(id);
  return index === 0
    ? Object.keys(jobs).filter((key) => !STAGES.includes(key))
    : [STAGES[index - 1]];
}
function readJson(file) {
  return JSON.parse(fs.readFileSync(file, "utf8"));
}
function save(file, value) {
  const temp = `${file}.${process.pid}.tmp`;
  fs.writeFileSync(temp, `${JSON.stringify(value, null, 2)}\n`, { flag: "wx" });
  fs.renameSync(temp, file);
}
function load(directory) {
  const plan = readJson(path.join(directory, "plan.json"));
  const ledger = readJson(path.join(directory, "ledger.json"));
  requireValue(
    ledger.version === 1 && ledger.planHash === jsonHash(plan),
    "Plan changed or unsupported ledger",
  );
  const derived = jobsFor(plan);
  requireValue(
    JSON.stringify(ledger.coverage) === JSON.stringify(derived.coverage),
    "Coverage changed",
  );
  requireValue(
    JSON.stringify(Object.keys(ledger.jobs)) ===
      JSON.stringify(Object.keys(derived.jobs)),
    "Job inventory changed",
  );
  for (const [id, job] of Object.entries(derived.jobs)) {
    requireValue(
      job.agent === ledger.jobs[id].agent && job.kind === ledger.jobs[id].kind,
      `Job changed: ${id}`,
    );
  }
  return { plan, ledger };
}
function fresh(ledger) {
  requireValue(
    git(process.cwd(), "rev-parse", "--show-toplevel").toString().trim() ===
      ledger.root,
    "Evidence belongs to a different repository",
  );
  requireValue(
    jsonHash(snapshot(ledger.root, ledger.base)) === jsonHash(ledger.scope),
    "Review scope is stale; start a fresh full run",
  );
}
function validate(directory, ledger) {
  fresh(ledger);
  const ids = new Set();
  for (const [id, job] of Object.entries(ledger.jobs)) {
    requireValue(
      job.status === "succeeded",
      `Incomplete job: ${id} (${job.status})`,
    );
    requireValue(
      Number.isInteger(job.started) &&
        Number.isInteger(job.finished) &&
        job.started < job.finished,
      `Invalid execution order: ${id}`,
    );
    if (job.agent !== "orchestrator") {
      requireValue(
        typeof job.agentId === "string" &&
          job.agentId.trim() &&
          !ids.has(job.agentId),
        `Missing or reused agent ID: ${id}`,
      );
      ids.add(job.agentId);
    }
    for (const dependency of dependencies(id, ledger.jobs)) {
      requireValue(
        ledger.jobs[dependency].finished < job.started,
        `Stage started too early: ${id}`,
      );
    }
    const output = fs.readFileSync(path.join(directory, `${id}.txt`));
    requireValue(
      output.toString().trim() && hash(output) === job.outputHash,
      `Missing or changed output: ${id}`,
    );
  }
}
function main(argv) {
  const [command, directoryArg, ...rest] = argv;
  requireValue(
    ["init", "start", "finish", "seal", "check"].includes(command) &&
      directoryArg,
    "Usage: review-execution.js init|start|finish|seal|check RUN_DIR [--key value]",
  );
  requireValue(rest.length % 2 === 0, "Options require values");
  const options = {};
  const allowed = {
    init: ["plan", "base"],
    start: ["job", "agent-id"],
    finish: ["job", "output", "status"],
    seal: ["report"],
    check: ["report", "aspects"],
  }[command];
  for (let i = 0; i < rest.length; i += 2) {
    const key = rest[i].replace(/^--/, "");
    requireValue(
      rest[i].startsWith("--") &&
        allowed.includes(key) &&
        !Object.hasOwn(options, key),
      `Invalid option: ${rest[i]}`,
    );
    options[key] = rest[i + 1];
  }
  const directory = path.resolve(directoryArg);
  if (command === "init") {
    requireValue(
      options.plan && options.base && !options.base.startsWith("-"),
      "init needs --plan and --base",
    );
    const root = git(process.cwd(), "rev-parse", "--show-toplevel")
      .toString()
      .trim();
    const relative = path.relative(root, directory);
    requireValue(
      relative.startsWith(`..${path.sep}`) || path.isAbsolute(relative),
      "Keep execution artifacts outside the working tree (use mktemp -d)",
    );
    const plan = readJson(options.plan);
    const { jobs, coverage } = jobsFor(plan);
    requireValue(
      typeof plan.context === "string" && plan.context.trim(),
      "Plan needs scope, PR metadata and previous-review context evidence",
    );
    const scope = snapshot(root, options.base);
    fs.mkdirSync(directory, { recursive: true });
    requireValue(
      fs.readdirSync(directory).length === 0,
      "Run directory must be empty",
    );
    const ledger = {
      version: 1,
      runId: crypto.randomUUID(),
      evidence: "self-attested",
      root,
      base: options.base,
      scope,
      planHash: jsonHash(plan),
      coverage,
      sequence: 0,
      jobs: Object.fromEntries(
        Object.entries(jobs).map(([id, job]) => [
          id,
          { ...job, status: "pending" },
        ]),
      ),
    };
    save(path.join(directory, "plan.json"), plan);
    save(path.join(directory, "ledger.json"), ledger);
    console.log(JSON.stringify(ledger));
    return;
  }
  const { plan, ledger } = load(directory);
  if (command === "start" || command === "finish") {
    requireValue(
      !ledger.reportHash,
      "Sealed run cannot change; start a fresh run",
    );
    const job = ledger.jobs[options.job];
    requireValue(Object.hasOwn(ledger.jobs, options.job), "Unknown job");
    if (command === "start") {
      fresh(ledger);
      requireValue(
        job.status === "pending",
        "Job already started; retain failed evidence and start a fresh run for retries",
      );
      for (const dependency of dependencies(options.job, ledger.jobs))
        requireValue(
          ledger.jobs[dependency].status === "succeeded" ||
            (options.job === "integrity" &&
              ledger.jobs[dependency].status === "failed"),
          `Incomplete dependency: ${dependency}`,
        );
      if (options.job === "integrity")
        requireValue(
          Object.values(ledger.jobs).some(
            (item) => item.kind === "reviewer" && item.status === "succeeded",
          ),
          "All primary reviewers failed",
        );
      if (job.agent !== "orchestrator") {
        requireValue(
          options["agent-id"]?.trim(),
          "Actual host agent ID required",
        );
        requireValue(
          !Object.values(ledger.jobs).some(
            (other) => other.agentId === options["agent-id"],
          ),
          "Use a distinct invocation ID per delegated job",
        );
        job.agentId = options["agent-id"];
      }
      job.status = "running";
      job.started = ++ledger.sequence;
    } else {
      requireValue(
        (job.status === "running" ||
          (job.status === "pending" && options.status === "failed")) &&
          ["succeeded", "failed"].includes(options.status) &&
          options.output,
        "finish needs running job, --status succeeded|failed and --output",
      );
      const output = fs.readFileSync(options.output);
      requireValue(
        output.toString().trim(),
        "Empty output is not evidence; save an explicit zero-findings result",
      );
      fs.writeFileSync(path.join(directory, `${options.job}.txt`), output, {
        flag: "wx",
      });
      if (job.status === "pending") job.started = ++ledger.sequence;
      job.status = options.status;
      job.outputHash = hash(output);
      job.finished = ++ledger.sequence;
    }
    save(path.join(directory, "ledger.json"), ledger);
    return;
  }
  validate(directory, ledger);
  requireValue(
    options.report,
    "Report file required (save exact inline content to a temporary file)",
  );
  const report = fs.readFileSync(options.report);
  const reportText = report.toString();
  for (const heading of [
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
  ]) {
    requireValue(
      reportText
        .split("\n")
        .some(
          (line) =>
            line === `## ${heading}` || line.startsWith(`## ${heading} (`),
        ),
      `Missing report section: ${heading}`,
    );
  }
  for (const prefix of ["Review status:", "Review execution:", "Review run:"])
    requireValue(
      reportText.split("\n").filter((line) => line.startsWith(prefix))
        .length === 1,
      `Ambiguous report field: ${prefix}`,
    );
  requireValue(
    reportText.split("\n").includes(`Review execution: ${directory}`),
    "Report must name this execution directory",
  );
  requireValue(
    reportText.split("\n").includes(`Review run: ${ledger.runId}`),
    "Report run ID missing",
  );
  requireValue(
    reportText.split("\n").includes("Review status: COMPLETE"),
    "Report status must be COMPLETE",
  );
  if (command === "seal") {
    requireValue(!ledger.reportHash, "Run already sealed");
    ledger.reportHash = hash(report);
    save(path.join(directory, "ledger.json"), ledger);
  } else {
    requireValue(
      ledger.reportHash === hash(report),
      "Missing seal or changed report",
    );
    if (options.aspects)
      requireValue(
        JSON.stringify(plan.aspects) ===
          JSON.stringify(options.aspects.split(",")),
        "Review aspect scope does not match consumer requirement",
      );
  }
  console.log(
    JSON.stringify({
      status: "COMPLETE",
      runId: ledger.runId,
      evidence: ledger.evidence,
      scope: ledger.scope,
      coverage: ledger.coverage,
      jobs: ledger.jobs,
    }),
  );
}
if (require.main === module) {
  try {
    main(process.argv.slice(2));
  } catch (error) {
    console.error(`INCOMPLETE: ${error.message}`);
    process.exitCode = 1;
  }
}
module.exports = { main, jobsFor, snapshot, validate };
