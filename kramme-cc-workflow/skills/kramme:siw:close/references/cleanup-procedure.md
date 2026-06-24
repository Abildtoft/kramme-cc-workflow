# Cleanup Procedure

Use this procedure after documentation has been generated and Step 6 file dispositions are resolved.

## 1. Verify Documentation Before Deletion

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

## 2. Remove Files

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
- `siw/contracts/` (only if `spec_disposition=remove`)

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
fi
```

If `trash` is unavailable and `AUTO_MODE` is false, use AskUserQuestion before any permanent deletion:

```yaml
header: "Permanent Delete"
question: "The 'trash' command is unavailable, so cleanup can only use permanent deletion. Delete these SIW paths permanently: {delete_targets}?"
options:
  - label: "Abort"
    description: "Stop without deleting files"
  - label: "Permanently delete"
    description: "Run rm -rf on the listed paths"
```

Only if the user chooses "Permanently delete", run:

```bash
rm -rf "${delete_targets[@]}"
```

After deletion, verify every target with `[ ! -e "$path" ]`. Record only verified-absent paths in `deleted_paths`. Record any surviving paths in `failed_delete_paths` with the captured error output; these must be reported as failures instead of "Removed".

## 3. Clean Up Empty `siw/` Directory

After deletion, check if `siw/` is empty:

```bash
SPEC_DISPOSITION="{spec_disposition}" python3 - <<'PY'
from pathlib import Path
import os

siw = Path("siw")
gitkeep_paths = [siw / "issues" / ".gitkeep", siw / "qa-intake" / ".gitkeep"]
empty_dirs = [siw / "issues", siw / "qa-intake"]

if os.environ.get("SPEC_DISPOSITION") == "remove":
    gitkeep_paths.append(siw / "supporting-specs" / ".gitkeep")
    gitkeep_paths.append(siw / "contracts" / ".gitkeep")
    empty_dirs.append(siw / "supporting-specs")
    empty_dirs.append(siw / "contracts")

if siw.exists() and not any(path.is_file() and path.name != ".gitkeep" for path in siw.rglob("*")):
    gitkeep_paths.append(siw / ".gitkeep")

for path in gitkeep_paths:
    if path.exists():
        if path.name != ".gitkeep" or path.parts[:1] != ("siw",):
            raise SystemExit(f"Refusing to delete unexpected path: {path}")
        path.unlink()

for directory in [*empty_dirs, siw]:
    if directory.exists() and directory.is_dir():
        try:
            directory.rmdir()
        except OSError:
            pass
PY
```

If `siw/` still has files (spec kept or other files present), leave it alone.
