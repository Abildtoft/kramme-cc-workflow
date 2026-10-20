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
  architecture: ["architecture-strategist"],
  removal: ["cleanup-reviewer"],
  lean: ["cleanup-reviewer"],
  refactor: ["cleanup-reviewer"],
  simplify: ["cleanup-reviewer"],
  performance: ["performance-oracle"],
  security: ["security-reviewer"],
};
const CONDITIONAL = [
  "tests",
  "comments",
  "types",
  "architecture",
  "removal",
  "performance",
  "security",
];
const ADVISORY_CLEANUP = ["lean", "refactor", "simplify"];
const STAGES = [
  "integrity",
  "relevance",
  "slop-meta",
  "previous-context",
  "aggregation",
  "final-check",
];
// Agent stages that have nothing to process when no finding reaches them. A skip launches no agent, needs explicit
// `Skipped:` evidence, and must be stated in the sealed report so a consumer can see the stage did not run.
const SKIPPABLE = {
  relevance: "Relevance validation: skipped (no findings)",
  "slop-meta": "Slop meta-review: skipped (no findings)",
};
const COMPLETE = ["succeeded", "skipped"];
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
  requireValue(
    !Object.hasOwn(plan, "noCleanup") || typeof plan.noCleanup === "boolean",
    "Plan noCleanup must be a boolean",
  );
  const emphasized = Object.hasOwn(plan, "emphasizedDimensions")
    ? plan.emphasizedDimensions
    : [];
  requireValue(
    Array.isArray(emphasized) &&
      emphasized.every(
        (dimension) =>
          typeof dimension === "string" && Object.hasOwn(REVIEWERS, dimension),
      ),
    "Plan emphasizedDimensions must be an array of recognized dimensions (not all)",
  );
  if (plan.noCleanup) {
    requireValue(
      !plan.aspects.some((dimension) => ADVISORY_CLEANUP.includes(dimension)),
      "--no-cleanup conflicts with explicitly requested cleanup aspects",
    );
    requireValue(
      !emphasized.some((dimension) => ADVISORY_CLEANUP.includes(dimension)),
      "--no-cleanup conflicts with emphasized cleanup dimensions",
    );
  }
  const all = plan.aspects.includes("all");
  requireValue(
    all || emphasized.every((dimension) => plan.aspects.includes(dimension)),
    "Emphasized dimension excluded by explicit aspect filter",
  );
  const jobs = {};
  const coverage = {};
  for (const [dimension, reviewers] of Object.entries(REVIEWERS)) {
    const selected = all || plan.aspects.includes(dimension);
    let active = selected;
    let reason = selected
      ? "required by selected scope"
      : "excluded by explicit aspect filter";
    if (selected && plan.noCleanup && ADVISORY_CLEANUP.includes(dimension)) {
      active = false;
      reason = "excluded by --no-cleanup";
    }
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
  requireValue(
    ledger.jobs.relevance?.status !== "skipped" ||
      ledger.jobs["slop-meta"]?.status === "skipped",
    "A skipped relevance stage leaves nothing for slop meta-review; skip it too",
  );
  for (const [id, job] of Object.entries(ledger.jobs)) {
    requireValue(
      job.status === "succeeded" ||
        (job.status === "skipped" && Object.hasOwn(SKIPPABLE, id)),
      `Incomplete job: ${id} (${job.status})`,
    );
    requireValue(
      Number.isInteger(job.started) &&
        Number.isInteger(job.finished) &&
        job.started < job.finished,
      `Invalid execution order: ${id}`,
    );
    if (job.agent !== "orchestrator" && job.status !== "skipped") {
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
function requireDependencies(ledger, id) {
  for (const dependency of dependencies(id, ledger.jobs))
    requireValue(
      COMPLETE.includes(ledger.jobs[dependency].status) ||
        (id === "integrity" && ledger.jobs[dependency].status === "failed"),
      `Incomplete dependency: ${dependency}`,
    );
  if (id === "integrity")
    requireValue(
      Object.values(ledger.jobs).some(
        (item) => item.kind === "reviewer" && item.status === "succeeded",
      ),
      "All primary reviewers failed",
    );
}
function applyStart(ledger, id, agentId) {
  const job = ledger.jobs[id];
  requireValue(Object.hasOwn(ledger.jobs, id), `Unknown job: ${id}`);
  requireValue(
    job.status === "pending",
    "Job already started; retain failed evidence and start a fresh run for retries",
  );
  requireDependencies(ledger, id);
  if (job.agent !== "orchestrator") {
    requireValue(agentId?.trim(), "Actual host agent ID required");
    requireValue(
      !Object.values(ledger.jobs).some((other) => other.agentId === agentId),
      "Use a distinct invocation ID per delegated job",
    );
    job.agentId = agentId;
  }
  job.status = "running";
  job.started = ++ledger.sequence;
}
function applyFinish(ledger, id, status, output) {
  const job = ledger.jobs[id];
  requireValue(Object.hasOwn(ledger.jobs, id), `Unknown job: ${id}`);
  requireValue(
    (job.status === "running" && ["succeeded", "failed"].includes(status)) ||
      (job.status === "pending" && ["failed", "skipped"].includes(status)),
    "finish needs running job, --status succeeded|failed and --output (or a pending job with --status failed|skipped)",
  );
  requireValue(
    output.toString().trim(),
    "Empty output is not evidence; save an explicit zero-findings result",
  );
  if (status === "skipped") {
    requireValue(
      Object.hasOwn(SKIPPABLE, id),
      `Only ${Object.keys(SKIPPABLE).join(" and ")} may be skipped`,
    );
    requireValue(
      output.toString().trimStart().startsWith("Skipped:"),
      "Skipped output must start with `Skipped:` and say why nothing reached the stage",
    );
    requireDependencies(ledger, id);
  }
  if (job.status === "pending") job.started = ++ledger.sequence;
  job.status = status;
  job.outputHash = hash(output);
  job.finished = ++ledger.sequence;
}
function readManifest(file) {
  const manifest = readJson(file);
  requireValue(
    Array.isArray(manifest) && manifest.length > 0,
    "Manifest must be a non-empty JSON array",
  );
  return manifest.map((entry, index) => {
    requireValue(
      entry &&
        typeof entry === "object" &&
        typeof entry.job === "string" &&
        typeof entry.status === "string" &&
        typeof entry.output === "string" &&
        (entry.agentId === undefined || typeof entry.agentId === "string") &&
        Object.keys(entry).every((key) =>
          ["job", "status", "output", "agentId"].includes(key),
        ),
      `Manifest entry ${index} needs job, status, output, and optional agentId`,
    );
    return { ...entry, data: fs.readFileSync(entry.output) };
  });
}
function main(argv) {
  const [command, directoryArg, ...rest] = argv;
  requireValue(
    ["init", "start", "finish", "record", "seal", "check"].includes(command) &&
      directoryArg,
    "Usage: review-execution.js init|start|finish|record|seal|check RUN_DIR [--key value]",
  );
  requireValue(rest.length % 2 === 0, "Options require values");
  const options = {};
  const allowed = {
    init: ["plan", "base"],
    start: ["job", "agent-id"],
    finish: ["job", "output", "status"],
    record: ["manifest"],
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
  if (command === "start" || command === "finish" || command === "record") {
    requireValue(
      !ledger.reportHash,
      "Sealed run cannot change; start a fresh run",
    );
    /** @type {{job: string, status?: string, agentId?: string, data?: Buffer}[]} */
    let steps;
    if (command === "start") {
      fresh(ledger);
      applyStart(ledger, options.job, options["agent-id"]);
      steps = [];
    } else if (command === "finish") {
      requireValue(
        options.job && options.status && options.output,
        "finish needs --job, --status succeeded|failed|skipped and --output",
      );
      steps = [
        {
          job: options.job,
          status: options.status,
          data: fs.readFileSync(options.output),
        },
      ];
      applyFinish(ledger, options.job, options.status, steps[0].data);
    } else {
      requireValue(options.manifest, "record needs --manifest <file.json>");
      fresh(ledger);
      // Apply every entry to the in-memory ledger before writing anything, so a bad entry records nothing.
      steps = readManifest(options.manifest);
      for (const step of steps) {
        const job = ledger.jobs[step.job];
        requireValue(
          Object.hasOwn(ledger.jobs, step.job),
          `Unknown job: ${step.job}`,
        );
        const startsNow =
          job.status === "pending" &&
          !(
            step.status === "skipped" ||
            (step.status === "failed" &&
              !step.agentId &&
              job.agent !== "orchestrator")
          );
        if (startsNow) applyStart(ledger, step.job, step.agentId);
        applyFinish(ledger, step.job, step.status, step.data);
      }
    }
    for (const step of steps)
      requireValue(
        !fs.existsSync(path.join(directory, `${step.job}.txt`)),
        `Output already recorded: ${step.job}`,
      );
    for (const step of steps)
      fs.writeFileSync(path.join(directory, `${step.job}.txt`), step.data, {
        flag: "wx",
      });
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
  for (const [id, line] of Object.entries(SKIPPABLE))
    if (ledger.jobs[id]?.status === "skipped")
      requireValue(
        reportText.split("\n").some((text) => text.trim() === line),
        `Report must state: ${line}`,
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
