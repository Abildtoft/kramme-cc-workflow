# Shared Codebase Weakness Audit

Identify the highest-leverage weaknesses across maintainability, readability, and correctness, then produce a ranked report. Read-only apart from writing one report; never modify implementation code.

## Caller Handoff

The calling skill resolves `SCOPE_MODE`, `SCOPE_TARGET`, a scope description and file list, stack, conventions, accepted ADRs, and glossary terms before loading this workflow. It selects `AUDIT_MODE=team` or `AUDIT_MODE=solo` and handles host prerequisites and mode flags. Optional history signals and rejection policies remain authoritative; do not broaden the resolved scope.

Parse the report options from the remaining arguments:

- **Output path**: optional `--output <path>`. Default is `CODEBASE_WEAKNESS_REPORT.md` in the project root. Refuse paths outside the working tree unless the user explicitly confirms.
- **Finding cap**: optional `--max-findings N`. Default is `20`; cap at `30` unless the user explicitly asks for a broader inventory. Team mode should collect a broader raw candidate pool before final filtering; this cap applies only to active ranked findings in the final report.

Store these as `OUTPUT_PATH` and `MAX_FINDINGS`. The caller resolves the shared rubric and report-template paths from its `SKILL.md`; pass those resolved paths into reviewer prompts rather than asking reviewers to expand plugin-root placeholders.

## Orientation

Reuse the caller's resolved scope, stack, conventions, accepted ADRs, glossary, and any supplied history signals. Preserve its rejection policy when filtering candidates. Use the caller's recorded provenance; refactor-opportunities records it in `SKILL.md` Phase 1 (Producer `kramme:code:refactor-opportunities --ranked`).

Detect prior report artifacts (`CODEBASE_WEAKNESS_REPORT.md`, `OUTSIDE_VIEW_REPORT.md`, `REFACTOR_OPPORTUNITIES_OVERVIEW.md`, `AGENT_NATIVE_AUDIT.md`, `REVIEW_OVERVIEW.md`) only as context. Treat outside-view complaint clusters as unverified leads worth checking against evidence. Do not copy findings without re-validating evidence in the current tree.

Gather quick quantitative signals when available:

- largest source files and functions
- dependency cycles or unusually deep import chains
- test coverage shape, not just existence
- recent churn from git history, using `HOT_SPOTS` when the caller supplied it
- recurring TODO/FIXME/temporary markers
- repeated error-handling, validation, or state-management patterns

Read `${CLAUDE_PLUGIN_ROOT}/shared/codebase-audit/references/audit-rubric.md` and `${CLAUDE_PLUGIN_ROOT}/shared/codebase-audit/assets/report-template.md`. Report the resolved scope before scanning: mode, target, file count, primary languages, and output path, plus the planned agent count: nine research reviewers plus one challenge reviewer, or none with `--solo`.

## Team Workflow

Run this section only when `AUDIT_MODE=team`. Use the caller's host setup to launch the active research reviewers as parallel read-only subagents; run the challenge reviewer after collecting their results. After cross-validation, proceed to Filter Hard, skipping Solo Fallback.

Select the active research reviewer set before launching. Default to all nine research reviewers, then run the challenge reviewer after their results are collected. Do not downsize the team for full-codebase or feature audits. For a very small path scope, keep the same roles unless the scope has fewer than five source files; if you reduce reviewers, record the active and omitted reviewer names and note the degraded coverage in the report.

Spawn these teammates:

