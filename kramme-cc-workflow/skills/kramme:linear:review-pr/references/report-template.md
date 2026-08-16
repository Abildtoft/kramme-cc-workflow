# Inline Report Template

Render every section. Use `None` for an empty findings or limitation section.

```markdown
# Linear Issue / Pull Request Review

- **Verdict:** PASS | PASS_WITH_CONCERNS | FAIL | BLOCKED
- **Linear issue:** [TEAM-123 — title](issue-url)
- **Pull Request:** [#123 — title](pr-url)
- **Reviewed head:** `<full head OID>`
- **PR state:** OPEN | CLOSED | MERGED
- **Base:** `<base branch>`

## Coverage

- Requirements: `<total>` (`<verified>` verified, `<partial>` partial, `<missing>` missing, `<contradicted>` contradicted, `<unverified>` unverified, `<out-of-scope>` out of scope)
- Material PR change groups: `<total>` (`<required>` required, `<supporting>` supporting, `<extensions>` undocumented extensions, `<unrelated>` unrelated, `<contradictory>` contradictory)
- Requirement-bearing references: `<accessible>` accessible, `<inaccessible>` inaccessible
- Test evidence: `<trusted-ci-passed>` trusted CI checks passed, `<trusted-ci-failed>` failed, `<not-run-locally>` not run locally

## Verdict Rationale

<Two to four sentences explaining the highest-severity evidence and why the verdict rules produce this result.>

## Requirement Traceability

| ID | Linear requirement | Status | PR evidence | Test evidence |
| --- | --- | --- | --- | --- |
| LREQ-001 | `<citation and concise requirement>` | VERIFIED | `<diff/code paths and lines>` | `<test path/result or evidence gap>` |

## Findings

### Critical

- **[LREQ-xxx or SCOPE-xxx] Finding title**
  - Linear: `<issue citation>`
  - PR: `<diff and code citations>`
  - Behavior: `<input/state -> behavior -> impact>`
  - Test evidence: `<evidence or exact gap>`
  - Recommendation: `<smallest issue-aligned correction>`

### Major

<same structure, or None>

### Minor

<same structure, or None>

## Undocumented Extensions and Unrelated Changes

- **[SCOPE-xxx] REQUIRED | SUPPORTING | UNDOCUMENTED_EXTENSION | UNRELATED | CONTRADICTORY** — `<change group, evidence, and issue relationship>`

Include `REQUIRED` and `SUPPORTING` rows only when needed to explain a disputed classification. Otherwise show only extensions, unrelated changes, and contradictions; use `None` when there are none.

## Unverified Requirements and Context Gaps

- **LREQ-xxx** — `<what cannot be established, why, and the exact evidence or access needed>`
- **Reference:** `<URL or Linear object>` — `<why it matters and why it was inaccessible>`

## Test Evidence

| Evidence | Result | Requirement coverage |
| --- | --- | --- |
| `Trusted CI: <approved app / workflow / check>` | PASS \| FAIL — `<exact snapshot, unchanged/base-controlled definition, and requirement-traced failure when applicable>` | `LREQ-001, LREQ-003` |

Only include CI results that satisfy the trusted CI policy: immutable snapshot, terminal conclusion, approved producer, and a base-controlled or unchanged execution definition. Use success as verification evidence; use failure as finding evidence only when the result traces the failure to a requirement. Never materialize or run code from the PR-head worktree locally. When no trusted runtime result is available, state `Not run locally` and name the exact evidence gap.

## Verified Alignments

- **LREQ-xxx** — `<concise requirement-to-code-to-test proof>`

## Recommended Next Actions

1. `<Fix or clarification ordered by verdict impact>`
2. `<Rerun $kramme:linear:review-pr with the same PR and issue after the head changes>`
```

## Output Discipline

- Sort findings Critical, Major, then Minor; within severity, follow requirement order and then scope findings.
- Use full file paths relative to the repository and line numbers from the immutable PR-head blobs.
- Keep quotes from the issue short; paraphrase when the clause is long.
- Do not bury a blocking inaccessible reference in prose. List it in coverage, context gaps, and verdict rationale.
- When the verdict is `PASS`, include enough verified alignments to demonstrate coverage across every major requirement area rather than merely saying no problems were found.
- When the verdict is `BLOCKED`, still include directly proven findings and alignments gathered before the blocker.
