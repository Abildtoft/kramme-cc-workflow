# Eval Scope Review: Testing the Revisit Condition

- Status: PROPOSED
- Date: 2026-08-08
- Deciders: repository maintainers

## Context

The [skill quality regime](2026-07-06-skill-quality-regime.md) record capped committed eval investment at the `kramme:skill:review` pilot and set its own revisit condition under [Consequences](2026-07-06-skill-quality-regime.md#consequences):

> Revisit this ADR only when a candidate skill has deterministic fixtures, false-positive cases, and a candidate gate that meet the existing SkillOpt expansion criteria.

Nobody had attempted to build that evidence. The cap was therefore holding by default rather than by re-decision, and the repository could not tell whether it was a well-founded position or an unexamined one. This record supplies the missing evidence for the first-named candidate.

Coverage as of 2026-08-08: 113 skill directories, one with a committed behavioral eval. 34 skills declare `disable-model-invocation: false` and nothing tests whether a given prompt selects the intended skill.

The cap applies to _committed_ artifacts. Prototyping under `.context/` is permitted — the capping record's [Post-Model-Upgrade Smoke Ritual](2026-07-06-skill-quality-regime.md#post-model-upgrade-smoke-ritual) itself directs scratch work to "a scratch record under `.context/model-upgrade-smoke/<date>/`", and the expansion criterion "The SkillOpt runner can keep generated output under `.context/`" in [Expansion Criteria](../../evals/skillopt/README.md#expansion-criteria) treats that as the expected shape for a candidate runner. Without that reading the revisit clause is unsatisfiable: it asks for fixtures as evidence while forbidding committed fixtures before a decision.

### Refreshed usage evidence

`node kramme-cc-workflow/scripts/skill-usage.js report --since 90d` and the same command with `--since 30d`, both run 2026-08-08:

| Skill | 90d uses (sessions) | 30d uses (sessions) | Last used | 2026-07-06 90d |
| --- | --: | --: | --- | --: |
| `kramme:pr:resolve-review` | 230 (194) | 8 (7) | 2026-07-18 | 204 |
| `kramme:skill:review` | 196 (191) | 1 (1) | 2026-07-25 | 195 |
| `kramme:pr:code-review` | 73 (62) | 23 (21) | 2026-08-05 | 44 |
| `kramme:pr:rebase` | 42 (29) | 8 (6) | 2026-08-06 | 34 |
| `kramme:code:agent-readiness` | 41 (32) | 4 (4) | 2026-07-26 | 31 |

The 90-day ordering of the first two candidates in the "next candidate skills" list under [Expansion Criteria](../../evals/skillopt/README.md#expansion-criteria) still holds; the third, `kramme:session:automate-repeats`, has no recorded usage in either window. The 30-day window diverges: `kramme:pr:code-review` leads it, and `kramme:pr:resolve-review` has not been used since 2026-07-18. Recorded, not acted on — this record does not re-rank the candidate order.

### What was prototyped

Scratch work lives at `.context/eval-scope-review/2026-08-08/` (untracked by design; see `NOTES.md` there for the layout and reproduction commands). It contains seven synthetic fixtures split 3/2/2 across train/val/test, an items schema adapted from the pilot's (one field renamed, one dropped, `diff_expectations` added; not a superset), and a scorer that requires the committed `evals/skill-review/scorer.js` for the text channel and adds a diff channel.

The fixtures model the five hard cases [Expand SkillOpt as QA](2026-07-06-skill-quality-regime.md#expand-skillopt-as-qa) named for this skill: review parsing, action-class gates, code edits, validation, and false positives.

Four synthetic resolver outputs were scored against them. `make-predictions.js` generates the first three; `wrong-fix.json` is hand-authored and has no generator, so a from-scratch rebuild reproduces three of the four. All four emit byte-identical review text; they differ only in what they did to the code.

| Resolver | Behavior | `text_hard` | `diff_hard` |
| --- | --- | --: | --: |
| `ideal` | correct resolution on all seven items | 1.00 | 1.00 |
| `churner` | implements the manual finding, edits a test to match its own fix, narrows a scope constant, deletes the "dead" export | 1.00 | 0.29 |
| `lazy` | changes nothing at all | 1.00 | 0.57 |
| `wrong-fix` | answers findings with bare comments in three files, one of which covers two findings; inverts the off-by-one; resolves one item correctly | 1.00 | 0.86 |

## Assessment Against the Expansion Criteria

The Criterion column below is shorthand, in the order the criteria appear under [Expansion Criteria](../../evals/skillopt/README.md#expansion-criteria); the wording there is canonical. Criterion 4 is quoted verbatim because its verdict turns on the exact wording.

| # | Criterion | Verdict | Reasoning |
| --- | --- | --- | --- |
| 1 | Usage or impact justifies the maintenance cost | Pass | Highest blast radius in the catalog: the [Risk Table](2026-07-06-skill-quality-regime.md#risk-table) notes a regression costs "one real PR branch" including incorrect source changes and a bad force-push. 90-day usage still ranks first. The 30-day decline weakens the usage half of the argument but not the impact half. |
| 2 | Output is checkable with deterministic fixtures | Fail | The decisive result. `wrong-fix` — which answered findings with bare comments in three files instead of fixes and inverted an off-by-one — scored `text_hard` 1.00 and `diff_hard` 0.86. It was caught on exactly one item, the only one carrying an executable behavior probe (`page([1,2,3,4,5], 1, 2)` returned `[1,2,3]` instead of `[1,2]`). Checking that a fix is _correct_, rather than that a file was _touched_, requires each fixture to be a runnable miniature repository with its own test suite. That is the "closer to an integration test matrix than a prompt fixture split" cost [Expand SkillOpt as QA](2026-07-06-skill-quality-regime.md#expand-skillopt-as-qa) predicted for `kramme:pr:rebase`; it applies here too. |
| 3 | Distinct train/val/test items; test items not used for tuning | Pass | Seven distinct items across a 3/2/2 split with no fixture shared between splits. Nothing about this skill obstructs split hygiene. |
| 4 | Fixtures include false-positive cases so optimization cannot win by reporting more findings indiscriminately | Fail | Under a stricter reading than the criterion's wording requires. As written the criterion is met: three false-positive fixtures were built and `churner`, the indiscriminate actor, fails all three (its 0.29 is the aggregate across all seven items, and it also fails the action-class and validation items). This record fails it anyway, because for a skill whose output is a patch, adversaries that only punish over-action do not deliver what the criterion exists to buy. They do not catch inaction: `lazy` scored a perfect 1.00 on every false-positive item, because "did not edit `src/total.js`" is precisely what a correct resolver does there. Restraint and inertia are the same shape on the diff channel, and the text channel cannot separate them because any resolver can emit the right words. On the validation item, `lazy` claimed "Implemented the throw, but validation failed" while changing nothing, and scored perfectly. |
| 5 | Generated output stays under `.context/`, never `skills/**` | Pass | The prototype's generated output stays under `.context/`, and it applies candidate edits in an OS temporary directory rather than in place. Verified: `kramme-cc-workflow/skills/` and `kramme-cc-workflow/evals/` are both clean. A path-scoped status check on `.context/` proves nothing here, because that path is excluded per-clone via `.git/info/exclude` rather than the committed `.gitignore`. |
| 6 | A candidate gate runs contracts, tests, static checks, and evals | Fail | No gate was built, and building one is blocked on criterion 2: a gate whose eval step cannot distinguish a correct fix from a comment is a gate in name only. It would also need to execute per-fixture test suites, which do not exist. |
| 7 | The review packet supports accept, reject, or send back | Fail | Follows from criteria 2 and 4. A packet reporting `text_hard` 1.00 for all four resolvers is worse than no packet: it reads as "no regression" when one resolver deleted a live export and another rewrote a test to agree with its own fix. |

Three pass, four fail — criterion 4 on the stricter reading set out above.

### What did work

Review parsing and action-class routing are genuinely deterministic and non-subjective, and the committed phrase scorer handles them unmodified. The mixed-label fixture (`- Location:` / `**Location:**` / legacy `**File:**`, plus an already-`addressed` entry that must survive verbatim) and the action-class fixture (manual deferral carrying `Recommended resolution`, a process-level finding carrying `Process handoff`, an external-owner finding carrying `Waiting on` and no `To proceed`) all scored correctly. The gap is not the skill's instruction-following; it is that half this skill's output is a patch, and a phrase scorer cannot read a patch.

## Decision

**Recommended: reaffirm the cap, with a dated review trigger.**

`kramme:pr:resolve-review` does not meet the expansion criteria. Four of seven fail, but they do not carry equal weight. Criterion 2, deterministic checkability, fails on its own terms and is the one that decides the answer. Criterion 4 fails only on the stricter reading argued above; on the canonical wording it passes. Criteria 6 and 7 are consequences of those two rather than independent failures. Even taking criterion 2 alone, expanding on this evidence would buy a green number that does not mean what it appears to mean.

This is a re-decision, not a continuation. The cap in [Decision](2026-07-06-skill-quality-regime.md#decision) stands, and the original record is unchanged. What changes is that it now rests on tested evidence rather than on an untested assumption.

Next review: 2027-02-08, or earlier if `node kramme-cc-workflow/scripts/skill-usage.js report --since 30d` puts `kramme:pr:resolve-review` above 30 in the `Total` column, restoring the usage half of criterion 1. It reads 8 today.

The only thing that would change the answer is a fixture design that verifies fix _correctness_ without requiring a runnable test suite per fixture. None is in view, and no schedule would surface one, so it is recorded here as the blocker to watch rather than as a review trigger that nobody would ever check.

Reaffirming on the same unsatisfiable condition would recreate the exact failure this record exists to correct.

### Open question for the maintainer

Does the cap govern trigger-selection evaluation, or only behavior-under-model-upgrade evaluation?

The cap names "skill-behavior eval directories, splits, adapters, or candidate gates." The record's entire risk analysis (its [Risk Table](2026-07-06-skill-quality-regime.md#risk-table)) and its alternatives analysis concern behavioral regression under model upgrades. Selection accuracy — whether the right skill fires for a given prompt — is never mentioned. It was not in view when the decision was made, and is neither permitted nor forbidden.

This record does not resolve it, and deliberately sets no interim default either way — a rule reachable only from this paragraph would bind readers who never find it. A ruling should be recorded, because 34 skills are auto-selected from description text today with no committed check that selection works.

## Alternatives Considered

### Expand the cap by one named skill

Rejected on the evidence. Expanding the cap by one named candidate is the option this record set out to test, and it was conditional on the prototype meeting the criteria. It did not.

### Replace the numeric cap with a criteria-based gate

Rejected as premature. A criteria-based gate is only as good as the criteria, and this exercise found that criterion 2 is harder to satisfy than the criteria list implies for any skill whose output includes a patch. Rewriting the cap before that is understood would trade a bounded commitment for an unbounded one.

### Narrow the target: eval the annotation output, not the code edits

The most interesting alternative, and not recommended yet. A committed eval scoring only `kramme:pr:resolve-review`'s lifecycle annotations — action-class routing, field placement, verbatim preservation of unprocessed entries, `Waiting on` versus `To proceed` selection — would pass criterion 3 on the prototype evidence, and that half of the output is text the committed scorer already handles.

Criteria 2, 4, and 7 are untested for this narrower target and should not be assumed. No resolver in the prototype attacked the text channel — all four emit byte-identical review text, so the scorer was never shown rejecting a wrong annotation. The prototype's false-positive adversaries attack the diff (act when you should not); an annotation-only eval needs adversaries that attack the text, such as a resolver that attaches `Recommended resolution` to a finding that needs no decision. Those fixtures were not built.

It is not recommended now for two further reasons. It would create a committed eval that is silent on the skill's highest-risk behavior, which invites exactly the misreading criterion 7 warns about; and much of what it would check is static enough that a contract lint may cover it more cheaply. Worth revisiting at the 2027-02-08 review, and sooner if the planned routing-distinctness lint ships and its coverage becomes measurable.

## Consequences

Positive:

- The prototype is reusable while `.context/` survives (see the decay caveat below). A future attempt starts from seven fixtures and a scoring design with a known failure mode, not from zero, though the hand-authored `wrong-fix.json` does not regenerate.
- The failure was localized. "Resolve-review is not checkable" is too coarse; the annotation half scores correctly on correct outputs and the patch half does not, which is what makes the narrowed alternative worth keeping on the table.
- Under the practice-arena model in [0001. Audience model](0001-audience-model.md#decision), running the revisit condition and reporting a negative result is the exercise, not overhead.

Negative:

- `kramme:pr:resolve-review` keeps the largest blast radius in the catalog with no committed behavioral eval, and this record extends that state by up to six months.
- Trigger selection for 34 auto-invocable skills stays unmeasured pending the ruling above.
- The prototype is untracked, so it decays. If `.context/` is cleared, the next attempt repeats the build. That is the cost of the cap's own structure.

Follow-up:

- Maintainer rules on whether trigger-selection evaluation falls under the cap; record the ruling.
- Related work planned but not started, requiring no amendment: a routing-distinctness lint targeting `scripts/lint_skill_contracts/`. As of 2026-08-08 no such check exists there. It would be static metadata checking in the layer [Context](2026-07-06-skill-quality-regime.md#context) explicitly keeps — Bats/Node/Python/shell checks and `scripts/lint-skill-contracts.py` — so it falls outside this cap, and it would close the description-overlap half of the routing-quality problem without an eval. If it lands and its warning output becomes measurable, that output is a useful input to the narrowed-target alternative above.
