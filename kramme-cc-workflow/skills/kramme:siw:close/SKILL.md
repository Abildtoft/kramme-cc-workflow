---
name: kramme:siw:close
description: Close an SIW project by generating permanent documentation in docs/<feature>/ and removing temporary workflow files
disable-model-invocation: true
user-invocable: true
---

# Close SIW Project

Generate permanent documentation from SIW artifacts, then remove temporary workflow files. This is the terminal lifecycle command for SIW projects -- it captures accumulated knowledge (decisions, architecture, principles) before cleaning up.

**Use when:** The project is complete and you want to preserve the knowledge before removing SIW files.
**Use `siw:reset` instead when:** You want to start a new iteration on the same project.
**Use `siw:remove` instead when:** You just want to delete SIW files without generating documentation.

## Workflow

```
/kramme:siw:close
    |
    v
[Step 1: Scan for SIW files] -> Not found? -> Error, abort
    |
    v
[Step 2: Pre-close verification] -> Open issues? -> Warn user
    |
    v
[Step 3: Determine feature name] -> From spec heading, confirm with user
    |
    v
[Step 4: Extract knowledge from all SIW artifacts]
    |
    v
[Step 5: Generate documentation in docs/<feature-name>/]
    |
    v
[Step 6: Ask about spec disposition]
    |
    v
[Step 7: Remove temporary SIW files]
    |
    v
[Step 8: Clean up empty siw/ directory]
    |
    v
[Step 9: Report results]
```

---

## Step 1: Scan for SIW Files

Check which SIW files exist:

```bash
ls siw/LOG.md siw/OPEN_ISSUES_OVERVIEW.md siw/AUDIT_IMPLEMENTATION_REPORT.md siw/AUDIT_SPEC_REPORT.md siw/SPEC_STRENGTHENING_PLAN.md siw/issues/ 2>/dev/null
find siw -maxdepth 1 -type f -name "*.md" \
  ! -name "LOG.md" \
  ! -name "OPEN_ISSUES_OVERVIEW.md" \
  ! -name "AUDIT_IMPLEMENTATION_REPORT.md" \
  ! -name "AUDIT_SPEC_REPORT.md" \
  ! -name "SPEC_STRENGTHENING_PLAN.md" \
  2>/dev/null
ls siw/supporting-specs/*.md 2>/dev/null
```

**If no SIW files found:**
```
No SIW workflow files found in this directory.

To initialize a new SIW workflow, run /kramme:siw:init
```
**Action:** Stop.

**If only a spec exists (no LOG.md or issues):**

Use AskUserQuestion:

```yaml
header: "Minimal SIW Project"
question: "Only a spec file was found -- no LOG.md, issues, or other workflow files. There's little to extract beyond the spec itself. How should I proceed?"
options:
  - label: "Generate docs from spec only"
    description: "Create documentation from the spec file alone"
  - label: "Abort"
    description: "Cancel -- nothing to close"
```

---

## Step 2: Pre-close Verification

### 2.1 Check for Open Issues

Read `siw/OPEN_ISSUES_OVERVIEW.md` and check for issues not marked DONE:

```bash
grep -E "\| (READY|IN PROGRESS|IN REVIEW) \|" siw/OPEN_ISSUES_OVERVIEW.md 2>/dev/null
```

**If open issues found:**

Use AskUserQuestion:

```yaml
header: "Open Issues Detected"
question: "There are {N} issues not marked DONE ({list statuses}). Closing will remove these issue files. How should I proceed?"
options:
  - label: "Close anyway"
    description: "Generate documentation and remove all SIW files despite open issues"
  - label: "Abort"
    description: "Cancel and finish remaining issues first"
```

### 2.2 Check for Uncommitted Changes

```bash
git status --porcelain siw/ 2>/dev/null
```

If uncommitted changes exist, warn:
```
Warning: There are uncommitted changes to SIW files.
These will be included in the generated documentation but the SIW file
changes themselves will be lost after cleanup.
```

---

## Step 3: Determine Feature Name

The feature name determines the output directory `docs/<feature-name>/`.

### 3.1 Derive Name

