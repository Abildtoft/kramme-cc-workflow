# Spec and Strengthening Plan Disposition

Resolve the fate of `siw/SPEC_STRENGTHENING_PLAN.md`, the main spec, and `siw/supporting-specs/` before SIW files are deleted in Step 7.

Outputs:

- `strengthening_plan_disposition`: `keep`, `move`, or `remove`
- `spec_disposition`: `keep`, `move`, or `remove`

If either ends up `move`, also add the README note described in the "Move instructions" section below.

## 1. Resolve the strengthening plan first

If `siw/SPEC_STRENGTHENING_PLAN.md` does not exist, set `strengthening_plan_disposition=remove` and skip to step 2.

Otherwise, use AskUserQuestion:

```yaml
header: "Strengthening Plan"
question: "A pending spec-strengthening plan still exists. What should happen to it during close?"
options:
  - label: "Keep in siw/"
    description: "Preserve siw/SPEC_STRENGTHENING_PLAN.md for later follow-up"
  - label: "Move to {docs_path}/spec/"
    description: "Preserve the plan alongside the generated documentation"
  - label: "Discard"
    description: "Delete the plan during close"
```

Store as `strengthening_plan_disposition` with values `keep`, `move`, or `remove`.

## 2. Detect discovery-rich content in the spec

Before asking about the spec, inspect it for discovery-origin context that is not fully preserved in the generated close-out docs. Treat any of the following spec sections as discovery-rich source content:

- `## Problem Statement`
- `## Who's Affected`
- `## Priorities & Tradeoffs`
- `## Constraints`
- `## Decision Boundaries`
- `## Risks`
- `## Discovery Notes`

If any of those sections are present, set `preserve_spec_source=true`.

## 3. Resolve spec disposition

If `preserve_spec_source=true`, use AskUserQuestion (two options, both preserve the source):

```yaml
header: "Specification Files"
question: "This spec still contains discovery context that is not copied verbatim into {docs_path}/. How should I preserve the source material?"
options:
  - label: "Move to {docs_path}/spec/"
    description: "Preserve the original spec alongside the generated docs"
  - label: "Keep in siw/"
    description: "Leave siw/{spec_filename} and siw/supporting-specs/ in place"
```

Store the result as `spec_disposition` with values `move` or `keep`.

Otherwise, use AskUserQuestion (three options, including removal):

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

Store the result as `spec_disposition` with values `remove`, `keep`, or `move`.

## 4. Validate the combination

`strengthening_plan_disposition=keep` is only valid when `spec_disposition=keep`. If the spec will move or be removed, the strengthening plan cannot remain orphaned in `siw/`.

If `strengthening_plan_disposition=keep` and `spec_disposition!=keep`, use AskUserQuestion:

```yaml
header: "Strengthening Plan Conflict"
question: "Keeping the strengthening plan in siw/ would orphan it because the spec will not remain there. What should happen instead?"
options:
  - label: "Move to {docs_path}/spec/"
    description: "Preserve the plan alongside the generated documentation"
  - label: "Discard"
    description: "Delete the plan during close"
```

Update `strengthening_plan_disposition` to `move` or `remove` based on the answer.

## 5. Move instructions

If `spec_disposition=move`, move `siw/{spec_filename}` and (if present) `siw/supporting-specs/` to `{docs_path}/spec/` after the documentation is generated.

If `strengthening_plan_disposition=move`, move `siw/SPEC_STRENGTHENING_PLAN.md` to `{docs_path}/spec/`.

When anything is moved into `{docs_path}/spec/`, append to `{docs_path}/README.md`:

```markdown
## Original Specification

The original project specification is preserved in [spec/](spec/) for reference.
```

Append the note once even if both the spec and the strengthening plan are moved.
