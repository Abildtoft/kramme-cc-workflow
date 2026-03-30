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

If any other workflow files exist, show the existing workflow prompt from `SKILL.md`.
