# Document Creation

Use this procedure during Phase 4 after `spec_filename`, `use_supporting_specs`, `artifact_readiness`, `readiness_reason`, `readiness_next_steps`, `open_issues_empty_message`, and any optional `linked_spec_files` or `discovered_content` values are set.

## Readiness Classification

Before creating documents, classify the initialized artifact using the Artifact Readiness Contract and store:

- `artifact_readiness`: `product-only`, `requirements-only`, or `planning-ready`
- `readiness_reason`: one concise reason
- `readiness_next_steps`: the exact next-step lines for generated `siw/LOG.md` and the success report
- `open_issues_empty_message`: the placeholder message for the empty `siw/OPEN_ISSUES_OVERVIEW.md` table

When `linked_spec_files` exists, base the classification on `linked_spec_readiness_context`. If the available linked-source context does not prove scope, success criteria, technical context/dependencies, and absence of blocking open questions, do not infer `planning-ready`; classify the artifact as `product-only` or `requirements-only` and route to discovery/spec hardening.

For `product-only` or `requirements-only`, generated tracking files must point to `/kramme:siw:discovery` and must not imply issue definition or implementation is ready. For `planning-ready`, choose either the phased path (`/kramme:siw:generate-phases`, then implementation after issues exist) or the single-issue path (`/kramme:siw:issue-define`, then implementation after the issue exists).

## Phase 4: Create Documents

Create the `siw/` directory if it doesn't already exist.

### 4.1 Create Specification Document

Before writing, check whether `siw/{spec_filename}` already exists with `[ -e "siw/{spec_filename}" ]`. This can happen when Phase 1's "Start fresh" branch preserved a permanent spec whose filename now collides with the one chosen in Phase 3.

If the target exists, use AskUserQuestion:

```yaml
header: "Spec File Exists"
question: "siw/{spec_filename} already exists (preserved from an earlier run). How should I proceed?"
options:
  - label: "Reuse existing spec"
    description: "Keep the existing file as-is and skip Step 4.1; continue with Step 4.2"
  - label: "Write to a new filename"
    description: "Save the generated spec as siw/{spec_filename-stem}-NEW{ext} and keep the original"
  - label: "Overwrite"
    description: "Replace siw/{spec_filename} with the newly generated content"
  - label: "Abort"
    description: "Stop without changing any files"
```

Apply the user's choice:

- **Reuse existing spec**: skip to Step 4.2 (do not write).
- **Write to a new filename**: update `spec_filename` to the renamed path before continuing.
- **Overwrite**: continue normally — the file will be replaced.
- **Abort**: stop this command without changing any files.

If the target does not exist, continue normally.

Create `siw/{spec_filename}` with structure based on available content.

Read the spec template for the appropriate path from `assets/spec-templates.md`. Use the slim template if `linked_spec_files` exists, the rich template if `discovered_content` exists, or the basic template otherwise. If `use_supporting_specs` is true, include the Supporting Specifications section from that file.

### 4.2 Create siw/LOG.md

Read the template from `assets/log-template.md`. Populate `{spec_filename}`, `{current date}`, `{artifact_readiness}`, `{readiness_reason}`, `{readiness_next_steps}`, and `{readiness_blockers}`, then write to `siw/LOG.md`.

Set `{readiness_blockers}` from readiness:

- `product-only`: `Needs testable scope and success criteria before issue creation.`
- `requirements-only`: `Needs planning detail before phase or issue creation.`
- `planning-ready`: `None`

Set `{readiness_next_steps}` from readiness:

- `product-only` or `requirements-only`:
  ```markdown
  1. Harden the spec with `/kramme:siw:discovery`
  2. Create phases or issues only after the artifact is planning-ready
  ```
- `planning-ready` and phased work:
  ```markdown
  1. Generate phase issues with `/kramme:siw:generate-phases`
  2. Begin implementation with `/kramme:siw:issue-implement` after issues exist
  ```
- `planning-ready` and one coherent issue:
  ```markdown
  1. Define the first issue with `/kramme:siw:issue-define`
  2. Begin implementation with `/kramme:siw:issue-implement` after the issue exists
  ```

### 4.3 Create siw/OPEN_ISSUES_OVERVIEW.md

Create `siw/OPEN_ISSUES_OVERVIEW.md`:

```markdown
# Open Issues Overview

## General

**Parallelization:** Needs coordination

| # | Title | Status | Size | Priority | Mode | Related |
| --- | --- | --- | --- | --- | --- | --- |
| _None_ | _{open_issues_empty_message}_ |  |  |  |  |  |

**Status Legend:** READY | IN PROGRESS | IN REVIEW | DONE

**Issue Naming:** `G-XXX` for general issues, `P1-XXX`, `P2-XXX` for phase-specific issues.

**Details:** See `siw/issues/ISSUE-{prefix}-XXX-*.md` files.
```

Set `{open_issues_empty_message}` from readiness:

- `product-only` or `requirements-only`: `Harden the spec with /kramme:siw:discovery before creating issues`
- `planning-ready` and phased work: `Use /kramme:siw:generate-phases to create phase issues`
- `planning-ready` and one coherent issue: `Use /kramme:siw:issue-define to create first issue (G-001)`

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
