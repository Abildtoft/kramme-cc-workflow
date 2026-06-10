---
name: kramme:code:optimize
description: "(experimental) Run metric-driven optimization experiments. Use when search relevance, clustering quality, prompt quality, build latency, ranking behavior, bundle size, or another measurable outcome needs repeatable variants instead of sequential guess-and-check. Requires a measurement command or judge rubric, persists baselines and experiment logs under `.context/code-optimize/`, and can use serial or worktree-isolated experiments. Not for ordinary one-shot performance fixes, implementation without a harness, or speculative optimization with no metric."
argument-hint: "[spec.yaml | optimization goal] [--auto]"
disable-model-invocation: true
user-invocable: true
---

# Measured Optimization

Run metric-driven optimization loops for problems where several plausible variants should be tested against the same repeatable harness. This skill defines a spec, records a baseline, runs experiments, writes every result to disk, keeps winners, rejects losses, and preserves enough state to resume after context compaction.

## Inputs

1. Parse `$ARGUMENTS`.
   - A path ending in `.yaml` or `.yml` means read and validate that spec.
   - Any other text is an optimization goal; convert it into a spec with the user.
   - `--auto` may choose conservative defaults and continue through non-destructive steps, but it must not push, open PRs, delete experiment logs, approve first-run measurement commands, approve new dependencies, ignore dirty in-scope files, or run with uncapped judge cost.

2. If no input is present, ask what outcome should be optimized and whether the user already has a measurement command.

3. Read the schema from `references/optimize-spec-schema.yaml` before validating or drafting a spec.
   - Start from `references/example-hard-spec.yaml` when the target is an objective scalar metric.
   - Start from `references/example-judge-spec.yaml` when real quality requires semantic judgment.
   - Read `references/usage-guide.md` when the user is deciding between hard metrics and judge mode.

Boundary with `kramme:code:performance`: repeatable harness-driven experiments belong here; one-shot review-and-fix performance passes without a variant harness belong to `kramme:code:performance`.

## Hard Stops

Stop and ask for the missing requirement before experiments run when any condition is true:

- `measurement.command` is empty.
- `metric.primary.type` is `judge` and `metric.judge.rubric` or `metric.judge.scoring.primary` is missing.
- No degenerate gates are defined.
- `scope.mutable` or `scope.immutable` is empty.
- In-scope mutable or immutable files have uncommitted changes.
- The measurement command does not output parseable JSON with the required gate and diagnostic keys.
- The first-run measurement command has not been explicitly approved after showing the command, working directory, timeout, environment variables, and spec source.
- Judge mode has `max_total_cost_usd: null` and the user has not explicitly approved uncapped spend.
- Any experiment requires an unapproved dependency.

## Artifact Layout

Use `.context/code-optimize/<spec-name>/` for local scratch state. These files are gitignored and are the source of truth for the optimization run:

| File | Purpose |
| --- | --- |
| `spec.yaml` | Approved optimization spec, written at setup |
| `experiment-log.yaml` | Append-first history of baseline, hypotheses, experiment results, outcomes, and current best |
| `strategy-digest.md` | Compact learning summary used to generate later hypotheses |
| `experiments/<iteration>/result.yaml` | Crash-recovery marker for a measured experiment |

Use `references/experiment-log-schema.yaml` when writing or validating `experiment-log.yaml`.

## Workflow

### 1. Set Up Spec

1. Classify the goal as hard-metric or judge-based:
   - Use `hard` when better is a scalar number: latency, bundle size, build time, memory, test pass rate, throughput.
   - Use `judge` when a proxy metric can be gamed or human usefulness matters: search relevance, cluster coherence, summary quality, prompt quality, recommendation relevance.
2. Draft or validate the spec:
   - `name` must be lowercase kebab-case and safe for branch/worktree names.
   - `metric.primary.direction` must be `maximize` or `minimize`.
   - Degenerate gates must use one of `>=`, `<=`, `>`, `<`, `==`, `!=`.
   - First-run defaults should be serial: `execution.mode: serial`, `execution.max_concurrent: 1`, `stopping.max_iterations: 4`, `stopping.max_hours: 1`.
3. Check for existing artifacts:
   - If `.context/code-optimize/<spec-name>/spec.yaml` exists and matches the incoming spec, continue with that spec.
   - If it exists and differs, stop and ask whether to resume with the existing spec, write a new spec name, or archive the existing directory.
   - If `spec.yaml` exists but `experiment-log.yaml` does not, treat the directory as partial setup; verify the spec and continue from measurement validation without deleting files.
   - If `experiment-log.yaml` exists, use the Resume workflow before any new writes.
4. Write `spec.yaml` to `.context/code-optimize/<spec-name>/spec.yaml`, then read it back and confirm the expected `name`, metric, measurement command, and scope are present before continuing.

### 2. Validate Measurement

1. Resolve `SKILL_DIR` to this skill's directory.
2. Before the first measurement run, present the measurement execution boundary:
   - spec source path or "drafted in this session",
   - `measurement.command`,
   - `measurement.working_directory`,
   - `measurement.timeout_seconds`,
   - any environment variables that will be passed,
   - whether the command came from a pasted/provided spec.

   Require explicit user approval before running it. `--auto` must not bypass this approval; it may only continue after approval has been recorded in the conversation or existing log.

3. Run the measurement helper from the user's repo root:

   ```bash
   "$SKILL_DIR/scripts/measure.sh" "<measurement.command>" "<timeout_seconds>" "<measurement.working_directory>"
   ```

4. Parse stdout as JSON. Confirm it includes:
   - every degenerate gate metric,
   - every diagnostic metric,
   - the hard primary metric when `metric.primary.type: hard`.
