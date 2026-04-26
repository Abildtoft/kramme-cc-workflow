---
name: kramme:docs:out-of-scope
description: "Record, check, append, or reconsider rejected enhancement concepts in the project's `.out-of-scope/` directory. One markdown file per concept; substantive reason + prior-request list. Use when the team rejects an enhancement and wants to remember why, or when checking whether a new request matches a prior rejection. Not for bug rejections (close as wontfix with a comment), not for deferrals (use issue priority/status instead), not for cross-repo aggregation."
argument-hint: "<record|check|append|reconsider> <concept>"
disable-model-invocation: true
user-invocable: true
---

# Out-of-Scope Knowledge Base

Maintain a `.out-of-scope/` directory at the project root: one short markdown file per rejected enhancement concept, capturing what was rejected and why so future sessions can check before re-litigating.

## When to use

Use this skill when:

- The team has just rejected an enhancement during discovery, triage, refactor planning, or review and wants to record the rejection so it does not get re-proposed in six months.
- A new request arrives and you suspect it has been rejected before — `check` looks up matches by concept similarity.
- A previously-rejected concept is being re-proposed with new evidence — `append` records the new request alongside the original.
- Priorities have changed and a prior rejection no longer applies — `reconsider` removes the entry.

Route elsewhere if:

- **Bug rejection** → close the issue as `wontfix` with a comment. This skill is for enhancement scope, not bug triage.
- **Deferral** ("not now, but maybe later") → use issue priority/status. A deferral is not a settled rejection, and `record` will gate on this distinction.
- **Architectural decision with rejected alternatives** → use `/kramme:docs:adr`, which preserves rejected alternatives inside the ADR itself.
- **In-project decisions during a tracked SIW initiative** → use `/kramme:siw:close`'s decision log.

## Argument parsing

1. Parse `$ARGUMENTS` by spaces. The first token is the subcommand.
2. Recognize `record`, `check`, `append`, `reconsider` as exclusive subcommands.
3. The remaining tokens form the concept. For `append`, the last token is the issue reference and the rest form the concept.
4. If no arguments are given or the subcommand is unknown, print the supported subcommands and stop.

## Slug rule

Lowercase, replace spaces and underscores with hyphens, strip characters outside `[a-z0-9-]`, collapse repeated hyphens. Example: `"Dark Mode"` → `dark-mode`. The skill always keys files by slug; the user-facing concept name is preserved verbatim inside the file body.

## Subcommands

### `record <concept>`

Capture a settled rejection.

1. Slug the concept.
2. If `.out-of-scope/<slug>.md` already exists, ask whether the user meant `append`. Stop unless overridden.
3. **Settled-vs-deferral gate** via `AskUserQuestion`:

   ```yaml
   header: "Is this a settled rejection?"
   question: "Recording a rejection here means future sessions will surface it before re-litigating. Is this a settled decision, or a deferral that might come back later?"
   options:
     - "Settled rejection — record it"
     - "Deferral — cancel"
   ```

   If the user picks deferral, stop without writing.
4. Gather rejection content via `AskUserQuestion`:
   - Substantive reason (project scope, technical constraints, or strategic decision; not "we're too busy").
   - Optional code sample illustrating a technical constraint.
   - Prior-request references (issue links or PR references that triggered or shaped the rejection).
   - Decider name or role.
5. Render `.out-of-scope/<slug>.md` from `assets/out-of-scope-template.md`:
   - `{Concept Name}` → user-facing concept (preserve original casing, not the slug).
   - `{YYYY-MM-DD}` → today's absolute date. Capture the date in the file body so `git mv`, re-checkout, or copy operations cannot reset it via mtime.
   - `{name or role}` → decider.
   - "Why this is out of scope" → substantive reason.
   - "Prior requests" → bullet list of issue references with one-line context each.
6. Create the directory first if missing (`mkdir -p .out-of-scope`).
7. If `.gitignore` would hide `.out-of-scope/`, surface a one-time `AskUserQuestion` asking whether to keep it gitignored or remove the ignore rule. Default recommendation: committed (institutional memory).
8. Print `recorded .out-of-scope/<slug>.md`.

### `check <concept>`