- **Architecture & boundaries reviewer**: module boundaries, dependency direction, ownership clarity, public entry points, coupling, framework boundaries, and accepted-ADR fit.
- **Complexity & abstraction reviewer**: large files/functions, branch complexity, state-management complexity, shallow wrappers, speculative indirection, and change blast radius.
- **Duplication & consistency reviewer**: repeated validation, duplicated algorithms, parallel type shapes, scattered constants/configuration, and inconsistent patterns across similar modules.
- **Correctness & invariants reviewer**: concrete failure paths, boundary validation, invariant enforcement, state transitions, data integrity, and behavior-relevant test gaps.
- **Runtime, async & error-handling reviewer**: async/concurrency risks, I/O failure paths, swallowed or under-contextualized errors, retries/timeouts, resource cleanup, and operational failure modes.
- **Test & feedback reviewer**: test coverage shape, source/test mapping, critical untested behaviors, slow or missing feedback loops, brittle fixtures, and verification command reliability.
- **Readability & traversal reviewer**: naming, domain language, local comprehension, file organization, comment accuracy, code navigation from entry points, and context-pointer quality.
- **History & change-risk reviewer**: high-churn files, recently unstable areas, repeated bug-fix patterns, TODO/FIXME clusters, large ownership hotspots, and maintenance-cycle risk.
- **Governance & conventions reviewer**: audits the project's instruction files, ADRs, glossaries, and process docs as artifacts in their own right: conventions that no longer serve the code, rules that exist to manage the coding agent rather than the product, stale or contradictory guidance, convention proliferation, and process weight relative to product value. This reviewer is exempt from the accepted-ADR constraint for its own scope: questioning an accepted decision is in scope when evidence shows the rule now costs more than it protects. Its question is "do the rules serve the code, or has the code started serving the rules?"
- **Challenge reviewer**: cross-checks raw findings after the active research reviewers finish; tries to falsify weak evidence, spot duplicate root causes, identify accepted-ADR conflicts, catch missing correctness risks, and verify that high-priority findings are worth acting on.

Each research reviewer receives:

- resolved scope description and file list
- detected stack and project conventions
- relevant accepted ADR summaries and glossary terms
- prior report paths as context only, with instructions to re-validate evidence
- quantitative signals gathered during scope resolution, including largest files/functions, churn, TODO/FIXME counts, test/source mapping, and dependency signals when available
- the audit rubric
- their specific lens mission

Each research reviewer must investigate broadly before returning:

- Scan across the entire resolved scope for the assigned lens, not just the first suspicious directory.
- For full-codebase audits, inspect at least the main entry points, the largest source files, highest-churn files, configuration and test entry points, and any files directly connected to serious candidates.
- Follow callers, callees, tests, and documentation far enough to establish the root cause and impact for every serious candidate.
- Keep researching after the first good candidates. The raw candidate pool should normally be at least `2 * MAX_FINDINGS` before challenge filtering when the scope is large enough.
- Return `Reviewed and cleared` notes for important areas that looked risky but did not produce a finding. This prevents the final report from implying that unmentioned areas were ignored.
- Be expansive in research and conservative in findings: collect near misses, then let challenge and synthesis filter them.

Each research reviewer must return raw candidates using the standard skill schema:

- concrete file locations and line ranges
- canonical lens: `maintainability`, `readability`, `correctness`, or `mixed`
- root cause
- evidence
- impact
- confidence and reason
- smallest useful first fix
- validation check
- effort and blast radius
- filtered/near-miss observations worth mentioning separately
- reviewed-and-cleared areas with one-line evidence
- answers to two off-rubric questions: the most important weakness in scope that the assigned lens did not ask about, and the one sentence the reviewer would tell the codebase owner. These bypass the evidence standards and are reported as unverified impressions, never as findings.

Map role-specific findings into the canonical lens vocabulary before returning them: architecture, complexity, duplication, history, test feedback, and operational-maintenance findings usually map to `maintainability`; traversal, naming, and comprehension findings map to `readability`; concrete failure paths, invariant breaks, async/error behavior, and data integrity findings map to `correctness`. Use `mixed` only when a single root cause materially spans more than one lens.

### Step 3: Cross-Validate

After the active research reviewers return, pass all raw candidates, near misses, and reviewed-and-cleared notes to the challenge reviewer.

The challenge reviewer must:

