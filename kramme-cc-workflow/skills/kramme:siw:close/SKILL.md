---
name: kramme:siw:close
description: Close an SIW project by generating permanent documentation in docs/<feature>/ and removing temporary workflow files
argument-hint: "[--auto]"
disable-model-invocation: true
user-invocable: true
---

# Close SIW Project

Generate permanent documentation from SIW artifacts, then remove temporary workflow files. This is the terminal lifecycle command for SIW projects -- it captures accumulated knowledge (decisions, architecture, principles) before cleaning up.

**Use when:** The project is complete and you want to preserve the knowledge before removing SIW files. **Use `siw:reset` instead when:** You want to start a new iteration on the same project. **Use `siw:remove` instead when:** You just want to delete SIW files without generating documentation.

Parse `$ARGUMENTS` before Step 1. If `--auto` is present, set `AUTO_MODE=true`. `--auto` uses the derived documentation directory and skips confirmation prompts only when the close is unambiguous: no open issues, no dirty SIW files, one main spec candidate, and no existing docs directory. It does not bypass cleanup safety or overwrite existing documentation.

## Step 1: Scan for SIW Files

Check whether any SIW artifacts exist:

```bash
find siw -type f -print -quit 2> /dev/null
```

If the command returns no output, no SIW files exist. Print the message below and stop:

```
No SIW workflow files found in this directory.

To initialize a new SIW workflow, run /kramme:siw:init
```

Otherwise, detect the "minimal SIW" case (only a spec, no workflow state):

```bash
if [ ! -f siw/LOG.md ] && [ ! -d siw/issues ] && [ -n "$(ls siw/*.md 2> /dev/null)" ]; then echo minimal; fi
```

If the check prints `minimal` and `AUTO_MODE=true`, choose **Generate docs from spec only** automatically.

If the check prints `minimal` and `AUTO_MODE` is false, use AskUserQuestion:

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
grep -iE "\| (READY|IN PROGRESS|IN REVIEW) \|" siw/OPEN_ISSUES_OVERVIEW.md 2> /dev/null
```

**If open issues found:**

If `AUTO_MODE=true`, stop with `MISSING REQUIREMENT: open SIW issues remain; rerun without --auto to close anyway or abort`.

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
git status --porcelain siw/ 2> /dev/null
```

If uncommitted changes exist and `AUTO_MODE=true`, stop with `MISSING REQUIREMENT: uncommitted SIW changes exist; rerun without --auto to review them before cleanup`.

If uncommitted changes exist and `AUTO_MODE` is false, warn:

```
Warning: There are uncommitted changes to SIW files.
These will be included in the generated documentation but the SIW file
changes themselves will be lost after cleanup.
```

### 2.3 Check Recoverable Deletion for Auto Mode

If `AUTO_MODE=true`, verify `trash` is installed before generating documentation or moving spec files:

```bash
command -v trash
```

If it is missing, stop with `MISSING REQUIREMENT: trash is required for --auto close; rerun without --auto to confirm permanent deletion`.

---

## Step 3: Determine Feature Name

The feature name determines the output directory `docs/<feature-name>/`.

### 3.1 Derive Name

1. Build `spec_candidates` from `siw/*.md`, excluding temporary SIW files:
   - `siw/LOG.md`
   - `siw/OPEN_ISSUES_OVERVIEW.md`
   - `siw/AUDIT_*.md`
   - `siw/PRODUCT_AUDIT.md`
   - `siw/SIW_*.md`
   - `siw/SPEC_STRENGTHENING_PLAN.md`
   - `siw/DISCOVERY_BRIEF.md`

   Synced SIW spec-exclusion contract (keep aligned across SIW spec detectors): `LOG.md`, `OPEN_ISSUES_OVERVIEW.md`, `DISCOVERY_BRIEF.md`, `SPEC_STRENGTHENING_PLAN.md`, `AUDIT_*.md`, `PRODUCT_AUDIT.md`, `SIW_*.md`.
2. If no spec candidates are found, follow the "No spec file found" edge case.
3. If exactly one spec candidate is found, use it as the main spec.
4. If multiple spec candidates are found, build a deterministic match set against the project title from `siw/LOG.md` by filename or first `#` heading (case-insensitive, hyphen/underscore-insensitive).

   Synced SIW main-spec ambiguity contract (keep aligned across SIW spec detectors): when multiple spec candidates remain after deterministic heading/filename matching, auto mode stops with MISSING REQUIREMENT and interactive mode asks the user which file is the main spec.

5. If exactly one spec candidate matches, use it as the main spec.
6. If zero or multiple spec candidates remain after matching and `AUTO_MODE=true`, stop with `MISSING REQUIREMENT: multiple spec candidates found; pass through an interactive close to choose the main spec`. Otherwise use AskUserQuestion to select the main one:
   ```yaml
   header: "Multiple Spec Files Found"
   question: "Which specification file is the main spec for this project?"
   options:
     - label: "{spec_file_1}"
     - label: "{spec_file_2}"
   ```