5. If `measurement.stability.mode: repeat`, run the helper `repeat_count` times, aggregate with the configured method, and record variance. Treat improvements smaller than `noise_threshold` as noise.
6. Run the parallelism probe before parallel experiments:

   ```bash
   "$SKILL_DIR/scripts/parallel-probe.sh" "$PWD" "<measurement.command>" "<measurement.working_directory>" <parallel.shared_files...>
   ```

   Use its output as advisory. Shared databases, hardcoded ports, lock files, and exclusive accelerators usually mean serial mode or per-experiment parameterization.

7. If `parallel.shared_files` includes sensitive files such as `.env`, credentials, databases, or private fixtures, present the list and require explicit approval before creating worktrees. Shared file paths must be relative repo paths; parent traversal and absolute paths are unsupported.

### 3. Record Baseline

1. Run the measurement command on the current code.
2. If judge mode is enabled, run baseline judge evaluation using `references/judge-prompt-template.md` after all degenerate gates pass.
3. Initialize `experiment-log.yaml` with:
   - `spec`,
   - `run_id`,
   - `started_at`,
   - `baseline`,
   - `experiments: []`,
   - `best` seeded from the baseline,
   - `hypothesis_backlog: []`.
4. Write the log, read it back, and verify baseline values before showing baseline results to the user.
5. Present the baseline, log location, parallel-readiness result, worktree budget, and judge cost cap. Do not proceed to hypotheses until approved unless `--auto` is present and all costs are capped, all paths are clean, and the first run is serial.

### 4. Generate Hypotheses

1. Read mutable-scope code and the approved spec.
2. Generate 10-30 hypotheses when possible, grouped by categories such as signal-extraction, algorithm, preprocessing, parameter-tuning, architecture, data-handling, ranking, prompt, or domain-specific categories.
3. Collect required new dependencies. Ask for approval before any experiment may use them.
4. Write `hypothesis_backlog` to `experiment-log.yaml`, then read the file back and verify the backlog before dispatching work.

### 5. Run Experiments

1. Select the next batch:
   - serial mode always selects one runnable hypothesis,
   - parallel mode selects at most `execution.max_concurrent`,
   - skip hypotheses with unapproved dependencies.
2. For each experiment:
   - For worktree isolation, run `"$SKILL_DIR/scripts/experiment-worktree.sh" create <spec-name> <iteration> <base-branch>`.
   - Pass only explicitly approved `parallel.shared_files` to the worktree helper. The helper does not copy `.env*` files implicitly.
   - Fill `references/experiment-prompt-template.md` with the hypothesis, current best, baseline, allowed mutable scope, immutable scope, constraints, approved dependencies, and last 10 experiment summaries.
   - Dispatch a worker to implement only the hypothesis. The worker must not modify the harness, run final measurements, or commit.
3. Measure each completed experiment immediately.
4. Write `experiments/<iteration>/result.yaml` immediately after measurement.
5. Append the experiment entry to `experiment-log.yaml` with outcome `measured`, then read the log back and verify the entry before processing the next experiment.
6. Evaluate gates:
   - Any failed degenerate gate produces outcome `degenerate`.
   - Measurement crashes or malformed JSON produce `error`; timeouts produce `timeout`.
   - Judge mode only runs after all degenerate gates pass.
7. Rank passing experiments by the primary metric direction. For hard metrics, require improvement beyond `measurement.stability.noise_threshold`; for judge metrics, require `metric.judge.minimum_improvement`.

### 6. Keep, Combine, or Reject

1. Keep the best improving experiment:
   - Commit only mutable-scope changes on the experiment branch.
   - Merge or cherry-pick the winning commit into the optimization branch.
   - Update `best` in `experiment-log.yaml`.
2. Evaluate file-disjoint runners-up up to `max_runner_up_merges_per_batch`:
   - Disjoint means completely different modified files.
   - Cherry-pick one runner-up at a time and re-measure the combined state.
   - Keep only if the combined measurement is strictly better; otherwise revert and log `runner_up_reverted`.
3. Reject non-improving experiments and clean up their worktrees.
4. Write finalized outcomes and the updated `best` section to disk, then verify the write.

### 7. Update Strategy and Stop Criteria

1. Write `strategy-digest.md` after every batch:
   - categories tried,
   - successes and failures,
   - current best metrics,
   - improvement from baseline,
   - learnings and remaining frontier.
2. Read the digest back before generating new hypotheses. Do not rely on conversation memory.
3. Stop when any criterion is met:
   - target reached,
   - max iterations,
   - max hours,
   - judge cost cap,
   - plateau iterations,
   - empty runnable backlog,
   - user interruption.

## Resume

When `.context/code-optimize/<spec-name>/experiment-log.yaml` exists:

1. Read the log from disk first.
2. Scan `experiments/*/result.yaml` for measured results not reflected in the log.
3. Recover missing measured entries before selecting new hypotheses.
4. Confirm the log's `spec` value matches `<spec-name>`. If a new incoming spec was supplied and differs from the existing `spec.yaml`, stop and ask whether to resume the existing run, create a new spec name, or archive the old directory.
5. Continue from the last finalized `best` and the current backlog.

## Wrap-Up

Before declaring the optimization complete:

- Write the final `experiment-log.yaml` state and verify it.
- Summarize baseline to final metrics, total experiments, kept/reverted/degenerate/error/deferred counts, judge cost, and winning changes.
- Preserve the optimization branch and local log for manual review.
- Offer follow-up verification with `kramme:verify:run` and review with `kramme:pr:code-review`.
- Do not push, create a PR, or delete the experiment log from this skill.
