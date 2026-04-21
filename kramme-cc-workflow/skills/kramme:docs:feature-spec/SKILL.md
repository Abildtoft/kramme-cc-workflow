---
name: kramme:docs:feature-spec
description: Author a lightweight PRD-style feature spec before implementation. Produces a single reviewable markdown artifact covering objective, scope, boundaries, assumptions, non-goals, and testing strategy. Use when starting a feature that needs written alignment before coding but does NOT warrant the full siw/ tracked workflow. For tracked initiatives (phased issues, LOG, audit) use kramme:siw:init instead.
argument-hint: "[feature name or brief description]"
disable-model-invocation: true
user-invocable: true
---

# Feature Spec

Author a one-page PRD-style spec before implementation. Emit an assumptions block first, draft the spec, then gate implementation on explicit user approval.

**Arguments:** "$ARGUMENTS"

## When to use this skill

Use when the user is about to start a feature and needs written alignment — scope, boundaries, success criteria — before any code is written, and the work is small enough that SIW's tracked artifacts would be overkill.

Route elsewhere if:

- **Multi-phase, multi-contributor, or needs an audit trail** → use `/kramme:siw:init` for the full tracked workflow (siw/ dir, LOG.md, OPEN_ISSUES_OVERVIEW.md, issues/).
- **Project-level rules** (package manager, commit style, coding conventions) → use `/kramme:docs:update-agents-md`.
- **Deep requirements unknown** (need a long adaptive interview) → use `/kramme:discovery:interview`, then run this skill on the resulting plan.
- **Security hardening depth** needed in the Boundaries section → this skill names the pattern (Always Do / Ask First / Never Do) but does not inline security content. Pair with a dedicated security-hardening skill if one exists.

## Workflow Boundaries

**This skill ONLY authors a single feature spec file.**

- **DOES**: Emit an assumptions block, wait for correction, draft a six-area spec markdown, gate implementation on explicit approval.
- **DOES NOT**: Create tracked SIW artifacts (no `siw/`, no `LOG.md`, no issue files). Does not decompose the spec into phases. Does not start implementation. Does not edit `AGENTS.md` or `CLAUDE.md`.

## Process Overview

```
Phase 1: Assumptions
    ↓
[User corrects or confirms]
    ↓
Phase 2: Draft spec file
    ↓
Phase 3: Approval gate
    ↓
[User approves] → Spec complete, skill ends
[User revises]  → Loop to Phase 2 (do not restart Phase 1)
```

## Phase 1: Assumptions

Before drafting anything, state what you are assuming about the feature. Emit this block verbatim, filling each bullet:

```
ASSUMPTIONS I'M MAKING:
- <assumption about scope>
- <assumption about users>
- <assumption about stack or constraints>
- <assumption about what's out of scope>

Correct me before I draft the spec.
```

Then stop and wait for the user's response. Do not proceed to Phase 2 until the user has either corrected or confirmed.

### Handling edge cases in Phase 1

- If the user's request is ambiguous or contradicts an earlier turn, emit a `CONFUSION:` block naming the ambiguity and ask for clarification.
- If a required spec area cannot be filled without more input (e.g. no testable success criteria are derivable), emit a `MISSING REQUIREMENT:` block naming what is missing. Do not invent.

## Phase 2: Draft the spec

Derive a slug from the feature name (lowercase, hyphenated, ~3–5 words). Write the spec to `<slug>-spec.md` in the repo root.

If the user passed an explicit path as the argument, honor it only when it still fits this skill's boundaries:

- The destination must be a markdown spec file.
- The resolved path must stay inside the current repository root.
- Reject reserved destinations: `AGENTS.md`, `CLAUDE.md`, and any path under `siw/`.
- If the path is reserved or otherwise unclear, emit `CONFUSION:` and ask for a different destination before writing.

Copy the six-area structure from `assets/feature-spec-template.md` and fill each area. The areas are:

1. **Objective** — one paragraph: problem statement + intended outcome.
2. **Scope & Non-goals** — what's in, what's explicitly out.
3. **Boundaries** — Always Do / Ask First / Never Do, feature-scoped.
4. **Testing Strategy** — what gets covered, at which tier (unit / integration / e2e).
5. **Open Questions** — unresolved items flagged for user input.
6. **Success Criteria** — testable statements that let anyone confirm "done".

