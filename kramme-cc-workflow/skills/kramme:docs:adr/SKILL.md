---
name: kramme:docs:adr
description: "Author Architecture Decision Records for significant, long-lived decisions. Creates ADRs in docs/decisions/ with sequential numbering and lifecycle states (PROPOSED / ACCEPTED / SUPERSEDED / DEPRECATED). Detects and preserves existing ADR format when one is in use; falls back to a Nygard-style template otherwise. Use when adopting a new pattern, committing to a dependency, changing a public interface, changing the data model, or rejecting an alternative a future maintainer might reasonably re-propose. For in-project decisions during a tracked SIW initiative use /kramme:siw:close's decision log instead."
disable-model-invocation: false
user-invocable: true
---

# Architecture Decision Record

Author an ADR for a significant, long-lived decision: state the problem, the choice, the alternatives rejected, and the consequences. Preserve predecessors; never delete history.

## When to use

A decision warrants an ADR if **any** of these are true:

- It affects more than one module.
- It commits to a dependency (library, service, data store, cloud provider).
- It changes a public interface.
- It changes the data model.
- It rejects an alternative a future maintainer might reasonably re-propose.

Route elsewhere if:

- **In-project decisions during a tracked SIW initiative** → use `/kramme:siw:close`, which emits a project-scoped `decisions.md`. This skill handles repo-level ADRs that outlive any single initiative.
- **Feature spec / scope decisions before implementation** → use `/kramme:docs:feature-spec`.
- **Agent-facing rules** (commit style, package manager, conventions) → use `/kramme:docs:update-agents-md`.

## Pre-flight: detect existing ADR format

Before drafting, check whether the project already has ADRs. If yes, **preserve the existing style** rather than imposing this template.

1. Look for an ADR directory. Common paths:
   - `docs/decisions/`
   - `docs/adr/` or `adr/`
   - `docs/architecture/decisions/`
   - `architecture/decisions/`
2. If found, read 1–2 of the most recent ADRs. Identify:
   - Template style (Nygard, MADR, custom).
   - Status vocabulary (may differ from the four states below).
   - Numbering format (`0001-` vs `001-` vs `ADR-001-`).
   - Filename slug convention.
3. Treat the matched directory as `ADR_DIR` for the rest of the workflow.
4. Match that style for the new ADR. Only fall back to `assets/adr-template.md` when the directory does not exist or is empty.

If the existing style uses a vocabulary that conflicts with the four lifecycle states below, prefer the project's vocabulary — but surface the mismatch with a `CONFUSION` marker so the user can decide whether to reconcile.

## Lifecycle states

