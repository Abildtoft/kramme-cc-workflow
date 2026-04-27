# Document Creation

Use this procedure during Phase 4 after `spec_filename`, `use_supporting_specs`, and any optional `linked_spec_files` or `discovered_content` values are set.

## Phase 4: Create Documents

Create the `siw/` directory if it doesn't already exist.

### 4.1 Create Specification Document

Create `siw/{spec_filename}` with structure based on available content.

Read the spec template for the appropriate path from `assets/spec-templates.md`. Use the slim template if `linked_spec_files` exists, the rich template if `discovered_content` exists, or the basic template otherwise. If `use_supporting_specs` is true, include the Supporting Specifications section from that file.

### 4.2 Create siw/LOG.md

Read the template from `assets/log-template.md`. Populate `{spec_filename}` and `{current date}`, then write to `siw/LOG.md`.

### 4.3 Create siw/OPEN_ISSUES_OVERVIEW.md

Create `siw/OPEN_ISSUES_OVERVIEW.md`:

```markdown
# Open Issues Overview

## General

**Parallelization:** Needs coordination

| # | Title | Status | Size | Priority | Related |
|---|-------|--------|------|----------|---------|
| _None_ | _Use `/kramme:siw:issue-define` to create first issue (G-001)_ | | | | |

**Status Legend:** READY | IN PROGRESS | IN REVIEW | DONE

**Issue Naming:** `G-XXX` for general issues, `P1-XXX`, `P2-XXX` for phase-specific issues.

**Details:** See `siw/issues/ISSUE-{prefix}-XXX-*.md` files.
```

### 4.4 Create siw/issues/ Directory

```bash
mkdir -p siw/issues
```

Create placeholder file `siw/issues/.gitkeep` to ensure directory is tracked:

```bash
touch siw/issues/.gitkeep
```

### 4.5 Create siw/supporting-specs/ Directory (if enabled)

**Only if `use_supporting_specs` is true:**

```bash
mkdir -p siw/supporting-specs
touch siw/supporting-specs/.gitkeep
```
