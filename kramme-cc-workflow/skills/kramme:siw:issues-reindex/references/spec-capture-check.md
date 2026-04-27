# Spec Capture Check

Before deleting DONE issues, check whether their decisions, outcomes, and related LOG.md entries are captured in the permanent specification files.

### 4.0 Preconditions

This step only runs if:
- There are DONE issues to delete (from Step 2)
- At least one spec file exists

**If no spec file exists:**
```
Note: No specification file found — skipping spec capture check.
```
Skip to Step 5.

### 4.1 Locate Spec Files

Find spec files using the same detection as other SIW skills:

1. Find `.md` files directly under `siw/` (non-recursive), excluding: `LOG.md`, `OPEN_ISSUES_OVERVIEW.md`, `SPEC_STRENGTHENING_PLAN.md`, `DISCOVERY_BRIEF.md`, `AUDIT_.*\.md`
2. Never include files under `siw/issues/` in spec detection
3. Find `.md` files under `siw/supporting-specs/` if the directory exists
4. Store as `spec_files` (main) and `supporting_spec_files`

### 4.2 Read DONE Issue Files

For each DONE issue (filtered by scope from Step 3.1), read the issue file and extract **capturable content**:

| Content Category | Where to Find | What Qualifies |
|---|---|---|
| **Decision** | `## Decision` section | Any non-placeholder content (not `_To be filled_`) |
| **Selected Option** | `## Options` with a chosen option, or `## Decision` referencing an option | The chosen approach and rationale |
| **Implementation Notes** | `## Technical Notes` section | Concrete architectural or pattern choices |
| **Key Outcomes** | `## Acceptance Criteria` with checked items | Criteria that reveal design decisions (not just "tests pass") |

Skip issues whose files are missing or contain only placeholder content.

### 4.3 Read LOG.md for Related Entries

If `siw/LOG.md` exists, scan for entries referencing DONE issue IDs (in any format: `G-002`, `ISSUE-G-002`, etc.):

**4.3.1 Decision Log entries** — Scan `## Decision Log` for decisions referencing DONE issues. Extract: decision number, title, problem, decision, rationale.

**4.3.2 Current Progress entries** — Scan `## Current Progress > ### Last Completed` for references to DONE issues with implementation details.

**4.3.3 Rejected Alternatives** — Scan `## Rejected Alternatives Summary` for rows linked to decisions that reference DONE issues.

**4.3.4 Guiding Principles** — If `## Guiding Principles` has non-placeholder content and the spec has no matching Guiding Principles section, include as a capture candidate.

### 4.4 Compare Against Spec

For each capture candidate, check whether it already exists in the spec files using lightweight text search:

1. **Decision heading match:** Search spec files for explicit decision headings like `### Decision #N:` (or `#### Decision #N:`). If found → **Captured**.
   - Do **not** treat a bare `#N` match as captured.
2. **Keyword co-occurrence:** Extract 2-3 distinctive terms from the candidate summary. If multiple terms co-occur within the same section of a spec file → **Possibly captured**.
3. **Section existence check:** For Guiding Principles, check if the spec has a non-empty `## Guiding Principles` section → **Captured** if present.

Classify each candidate as: **Captured** / **Possibly captured** / **Uncaptured**.

### 4.5 Present to User

**If all candidates are Captured:**
```
Spec Capture Check: All decisions and outcomes from DONE issues are already reflected in the specification.
```
Proceed to Step 5.

**If uncaptured or possibly-captured items exist**, present grouped by source:

