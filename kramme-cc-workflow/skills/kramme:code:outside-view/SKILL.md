---
name: kramme:code:outside-view
description: "Rate the codebase from the outside view. Fans out unprimed raters that deliberately skip project instructions, rubrics, and prior reports before forming an impression, collects free-form scores and complaints, clusters them, diffs the clusters against the latest CODEBASE_WEAKNESS_REPORT.md to expose rubric blind spots, and tracks the gestalt score across runs in OUTSIDE_VIEW_REPORT.md. Cross-model rating is an explicit opt-in and runs only through a verified isolated profile. Use to surface unknown-unknown quality issues that structured audits filter out — especially in primarily AI-engineered codebases where author and reviewer share the same taste. Not for ranked evidence-backed findings (use kramme:code:weakness-audit), PR review, or implementation."
argument-hint: "[--raters N] [--output <path>] [--compare <report-path>] [--cross-model]"
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code, codex]
---

# Outside-View Codebase Rating

Elicit unprimed, frame-diverse judgments of the codebase, then synthesize them into complaint clusters, a delta against the latest structured weakness audit, and a gestalt trend across runs.

**Arguments:** "$ARGUMENTS"

**What it touches:** writes one report file, `OUTSIDE_VIEW_REPORT.md` by default. Read-only otherwise. Do not modify implementation code.

## Why This Skill Exists

Structured audits measure conformance to a rubric, and heavily AI-engineered codebases optimize hard toward whatever is measured, so residual defects concentrate in the unmeasured directions. This skill is the counterweight:

- **Elicitation is separated from filtering.** Raters record everything they notice; triage happens later, in a different context, and labels rather than drops.
- **Raters stay outside the frame.** They form impressions before reading the project's instruction files, ADRs, or glossaries, so the project's self-image cannot constrain what they see.
- **The delta is the product.** What the naive pass surfaces that the structured audit filtered or never saw is either noise or a rubric blind spot — and recurring blind spots become amendments to the structured system.

## Inputs

- **Rater count**: optional `--raters N`. Default is `4` in-repo raters. Reject values below `3` or above `6`; the persona pool and rotation contract do not support larger runs.
- **Output path**: optional `--output <path>`. Default is `OUTSIDE_VIEW_REPORT.md` in the project root. Refuse paths outside the working tree unless the user explicitly confirms the exact resolved destination.
- **Comparison report**: optional `--compare <report-path>`. Default is `CODEBASE_WEAKNESS_REPORT.md` in the project root when it exists; skip the delta step when no comparison report is available.
- **Cross-model rater**: disabled by default. Enable it with the explicit repository-scoped opt-in `--cross-model`; the run still skips the rater unless a different model family and a verified isolation profile are available.

## Workflow

### 1. Minimal Orient

This step is deliberately shallow. The orchestrator must stay outside the project's frame until synthesis.

1. Parse arguments into `RATER_COUNT`, `OUTPUT_PATH`, `COMPARE_PATH`, and `CROSS_MODEL`. Reject the run when `RATER_COUNT < 3` or `RATER_COUNT > 6`.
2. Resolve the canonical working-tree root and validate `OUTPUT_PATH` before reading it:
   - Reject an existing output that is a symlink or is not a regular file.
   - Reject any existing symlink in its parent path.
   - Resolve the parent directory and require the destination to remain under the canonical working-tree root unless the user explicitly confirms the exact resolved outside path.
3. If a previous report exists at `OUTPUT_PATH`, read only its `Run History` section and the persona ids used in the most recent run. Do not read its clusters or findings yet.
4. When `--cross-model` is present, determine `HOST_MODEL_FAMILY` from the active runtime, then follow the capability and isolation gates in `references/personas.md`. Never treat an available CLI as proof of a different model or a safe execution boundary.
5. Do **not** read `CLAUDE.md`, `AGENTS.md`, ADRs, glossaries, audit rubrics, or prior audit reports in this step. The comparison report is read only in step 5.

### 2. Select Raters

Read `references/personas.md`, then assemble the rater set:

1. Rater 1 is always the bare probe, verbatim.
2. Fill the remaining `RATER_COUNT - 1` slots from the persona pool, following the rotation rules: overlap with the previous run's persona set by at most one persona, and paraphrase every seed prompt.
3. If the opt-in cross-model candidate passed every gate in `references/personas.md`, add one extra cross-model rater that runs the bare probe. It does not count against `RATER_COUNT`.

### 3. Elicit

Run each rater in a fresh subagent context with only its persona frame and the elicitation contract below. Run raters concurrently when subagent execution is available; otherwise run them sequentially, each starting from a clean context, and record reduced isolation in the report. Never show one rater another rater's output, prior reports, or any hint of expected findings.

Every rater receives this contract in addition to its frame:

- Explore the code first. Do not open agent instruction files (`CLAUDE.md`, `AGENTS.md`, `.cursorrules`, ADR directories, glossaries) or report artifacts until your impression is formed; afterward you may skim them only to note whether the project already knows about a problem you found.
- There is no rubric. Say what you actually notice, in plain language. Holistic complaints ("this feels over-engineered") are welcome; concrete examples are encouraged but file:line evidence is not required.
- Return: a score from 1–10 with a one-line justification; 3–7 complaints; the one sentence you would tell the codebase owner; and up to 3 genuine strengths.
- After your impression is formed, list what you actually looked at — directories, files, and docs — so the report can record your footprint. Be honest about how far you got; a narrow footprint is normal and will not be judged.