1. Drop or mark candidates whose evidence is weak, speculative, purely stylistic, or contradicted by project conventions.
2. Check whether a finding contradicts accepted ADRs; keep it only when new evidence shows the trade-off has shifted.
3. Deduplicate candidates with the same root cause.
4. Flag disagreements between reviewers.
5. Promote any missed correctness candidate that has a concrete failure path.
6. Check whether the raw candidate pool was broad enough for the resolved scope; if not, name the missing research area.
7. Pass every off-rubric impression through unfiltered. The challenge reviewer may annotate an impression with corroborating or conflicting evidence but must not drop, merge, or rewrite it; impressions are exempt from the evidence bar by design.
8. Return a validation summary: kept, dropped, merged, disputed, added, and coverage-gapped candidates.

If the challenge reviewer fails but the research phase met its success quorum, continue with a degraded-coverage note. For the full nine-reviewer set, the quorum is at least seven successful research reviewers. For a reduced tiny-scope set, the quorum is every selected research reviewer. If the quorum is not met, stop without writing the report.

## Solo Fallback

Run this section only when `AUDIT_MODE=solo`; launch no reviewers. Use `--solo` only for small scopes, constrained runtimes, or when multi-agent execution is unavailable.

Use `--solo` only when:

- the scope is small
- you want a faster, lower-cost pass
- you only need directional prioritization

Read `${CLAUDE_PLUGIN_ROOT}/shared/codebase-audit/references/audit-rubric.md` before recording findings.

Scan through three lenses in the main thread. Default multi-agent audits use the Team Workflow above; this section is intentionally lower coverage.

- **Maintainability lens**: module boundaries, coupling, duplication, complexity, ownership clarity, change blast radius, operational friction, and testability.
- **Readability lens**: naming, local comprehension, control-flow clarity, domain language, file organization, comment quality, and traversability from entry points to implementation.
- **Correctness lens**: concrete failure paths, missing boundary validation, invariant breaks, state transitions, error propagation, concurrency/race risks, data integrity, and meaningful test gaps.

Each raw candidate must include:

- concrete file locations and line ranges
- lens: maintainability, readability, correctness, or mixed
- root cause, not only symptom
- evidence from code, tests, history, or project conventions
- likely user, operator, developer, or reviewer impact
- confidence level with reason
- smallest useful first fix
- validation check that would prove the fix worked
- rough effort and blast radius

After finishing the lens scans, answer two off-rubric questions before any filtering:

- What is the most important weakness in this scope that none of the three lenses asked about?
- If you could tell the codebase owner one sentence, what would it be?

Record the answers for the report's Impressions (Unverified) section. Impressions are exempt from the evidence standards and from Filter Hard: label them as unverified instead of dropping them or forcing them into finding format.

## Filter Hard

1. Drop candidates without concrete evidence. "Feels messy" is not a finding.
2. Drop style preferences that do not affect comprehension, correctness, or change cost.
3. Drop generic best-practice advice unless the current code shows actual risk or repeated friction.
4. Drop findings that are only missing tests unless the missing test maps to an important behavior, invariant, regression risk, or recently changed area.
5. Drop issues explained by documented project conventions, accepted ADRs, framework guarantees, generated-code contracts, or deliberate performance trade-offs.
6. Keep a candidate that is localized but correctness-critical even if it appears once.
7. Promote a maintainability or readability candidate only when it affects repeated work, important code paths, cross-module changes, onboarding/traversal, or review confidence.
8. Prefer fewer high-confidence findings over a complete inventory. If more than `MAX_FINDINGS` remain, keep only the top-ranked findings and list the rest as filtered or follow-up candidates.
9. Never apply these filters to off-rubric impressions. They are reported separately as unverified and are the report's escape hatch for rubric blind spots.

Apply any caller-supplied rejection policy at this point. The Governance & conventions reviewer may still question an accepted ADR within its own scope when evidence shows the rule now costs more than it protects.

