# Route Review Convergence Depth by the Deterministic Risk Floor

- Status: ACCEPTED
- Date: 2026-10-20
- Deciders: repository maintainer (explicit implementation request)
- First adoption review: 2027-01-20

## Context

`kramme:linear:issue-to-pr` and `kramme:code:plan-to-pr` delegate review to `kramme:pr:review-convergence`, which ran the same gates at the same depth on every branch. On 2026-10-20 the maintainer asked how simple Pull Requests could get through review faster and with fewer tokens. A measurement of the 38 Claude Code runs of those two workflows recorded between 2026-10-06 and 2026-10-20 (17 `issue-to-pr`, 21 `plan-to-pr`) found:

- **Review dominated.** The review phase took a median 11.3M weighted tokens (input + 1.25 × cache write + 0.1 × cache read + 5 × output), 83% of each run's tokens and 77% of its active time, about 14 times the implementation phase.
- **Small changes were not cheap.** Branches under 100 changed lines still took a median 7.1M weighted tokens, 37 active minutes, and 24 agents, about a third of a 300-line branch. Cost tracked remediation cycles, main-thread turns, and agent count (rank correlation about 0.8), not diff size (0.39).
- **Re-review was most of the cost.** Initial passes were 29% of gate tokens; confirmation passes were 36%, delta rounds 18%, post-CI validation-only passes 9%, and repeats or retries 8%.
- **Advisory fixes bought extra rounds.** Seven runs opened fix cycles without fixing a single Critical, Important, or `OVERDONE` finding; re-review took 57M of their 102M review tokens.
- **Some gates rarely changed code.** Convention review took 14% of review tokens and produced about 3% of fixes, none on small branches; about 70% of its cost came from reruns.
- **plan-to-pr ran long loops.** Every run with three or four cycles was `plan-to-pr`, which forwarded no budget and so received convergence's ceiling of five.
- **Orchestration was about half of small-branch cost.** Main-thread turns and per-gate wrapper agents re-read large contexts; the plugin's own `block-rm-rf` hook refused 172 instructed or improvised `rm -rf` cleanups.
- **The first pass delivered the value.** On low-risk branches the real fixes came from the first code-review pass. The one serious catch on a tiny branch, a production key exposed to third-party CI runners, came from a `.github/workflows/` change that the deterministic triage floor already rates high.

Replaying the measured per-gate costs of the 13 Pull Requests whose committed diff scores a `low` floor, keeping their first-pass gut check, code review, overengineering review, and one post-fix code review, gave 164M → about 68M weighted tokens (−59%) and roughly 42 → 21 active minutes. The [risk triage record](2026-09-28-pr-risk-triage.md) deliberately left automatic routing to its own decision; this is that decision for review convergence.

## Decision

Review convergence chooses a **review profile** from evidence the branch cannot argue down, and the profile decides which gates run and how a fix batch is checked.

- **Deterministic floor.** `scripts/convergence-state.py profile` runs the plugin's `risk-signals.py` over the committed branch, reads repository policy only from the default branch, and maps the floor without discounts: `low` → `light`, `medium` → `balanced`, `high` → `full`. `--strict` selects `full`; `--depth balanced|full` raises the profile; the orchestrator raises it with recorded evidence when it accepts a Critical finding or sees risk the paths could not. A profile never lowers within a run. The helper moves from the triage skill to plugin-level `scripts/` because both skills now run it.
- **Gate sets.** `light` runs Gate 0, Gate 1 without the advisory cleanup dimensions, Gate 2 only on an explicit convention trigger, and Gate 3, and never runs the advisory refactor scan. `balanced` runs every gate by applicability except that Gate 2 needs a convention trigger. `full` keeps the previous applicability rules.
- **Loop shape.** `full` keeps the delta round and the full confirmation pass. `light` and `balanced` follow each fix batch with one full-scope closing pass that runs Gate 1 without cleanup dimensions plus only the gates the batch made relevant, and the loop closes on a pass that changes nothing.
- **Only required findings open a batch** in standard mode: an accepted Critical or Important finding, an accepted `OVERDONE` finding, or a verification failure. Advisory items may ride along in an open batch; otherwise they are deferred and reported.
- **Callers.** `kramme:code:plan-to-pr` forwards a two-cycle budget, matching `kramme:linear:issue-to-pr`, and gains `--cycles`; both callers accept `--depth` and forward the earlier profile to their post-CI validation-only pass so it never reviews more lightly. On hosts where a delegated agent may invoke skills and launch agents, both callers run convergence inside one delegated agent and pass `--isolated`, and convergence then runs its gates directly instead of wrapping each in its own agent.
- **Code-review bookkeeping.** The relevance and slop meta-review stages may be recorded as `skipped` when no finding reaches them, with `Skipped:` evidence and a matching report line the seal requires. `review-execution.js record --manifest` records a batch of jobs in one call. This amends the [review execution evidence record](2026-09-08-review-execution-evidence.md): every applicable reviewer still runs, and a skip launches no agent and needs evidence.
- **Cleanup.** Review instructions stop telling the model or its reviewers to delete scratch directories with `rm -rf`.

Direct invocations of `kramme:pr:review-convergence` keep their five-cycle default and per-gate wrappers on hosts that nest agents.

## Consequences

- Low- and medium-risk branches skip work that rarely changed code, and every fix batch costs one closing pass instead of a delta round plus a confirmation pass.
- Some findings now reach the human reviewer instead of the loop. Reviewers are stochastic, and a few Important findings in the measured runs first appeared on a third or later pass; under `light` and `balanced` those surface in human review or in the closing pass when it runs.
- The floor has false negatives: risky logic outside recognizable paths scores `low`. `--depth full`, finding-driven raises, and repository policy in `.github/pr-risk.json` are the mitigations. Repositories whose Markdown carries behavior, such as this plugin's skills, score `low` for that Markdown unless their policy lists those paths.
- The convergence policy grows to describe three loop shapes, and callers gain one flag each. Codex keeps inline gates because every spawned agent opens its own thread.

## Alternatives Considered

### Let the model choose the depth

Rejected for the reason the triage record gives: branch content, commit messages, and Pull Request text are author-controlled and could argue a risky change into a light review. The model may only raise the profile.

### Skip code review on low-risk branches

Rejected. The first code-review pass found the real defects on low-risk branches; the waste came from later passes, advisory fixes, and low-yield gates.

### Keep the full confirmation pass for every profile

Rejected for `light` and `balanced`: it was the largest cost bucket, and on a small branch a full-scope closing pass already covers the batch and the tree.

### Default reviewers to a lower model class

Deferred. Reviewers stay on the orchestrator's model by default; `KRAMME_REVIEW_SUBAGENT_LEVEL=lower` remains the opt-in.

## Adoption Review

On 2027-01-20, re-measure the same two workflows with the same weighting and compare against the 2026-10-20 baseline: review-phase tokens and active minutes by profile, the profile distribution, cycles per run, validation-only cost, and how often human review or follow-up commits found defects on `light`-profile branches that a deeper profile would have caught.
