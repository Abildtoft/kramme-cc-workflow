---
name: kramme:code:breakdown-findings
description: "Cluster validated findings into PR-sized themes and generate self-contained implementation plans. Use after review, audit, scan, or QA workflows that produce findings reports."
argument-hint: "[source-file-or-content]"
disable-model-invocation: true
user-invocable: true
---

# Plan Findings into PRs

Cluster validated findings from reviews, audits, or scans into PR-sized themes. Generate a self-contained implementation plan for each theme and an index linking them all.

**Accepted sources**
- An auto-detected overview/audit report in the project root (see Phase 1)
- A path to any markdown file containing findings (non-standard names are fine)
- Inline findings text pasted as the argument

**Arguments:** "$ARGUMENTS"

## Workflow

### Phase 1: Locate Findings

1. Check `$ARGUMENTS` for input:
   - If a file path is provided (any filename — the list below is for auto-detection only; user-supplied paths are accepted regardless of name), read that file as the findings source.
   - If `$ARGUMENTS` is not a file path (no path separator, or the path does not resolve) but contains findings-like content, treat the argument as the findings source directly. Recognize inline findings by presence of any of:
     - severity labels (`critical`, `high`, `major`, `medium`, `minor`, `low`, `suggestion`)
     - file:line references (e.g. `src/foo.ts:42`)
     - a numbered or bulleted list of issues with descriptions
     - headings like `Finding`, `Issue`, `## 1.`

     If the argument is a plain sentence with none of these markers, ask the user to clarify whether it is a path, inline findings, or a description of intent.
   - If empty, auto-detect by checking for these common findings artifacts in the project root (use the first one found):
     1. `REVIEW_OVERVIEW.md`
     2. `REFACTOR_OPPORTUNITIES_OVERVIEW.md`
     3. `UX_REVIEW_OVERVIEW.md`
     4. `PRODUCT_REVIEW_OVERVIEW.md`
     5. `COPY_REVIEW_OVERVIEW.md`
     6. `AGENT_NATIVE_AUDIT.md`
     7. `PRODUCT_AUDIT_OVERVIEW.md`
     8. `QA_REPORT.md`
     9. `AUDIT_IMPLEMENTATION_REPORT.md`
     10. `AUDIT_SPEC_REPORT.md`
     11. `PRODUCT_AUDIT.md`
     12. `siw/AUDIT_IMPLEMENTATION_REPORT.md`
     13. `siw/AUDIT_SPEC_REPORT.md`
     14. `siw/PRODUCT_AUDIT.md`
   - If multiple files exist, list them and ask the user which to use (or process all if they choose "all").
   - If no source is found, stop and tell the user: "No findings source found. Provide a file path (any markdown file with findings will work), paste findings inline, or run a report-producing skill first (for example `/kramme:pr:code-review`, `/kramme:code:copy-review`, `/kramme:code:refactor-opportunities`, `/kramme:code:agent-readiness`, `/kramme:product:review`, `/kramme:qa`, or `/kramme:siw:spec-audit`)."

2. Parse the findings source into a normalized list. For each finding, extract:
   - **Description** of the issue (the full problem statement, not a reference ID)
   - **Location** (file paths, line ranges, modules)
   - **Severity** (critical / high / medium / low / suggestion -- normalize to these levels)
   - **Category/type** (if tagged in the source)
   - **Suggested fix** (if present)

3. Count findings and report to the user before proceeding:
   ```
   Found N findings from {source}. Proceeding to cluster.
   ```

### Phase 2: Cluster into Themes

Group findings into PR-sized themes. A theme is a set of findings that should be fixed together because they share one or more of:

- **Root cause** -- same underlying problem manifesting in multiple places
- **Affected area** -- same file, module, or subsystem
- **Implementation dependency** -- fixing one requires or enables fixing another
- **Conceptual cohesion** -- same type of change (e.g., "add error handling to all API endpoints")

#### Clustering rules

1. **Target size**: each theme should map to a realistic single PR (roughly 1-8 findings, touching a bounded set of files). If a theme grows beyond what a single PR can cover, split it into a short series and note the dependency.

   Apply this sizing grammar when sizing themes:

   | Size | Scope |
   |---|---|
   | XS | 1 file, single finding |
   | S | 1–2 files |
   | M | 3–5 files |
   | L | 6–8 files |
   | **XL** | **9+ files — split into a series** |

   Aim for S/M themes. Any theme that sizes XL MUST split before generating plans.