## Rank and Synthesize

1. Score every surviving finding using the scoring worksheet in `${CLAUDE_PLUGIN_ROOT}/shared/codebase-audit/references/audit-rubric.md`.
2. Assign stable IDs `WA-001`, `WA-002`, ... after sorting.
3. Sort by priority score, then severity, then confidence. Map rubric confidence 4-5, 3, and 1-2 to `HIGH`, `MED`, and `LOW`, and effort small, medium, and large to `S`, `M`, and `L`.
4. Group related findings into themes. A theme should describe a shared root cause, not a bucket of vaguely similar symptoms.
5. Assign severity:
   - **Critical**: likely incorrect behavior, data loss, production breakage, or repeated failure in an important flow.
   - **High**: materially raises change risk, hides important logic, weakens a core invariant, or causes repeated developer friction.
   - **Medium**: meaningful maintainability/readability/correctness weakness with clear evidence but bounded impact.
   - **Low**: worth noting only as context; normally exclude low findings from the ranked list unless the codebase has no larger issues.
6. Build a recommended fix sequence that separates quick validation wins from larger design work. Do not prescribe a broad rewrite when targeted steps would reduce risk.

The orchestrator, not a teammate, owns final ranking and report writing. Enforce `MAX_FINDINGS` after sorting, keep only the highest-ranked findings active, and preserve the raw-candidate, filtered-candidate, reviewed-and-cleared, and coverage-gap counts. Collect every reviewer's off-rubric impressions in Impressions (Unverified); deduplicate only near-verbatim duplicates without filtering, scoring, or ranking them.

## Write Report

1. Read `${CLAUDE_PLUGIN_ROOT}/shared/codebase-audit/assets/report-template.md`.
2. Write the report to `OUTPUT_PATH`, overwriting any previous report at that path. Include the resolved scope and date in the header so an overwritten report remains understandable. Write `## Report Provenance` and name the detailed findings section `## Breakdown-Ready Finding Data`, per `${CLAUDE_PLUGIN_ROOT}/shared/findings/references/breakdown-ready-findings.md`.
3. Include all required sections from the template, including the Team Review block in team mode only; omit that block for `--solo` runs. If no major weakness is found, keep the same header, provenance, scorecard, filtered candidates, impressions, and coverage notes, and write `None.` under `## Breakdown-Ready Finding Data`. Replace the other findings sections with: `No major weaknesses met the evidence bar in this scope.` Explain the scope, evidence reviewed, and residual risks instead of inventing findings.
4. Treat the report as a working artifact that should not be committed. It is consumed by the user, by `/kramme:code:breakdown-findings` when turning validated findings into implementation plans, and by `/kramme:code:outside-view` comparisons. It is retired by `/kramme:workflow:cleanup-artifacts` when no longer useful, or manual deletion.

## Summarize

Reply with:

- report path
- team coverage status
- research breadth: raw candidates reviewed, filtered candidates, and coverage gaps
- number of findings by severity and lens
- top 3 weaknesses
- recommended first action
- any skipped areas, degraded reviewers, disputes, or confidence limits

End the run with `Agents launched: N` — the research and challenge reviewers launched, or `0` with `--solo` — so the cost of the run is visible.

## Discipline

- Evidence beats coverage. A short report with 5 defensible weaknesses is better than 20 speculative observations.
- Correctness findings must name a plausible failure path or missing invariant.
- Maintainability findings must explain how future changes become riskier or slower.
- Readability findings must explain what a maintainer would misunderstand or fail to find.
- Impressions are the escape hatch for rubric blind spots: report them honestly and label them unverified rather than suppressing them or dressing them up as findings. Recurring impressions belong in `/kramme:code:outside-view` runs and eventual rubric amendments.
- Do not implement fixes. This skill ranks and explains weaknesses; separate implementation work belongs in follow-up tasks.
