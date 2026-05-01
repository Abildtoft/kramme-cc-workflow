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
2. Draft theme names using the pattern `verb-noun` in kebab-case (e.g., `add-api-error-handling`, `consolidate-config-parsing`, `remove-dead-code`).
3. Build a dependency graph across themes before naming files:
   - A dependency exists when a theme cannot start until another theme lands, or when landing one theme materially reduces risk for another.
   - A blocker exists when a theme must land before one or more downstream themes.
   - Themes with no direct or transitive dependency between them are parallel candidates.
   - If dependency direction is unclear, add an open question and choose the most conservative ordering.
4. Assign every theme an execution label before generating files:
   - Use `W##L` where `##` is a zero-padded wave number and `L` is an uppercase lane letter, such as `W01A`, `W01B`, `W02A`.
   - Same wave number means the plans can run in parallel.
   - A later wave number means the plan is blocked by at least one earlier-wave plan, and the exact blocker labels must be named in the plan title, index, and summary.
   - Independent single-plan work still receives `W01A`.
5. Create file slugs by prefixing the theme slug with the execution label, using kebab-case for the working slug and UPPER_SNAKE_CASE for the filename slug. Example: `w01a-define-error-types` becomes `PR_PLAN_W01A_DEFINE_ERROR_TYPES.md`.
6. Verify no theme is too large (would require 500+ changed lines or touch 9+ files). Split if needed.
7. Verify no two themes overlap in affected files without an explicit dependency note.

Present the clustering to the user before generating files. Prefix the block with the `PLAN:` output marker so downstream tooling can parse the proposed clustering:

```
PLAN: Proposed themes
  Wave W01 (parallel):
    W01A add-api-error-handling (4 findings, size M) -- blocks W02A -- files: src/api/*.ts
    W01B remove-dead-exports (2 findings, size S) -- independent -- files: src/lib/*.ts
  Wave W02:
    W02A consolidate-config-parsing (3 findings, size S) -- blocked by W01A -- files: src/config/*, src/utils/config.ts
  0 excluded findings

Proceed? (yes / adjust)
```

Wait for user confirmation. If the user requests adjustments, re-cluster accordingly.

### Phase 3: Generate Plans

For each confirmed theme:

1. Read the plan template from `assets/plan-template.md`.
2. Fill in all sections. Every plan must be **fully self-contained** -- an engineer who has never read any prior document must understand the problem, context, and solution from the plan alone.
3. Write the file to `PR_PLAN_{EXECUTION_LABEL}_{SLUG}.md` in the project root. Use UPPER_SNAKE_CASE for the slug in the filename (e.g., `PR_PLAN_W01A_DEFINE_ERROR_TYPES.md`).
4. Create a plan display name using this pattern: `{execution label} {theme name} ({parallel / blocked-by / blocks summary})`.
5. Include the full plan display name in the plan title:
   - Independent or parallel plan: `# PR Plan W01A: define-error-types (parallel in W01; independent)`
   - Blocker plan: `# PR Plan W01A: define-error-types (blocks W02A)`
   - Blocked plan: `# PR Plan W02A: adopt-typed-errors (blocked by W01A; blocks W03A)`
   - Use multiple labels when needed, e.g. `blocked by W01A, W01B`.
6. Keep the title, filename, Dependencies and Sequencing section, index row, dependency map, and final summary aligned. The same blocker/dependent labels must appear in all of them.

#### Plan content requirements

Every section and subsection in the template must be populated. Do not leave headings empty or write "N/A".

- **Problem Statement**: Restate the full problem. Do NOT reference finding IDs, report names, or prior documents.
- **Why These Belong Together**: Explain the shared root cause, area, or dependency.
- **Goals**: What the PR achieves. Be specific and measurable.
- **Non-Goals**: What the PR explicitly does NOT do.
- **Affected Files and Systems**: Every file, module, and system that will be touched.
- **Current Behavior**: What happens today, with concrete examples or code references.
- **Intended End State**: Target behavior after the PR lands.
- **Dependencies and Sequencing**: The execution label, parallel wave, exact blocker labels, exact dependent labels, what work must be completed before this PR can start, and what work this PR unblocks. Describe both labels and content so the plan is self-contained.
- **Risks**: What could go wrong. Include mitigation for each risk.
- **Open Questions**: Questions that must be answered before implementation. Note who should answer and the default assumption.
- **Implementation Plan**: Numbered step-by-step instructions. Each step small enough to verify independently.
- **Test and Verification Plan**: Use the verification methods that fit the theme. Include automated tests when code or executable behavior changes, and use workflow-specific checks such as manual validation, rerunning the source audit/review, docs/build validation, screenshots, or reproduced QA steps when the work is non-code.
- **Completion Criteria**: Checklist of conditions for the PR to be mergeable.

### Phase 4: Generate Index

1. Read the index template from `assets/index-template.md`.
2. Write `PR_PLAN_INDEX.md` in the project root with:
   - **Plan listing**: execution label, filename, full plan display name, blocking status, parallel group, and a 2-4 sentence summary for each plan.
   - **Recommended implementation order**: ordered by wave and dependency, with rationale (dependencies, risk reduction, quick wins first). Explicitly group same-wave plans as parallel.
   - **Dependency map**: which labeled plans depend on which labeled blockers, and which plans are independent.
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
  PR_PLAN_{EXECUTION_LABEL}_{SLUG_1}.md -- {execution label} {theme name} ({n} findings, size {XS|S|M|L}; {parallel in W## / blocked by W##L / blocks W##L})
  PR_PLAN_{EXECUTION_LABEL}_{SLUG_2}.md -- {execution label} {theme name} ({n} findings, size {XS|S|M|L}; {parallel in W## / blocked by W##L / blocks W##L})
  ...

THINGS I DIDN'T TOUCH:
  • The source findings file (read-only for this skill)
  • Any existing PR_PLAN_*.md files from prior runs (surface them here if present)
  • Findings listed under "Excluded" in the index

POTENTIAL CONCERNS:
  • {Any conflicting-findings CONFUSION markers that remained unresolved}
  • {Any inferred severities flagged UNVERIFIED}
  • {If none, state: "None"}

Recommended first PR: PR_PLAN_{EXECUTION_LABEL}_{SLUG}.md -- {one-line rationale including what it unblocks}
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
- **Dependency-readable naming.** Plan titles, filenames, index rows, and the final summary must make sequencing obvious without reading the full plan. Use `W01A`/`W01B` for parallel first-wave plans, higher wave numbers for blocked follow-up plans, and explicit `blocked by`/`blocks` labels wherever a dependency exists.
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
- Any generated plan filename or title lacks an execution label such as `W01A`.
- A blocked plan's title, index row, or dependency section omits the label of the plan blocking it.
- Same-wave plans are described as sequential instead of parallel.
- Conflicting findings were silently reconciled instead of flagged as an open question.
- The index excludes nothing even though some findings are duplicates, already resolved, or not actionable — likely a missed exclusion pass.
- A plan references "the review" or "finding #3" (violates self-contained rule).

## Verification

Before reporting Phase 5, verify:

- Every theme is sized ≤L.
- `! grep -l "as described in the review\|see finding #\|per the report" PR_PLAN_*.md >/dev/null` succeeds (self-contained rule).
- Every generated plan filename and title includes its execution label.
- Every blocked plan names its blocker labels in the title, index row, dependency map, and Dependencies and Sequencing section.
- Every same-wave group is marked as parallel in the index and summary.
- Every conflict between findings is surfaced as an open question, not resolved unilaterally.
- Every plan has all template sections populated with concrete content (no "N/A").
