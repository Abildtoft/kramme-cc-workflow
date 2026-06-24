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

Read `siw/OPEN_ISSUES_OVERVIEW.md` and check for issues not marked DONE. Treat every non-empty status other than normalized `DONE` as open, including unknown, malformed, or future status values:

```bash
python3 - <<'PY'
from pathlib import Path

path = Path("siw/OPEN_ISSUES_OVERVIEW.md")
if not path.exists():
    raise SystemExit(0)

status_index = None
known_statuses = {"READY", "IN PROGRESS", "IN REVIEW", "DONE"}

for line in path.read_text().splitlines():
    stripped = line.strip()
    if not stripped.startswith("|") or "---" in stripped:
        continue

    cells = [cell.strip() for cell in stripped.strip("|").split("|")]
    normalized_cells = [cell.lower() for cell in cells]
    if "status" in normalized_cells:
        status_index = normalized_cells.index("status")
        continue

    if status_index is None or len(cells) <= status_index:
        continue

    issue_id = cells[0] if cells else ""
    status = " ".join(cells[status_index].upper().split())
    if issue_id and status and status != "DONE":
        marker = "UNKNOWN" if status not in known_statuses else "OPEN"
        print(f"{issue_id}: {status} ({marker})")
PY
```

**If open issues found:**

If `AUTO_MODE=true`, stop with `MISSING REQUIREMENT: open SIW issues remain; rerun without --auto to close anyway or abort`. If any reported row is marked `UNKNOWN`, include those statuses in the stop message so the user can fix the tracker or close interactively.

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

Read `references/knowledge-extraction.md` and follow it. Extract the structured project knowledge before generating any documentation.

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
  - supporting or contract specs exist with substantive content, **or**
  - 5+ decisions are tagged with architecture-related categories

### Content Rules

All generated documentation must be:

- **Self-contained** -- readable without SIW context
- **Free of SIW references** -- no mentions of `siw/`, `LOG.md`, `OPEN_ISSUES_OVERVIEW.md`, issue file paths, or SIW-specific concepts
- **Written in past tense** where describing what was built
- **Concrete** -- include actual technical details, not placeholders

---

## Step 6: Resolve File Dispositions

Decide what happens to the spec, `siw/supporting-specs/`, `siw/contracts/`, and `siw/SPEC_STRENGTHENING_PLAN.md`. Read `references/spec-disposition.md` for the prompts, discovery-rich detection rules, and conflict handling.

If `AUTO_MODE=true`, do not use the interactive prompts from `references/spec-disposition.md`. Use conservative preservation defaults instead:

- Set `spec_disposition=move` so the main spec, `siw/supporting-specs/`, and `siw/contracts/` are preserved under `{docs_path}/spec/`.
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

Read `references/cleanup-procedure.md` and follow sections 1 and 2. Documentation verification must happen before any SIW files are removed.

---

## Step 8: Clean Up Empty `siw/` Directory

Read `references/cleanup-procedure.md` and follow section 3. If `siw/` still has files (spec kept or other files present), leave it alone.

---

## Step 9: Report Results

Read `assets/close-summary-template.md` and use it to print a closing summary built from what actually happened.

---

## Edge Cases

Read `references/edge-cases.md` when an edge case is encountered. Apply the relevant rule before continuing or stopping.

## Important Notes

1. **Generate before deleting** -- all documentation must be written and confirmed before any files are removed
2. **Use `trash` when available** -- allows recovery from system Trash
3. **Self-contained output** -- generated docs must never reference SIW file paths or concepts
4. **Respect linked files** -- never delete files outside `siw/`
5. **Deduplicate decisions** -- merge LOG.md and spec decisions, preferring LOG.md for completeness
