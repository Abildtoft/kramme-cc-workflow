# Default Team-Based Codebase Weakness Audit

Run a codebase weakness audit using a broad multi-agent team. Each reviewer runs with its own context window and researches one cross-cutting lens across the whole resolved scope. The orchestrator keeps the final report ranked and evidence-based.

This reference is loaded by default from `/kramme:code:weakness-audit`; assume optional compatibility flags such as `--team` have already been removed from `$ARGUMENTS`. Use the solo fallback only when the caller passed `--solo`.

**Arguments:** "$ARGUMENTS"

## Prerequisites

This mode requires multi-agent execution.

- **Claude Code:** Agent Teams must be enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`).
- **Codex:** run in a Codex runtime with `multi_agent` enabled.

If multi-agent execution is not available, print:

```text
Multi-agent execution is not enabled. Re-run /kramme:code:weakness-audit --solo for the lower-coverage fallback.
Claude Code: add CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 to settings.json.
Codex: use a runtime with `multi_agent` enabled (for example, Conductor Codex runtime).
```

Then stop.

## Workflow

### Step 1: Resolve Audit Scope

Use the input parsing and orientation rules from `SKILL.md`:

1. Parse `full`, `path <file-or-folder>`, `feature <name>`, `--scope`, `--output`, `--max-findings`, and `--base <ref>`.
2. Detect stack, project layout, relevant instruction files, accepted ADRs, glossary files, and prior reports.
3. Build the effective file set and exclude generated, vendored, binary, build, cache, and dependency directories.
4. Read `references/audit-rubric.md` and `assets/report-template.md`.
5. Report the resolved scope before launching teammates: mode, target, file count, primary languages, and output path.

### Step 2: Spawn Audit Teammates

Create a multi-agent session named `codebase-weakness-audit` and use delegate mode: teammates inspect and report; the orchestrator writes the final report.

Select the active research reviewer set before launching. Default to all eight research reviewers, then run the challenge reviewer after their results are collected. Do not downsize the team for full-codebase or feature audits. For a very small path scope, keep the same roles unless the scope has fewer than five source files; if you reduce reviewers, record the active and omitted reviewer names and note the degraded coverage in the report.

Spawn these teammates:

- **Architecture & boundaries reviewer**: module boundaries, dependency direction, ownership clarity, public entry points, coupling, framework boundaries, and accepted-ADR fit.
- **Complexity & abstraction reviewer**: large files/functions, branch complexity, state-management complexity, shallow wrappers, speculative indirection, and change blast radius.
- **Duplication & consistency reviewer**: repeated validation, duplicated algorithms, parallel type shapes, scattered constants/configuration, and inconsistent patterns across similar modules.
- **Correctness & invariants reviewer**: concrete failure paths, boundary validation, invariant enforcement, state transitions, data integrity, and behavior-relevant test gaps.
- **Runtime, async & error-handling reviewer**: async/concurrency risks, I/O failure paths, swallowed or under-contextualized errors, retries/timeouts, resource cleanup, and operational failure modes.
- **Test & feedback reviewer**: test coverage shape, source/test mapping, critical untested behaviors, slow or missing feedback loops, brittle fixtures, and verification command reliability.
- **Readability & traversal reviewer**: naming, domain language, local comprehension, file organization, comment accuracy, code navigation from entry points, and context-pointer quality.
- **History & change-risk reviewer**: high-churn files, recently unstable areas, repeated bug-fix patterns, TODO/FIXME clusters, large ownership hotspots, and maintenance-cycle risk.
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
7. Return a validation summary: kept, dropped, merged, disputed, added, and coverage-gapped candidates.

If the challenge reviewer fails but the research phase met its success quorum, continue with a degraded-coverage note. For the full eight-reviewer set, the quorum is at least six successful research reviewers. For a reduced tiny-scope set, the quorum is every selected research reviewer. If the quorum is not met, stop without writing the report.

### Step 4: Aggregate and Rank

The orchestrator, not a teammate, owns final ranking and report writing.

1. Apply the standard filtering rules from `SKILL.md`.
2. Score every surviving candidate using `references/audit-rubric.md`.
3. Assign stable IDs `WA-001`, `WA-002`, ... after sorting.
4. Sort by priority score, then severity, then confidence.
5. Enforce `MAX_FINDINGS`; keep only the highest-ranked findings in the active list.
6. Group related findings into cross-cutting themes.
7. Build the recommended fix sequence.
8. Preserve research breadth in the report summary: raw candidates reviewed, filtered candidates, reviewed-and-cleared areas, and any coverage gaps.

### Step 5: Write Report

Write the same output artifact as standard mode: `CODEBASE_WEAKNESS_REPORT.md` by default, or `--output <path>`.

Follow `assets/report-template.md` and add a short team metadata block after the header:

```markdown
## Team Review

- **Mode:** Team
- **Reviewers:** {active research reviewer names}, Challenge
- **Research breadth:** {raw candidates N, reviewed-and-cleared areas N, coverage gaps N}
- **Cross-validation:** {kept N, dropped N, merged N, disputed N, added N, coverage-gapped N}
- **Coverage status:** {complete | degraded with reason}
```

Keep the rest of the report schema-compatible with standard mode so `/kramme:code:breakdown-findings` can consume the findings.

### Step 6: Summarize and Clean Up

Reply with:

- report path
- team coverage status
- research breadth: raw candidates reviewed, filtered candidates, and coverage gaps
- number of findings by severity and lens
- top 3 weaknesses
- recommended first action
- any skipped areas, degraded reviewers, disputes, or confidence limits

Then shut down the multi-agent session.

## Usage Examples

```text
/kramme:code:weakness-audit
# Full-codebase team audit

/kramme:code:weakness-audit path src/api --max-findings 8
# Team audit scoped to one area

/kramme:code:weakness-audit feature billing --output docs/billing-weakness-report.md
# Feature-scoped team audit with custom output

/kramme:code:weakness-audit --solo path src/api
# Lower-coverage fallback for constrained runtimes or tiny scopes
```

## Coverage Posture

Team mode is the default because this audit is used for prioritization and planning. It should favor comprehensive research before synthesis:

- the codebase or scope is large
- correctness risk matters as much as maintainability cleanup
- you want independent reviewers to challenge each other's findings
- the report will guide a maintenance cycle or PR planning

Use `--solo` only when:

- the scope is small
- you want a faster, lower-cost pass
- you only need directional prioritization