1. Build `spec_candidates` from `siw/*.md`, excluding temporary SIW files:
   - `siw/LOG.md`
   - `siw/OPEN_ISSUES_OVERVIEW.md`
   - `siw/AUDIT_IMPLEMENTATION_REPORT.md`
   - `siw/AUDIT_SPEC_REPORT.md`
   - `siw/SPEC_STRENGTHENING_PLAN.md`
2. If no spec candidates are found, follow the "No spec file found" edge case.
3. If multiple spec candidates are found, use AskUserQuestion to select the main one:
   ```yaml
   header: "Multiple Spec Files Found"
   question: "Which specification file is the main spec for this project?"
   options:
     - label: "{spec_file_1}"
     - label: "{spec_file_2}"
   ```
4. Read the first `# heading` from the selected spec
5. Convert to kebab-case: lowercase, replace spaces/underscores with hyphens, strip non-alphanumeric characters
6. If the heading is too generic (e.g., just "Specification" or "Feature"), fall back to the filename minus suffixes like `_SPECIFICATION`, `_DESIGN`, `_PLAN`, `.md`

### 3.2 Confirm with User

Use AskUserQuestion:

```yaml
header: "Documentation Directory"
question: "Where should the documentation be generated?"
freeform: true
defaultValue: "docs/{derived-feature-name}"
```

Store as `docs_path`.

### 3.3 Check for Existing Directory

If `docs_path` already exists:

```yaml
header: "Documentation Directory Exists"
question: "{docs_path} already exists. How should I proceed?"
options:
  - label: "Overwrite"
    description: "Replace existing documentation files"
  - label: "Choose different directory"
    description: "Enter a different path"
  - label: "Abort"
    description: "Cancel without making changes"
```

If "Choose different directory", re-prompt with freeform AskUserQuestion.

---

## Step 4: Extract Knowledge from SIW Artifacts

Read all existing SIW files and extract structured knowledge.

### 4.1 From the Spec (`siw/[YOUR_SPEC].md`)

Extract:
- **Project title** (from `#` heading)
- **Overview** (from `## Overview`)
- **Objectives** (from `## Objectives`)
- **Scope** (from `## Scope` -- In Scope and Out of Scope)
- **Success criteria** (from `## Success Criteria`)
- **Design decisions** (from `## Design Decisions`)
- **Technical design** (from `## Technical Design` if present)
- **Linked specifications** (from `## Linked Specifications` if present)

### 4.2 From Supporting Specs (`siw/supporting-specs/*.md`)

For each supporting spec:
- Extract title and key content
- Categorize by domain (data model, API, UI, etc.)

### 4.3 From `siw/LOG.md`

Extract:
- **Decision Log entries** -- all decisions with number, title, problem, decision, rationale, alternatives, impact
- **Guiding Principles** (from `## Guiding Principles`)
- **Rejected Alternatives Summary** (from the table)
- **Final project status** (from `## Current Progress`)

### 4.4 From `siw/OPEN_ISSUES_OVERVIEW.md`

Extract:
- Phase structure (from section headers)
- Issue count and completion percentage
- All issues with final statuses

### 4.5 From Individual Issue Files (`siw/issues/ISSUE-*.md`)

For DONE issues:
- Title, description, resolution section

For non-DONE issues:
- Title and status (listed as deferred work)

### 4.6 From Audit Reports (if present)

From `siw/AUDIT_IMPLEMENTATION_REPORT.md` and `siw/AUDIT_SPEC_REPORT.md`:
- Note their existence as quality verification evidence

### 4.7 Deduplicate Decisions

Decisions may appear in both LOG.md and the spec's Design Decisions section (from prior resets or syncs):
1. Read decisions from LOG.md (primary, most complete)
2. Read decisions from spec's Design Decisions section
3. Match by decision number (`Decision #N`) or title
4. Prefer the LOG.md version (has full detail: alternatives, impact)
5. Include any decisions that appear only in the spec

---

## Step 5: Generate Documentation

Create the documentation directory and files.

```bash
mkdir -p {docs_path}
```

### 5.1 `README.md` -- Project Summary