7. Read the first `# heading` from the selected spec
8. Convert to kebab-case: lowercase, replace spaces/underscores with hyphens, strip non-alphanumeric characters
9. If the heading is too generic (e.g., just "Specification" or "Feature"), fall back to the filename minus suffixes like `_SPECIFICATION`, `_DESIGN`, `_PLAN`, `.md`

### 3.2 Confirm with User

If `AUTO_MODE=true`, use the default `docs/{derived-feature-name}` and print it. Otherwise use AskUserQuestion:

```yaml
header: "Documentation Directory"
question: "Where should the documentation be generated?"
freeform: true
defaultValue: "docs/{derived-feature-name}"
```

Store as `docs_path`.

### 3.3 Check for Existing Directory

If `docs_path` already exists:

If `AUTO_MODE=true`, stop with `MISSING REQUIREMENT: {docs_path} already exists; rerun without --auto to overwrite or choose another directory`.

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
- **Problem statement** (from `## Problem Statement` if present)
- **Stakeholders** (from `## Who's Affected` if present)
- **Objectives** (from `## Objectives`)
- **Scope** (from `## Scope` -- In Scope, Out of Scope, and Deferred)
- **Success criteria** (from `## Success Criteria`)
- **Priority tradeoffs** (from `## Priorities & Tradeoffs` if present)
- **Constraints** (from `## Constraints` if present)
- **Design decisions** (from `## Design Decisions`)
- **Decision boundaries** (from `## Decision Boundaries` if present)
- **Risks** (from `## Risks` if present)
- **Discovery notes** (from `## Discovery Notes` if present)
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

Create the documentation directory and write the output files:

```bash
mkdir -p "{docs_path}"
```

Read the templates from `assets/documentation-templates.md`, substitute placeholders from Step 4's extracted knowledge, and write:

- `{docs_path}/README.md` -- project summary (scope, decisions, principles, implementation metrics)
- `{docs_path}/decisions.md` -- architecture decision records (index, context, rationale, alternatives)
- `{docs_path}/architecture.md` -- technical design, **only** if any of the following holds:
  - the spec has a `## Technical Design` section, **or**
  - supporting specs exist with substantive content, **or**
  - 5+ decisions are tagged with architecture-related categories

### Content Rules

All generated documentation must be:

- **Self-contained** -- readable without SIW context
- **Free of SIW references** -- no mentions of `siw/`, `LOG.md`, `OPEN_ISSUES_OVERVIEW.md`, issue file paths, or SIW-specific concepts
- **Written in past tense** where describing what was built
- **Concrete** -- include actual technical details, not placeholders

---

## Step 6: Resolve File Dispositions

Decide what happens to the spec, `siw/supporting-specs/`, and `siw/SPEC_STRENGTHENING_PLAN.md`. Read `references/spec-disposition.md` for the prompts, discovery-rich detection rules, and conflict handling.

If `AUTO_MODE=true`, do not use the interactive prompts from `references/spec-disposition.md`. Use conservative preservation defaults instead:

- Set `spec_disposition=move` so the main spec and `siw/supporting-specs/` are preserved under `{docs_path}/spec/`.
- If `siw/SPEC_STRENGTHENING_PLAN.md` exists, set `strengthening_plan_disposition=move`; otherwise set `strengthening_plan_disposition=remove`.
- Before moving anything, verify the relevant destination paths under `{docs_path}/spec/` do not already exist. If any destination would overwrite a file or directory, stop with `MISSING REQUIREMENT: spec disposition target already exists; rerun without --auto to choose how to preserve the source material`.
- Append the "Original Specification" README note described in `references/spec-disposition.md` after the move. This keeps durable source material while avoiding hidden prompts in auto mode.

If `AUTO_MODE` is false, read and follow `references/spec-disposition.md`.

Outputs (consumed by Step 7):

- `spec_disposition`: `remove`, `keep`, or `move`
- `strengthening_plan_disposition`: `remove`, `keep`, or `move`

When either disposition is `move`, append the "Original Specification" README note described in the reference.

The reference enforces: `strengthening_plan_disposition=keep` requires `spec_disposition=keep`; otherwise the plan cannot remain orphaned in `siw/` after Step 7.

---

## Step 7: Remove Temporary SIW Files

### 7.1 Verify documentation before deletion

Before removing any SIW files, confirm the generated documentation is present and non-empty. If any required file is missing or zero-byte, abort without deleting anything; the docs must be rewritten before retrying.

```bash
test -s "{docs_path}/README.md" || {
  echo "ERROR: {docs_path}/README.md missing or empty"
  exit 1
}
test -s "{docs_path}/decisions.md" || {
  echo "ERROR: {docs_path}/decisions.md missing or empty"
  exit 1
}
```

If `architecture.md` was generated in Step 5, also require:

```bash
test -s "{docs_path}/architecture.md" || {
  echo "ERROR: {docs_path}/architecture.md missing or empty"
  exit 1
}
```

If any `move` disposition from Step 6 applies, confirm the move targets are in place under `{docs_path}/spec/` before deletion.

### 7.2 Remove files

Use `trash` (recoverable). Always quote the spec filename: it can contain spaces or other shell-significant characters.

In `AUTO_MODE`, `trash` was already verified during Step 2.3 before documentation generation or spec moves. If it is missing here anyway, stop with `MISSING REQUIREMENT: trash is required for --auto close; rerun without --auto to confirm permanent deletion`.

**Temporary files (always deleted):**

- `siw/LOG.md`
- `siw/OPEN_ISSUES_OVERVIEW.md`
- `siw/AUDIT_*.md`
- `siw/PRODUCT_AUDIT.md`
- `siw/SIW_*.md`
- `siw/DISCOVERY_BRIEF.md`
- `siw/issues/` (entire directory)
- `siw/qa-intake/` (QA intake parent summaries)

**Conditional (based on Step 6):**

- `siw/SPEC_STRENGTHENING_PLAN.md` (only if `strengthening_plan_disposition=remove`)
- `siw/{spec_filename}` (only if `spec_disposition=remove`; skip when empty)
- `siw/supporting-specs/` (only if `spec_disposition=remove`)

Build `delete_targets` from the paths above that actually exist. Expand globs before deletion so unmatched globs are never reported as removed. If `delete_targets` is empty, skip the deletion command and continue to reporting. Delete directories by passing them to `trash` as normal path arguments; do not pass recursive flags to `trash`. Do not suppress deletion errors. Capture stderr/stdout so any failure can be reported.

```bash
if command -v trash &> /dev/null; then
  trash "${delete_targets[@]}"
else
  if [ "${AUTO_MODE:-false}" = "true" ]; then
    echo "MISSING REQUIREMENT: trash is required for --auto close; rerun without --auto to confirm permanent deletion"
    exit 1
  fi
  echo "Warning: 'trash' command not found. Files will be permanently deleted."
  echo "Consider installing: brew install trash"
  # Ask for explicit confirmation before running:
  rm -rf "${delete_targets[@]}"
fi
```

After deletion, verify every target with `[ ! -e "$path" ]`. Record only verified-absent paths in `deleted_paths`. Record any surviving paths in `failed_delete_paths` with the captured error output; these must be reported as failures instead of "Removed".

---

## Step 8: Clean Up Empty `siw/` Directory

After deletion, check if `siw/` is empty:

```bash
# Remove .gitkeep only from directories that were part of delete_targets.
rm -f siw/issues/.gitkeep siw/qa-intake/.gitkeep 2> /dev/null
if [ "{spec_disposition}" = "remove" ]; then
  rm -f siw/supporting-specs/.gitkeep 2> /dev/null
fi
if [ -z "$(find siw -mindepth 1 ! -name .gitkeep -print -quit 2> /dev/null)" ]; then
  rm -f siw/.gitkeep 2> /dev/null
fi
# Remove empty directories
rmdir siw/issues siw/qa-intake 2> /dev/null
if [ "{spec_disposition}" = "remove" ]; then
  rmdir siw/supporting-specs 2> /dev/null
fi
rmdir siw 2> /dev/null
```

If `siw/` still has files (spec kept or other files present), leave it alone.

---

## Step 9: Report Results

Print a closing summary built from what actually happened. Include only lines that apply -- do not emit the `(if …)` annotations themselves.

Sections to include:

- **Documentation generated:** every file written under `{docs_path}/` (always at least `README.md` and `decisions.md`; `architecture.md` when generated).
- **Removed:** each path verified absent in Step 7.2 (skip lines for files that never existed).
- **Failed to remove:** each target that still exists after Step 7.2, with the captured error. Omit the section if all targets were removed.
- **Preserved:** each path that survived (`siw/{spec_filename}`, `siw/supporting-specs/`, `siw/SPEC_STRENGTHENING_PLAN.md`, `{docs_path}/spec/`). Omit the section if nothing was preserved.
- **Recovery note:** if `trash` was used in Step 7.2, add: `Files moved to Trash and can be restored if needed.`
- A final line: `The documentation in {docs_path}/ is self-contained and can be read without any SIW context.`

Example shape (with placeholders for the dynamic content):

```
SIW Project Closed

Documentation generated:
  {docs_path}/README.md              - Project summary
  {docs_path}/decisions.md           - {N} design decisions
  {docs_path}/architecture.md        - Technical design

Removed:
  siw/LOG.md
  siw/OPEN_ISSUES_OVERVIEW.md
  siw/issues/ ({count} issue files)
  siw/qa-intake/ ({count} intake summaries)

Preserved:
  {docs_path}/spec/

Files moved to Trash and can be restored if needed.

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