```
Spec Capture Check
==================

{N} items from DONE issues may not be captured in the specification:

From G-002 (API Design Pattern):
  1. [Decision] Chose explicit properties over IAuditable
     Source: siw/issues/ISSUE-G-002-api-design.md > Decision section
     Status: UNCAPTURED

  2. [LOG Decision #5] Make ActionByUserId Nullable
     Source: siw/LOG.md > Decision Log > Decision #5
     Status: UNCAPTURED

From P1-003 (Bug Fix):
  3. [Implementation Notes] Used retry pattern with exponential backoff
     Source: siw/issues/ISSUE-P1-003-retry-logic.md > Technical Notes
     Status: POSSIBLY CAPTURED - "retry" mentioned in spec but details differ

Cross-cutting:
  4. [Guiding Principles] 4 principles in LOG.md
     Source: siw/LOG.md > Guiding Principles
     Status: UNCAPTURED
```

Use AskUserQuestion:

```yaml
header: "Spec Capture Check"
question: "Found uncaptured content from DONE issues. How should I proceed?"
options:
  - label: "Migrate all to spec"
    description: "Add all uncaptured items to the specification before deleting issues"
  - label: "Review each item"
    description: "Let me choose which items to migrate"
  - label: "Skip — proceed with deletion"
    description: "Delete DONE issues without migrating (content may be lost)"
```

**If "Review each item":** For each uncaptured item, use AskUserQuestion:

```yaml
header: "Migrate to Spec?"
question: "Item {N}: [{category}] {summary}\n\nFrom {issue_id}: {issue_title}\nSource: {source}"
options:
  - label: "Migrate to spec"
    description: "Add this to the specification"
  - label: "Skip"
    description: "Not worth preserving"
```

**If >10 uncaptured items**, ask once for high-level handling first:

```yaml
header: "Spec Capture Check"
question: "Found {N} uncaptured items from DONE issues. How should I proceed?"
options:
  - label: "Migrate all to spec"
    description: "Add all uncaptured items before deleting DONE issues"
  - label: "Review by category"
    description: "Choose categories to migrate in one step"
  - label: "Skip — proceed with deletion"
    description: "Delete DONE issues without migration (content may be lost)"
```

**If "Review by category":** use category-level multiSelect:

```yaml
header: "Select Categories"
question: "Choose categories to migrate to the specification."
multiSelect: true
options:
  - label: "Decisions ({n})"
    description: "Migrate decision entries"
  - label: "Implementation notes ({n})"
    description: "Migrate architectural/pattern notes"
  - label: "Key outcomes ({n})"
    description: "Migrate decision-relevant acceptance outcomes"
  - label: "Guiding principles ({n})"
    description: "Migrate principles from LOG.md"
```

If no categories are selected, treat it as:
```
Spec Capture: Skipped (user chose to proceed without migration)
```

### 4.6 Migrate Selected Items to Spec

Route items to the appropriate spec file using the same patterns as `issue-implement` Step 10.4:

**Routing rules for supporting specs:**
- Data model decisions → `*-data-model*.md`
- API decisions → `*-api*.md`
- UI/frontend decisions → `*-ui*.md` or `*-frontend*.md`
- Default → main spec

**For supporting specs:** Update actual spec content (not just append to Design Decisions). If a decision changes an API endpoint, update the endpoint definition.

**For main spec — Decisions:**

Add to `## Design Decisions` section (create if missing):

```markdown
### Decision #{n}: {Title}
**Date:** {date from LOG.md or current date} | **Source:** {issue_id}

**Context:** {problem statement}
**Decision:** {chosen approach}
**Rationale:** {why}
```

**For main spec — Guiding Principles:**

Add to or create `## Guiding Principles` section.

**For main spec — Rejected Alternatives:**

Add to `## Rejected Approaches` or `## Design Decisions` section:

```markdown
### Rejected: {alternative name}
**For:** {purpose} | **Decision:** #{n}
**Why Rejected:** {reason}
```

### 4.7 Report Migration Results

```
Spec Capture: {N} items migrated
- {spec_file_1}: {n1} item(s)
- {spec_file_2}: {n2} item(s)
```
or
```
Spec Capture: Skipped (user chose to proceed without migration)
```
or
```
Spec Capture: All items already captured in spec
```

Proceed to Step 5.