```markdown
# {Project Title}

## Overview

{Overview text from spec, rewritten to be self-contained}

**Status:** Completed
**Completed:** {current date}

## What Was Built

{Narrative summary synthesized from completed issues and spec objectives.
Describe what the implementation delivers, not a list of issue IDs.}

### Scope

**Included:**
{In-scope items from spec, updated based on what was actually implemented}

**Excluded:**
{Out-of-scope items from spec}

## Key Decisions

{N} design decisions were made during this project. See [decisions.md](decisions.md) for full details.

Notable decisions:
- **{Decision title}**: {one-line summary}
- **{Decision title}**: {one-line summary}
- **{Decision title}**: {one-line summary}
{Top 3-5 most impactful decisions}

## Architecture

{If architecture.md was generated:}
See [architecture.md](architecture.md) for technical design details.

{If no architecture.md: brief technical summary from spec's Technical Design
section if it existed, otherwise omit this section entirely.}

## Guiding Principles

{Principles from LOG.md -- learned wisdom during implementation}

1. {Principle 1}
2. {Principle 2}

## Implementation Summary

| Metric | Value |
|--------|-------|
| Issues completed | {done count} / {total count} |
| Decisions made | {N} |

{If any issues were not DONE:}
### Deferred Work
- {Issue title} ({status})
```

### 5.2 `decisions.md` -- Architecture Decision Records

```markdown
# Design Decisions

Key design decisions made during the {project title} implementation.
Each decision includes context, the choice made, alternatives considered, and rationale.

## Decision Index

| # | Title | Category | Date |
|---|-------|----------|------|
| 1 | {title} | {category} | {date} |
...

---

## Decision #{N}: {Title}

**Date:** {date} | **Category:** {category}

### Context
{Problem statement -- what needed to be decided and why}

### Decision
{The chosen approach}

### Rationale
{Why this was chosen}

### Alternatives Considered

| Alternative | Why Rejected |
|-------------|-------------|
| {alt 1} | {reason} |
| {alt 2} | {reason} |

### Impact
{What changed as a result}

---
```

**Source mapping:**
- Decision fields from LOG.md Decision Log entries
- Merge rejected alternatives from both LOG.md per-decision "Alternatives" and the Rejected Alternatives Summary table

**If no decisions found:** Write a brief note: "No formal design decisions were recorded during this project."

### 5.3 `architecture.md` -- Technical Design (Conditional)

**Only generate this file if at least one of:**
- The spec has a `## Technical Design` section
- Supporting specs exist with substantive content
- 5+ decisions with architecture-related categories

```markdown
# Architecture

## Technical Overview

{From spec's Technical Design section and/or supporting specs}

## Data Model

{From supporting spec matching *data-model* or spec's data model section}

## API Design

{From supporting spec matching *api* or spec's API section}

## Component Structure

{From supporting spec matching *ui*, *frontend*, or *architecture*}
```

Include only sections that have content. Omit empty sections.

### Content Rules

All generated documentation must be:
- **Self-contained** -- readable without SIW context
- **Free of SIW references** -- no mentions of `siw/`, `LOG.md`, `OPEN_ISSUES_OVERVIEW.md`, issue file paths, or SIW-specific concepts
- **Written in past tense** where describing what was built
- **Concrete** -- include actual technical details, not placeholders

---

## Step 6: Ask About Spec Disposition

Use AskUserQuestion:

```yaml
header: "Specification Files"
question: "What should happen to the SIW specification file(s)?"
options:
  - label: "Remove"
    description: "Delete spec and supporting specs (knowledge is captured in {docs_path}/)"
  - label: "Keep in siw/"
    description: "Preserve siw/{spec_filename} and siw/supporting-specs/ as-is"
  - label: "Move to {docs_path}/spec/"
    description: "Move spec file(s) into the documentation directory"
```

**If "Move":** Move spec and supporting specs to `{docs_path}/spec/`. Add to README.md:

```markdown
## Original Specification

The original project specification is preserved in [spec/](spec/) for reference.
```

---

## Step 7: Remove Temporary SIW Files

Use `trash` command (recoverable). Fall back to `rm` if `trash` is not available.

**Temporary files (always deleted):**
- `siw/LOG.md`
- `siw/OPEN_ISSUES_OVERVIEW.md`
- `siw/AUDIT_IMPLEMENTATION_REPORT.md`
- `siw/AUDIT_SPEC_REPORT.md`
- `siw/SPEC_STRENGTHENING_PLAN.md`
- `siw/issues/` (entire directory)