Four states (Addy's convention; use verbatim unless the project already uses a different vocabulary):

- **PROPOSED** — under discussion; not yet adopted.
- **ACCEPTED** — in effect.
- **SUPERSEDED** — replaced by a later ADR; still preserved as historical context.
- **DEPRECATED** — no longer applies; preserved for history.

## Preservation rule

> "Don't delete old ADRs. They capture historical context."

Even SUPERSEDED ADRs stay in the directory. They explain *why* the current approach was chosen over the previous one. Deleting them erases the reasoning that a future maintainer needs to avoid re-making a rejected choice.

## Markers

Emit these markers as you draft. They are non-optional when the condition applies.

### SIMPLICITY CHECK

Before expanding sections past the minimum, state the minimum viable ADR.

```
SIMPLICITY CHECK: minimum ADR = Context + Decision + one rejected alternative. Expanding Consequences because the decision has downstream effects on two services.
```

A minimum viable ADR has Context, Decision, and at least one rejected alternative. Expand only when a concrete reason forces it.

### NOTICED BUT NOT TOUCHING

When drafting, you will spot prior decisions that were never documented. Do not backfill them silently.

```
NOTICED BUT NOT TOUCHING: caching strategy choice (Redis over Memcached, ~2024) was never captured as an ADR
Why skipping: out-of-scope for this ADR; log for a future backfill pass
```

Log the gap; do not retroactively invent ADRs for decisions you weren't present for.

### UNVERIFIED

Any claim in Context or Consequences that rests on measurement, benchmark, or external source must be verified. If you cannot verify it now, mark it.

```
UNVERIFIED: "Postgres writes are ~3x slower than Redis for our workload"
Source needed: benchmark in #perf channel or ops dashboard
```

An ADR built on unverified claims misleads future readers more than no ADR at all.

### MISSING REQUIREMENT

Gate drafting if any of these are absent:

- Deciders (at least one named person or role).
- Date of writing.
- Context framing (what problem forced the choice).
- At least one rejected alternative.

```
MISSING REQUIREMENT: no deciders named
Cannot proceed past draft until resolved
```

### CONFUSION

If the decision scope is unclear — "is this one ADR or three?" — stop and clarify with the user before drafting.

```
CONFUSION: proposed ADR covers both session storage AND session encryption. These are separable decisions with different alternatives. Split into two ADRs?
```

### PLAN

Superseding produces a multi-file change (new ADR + predecessor update). State the plan before editing.

```
PLAN:
1. Write the new ADR in ADR_DIR using the detected filename convention (for example `0007-title.md` or `ADR-007-title.md`) with status PROPOSED unless the decision is already adopted
2. If the new ADR is already ACCEPTED, update #MMMM: change status to "SUPERSEDED by #NNNN", add forward-reference
3. Do not edit any other content of #MMMM
```

### ASK FIRST

These are Tier-2 decisions — ask the user before proceeding:

- Deprecating a live ADR.
- Changing the project's established ADR format.
- Superseding an ADR authored by someone else.

```
ASK FIRST: about to supersede #0003 (ACCEPTED, authored by @alice 2024-06). Confirm before writing new ADR?
```

## Core workflow

Five steps. Do not skip steps.

### 1. Detect significance

Apply the **When to use** criteria. If the decision affects only one function or is a purely tactical choice, emit a `NOTICED BUT NOT TOUCHING` marker (or nothing) and stop — this is not ADR-worthy.

### 2. Find next ADR number

Use `ADR_DIR` from pre-flight. Scan that directory for the highest existing ADR number and increment it. Match the project's filename convention, including any prefix (for example `0001-`, `001-`, or `ADR-001-`) and zero-padding.

```bash
find "$ADR_DIR" -maxdepth 1 -type f -print \
  | sed 's#.*/##' \
  | sed -nE 's/^(ADR-)?([0-9]+)-.*/\2/p' \
  | sort -n \
  | tail -1
```

If no ADR directory exists, create `docs/decisions/`, set `ADR_DIR=docs/decisions/`, and start at `0001`.

### 3. Draft using the detected or default template

- If a project template was detected in pre-flight, match it.
- Otherwise, use `assets/adr-template.md` verbatim.

Populate: Status (PROPOSED to start), Date (today, not the decision date — see Rationalizations), Deciders, Context, Decision, Consequences (positive / negative / neutral-or-follow-on), Alternatives considered (at least one).

Emit `SIMPLICITY CHECK` before expanding Consequences or Alternatives past the minimum.

### 4. Set status

Start as PROPOSED. Transition to ACCEPTED only when the decision is adopted (e.g. PR merged, team consensus recorded, external approval granted). Do not mark ACCEPTED pre-emptively.

### 5. If superseding

Emit a `PLAN` marker first. Then:

1. In the new ADR's header, set Status to `PROPOSED` by default and add a line noting the intended predecessor, such as `Proposed successor to #MMMM`.
2. If the decision is already adopted, set the new ADR's Status to `ACCEPTED` and replace that note with `Supersedes #MMMM`.
3. Once the new ADR is `ACCEPTED`, update the old ADR (#MMMM): change Status to `SUPERSEDED by #NNNN` and add a line referencing the successor. Do not edit any other content of the predecessor.
4. Keep both files. Never delete the predecessor.

If the predecessor was authored by someone else, emit `ASK FIRST` before proceeding.

## Integration with other skills

- **Sibling — API surface decisions**: `kramme:code:api-design` often surfaces choices that warrant an ADR (public surface shape, backwards-compatibility policy, versioning).
- **Sibling — migration strategy**: `kramme:code:migrate` frequently produces an ADR recording the chosen migration path and what alternatives were rejected.
- **Sibling — in-project decisions**: `kramme:siw:init` / `kramme:siw:close` handle decisions that live within a single tracked initiative via a project-scoped `decisions.md`. Do not double-log those here.
- **Upstream discipline**: `kramme:code:incremental` — when an ADR accompanies code changes, each slice stays scoped to its own decision. Do not bundle multiple ADR-worthy decisions into one slice.

---

## Common Rationalizations

These are the lies you will tell yourself to skip or distort the ADR. Each has a correct response:

- *"It's just a tactical choice, not worth an ADR."* → Apply the significance test. If it affects more than one module, commits to a dependency, changes a public interface, changes the data model, or rejects a reasonable alternative — it warrants an ADR.
- *"We'll capture the reasoning in the README."* → READMEs rot and get edited without attribution. ADRs are dated, numbered, and preserved.
- *"This supersedes the old one, so delete it."* → Preservation rule. SUPERSEDED stays. The rejected previous approach is load-bearing context for the current one.
- *"I'll backdate the ADR to when we actually decided."* → Date the writing, not the decision. Honesty beats revisionism. Backdated ADRs erode trust in the whole log.
- *"Everyone already knows why."* → Nobody who joins next year knows why. The ADR is for them, not you.
- *"I'll skip Alternatives — we never really considered any."* → Every decision rejected alternatives, even implicit ones ("do nothing", "keep what we have"). Name at least one.
- *"I'll backfill the three prior undocumented decisions while I'm here."* → Emit `NOTICED BUT NOT TOUCHING` for each. Backfilling decisions you weren't present for invents history.

## Red Flags

Rejection criteria. If any of these are true, revert the ADR and re-plan:

- **Silently deleting a prior ADR** instead of marking it SUPERSEDED or DEPRECATED.
- **ACCEPTED status with no deciders named.** An unattributed decision is an anonymous decree.
- **No Alternatives section.** Every architectural decision has rejected paths — list at least one.
- **Decision paragraph longer than the Context paragraph.** A decision without problem framing is a preference, not an ADR.
- **Editing a SUPERSEDED ADR's content** instead of writing a new one. The predecessor is frozen; capture the new thinking in a new ADR.
- **Claims in Context or Consequences with no `UNVERIFIED` marker and no source.** Build on evidence or mark the gap.
- **Bundling multiple separable decisions into one ADR.** One decision per ADR. If `CONFUSION` fires during drafting, split.

## Verification

Before declaring the ADR done, self-check:

- [ ] ADR numbered sequentially — the numeric portion is the highest existing ADR number + 1, with the project's filename prefix and padding convention.
- [ ] Status set (PROPOSED or ACCEPTED), not blank.
- [ ] Date filled with today's date (the date of writing, not the decision).
- [ ] At least one decider listed.
- [ ] Context explains the problem or constraint that forced the decision.
- [ ] Decision stated in one clear paragraph.
- [ ] Consequences cover positive **and** negative effects (neutral/follow-on optional).
- [ ] At least one rejected alternative with a reason.
- [ ] If superseding: predecessor marked `SUPERSEDED by #NNNN` with forward-reference; predecessor content otherwise untouched.
- [ ] No prior ADR deleted.
- [ ] Every unverifiable claim carries an `UNVERIFIED` marker.
- [ ] ADR lives in the detected ADR directory (`ADR_DIR`), or `docs/decisions/` when bootstrapping a new log.
- [ ] File committed; not left uncommitted locally where it can be lost.

If any box is unchecked, finish the gap or revert before declaring done.