2. **Avoid overlap**: every finding belongs to exactly one theme. If a finding could fit multiple themes, assign it to the one where it shares the strongest implementation dependency.

3. **Singleton themes are fine**: if a finding does not cluster with others, it becomes its own single-finding theme.

4. **Exclusions**: if any finding should be excluded from all plans (e.g., duplicates, already resolved, not actionable), record it with a reason. These go into the index under "Excluded Findings" as one marker-prefixed line per finding. If nothing is excluded, write a plain sentence with no marker.

5. **Conflicts**: if two findings contradict each other (e.g., "add abstraction" vs. "remove abstraction" for the same code), flag the conflict as an open question in the relevant plan(s) and do not assume a resolution.

#### Clustering process

1. Read all findings. Identify natural groupings by scanning for shared files, shared root causes, and shared fix patterns.
2. Draft theme names using the pattern `verb-noun` in kebab-case (e.g., `add-api-error-handling`, `consolidate-config-parsing`, `remove-dead-code`). These become the `<slug>` in filenames.
3. Verify no theme is too large (would require 500+ changed lines or touch 9+ files). Split if needed.
4. Verify no two themes overlap in affected files without an explicit dependency note.

Present the clustering to the user before generating files. Prefix the block with the `PLAN:` output marker so downstream tooling can parse the proposed clustering:

```
PLAN: Proposed themes
  1. add-api-error-handling (4 findings, size M) -- files: src/api/*.ts
  2. consolidate-config-parsing (3 findings, size S) -- files: src/config/*, src/utils/config.ts
  3. remove-dead-exports (2 findings, size S) -- files: src/lib/*.ts
  0 excluded findings

Proceed? (yes / adjust)
```

Wait for user confirmation. If the user requests adjustments, re-cluster accordingly.

### Phase 3: Generate Plans

For each confirmed theme:

1. Read the plan template from `assets/plan-template.md`.
2. Fill in all sections. Every plan must be **fully self-contained** -- an engineer who has never read any prior document must understand the problem, context, and solution from the plan alone.
3. Write the file to `PR_PLAN_{SLUG}.md` in the project root. Use UPPER_SNAKE_CASE for the slug in the filename (e.g., `PR_PLAN_ADD_API_ERROR_HANDLING.md`).

#### Plan content requirements

Every section and subsection in the template must be populated. Do not leave headings empty or write "N/A".

- **Problem Statement**: Restate the full problem. Do NOT reference finding IDs, report names, or prior documents.
- **Why These Belong Together**: Explain the shared root cause, area, or dependency.
- **Goals**: What the PR achieves. Be specific and measurable.
- **Non-Goals**: What the PR explicitly does NOT do.
- **Affected Files and Systems**: Every file, module, and system that will be touched.
- **Current Behavior**: What happens today, with concrete examples or code references.
- **Intended End State**: Target behavior after the PR lands.
- **Dependencies and Sequencing**: What work must be completed before this PR can start, and what work this PR unblocks. Describe constraints by their content, not by referencing other plan files. External dependencies.
- **Risks**: What could go wrong. Include mitigation for each risk.
- **Open Questions**: Questions that must be answered before implementation. Note who should answer and the default assumption.
- **Implementation Plan**: Numbered step-by-step instructions. Each step small enough to verify independently.
- **Test and Verification Plan**: Use the verification methods that fit the theme. Include automated tests when code or executable behavior changes, and use workflow-specific checks such as manual validation, rerunning the source audit/review, docs/build validation, screenshots, or reproduced QA steps when the work is non-code.
- **Completion Criteria**: Checklist of conditions for the PR to be mergeable.

### Phase 4: Generate Index

1. Read the index template from `assets/index-template.md`.
2. Write `PR_PLAN_INDEX.md` in the project root with:
   - **Plan listing**: filename, theme name, and a 2-4 sentence summary for each plan.
   - **Recommended implementation order**: ordered list with rationale (dependencies, risk reduction, quick wins first).
   - **Dependency map**: which plans depend on which.
   - **Excluded findings**: any findings not included in any plan, with the reason. Emit each excluded entry on its own line prefixed with `NOTICED BUT NOT TOUCHING:` so downstream tooling can parse it reliably. If there are no exclusions, write `All findings were included in plans.` with no marker line.
   - **Source**: the findings source file or description used as input.
   - **Statistics**: total findings, plans generated, findings per plan, excluded count.

### Phase 5: Summary

Report to the user using the standard end-of-turn triplet (adapted: "CHANGES MADE" becomes "PLANS GENERATED" since this skill writes plan artifacts, not code):