**Conditional (based on Step 6):**
- `siw/{spec_filename}` (if "Remove" selected)
- `siw/supporting-specs/` (if "Remove" selected)

```bash
if command -v trash &> /dev/null; then
    trash siw/LOG.md siw/OPEN_ISSUES_OVERVIEW.md siw/AUDIT_IMPLEMENTATION_REPORT.md siw/AUDIT_SPEC_REPORT.md siw/SPEC_STRENGTHENING_PLAN.md 2>/dev/null
    trash -r siw/issues/ 2>/dev/null
    # If spec removal selected:
    trash siw/{spec_filename} 2>/dev/null
    trash -r siw/supporting-specs/ 2>/dev/null
else
    echo "Warning: 'trash' command not found. Files will be permanently deleted."
    echo "Consider installing: brew install trash"
    rm -f siw/LOG.md siw/OPEN_ISSUES_OVERVIEW.md siw/AUDIT_IMPLEMENTATION_REPORT.md siw/AUDIT_SPEC_REPORT.md siw/SPEC_STRENGTHENING_PLAN.md
    rm -rf siw/issues/
    # If spec removal selected:
    rm -f siw/{spec_filename}
    rm -rf siw/supporting-specs/
fi
```

---

## Step 8: Clean Up Empty `siw/` Directory

After deletion, check if `siw/` is empty:

```bash
# Remove .gitkeep files
rm -f siw/.gitkeep siw/issues/.gitkeep siw/supporting-specs/.gitkeep 2>/dev/null
# Remove empty directories
rmdir siw/issues siw/supporting-specs siw 2>/dev/null
```

If `siw/` still has files (spec kept or other files present), leave it alone.

---

## Step 9: Report Results

```
SIW Project Closed

Documentation generated:
  {docs_path}/README.md              - Project summary
  {docs_path}/decisions.md           - {N} design decisions
  {docs_path}/architecture.md        - Technical design       (if generated)

Removed:
  siw/LOG.md
  siw/OPEN_ISSUES_OVERVIEW.md
  siw/AUDIT_IMPLEMENTATION_REPORT.md      (if existed)
  siw/AUDIT_SPEC_REPORT.md               (if existed)
  siw/SPEC_STRENGTHENING_PLAN.md         (if existed)
  siw/issues/ ({count} issue files)
  siw/{spec_filename}                     (if removed)
  siw/supporting-specs/                   (if removed)
  siw/ directory                          (if empty)

{If using trash: Files moved to Trash and can be restored if needed.}

Preserved:
  siw/{spec_filename}                     (if kept)
  siw/supporting-specs/                   (if kept)
  {docs_path}/spec/                       (if moved)

The documentation in {docs_path}/ is self-contained and
can be read without any SIW context.
```

---

## Edge Cases

### No spec file found

```yaml
header: "No Specification Found"
question: "No specification file was found in siw/ after excluding temporary SIW files. Cannot generate meaningful documentation. How should I proceed?"
options:
  - label: "Remove SIW files only"
    description: "Delete temporary files without generating documentation (same as /kramme:siw:remove)"
  - label: "Abort"
    description: "Cancel"
```

### Linked external specifications

If the spec has a `## Linked Specifications` section referencing files outside `siw/`:
- Include the linked file references in the documentation README
- Do NOT delete linked files (they are outside `siw/`)
- Note them in the README under a "Related Documentation" section

### No decisions in LOG.md

If LOG.md has no Decision Log entries:
- `decisions.md` will contain only the note: "No formal design decisions were recorded during this project."
- README.md "Key Decisions" section replaced with: "No formal decisions were recorded. See the architecture documentation for technical details."

## Important Notes

1. **Generate before deleting** -- all documentation must be written and confirmed before any files are removed
2. **Use `trash` when available** -- allows recovery from system Trash
3. **Self-contained output** -- generated docs must never reference SIW file paths or concepts
4. **Respect linked files** -- never delete files outside `siw/`
5. **Deduplicate decisions** -- merge LOG.md and spec decisions, preferring LOG.md for completeness