Replace every angle-bracket template placeholder with concrete content and delete the author note comment block before treating the draft as reviewable.

### Marking claims honestly

- If a claim in the spec is an inference rather than confirmed fact (e.g. presumed user count, presumed API availability, presumed schema), prefix it inline with `UNVERIFIED:`.
- If the Open Questions area surfaces a risk the user should weigh, prefix that bullet with `POTENTIAL CONCERNS:`.

After writing the file, emit a `PLAN:` block summarizing the spec shape — area headings, key decisions in each area, and the file path — so the user can review structure before reading prose.

```
PLAN: Drafted <slug>-spec.md with:
- Objective: <one-line summary>
- Scope: <in>, Non-goals: <out>
- Boundaries: <count> Always, <count> Ask First, <count> Never Do rules
- Testing: <tiers covered>
- Open Questions: <count> (<count> flagged POTENTIAL CONCERNS)
- Success Criteria: <count> testable statements

Review the file, then approve or request revisions.
```

## Phase 3: Approval gate

**Implementation does not start until the spec is explicitly approved.**

This is a single checkpoint — the entire spec is reviewed and approved (or revised) in one go. If the user asks to start coding before approving, refuse and point back to this gate.

On revision:

- Edit the spec file in place.
- Re-emit the `PLAN:` block if structure changed.
- Do not restart Phase 1; assumptions are already settled.

On approval:

- Confirm the file path.
- State that implementation is now unblocked.
- Optionally point to next-step skills: `/kramme:siw:init <spec-file>` if the spec should be promoted to tracked phased work. After SIW is initialized, the next step is `/kramme:siw:generate-phases`. For a single-sitting change, point straight to implementation instead.

## Conventions — output markers used in this skill

| Marker | Used when |
|--------|-----------|
| `ASSUMPTIONS I'M MAKING:` | Phase 1, before drafting. Always. |
| `CONFUSION:` | Phase 1 or 2, when user input is ambiguous. |
| `MISSING REQUIREMENT:` | Phase 2, when a required area cannot be filled. |
| `UNVERIFIED:` | Phase 2, inline on any inferred claim inside the spec. |
| `POTENTIAL CONCERNS:` | Phase 2, inside Open Questions for risks worth flagging. |
| `PLAN:` | Phase 3, summary block before the approval gate. |

These markers are deliberate. Keep them verbatim — tooling and downstream skills may parse them.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "This feature is small enough to just start coding." | Then the spec takes ten minutes. Skip the skill and write code, but don't invoke this skill and then bypass the gate. |
| "I'll write the spec after, once I see the shape." | That's reverse-engineering, not speccing. Use `/kramme:siw:reverse-engineer-spec` for that path. |
| "The assumptions block is noise, the user knows what they want." | The block costs one turn and catches misalignment before you've drafted six areas of the wrong spec. |
| "One ambiguous area is fine, we'll figure it out in code." | No. Emit `MISSING REQUIREMENT:` and stop. Ambiguous specs produce ambiguous code. |
| "The user said yes in a previous turn, that's approval." | Approval is explicit and scoped to the current spec version. Re-confirm after each revision. |

## Red Flags — STOP

- Implementation starts before the user explicitly approves the spec.
- Scope creep mid-draft (new areas appearing without updating Phase 1 assumptions).
- The Assumptions block is skipped or collapsed into the draft.
- Claims inside the spec are presented as fact when they are inference — any such claim must be prefixed `UNVERIFIED:`.
- The skill begins writing `siw/`, `LOG.md`, or issue files. That's out of scope — use `/kramme:siw:init` instead.
- The user asks for phased breakdown — route to `/kramme:siw:init <spec-file>` after approval, then `/kramme:siw:generate-phases`; do not inline phases here.

## Verification

Before claiming the spec is complete:

1. The file exists at the agreed path.
2. All six areas are populated (no angle-bracket template placeholders or author note `<!-- ... -->` blocks remain).
3. Every inferred claim is prefixed `UNVERIFIED:`.
4. Every flagged risk inside Open Questions is prefixed `POTENTIAL CONCERNS:`.
5. Any explicit destination path resolves inside the current repository root and stays out of `AGENTS.md`, `CLAUDE.md`, and `siw/`.
6. The user has explicitly approved — not "sounds good" from an earlier turn, but a current-turn approval of the current spec version.

If any check fails, stay in Phase 2 or Phase 3; do not hand off downstream.
