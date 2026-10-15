# SIW Mode (`--siw`)

Read this file only when `SIW_MODE=true`. It retires the local `siw/` workspace after a verified `/kramme:siw:transfer-to-linear` migration or an explicitly abandoned preparation run. It overrides the default workflow only where a step below says so; every other rule in `SKILL.md` still applies, including the project-local symlink and containment checks, the pre-delete recheck, the Trash requirements, the `block-rm-rf` guardrail, and verified-absent reporting.

`--siw` is direct-user-only and never runs with `--auto`; `SKILL.md` rejects both cases before this file is read.

## Transfer-first warning

Before Step 1, show:

```
SIW cleanup is destructive. If specifications, decisions, or issues must be preserved, run /kramme:siw:transfer-to-linear and verify the migration before continuing.
```

## Step 1 override: SIW-only scan

Select only registry entries whose `scopes` include `siw`. Never select root-level reports, `.context/` evidence, or shared diagrams in this mode. Record two lists:

- `found_temporary` — every `siw`-scope `disposable` entry found, including `siw/DISCOVERY_BRIEF.md`, `siw/SPEC_STRENGTHENING_PLAN.md`, and `siw/SIW_*.md`, which default cleanup intentionally leaves alone.
- `found_permanent` — every `siw`-scope `permanent-spec` entry found: specification files under `siw/`, `siw/supporting-specs/`, and `siw/contracts/`.

Specification files come from the `siw-spec-files` entry: expand `siw/*.md`, then keep a match only when its basename fits one `match_any` pattern and no `exclude` pattern, compared case-sensitively. Synced SIW spec-exclusion contract (keep aligned across SIW spec detectors): `LOG.md`, `OPEN_ISSUES_OVERVIEW.md`, `DISCOVERY_BRIEF.md`, `SPEC_STRENGTHENING_PLAN.md`, `AUDIT_*.md`, `PRODUCT_AUDIT.md`, `SIW_*.md`. The registry's `match_any` and `exclude` lists are the only copy of these filters. Every detector match, including a symlinked specification, goes through the `SKILL.md` Step 1 symlink and containment check and is reported as skipped when unsafe.

Conditional directories (`siw/issues/`, `siw/qa-intake/`) do not require their `condition` marker in this mode, because retiring the whole SIW workspace is the explicit request. Their `expected_contents` gate still applies, except that a `.gitkeep` placeholder child is accepted; drop a directory with any other unexpected child and report it as skipped.

If both lists are empty, report `No SIW workflow files found in this directory.` and stop.

## Step 2 override: uncommitted SIW changes

If the working directory is a git repository, run `git status --porcelain -- siw/`, which includes untracked paths. If it prints anything, warn before confirmation and continue:

```
Warning: There are uncommitted changes to SIW files:
{paths from porcelain output, one per line}

If `trash` is available, these will be recoverable from the system Trash. Otherwise they will be permanently lost.
```

## Step 3 override: confirmation

Ask with the host's question tool. Build every description from the Step 1 lists only:

```yaml
header: "Delete SIW Files"
question: "Found {len(found_temporary)} temporary item(s){, plus {len(found_permanent)} permanent item(s) if non-empty}. Which should I delete?"
options:
  - label: "Temporary files only"
    description: "Delete: {comma-separated paths in found_temporary}. Keep permanent files."
  - label: "All SIW files"
    description: "Delete the temporary items plus: {comma-separated paths in found_permanent}."
  - label: "Abort"
    description: "Cancel and keep all files"
```

Omit "All SIW files" when `found_permanent` is empty. Permanent files are kept unless the user selects "All SIW files". On "Abort", stop without deleting.

## Step 4: delete

Follow `SKILL.md` Step 4 for the confirmed set, including the explicit confirmation after the permanent-deletion warning when `trash` is missing. Directories have no fallback without `trash`; skip and report them.

## Step 5 additions: empty `siw/` and report

After verification, if `siw/` exists, is a real non-symlink directory, and is empty, remove it with the non-recursive `rmdir siw` and record that it was removed. Leave it in place when anything remains, such as kept specifications or skipped directories.

Report:

```
SIW Cleanup Complete

Deleted:
{each path in deleted_paths, one per line}

Failed to delete:
{each path in failed_delete_paths with error, one per line; omit section if empty}

Skipped:
{each skipped path with reason; omit section if empty}

{If using trash: Files moved to Trash and can be restored if needed.}
{If siw/ was removed: siw/ directory removed.}
```

The workflow can be re-initialized afterwards with `/kramme:siw:init`.
