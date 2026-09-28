# Route Pull Request Review by an Advisory Risk Tier

- Status: ACCEPTED
- Date: 2026-09-28
- Deciders: repository maintainer (explicit implementation request)
- First adoption review: 2026-12-28

## Context

The plugin already covers most stages of a risk-routed review pipeline. Authors implement and ship through `kramme:linear:issue-to-pr`, `kramme:code:plan-to-pr`, `kramme:pr:create`, `kramme:pr:fix-ci`, and `kramme:pr:github-review-reply`. Deep review runs through `kramme:pr:code-review` and `kramme:pr:review-convergence`, independent review through `kramme:pr:adversarial-review`, and reviewer-side drafting through `kramme:pr:github-review`.

Every one of those entry points starts at full depth. Nothing decides, before review begins, how much review a change needs or which decisions need a person rather than an agent. A one-line copy fix and a session-handling rewrite get the same multi-agent review, and a reviewer gets no signal that a migration or CI change needs explicit human sign-off.

The target shape, taken from a user-supplied pipeline diagram, is: author → risk analyzer → one of {light review, deep review, pair review with a human} → review outcome → a review memory that feeds later reviews. That diagram also shows auto-approval of low-risk changes and a learning memory. Those two parts carry risks the analyzer does not. Auto-approval needs a separate approving identity, because a Pull Request author cannot approve their own Pull Request, and it changes branch-protection trust. Review memory turns untrusted review comments into durable rules. Each part needs its own decision.

A risk analyzer that relies only on model judgment inherits a prompt-injection path: Pull Request text, commit messages, and code comments are written by the author and can argue that a change is trivial. A purely deterministic analyzer cannot see semantic risk, such as a behavior change in code with many callers.

## Decision

Add `kramme:pr:triage-risk` as a read-only, model-invocable Pull Request skill. It is the first stage of the pipeline and the only stage this record decides.

- **Scope.** It triages the committed diff between the resolved base and `HEAD`, using the shared `collect-review-diff.sh` collector to resolve the base. Uncommitted paths are counted and reported as untriaged.
- **Deterministic signals.** A skill-local script, `scripts/risk-signals.py`, classifies every changed file, scans added lines for a small set of high-signal patterns (credential shapes, dynamic-execution, shell, raw-HTML, and unsafe-deserialization sinks, and disabled, focused, or expected-failure tests), and emits a JSON report of signals with fixed levels. It reports paths, line numbers, and pattern names only, never file content. It computes a `floor` (highest level) and a `hard_floor` (highest level among non-discountable signals).
- **Model judgment on top.** The model reads the flagged hunks and as much of the remaining code as fits. It may raise the tier for semantic risk, citing `path:line`. It may lower the tier below the floor only by discounting each discountable signal above the chosen tier with a reason grounded in the diff; reasons taken from Pull Request text, commit messages, or comments alone do not count. It may never go below the hard floor.
- **Repository policy.** A repository may commit `.github/pr-risk.json` to declare high-risk, medium-risk, and generated paths. The skill reads it only from the repository's default branch, never from the branch under triage or its Pull Request base, because the author chooses the base. Policy path matches, a branch that edits the policy, and an invalid policy are non-discountable high or medium signals, so a branch cannot weaken its own triage and a malformed policy escalates rather than fails. Credential-shaped values are also non-discountable.
- **Output.** The skill replies inline with a tier (`low`, `medium`, or `high`), the signals confirmed or discounted, the review commands to run (existing skills only, from a skill-local lane table), and a "Needs a human" list of decisions tied to paths. It writes no files and never posts, labels, or approves. A `low` tier means a light review is proportionate; it is not an approval.

### Not decided here

Each of these needs its own record before implementation:

- A router that runs the recommended lanes automatically.
- Auto-approval of low-tier changes, including the approving identity and branch-protection interaction.
- A pair-review mode in which an agent brings findings and a human makes the calls, likely as a mode of `kramme:pr:github-review` under the catalog merge rule.
- A review memory that captures, distills, and shares human review signals.
- Triage of a Pull Request by number, and running triage in CI.

## Catalog Evidence

The [skill catalog shape policy](2026-07-29-skill-catalog-shape.md) requires this evidence for a new skill.

- **Usage.** Reports run on 2026-09-28 with `node kramme-cc-workflow/scripts/skill-usage.js report --since 30d --json` and `--since 90d`. The 30-day window recorded 61 invocations across 17 skills; the 90-day window recorded 298 across 33. Review-family counts (30-day / 90-day): `kramme:pr:code-review` 4 / 41, `kramme:pr:resolve-review` 7 / 35, `kramme:pr:github-review` 2 / 5, `kramme:pr:review-convergence` 1 / 1, `kramme:pr:gut-check` 0 / 0. Full-depth review is among the most used workflows, which is the cost triage routes.
- **Nearest domain and skills.** `pr`. The nearest skills are `kramme:pr:gut-check` (a first-reader reaction with no rubric or scores), `kramme:pr:code-review` (defect findings in a report), `kramme:pr:plan-split` (slicing an oversized change), and `kramme:deps:audit` (repository-wide dependency risk).
- **Positive routing boundary.** Decide how much review a branch needs, and which decisions need a person, before any reviewer runs.
- **Differences.** Input is the committed branch diff only. Output is an inline tier, lane list, and human-decision list, not findings. It has no side effects beyond the collector fetching the base. Base or diff failures stop the skill, while an invalid policy escalates the tier instead of failing.
- **First adoption review: 2026-12-28.** Inspect invocation counts, how often the recommended lanes were run, the discount rate per signal, signals that were discounted almost every time (false-positive candidates), and whether high-tier branches drew more review findings than low-tier ones.

## Consequences

- Review effort can become proportional to risk without changing any existing review skill's behavior.
- The deterministic floor gives a reproducible baseline that later automation, such as a router or CI job, can consume without trusting model output.
- Path and size heuristics produce false positives, such as `shape:very-large` on a deletion-heavy change, and false negatives for risky code outside recognizable paths. The discount rule handles the first case visibly; the raise rule and repository policy address the second.
- Non-discountable signals can force a `high` tier on a harmless change, such as a fake key in a test fixture. The cost is one human confirmation, which this record accepts.
- Repositories that want accurate triage should commit a policy file. Without one, the built-in heuristics are all the script has.

## Alternatives Considered

### Add triage as a mode of `kramme:pr:gut-check`

Rejected. Gut-check is deliberately a reaction with no rubric, scores, or thresholds. Triage is a rubric with fixed levels and a scoring floor. Folding one into the other would break the contract that makes gut-check useful.

### Add triage as a mode of `kramme:pr:code-review`

Rejected. Triage runs in a different workflow phase, before any reviewer is chosen, and produces routing rather than findings. Code review writes `REVIEW_OVERVIEW.md` and launches reviewer agents; triage must stay cheap enough to run first.

### Let the model decide the tier without a deterministic floor

Rejected because branch content is author-controlled. A persuasive description or code comment could talk the model out of a high tier, and the result would not be reproducible across runs.

### Decide the tier from the script alone

Rejected because paths and line counts cannot see semantic risk, and they over-flag harmless changes such as large deletions or comment-only edits in sensitive directories.

### Read the policy file from the working tree, or use YAML

Rejected. Reading policy from the branch would let a branch lower its own triage. YAML would add a third-party parser to a runtime that otherwise needs only the Python standard library.