Run the cross-model rater only through the verified isolation profile selected in `references/personas.md`. Give it the same elicitation contract as every other rater. Never invoke a raw model CLI from the repository root. If the profile is unavailable, the CLI fails, or the output is unusable, record the reason and continue without that rater.

Before clustering or writing, require at least 3 successful, parseable in-repo raters. Cross-model results do not count toward this quorum. Below quorum, list every failure and stop without overwriting `OUTPUT_PATH`. Compute means, support counts, and majority thresholds from successful, parseable raters only.

### 4. Cluster

Elicitation is now over; synthesis begins. The orchestrator:

1. Clusters complaints by underlying issue, even when raters use different wording. Do not merge complaints that merely sound similar but name different root causes.
2. Assigns each cluster a run-local id `OV-001`, `OV-002`, ... sorted by support count, then by severity of language.
3. Assigns a durable fingerprint from the normalized root cause. Reuse a prior Run History fingerprint when its recorded title describes the same underlying issue.
4. Labels each cluster `consensus` (strict majority of successful raters), `split` (any non-majority multi-rater cluster, whether other raters are silent or disagree), or `single-voice` (exactly one supporting rater).
5. Drops nothing. Every complaint lands in exactly one semantic cluster, and the report preserves representative verbatim evidence for each cluster.

### 5. Delta Against the Structured Audit

Only now does the orchestrator enter the project's frame.

1. If `COMPARE_PATH` exists, read it and classify every cluster:
   - **covered** — matches an active ranked finding.
   - **filtered** — matches a filtered candidate, near miss, or unverified impression.
   - **blind spot** — absent from the comparison report entirely.
2. Using the complete blind-spot fingerprint list in `Run History`, count how many consecutive runs each current blind-spot fingerprint has appeared in.
3. For every blind spot recurring in 2 or more runs, emit a **promotion candidate**: name the concrete place the pattern should be encoded — a weakness-audit rubric signal, a deslop pattern, a lint or CI gate, or a documentation fix. Promotion always targets the structured system, never this skill's rater prompts.
4. If no comparison report exists, mark the delta section `no comparison available` and recommend running `/kramme:code:weakness-audit` before the next outside-view run.

### 6. Write Report

1. Read `assets/report-template.md`.
2. Carry the previous report's `Run History` forward verbatim and append a row for this run (date from `date +%F`, mean score, per-rater scores, top clusters, every blind-spot `fingerprint: title`, persona ids, and model diversity).
3. Summarize rater footprints in Coverage Notes: what each rater reported examining, and which top-level areas of the repository no rater visited. Footprints are self-reported after the fact — never assign areas to raters, and never mark a run as complete coverage; the footprint exists so the reader can judge how much weight the run deserves.
4. Repeat the canonical containment, parent-symlink, leaf-symlink, and regular-file checks from step 1 immediately before writing. Stop without changing the existing report if any check fails.
5. Write the report to `OUTPUT_PATH`, overwriting the previous report.

### 7. Summarize

Reply with:

- report path
- mean score and spread, plus the trend against previous runs when history exists
- top 3 complaint clusters
- blind-spot count and any promotion candidates
- model diversity status (which alternative model rated, or none)
- footprint breadth: which areas raters examined and which areas no rater visited
- degraded modes: sequential elicitation, failed raters, missing comparison report

## Artifact Lifecycle

- **Produces/updates:** `OUTSIDE_VIEW_REPORT.md` by default, or the path passed with `--output`. The report carries its own run history forward across overwrites.
- **Consumed by:** the user for entropy tracking; `/kramme:code:weakness-audit` runs that act on promotion candidates; future outside-view runs for persona rotation and recurrence counting.
- **Refresh trigger:** re-run on a regular cadence (after a merge cycle or before a maintenance cycle), and after acting on promotion candidates to confirm the blind spot closed.
- **Retired by:** `/kramme:workflow-artifacts:cleanup` when the report is no longer useful, or manual deletion.

## Discipline

- **The bare probe stays bare.** Never add hints, categories, or past findings to any rater prompt. When a discovery deserves enforcement, promote it into the structured system and leave this skill's prompts untouched — a codified probe stops detecting unknown unknowns.
- **Elicitation filters nothing.** Evidence bars, convention checks, and ADR constraints belong to the structured audit. Here they would kill the signal before it is recorded.
- **Rotate and paraphrase personas every run** so successive runs do not converge on a de facto checklist.
- **Never argue with a rater** or re-run one because its answer looks wrong. A misinformed complaint is data about first-contact comprehension.
- **Footprints are recorded, never assigned.** Use them to weight a run's conclusions, not to direct the next run's raters toward unvisited areas; coverage accumulates through persona rotation and cadence, not through targeting.
- **Track the trend, not the number.** A single score is nearly meaningless; movement in the score and churn in the complaint clusters across runs are the signal.
- **Prefer paired runs.** The delta against a fresh `CODEBASE_WEAKNESS_REPORT.md` is where rubric blind spots become visible; an unpaired run is a health ping, not an audit.