Look up whether a concept has been rejected before.

1. If `.out-of-scope/` is missing or empty, print `no prior rejections recorded` and stop.
2. List filenames in `.out-of-scope/` (`ls .out-of-scope/`).
3. Reason about which slugs plausibly match the concept. Concept similarity is judgmental, not fuzzy: `dark-mode` and `night-theme` plausibly match; `dark-mode` and `darken-image-filter` do not.
4. For each plausible match, read the file body and surface:

   ```
   This is similar to `.out-of-scope/<slug>.md` (decided <date>) — we rejected this before because <one-line summary of "Why this is out of scope">. Continue, or honor the prior rejection?
   ```

5. Route the answer through `AskUserQuestion`:

   ```yaml
   header: "Honor prior rejection?"
   question: "<surface format above>"
   options:
     - "Honor the prior rejection — stop"
     - "Continue anyway"
   ```

   If continuing, note the prior rejection in subsequent output so callers can see the override.
6. If no plausible match, print `no prior rejections found for <concept>`.

### `append <concept> <issue-ref>`

Record an additional request that asked for an already-rejected concept.

1. Slug the concept; locate `.out-of-scope/<slug>.md`.
2. If absent, ask whether the user meant `record`. Stop unless overridden.
3. Append a new bullet under the "Prior requests" heading: `- <issue-ref> — <short context>`. Ask for the short context if not provided.
4. Print `appended <issue-ref> to .out-of-scope/<slug>.md`.

### `reconsider <concept>`

Remove a rejection that no longer applies.

1. Slug the concept; locate `.out-of-scope/<slug>.md`.
2. If absent, print `no rejection recorded for <concept>` and stop.
3. Read the file and surface its content so the user sees what is being removed.
4. Confirm via `AskUserQuestion`:

   ```yaml
   header: "Remove this rejection?"
   question: "Removing means future sessions will no longer surface it. Continue?"
   options:
     - "Remove"
     - "Keep"
   ```

5. If confirmed, delete the file. Print `removed .out-of-scope/<slug>.md — rejection no longer recorded`.
6. Reopening the original issue is a separate action — this skill does not touch Linear or git history.

## File format

Files in `.out-of-scope/` follow the canonical structure in `assets/out-of-scope-template.md`. Preview:

```markdown
# {Concept Name}

Decided: {YYYY-MM-DD}
Decided by: {name or role}

## Why this is out of scope

{Substantive paragraph or two explaining the reason. Reference project scope, technical constraints, or strategic decisions. Avoid temporary excuses ("we're too busy") — those are deferrals, not rejections.}

{Optional code sample illustrating the technical constraint, if applicable.}

## Prior requests

- {issue reference 1} — {short context}
- {issue reference 2} — {short context}
```

The headings are load-bearing — `check` looks up files by slug and first-heading match, `append` locates the "Prior requests" list by heading. Manual edits should preserve heading text and order.

## Reading guidance for consuming skills

Other skills (`kramme:siw:discovery`, `kramme:linear:issue-define`, `kramme:code:refactor-opportunities`) read `.out-of-scope/` during their context-gathering phase. Each skill carries its own inline instruction so it stays self-contained when this skill is missing. The shared protocol they follow:

1. **Cheap-list filenames first.** Run `ls .out-of-scope/` (or equivalent). If absent or empty, skip silently.
2. **Read file bodies only on plausible match.** Concept similarity is judgmental, not fuzzy. Read at most a handful of files per session.
3. **Surface format:** `This is similar to .out-of-scope/<slug>.md (decided <date>) — we rejected this before because <one-line summary>. Continue, or honor the prior rejection?`
4. **User is the gate.** Never auto-fail; route through `AskUserQuestion` and let the user override.

## Verification

- `.out-of-scope/<slug>.md` is created with the canonical template after `record`.
- `Decided:` line in the file body is today's absolute date (not just file mtime).
- `check` surfaces matches by concept similarity, not by exact slug equality only.
- `append` grows the "Prior requests" list by one bullet per call.
- `reconsider` deletes the matching file and prints a confirmation.
- `description` field is ≤ 1024 chars; this SKILL.md is ≤ 500 lines.
