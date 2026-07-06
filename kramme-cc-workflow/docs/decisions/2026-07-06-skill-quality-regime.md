# Skill Quality Regime

- Status: ACCEPTED
- Date: 2026-07-06
- Deciders: repository maintainers

## Context

`kramme-cc-workflow` ships 108 prompt-based skills. Committed deterministic
behavioral evals currently cover exactly one skill: `kramme:skill:review`,
through `evals/skill-review/` and the constrained SkillOpt pilot documented in
`evals/skillopt/README.md`.

The other verification layers are valuable but do not generally exercise skill
behavior under a new generation model:

- Bats, Node, Python, shell, and type checks cover scripts, adapters, fixtures,
  and metadata contracts.
- `scripts/lint-skill-contracts.py` covers frontmatter, naming, references,
  platform filtering, and self-contained resource policy.
- SkillSpector covers static skill security risks, and semantic scanning is not
  part of the default gate.
- The default `make verify` path runs the `skill-review` fixture eval, but it
  does not run all top skills through a live model.

The 90-day local usage report on 2026-07-06 showed the top five skills as:

| Rank | Skill | 90-day uses | Sessions |
| --- | --- | ---: | ---: |
| 1 | `kramme:pr:resolve-review` | 204 | 176 |
| 2 | `kramme:skill:review` | 195 | 190 |
| 3 | `kramme:pr:code-review` | 44 | 36 |
| 4 | `kramme:pr:rebase` | 34 | 23 |
| 5 | `kramme:code:agent-readiness` | 31 | 24 |

## Risk Table

If a model-generation upgrade silently degraded behavior, these are the existing
signals and their damage window.

| Skill | Existing signal likely to catch a model-regression | Damage before signal |
| --- | --- | --- |
| `kramme:pr:resolve-review` | No committed behavioral eval. The narrow `pr code review exposes resolver readiness contract` Bats test checks that `pr:code-review` emits fields the resolver expects, and SkillSpector/static contracts can catch changed instructions, but a model regression in finding triage, action-class handling, or patch implementation is caught by the user, tests, CI, review, or a failed resolution run. | Potentially one real PR branch before detection. Because the skill can edit code and commit fixes, the damage can include incorrect source changes, reviewer time, and a bad force-push if later workflows push the branch. |
| `kramme:skill:review` | The only skill with a deterministic behavior harness and SkillOpt candidate gate. It can catch regressions when run in adapted/live prediction mode or as part of a candidate review. The default fixture eval validates the harness and fixture expectations, not every future model response. | If the live/adapted eval or smoke is skipped, the next skill audit may miss a bad skill or report false findings. Direct blast radius is review quality, with downstream risk if maintainers accept the bad review. |
| `kramme:pr:code-review` | No committed behavioral eval. The Bats resolver-readiness contract checks action-class output structure; script tests check diff/base helpers. Missing defects, hallucinated findings, weak severity, or poor evidence are caught by human review, resolver failure, later CI, or production fallout. | Potentially one or more PRs before detection. Damage is missed bugs, false-positive churn, or bad local review artifacts that mislead `pr:resolve-review`. |
| `kramme:pr:rebase` | No committed behavioral eval. Git itself, `--force-with-lease`, conflict markers, branch checks, user confirmation gates, and command-safety hooks catch some unsafe operations at runtime. They do not prove the model made the right semantic conflict choices. | Usually one branch/rebase attempt. Worst case is a semantically wrong conflict resolution that passes mechanically and is pushed after confirmation or dangerous `--auto` use. |
| `kramme:code:agent-readiness` | No committed behavioral eval. Static contracts catch metadata/resource problems; the user reads the generated `AGENT_NATIVE_AUDIT.md`. There is no deterministic score-quality check. | One inaccurate report before detection. Damage is bad prioritization and planning guidance; source code is not edited except for the report artifact. |

## Decision

Use **dogfooding-is-QA** as the skill-quality regime for prompt behavior.

The committed `evals/` investment is explicitly capped at the current
`kramme:skill:review` pilot:

- exactly one committed behavioral eval target: `evals/skill-review/`
- exactly one SkillOpt bridge: `evals/skillopt/` for `kramme:skill:review`
- zero additional committed skill-behavior eval directories, splits, adapters,
  or candidate gates until a future ADR changes this decision

The default quality signal for the rest of the skill catalog is maintainer
dogfooding plus lightweight post-model-upgrade smoke testing of the current top
N skills, where `N = 5`.

## Post-Model-Upgrade Smoke Ritual

After a model-generation upgrade that could affect skill behavior, run this
ritual before relying on the affected model for high-leverage skill work:

1. Refresh the top-five list:

   ```bash
   node scripts/skill-usage.js report --since 90d --json --limit 5
   ```

2. Create a scratch record under `.context/model-upgrade-smoke/<date>/`.
3. For each top-five skill, run one representative sandbox task and record:
   prompt, model/version if known, pass/fail, notable drift, and follow-up.
4. Treat any failed smoke on an editing or history-rewriting skill as a block on
   production use of that skill with the new model until the prompt, workflow,
   or model choice is adjusted.

For the 2026-07-06 top five, the smoke cases are:

| Skill | Smoke case |
| --- | --- |
| `kramme:pr:resolve-review` | Resolve a small structured local review in a disposable branch/worktree. Verify action-class gates, manual deferral, code edits, validation, and summary behavior. |
| `kramme:skill:review` | Run `make skill-eval-skill-review`, then perform one live review of a known good or intentionally flawed fixture skill and compare against expected rubric coverage. |
| `kramme:pr:code-review` | Review a small known diff. Verify scoped findings, evidence, no hallucinated file references, severity, and `Auto-resolution Readiness` output. |
| `kramme:pr:rebase` | Rebase a disposable branch with a simple conflict. Verify preflight, conflict summary, no unresolved markers, confirmation behavior, and `--force-with-lease` push gating. |
| `kramme:code:agent-readiness` | Run against this repo or a stable fixture repo. Verify evidence-backed dimension scores, no early return, and a prioritized plan that maps to observed files/config. |

## Alternatives Considered

### Expand SkillOpt as QA

Rejected for now.

`evals/skillopt/README.md` already defines the expansion criteria: high
usage/high impact, deterministic fixtures, distinct train/val/test splits,
false-positive cases, `.context/` output isolation, a candidate gate, and a
manual review packet.

The current top-five list does not make expansion free:

| Candidate | Criteria fit |
| --- | --- |
| `kramme:pr:resolve-review` | High usage and impact. Not ready because deterministic fixtures must model review parsing, action-class gates, code edits, validation, and false positives without rewarding broad churn. |
| `kramme:pr:code-review` | High usage and already named in the SkillOpt shortlist. Not ready because broad finding categories need a larger split and strong false-positive protection. |
| `kramme:pr:rebase` | High impact, but behavior depends on Git state, conflicts, and safety gates. A useful eval would be closer to an integration test matrix than a prompt fixture split. |
| `kramme:code:agent-readiness` | Medium impact and checkability is subjective. Deterministic score fixtures would need stable fixture repos and rubrics before optimization is credible. |

Expansion remains available later, but each added skill must first satisfy the
documented SkillOpt expansion criteria and come with its own deterministic split
and candidate gate.

## Consequences

Positive:

- Keeps committed eval maintenance size explicit and bounded.
- Avoids optimizing broad subjective workflows against weak or misleading
  fixtures.
- Makes model-upgrade risk visible through a repeatable smoke ritual.
- Preserves the existing SkillOpt pilot as the place to learn before scaling.

Negative:

- Most skill behavior regressions are still detected by dogfooding, not by CI.
- A model regression can affect at least one real task before detection when the
  smoke ritual is skipped or too narrow.
- High-leverage editing skills remain dependent on human judgment, tests, and
  review after they act.

Follow-up:

- Revisit this ADR only when a candidate skill has deterministic fixtures,
  false-positive cases, and a candidate gate that meet the existing SkillOpt
  expansion criteria.
