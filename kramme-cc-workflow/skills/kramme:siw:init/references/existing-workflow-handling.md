# Existing Workflow Handling

Apply the first matching branch after scanning `siw/` in Phase 1.

When a branch needs to change how Phase 1.5 routes the command, set `resolved_arguments` before returning to `kramme:siw:init`.

## `siw/DISCOVERY_BRIEF.md` only

Trigger this branch when all of the following are true:

- `siw/DISCOVERY_BRIEF.md` exists
- No permanent SIW spec file exists
- `siw/LOG.md`, `siw/OPEN_ISSUES_OVERVIEW.md`, `siw/SPEC_STRENGTHENING_PLAN.md`, and `siw/issues/` do not exist

Behavior:

- Treat the brief as resumable pre-init discovery output
- If `$ARGUMENTS` is empty, set `resolved_arguments=siw/DISCOVERY_BRIEF.md`
- If `$ARGUMENTS` starts with `discover` or `interview`, do not launch a fresh discovery automatically. Use AskUserQuestion:

```yaml
header: "Discovery Brief Found"
question: "A discovery brief already exists. Should I continue from that brief or replace it with a new discovery interview?"
options:
  - label: "Continue from brief"
    description: "Import siw/DISCOVERY_BRIEF.md into the new SIW workflow"
  - label: "Replace brief"
    description: "Delete the existing brief and run a new discovery interview"
  - label: "Abort"
    description: "Keep the brief untouched and stop"
```

If "Continue from brief":

- Set `resolved_arguments=siw/DISCOVERY_BRIEF.md`
- Continue directly to Phase 1.5

If "Replace brief":

- Delete `siw/DISCOVERY_BRIEF.md`
- Set `resolved_arguments=$ARGUMENTS`
- Continue directly to Phase 1.5 with the original `discover` / `interview` arguments

If "Abort":

- Stop this command without changing any files

Otherwise, continue directly to Phase 1.5 without showing the existing-workflow prompt.

## `siw/DISCOVERY_BRIEF.md` + `siw/SPEC_STRENGTHENING_PLAN.md` only

Trigger this branch when all of the following are true:

- `siw/DISCOVERY_BRIEF.md` exists
- `siw/SPEC_STRENGTHENING_PLAN.md` exists
- No permanent SIW spec file exists
- `siw/LOG.md`, `siw/OPEN_ISSUES_OVERVIEW.md`, and `siw/issues/` do not exist

Behavior:

- Treat this as pre-init discovery output plus a pending refinement handoff
- Use AskUserQuestion:

```yaml
header: "Pending Discovery Refinement"
question: "A discovery brief and a pending strengthening plan both exist. How should I proceed?"
options:
  - label: "Apply plan first"
    description: "Stop so you can fold the strengthening plan into the brief before init"
  - label: "Discard plan and continue"
    description: "Delete siw/SPEC_STRENGTHENING_PLAN.md and initialize from the brief"
  - label: "Abort"
    description: "Keep both files untouched and stop"
```

If "Apply plan first":

- Stop this command
- Tell the user to review `siw/SPEC_STRENGTHENING_PLAN.md`, fold the accepted changes into `siw/DISCOVERY_BRIEF.md`, then archive/remove the plan before re-running `/kramme:siw:init`

If "Discard plan and continue":

- Delete `siw/SPEC_STRENGTHENING_PLAN.md`
- Set `resolved_arguments=siw/DISCOVERY_BRIEF.md`
- Continue directly to Phase 1.5

If "Abort":

- Stop this command without changing any files

## `siw/SPEC_STRENGTHENING_PLAN.md` only

Trigger this branch when all of the following are true:

- `siw/SPEC_STRENGTHENING_PLAN.md` exists
- No permanent SIW spec file exists
- `siw/LOG.md`, `siw/OPEN_ISSUES_OVERVIEW.md`, and `siw/issues/` do not exist

Behavior:

- Treat it as unresolved refinement output, not a resumable SIW workflow
- Use AskUserQuestion:

```yaml
header: "Existing Strengthening Plan Found"
question: "A spec-strengthening plan exists in this workspace, but there is no active SIW workflow to resume. How should I proceed?"
options:
  - label: "Delete plan and continue"
    description: "Discard siw/SPEC_STRENGTHENING_PLAN.md and initialize fresh"
  - label: "Keep plan and abort"
    description: "Stop so you can apply, archive, or review the plan first"
  - label: "Abort"
    description: "Cancel without changing anything"
```

If "Delete plan and continue":

- Delete `siw/SPEC_STRENGTHENING_PLAN.md`
- Continue directly to Phase 1.5 using the current `resolved_arguments`

If "Keep plan and abort":

- Stop this command
- Tell the user to apply, archive, or remove the strengthening plan before re-running `/kramme:siw:init`

If "Abort":

- Stop this command without changing any files

## Any other workflow files

Trigger this branch when any other workflow files exist.

If `AUTO_MODE=true`, stop with `MISSING REQUIREMENT: SIW workflow files already exist; rerun without --auto to resume, start fresh, or abort`. Do not delete existing workflow files in auto mode.

Use AskUserQuestion:

```yaml
header: "Existing Workflow Files Found"
question: "Workflow files already exist in this directory. How would you like to proceed?"
options:
  - label: "Resume existing workflow"
    description: "Continue with current files (invokes kramme:siw:continue skill)"
  - label: "Start fresh"
    description: "Delete existing workflow files and create new ones"
  - label: "Abort"
    description: "Cancel and keep existing files"
```

If "Resume existing workflow":

- Stop this command.
- Inform the user that the `kramme:siw:continue` skill will auto-trigger when they start working.
- Suggest reading `siw/LOG.md` for current progress.

If "Start fresh":

1. Before deleting `siw/issues/`, count any existing issue files:

   ```bash
   ls siw/issues/ISSUE-*.md 2> /dev/null | wc -l
   ```

2. If the count is greater than zero, surface a second confirmation using AskUserQuestion before deleting:

   ```yaml
   header: "Delete Existing Issues"
   question: "{n} issue file(s) in siw/issues/ will be deleted. This cannot be undone."
   options:
     - label: "Delete all issues"
       description: "Proceed with Start fresh; all issue files are removed"
     - label: "Abort"
       description: "Stop so I can back up or move issues out of siw/issues/ first"
   ```

3. If the user aborts, stop without changing any files.
4. Delete existing temporary workflow files: `siw/LOG.md`, `siw/OPEN_ISSUES_OVERVIEW.md`, `siw/issues/`, `siw/DISCOVERY_BRIEF.md`, `siw/SPEC_STRENGTHENING_PLAN.md`, `siw/AUDIT_IMPLEMENTATION_REPORT.md`, `siw/AUDIT_SPEC_REPORT.md`, `siw/PRODUCT_AUDIT.md`, and `siw/SIW_*.md`.
5. Preserve permanent SIW spec files matched by the `permanent-spec find` from Phase 1: `*SPEC*.md`, `*SPECIFICATION*.md`, `*PLAN*.md`, and `*DESIGN*.md`, case-insensitive. The permanent-spec find already excludes the synced SIW spec-exclusion contract.
6. Use `trash` without recursive flags when available so the deleted workflow files are recoverable from the system Trash.
7. If `trash` is missing, warn that deletion will be permanent and ask for explicit confirmation before running `rm -rf`.
8. After deletion, verify each target with `[ ! -e "$path" ]`; report any surviving path as a deletion failure instead of continuing as if Start fresh succeeded.
9. Continue to Phase 1.5.

If "Abort", stop without changing any files.

## No workflow files

Continue to Phase 1.5.
