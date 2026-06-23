# Team-Based Codebase Weakness Audit

Run a codebase weakness audit using multi-agent execution. Each reviewer runs with its own context window, then a challenge reviewer cross-checks the highest-priority candidates before the final report is written.

This reference is loaded by `/kramme:code:weakness-audit --team`; assume `--team` has already been removed from `$ARGUMENTS`.

**Arguments:** "$ARGUMENTS"

## Prerequisites

This mode requires multi-agent execution.

- **Claude Code:** Agent Teams must be enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`).
- **Codex:** run in a Codex runtime with `multi_agent` enabled.

If multi-agent execution is not available, print:

```text
Multi-agent execution is not enabled. Run /kramme:code:weakness-audit instead.
Claude Code: add CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 to settings.json.
Codex: use a runtime with `multi_agent` enabled (for example, Conductor Codex runtime).
```

Then stop.

## Workflow

### Step 1: Resolve Audit Scope

Use the same input parsing and orientation steps as the standard `/kramme:code:weakness-audit` workflow:

1. Parse `full`, `path <file-or-folder>`, `feature <name>`, `--scope`, `--output`, `--max-findings`, and `--base <ref>`.
2. Detect stack, project layout, relevant instruction files, accepted ADRs, glossary files, and prior reports.
3. Build the effective file set and exclude generated, vendored, binary, build, cache, and dependency directories.
4. Read `references/audit-rubric.md` and `assets/report-template.md`.
5. Report the resolved scope before launching teammates: mode, target, file count, primary languages, and output path.

### Step 2: Spawn Audit Teammates

Create a multi-agent session named `codebase-weakness-audit` and use delegate mode: teammates inspect and report; the orchestrator writes the final report.

Spawn these teammates:

- **Maintainability reviewer**: module boundaries, coupling, duplication, complexity, ownership clarity, change blast radius, operational friction, testability, and future-change cost.
- **Readability reviewer**: naming, domain language, local comprehension, control-flow clarity, file organization, comment accuracy, and traversal from entry points to implementation.
- **Correctness reviewer**: concrete failure paths, invariant enforcement, boundary validation, state transitions, async/concurrency risks, error propagation, data integrity, and behavior-relevant test gaps.
- **Challenge reviewer**: cross-checks the raw findings after the first three reviewers finish; tries to falsify weak evidence, spot duplicate root causes, identify accepted-ADR conflicts, and catch missing correctness risks.

Each lens reviewer receives:

- resolved scope description and file list
- detected stack and project conventions
- relevant accepted ADR summaries and glossary terms
- prior report paths as context only, with instructions to re-validate evidence
- the audit rubric
- their specific lens mission

Each lens reviewer must return raw candidates using the standard skill schema:

- concrete file locations and line ranges
- lens
- root cause
- evidence
- impact
- confidence and reason
- smallest useful first fix
- validation check
- effort and blast radius
- filtered/near-miss observations worth mentioning separately

### Step 3: Cross-Validate

After the lens reviewers return, pass all raw candidates to the challenge reviewer.

The challenge reviewer must:

1. Drop or mark candidates whose evidence is weak, speculative, purely stylistic, or contradicted by project conventions.
2. Check whether a finding contradicts accepted ADRs; keep it only when new evidence shows the trade-off has shifted.
3. Deduplicate candidates with the same root cause.
4. Flag disagreements between reviewers.
5. Promote any missed correctness candidate that has a concrete failure path.
6. Return a validation summary: kept, dropped, merged, disputed, and added candidates.

If the challenge reviewer fails but at least two lens reviewers succeeded, continue with a degraded-coverage note. If fewer than two lens reviewers succeed, stop without writing the report.

### Step 4: Aggregate and Rank

The orchestrator, not a teammate, owns final ranking and report writing.

1. Apply the standard filtering rules from `SKILL.md`.
2. Score every surviving candidate using `references/audit-rubric.md`.
3. Assign stable IDs `WA-001`, `WA-002`, ... after sorting.
4. Sort by priority score, then severity, then confidence.
5. Enforce `MAX_FINDINGS`; keep only the highest-ranked findings in the active list.
6. Group related findings into cross-cutting themes.
7. Build the recommended fix sequence.

### Step 5: Write Report

Write the same output artifact as standard mode: `CODEBASE_WEAKNESS_REPORT.md` by default, or `--output <path>`.

Follow `assets/report-template.md` and add a short team metadata block after the header:

```markdown
## Team Review

- **Mode:** Team
- **Reviewers:** Maintainability, Readability, Correctness, Challenge
- **Cross-validation:** {kept N, dropped N, merged N, disputed N, added N}
- **Coverage status:** {complete | degraded with reason}
```

Keep the rest of the report schema-compatible with standard mode so `/kramme:code:breakdown-findings` can consume the findings.

### Step 6: Summarize and Clean Up

Reply with:

- report path
- team coverage status
- number of findings by severity and lens
- top 3 weaknesses
- recommended first action
- any skipped areas, degraded reviewers, disputes, or confidence limits

Then shut down the multi-agent session.

## Usage Examples

```text
/kramme:code:weakness-audit --team
# Full-codebase team audit

/kramme:code:weakness-audit --team path src/api --max-findings 8
# Team audit scoped to one area

/kramme:code:weakness-audit --team feature billing --output docs/billing-weakness-report.md
# Feature-scoped team audit with custom output
```

## When to Use Team Mode

Use `--team` when:

- the codebase or scope is large
- correctness risk matters as much as maintainability cleanup
- you want independent reviewers to challenge each other's findings
- the report will guide a maintenance cycle or PR planning

Use standard mode when:

- the scope is small
- you want a faster, lower-cost pass
- you only need directional prioritization