```
PR Plan Generation Complete

Source: {source file or description}
Findings processed: N
Plans generated: M
Findings excluded: X

PLANS GENERATED:
  PR_PLAN_INDEX.md
  PR_PLAN_{SLUG_1}.md -- {theme name} ({n} findings, size {XS|S|M|L})
  PR_PLAN_{SLUG_2}.md -- {theme name} ({n} findings, size {XS|S|M|L})
  ...

THINGS I DIDN'T TOUCH:
  • The source findings file (read-only for this skill)
  • Any existing PR_PLAN_*.md files from prior runs (surface them here if present)
  • Findings listed under "Excluded" in the index

POTENTIAL CONCERNS:
  • {Any conflicting-findings CONFUSION markers that remained unresolved}
  • {Any inferred severities flagged UNVERIFIED}
  • {If none, state: "None"}

Recommended first PR: PR_PLAN_{SLUG}.md -- {one-line rationale}
```

## Edge Cases

- **Single finding**: create one plan and one index. Do not skip sections.
- **Single theme**: create one plan. The index still lists it with order and summary.
- **No actionable findings**: if all findings are duplicates, resolved, or not actionable, write no plan files. Report this and stop.
- **Large input (30+ findings)**: cluster aggressively. Aim for 5-10 themes maximum. Split oversized themes into a series with sequencing notes.
- **Conflicting findings**: do not pick a side. Flag the conflict as an open question and present both positions.
- **Ambiguous severity**: infer from context (security = critical, style = low). State the inference in the plan.

## Guidelines

- **Self-contained plans above all.** Every plan must be readable in isolation. Never write "as described in the review" or "see finding #3."
- **Actionable specificity.** "Improve error handling" is not a plan step. "Add try-catch to `fetchUser()` in `src/api/users.ts:45` that catches `NetworkError` and returns a typed error result" is.
- **Conservative sizing.** No theme should land at XL. When in doubt, size down — a focused M theme (200-line PR) is better than a stretched L that inches toward an 800-line sprawl.
- **Respect the source.** Do not add findings that were not in the input. Do not reinterpret findings. If a finding is unclear, flag it as an open question.
- **Match verification to the work.** Do not force code-only requirements onto documentation, copy, QA, audit, or workflow changes. Generated plans should require the evidence that actually proves the theme is complete.
- **Clean output files.** The generated markdown files are working artifacts. They can be cleaned up with `/kramme:workflow-artifacts:cleanup`.

## Output Markers

Use these markers as prefixes when surfacing specific kinds of information so output stays parseable across the plugin:

- `UNVERIFIED:` — use in Phase 1 parsing when severity (or any other field) is inferred from context rather than stated in the source.
- `CONFUSION:` — use when two findings conflict and both positions are surfaced as open questions in the generated plan(s).
- `MISSING REQUIREMENT:` — use for any open question added to a plan that must be answered before implementation.
- `NOTICED BUT NOT TOUCHING:` — prefix each excluded-finding entry in the index.
- `PLAN:` — prefix the Phase 2 proposed-themes block.
- `PLANS GENERATED / THINGS I DIDN'T TOUCH / POTENTIAL CONCERNS` — end-of-turn triplet used in Phase 5 Summary.

Adopt all markers or none — mixed marker vocabularies degrade downstream parseability.

## Common Rationalizations

Watch for these justifications that signal you are about to skip a hard gate:

- "All findings in one PR is faster." — A sprawling PR is harder to review and more likely to stall. Split the theme.
- "This theme is slightly XL but the engineer will manage." — XL is "split into a series," not "try harder."
- "Conflicting findings can both be addressed together." — If two findings contradict, surface the conflict as an open question. Do not paper over it.

## Red Flags

Stop and re-cluster if any of these appear:

- Any theme lands at 9+ findings, or a single plan touches 9+ files.
- Conflicting findings were silently reconciled instead of flagged as an open question.
- The index excludes nothing even though some findings are duplicates, already resolved, or not actionable — likely a missed exclusion pass.
- A plan references "the review" or "finding #3" (violates self-contained rule).

## Verification

Before reporting Phase 5, verify:

- Every theme is sized ≤L.
- `! grep -l "as described in the review\|see finding #\|per the report" PR_PLAN_*.md >/dev/null` succeeds (self-contained rule).
- Every conflict between findings is surfaced as an open question, not resolved unilaterally.
- Every plan has all template sections populated with concrete content (no "N/A").
