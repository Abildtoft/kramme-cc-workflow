# Auto Create Mode

Use this reference when `kramme:linear:issue-define` is invoked with `--auto` and the target is a new Linear issue.

## Goal

Create one useful Linear issue quickly. Prefer a clear, durable ticket over exhaustive refinement.

## Boundaries

- Create new Linear issues only.
- Do not update existing issues.
- Do not perform deep codebase exploration unless the user supplied specific files.
- Do not implement, branch, or start work after creating the issue.

## Workflow

1. Confirm Linear metadata from the main skill: team must already be selected in Phase 2; labels, project, and priority are optional. If no team is selected, stop and resolve the team before drafting.
2. Use duplicate findings from Phase 3:
   - Phase 3 already handles the strong-duplicate decision. If execution reaches this reference, treat that decision as resolved and do not ask again.
   - Keep partial overlaps, related issues, and any user-approved duplicate context for the `Context` section.
3. Ask at most two clarifying questions, only when the answer materially changes the ticket.
4. Draft the title, body, and metadata.
5. Show the draft and ask for approval.
6. Create the issue through the available Linear create tool.
7. Return the Linear issue ID, URL, title, and applied metadata.

## Clarification Targets

Ask only for missing essentials:

- Observable problem or requested capability.
- Expected outcome.
- User or stakeholder affected.
- Reproduction details for bugs.
- Scope boundary that should stay out.

If the user input already covers these, ask no questions.

## Title Rules

1. Keep the title under 90 characters when possible.
2. Start with a concrete verb: `Fix`, `Add`, `Improve`, `Clarify`, `Support`, or `Prevent`.
3. Name the user-visible surface or workflow.
4. Do not include raw file paths, line numbers, stack-trace fragments, or private helper names.

## Body Shape

Use only sections that have useful content. Do not include empty placeholder headings.

```markdown
## Problem

{1-3 sentences describing the user-visible problem, opportunity, or request.}

## Requested outcome

{What should be true after this issue is resolved.}

## Acceptance criteria

- [ ] {Behavioral criterion}
- [ ] {Behavioral criterion}
- [ ] {Verification or edge-case criterion, if known}

## Context

{Relevant notes from user input, supplied files, duplicate search, related issues, or constraints.}

## Out of scope

{Boundaries that keep the ticket focused, if known.}
```

For bugs, include reproduction details when known:

```markdown
## Current behavior

{What happens now.}

## Expected behavior

{What should happen instead.}

## Reproduction

1. {Step}
2. {Step}
3. {Observed result}
```

## Writing Rules

- Write for product first and engineering second.
- Use durable language: behaviors, public surfaces, contracts, and outcomes.
- Summarize supplied file context instead of pasting file contents.
- Mention file paths only when the issue is explicitly a developer chore and the path is necessary.
- Redact secrets, tokens, personal data, and customer-specific identifiers before filing.
- Use labels, project, and priority only when they are available in Linear and clearly match the issue.

## Create Tool Mapping

Use the available Linear create operation:

- Claude Code: `mcp__linear__create_issue` with `title`, `description`, `team`, and confirmed `labels`, `priority`, or `project`.
- Codex: `save_issue` without `id`, with `title`, `description`, `team`, and confirmed `labels`, numeric `priority`, or `project`.

Codex priority mapping:

| User wording                     | Linear priority |
| -------------------------------- | --------------- |
| urgent, blocker, production down | `1`             |
| high, important, severe          | `2`             |
| medium, normal                   | `3`             |
| low, minor, polish, not urgent   | `4`             |

If creation fails, report the exact error and print the drafted title, body, and intended metadata so the work is not lost.
