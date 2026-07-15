---
name: kramme:siw:generate-phases
description: Break spec into atomic, phase-based issues with tests and validation
argument-hint: "[spec-file-path] [--auto]"
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code, codex]
---

# Generate Phases from Specification

Break down a specification into atomic, committable issues organized into phases. Each phase results in a demoable or reviewable outcome appropriate to the work type, and each issue represents a self-contained piece of work with tests/validation.

## Workflow Boundaries

**This command creates issue files from a specification.**

- **DOES**: Read spec, decompose into phases/tasks, create issue files, update overview table, update log progress
- **DOES NOT**: Implement features, write code, or make changes to the codebase

**Implementation is a separate workflow.** After this command completes, use `/kramme:siw:issue-implement` to start implementing.

### Artifact Readiness Contract

Use this shared vocabulary when gating inputs and describing outputs:

- `product-only`: problem/user/outcome context exists, but testable requirements are missing.
- `requirements-only`: scope and success criteria exist, but the spec lacks enough technical context, dependencies, or planning detail to create issue slices.
- `planning-ready`: the spec is concrete enough to decompose into phases and atomic issues.
- `implementation-ready`: generated issue files have bounded scope, dependencies, acceptance criteria, Mode, and verification. This skill produces implementation-ready artifacts only after the reviewed issue files are written.

If the input is `product-only` or `requirements-only`, stop before decomposition and route to `/kramme:siw:discovery` or spec hardening. Do not create issue files from an artifact that cannot support planning-ready decomposition.

## Issue Numbering Scheme

Use **phase-prefixed numbering** for clear organization: `ISSUE-G-001` for general tasks, `ISSUE-P1-001` for Phase 1, `ISSUE-P2-001` for Phase 2, and so on. Read `references/issue-numbering.md` before assigning, splitting, replacing, or appending issue IDs.

## Issue Identifier Stability

Issue IDs are stable once issue files are written. Preserve existing append-mode IDs, leave numbering gaps in place, and use `/kramme:siw:issue-reindex` for intentional cleanup instead of renumbering here. `references/issue-numbering.md` is the local authority for details.

## SIW Issue-State Protocol

Synced SIW issue-state contract (keep aligned across SIW issue creators): every SIW issue creation or tracker-visible issue update keeps the issue file, siw/OPEN_ISSUES_OVERVIEW.md, and siw/LOG.md synchronized as one issue-state change; partial write failures must be surfaced instead of accepted silently.

All final issue creation and tracker publication use this skill's `scripts/siw-issue-reservation.sh` helper. The helper serializes its own invocations, provides an ownership-tokened publication lock, and creates exclusive per-ID reservations using portable atomic hard-link claims. A killed invocation's operation claim is reclaimed only after its recorded process no longer exists. Keep the locked critical section short. Draft IDs remain provisional until Phase 6 acquires publication ownership and reserves final IDs.

## Process Overview

```
/kramme:siw:generate-phases [spec-file-path]
    ↓
[Validate SIW workflow exists]
    ↓
[Find and read spec file(s)]
    ↓
[Check if implementation in progress] -> Ask: continue or abort
    ↓
[Check for existing issues] -> Ask: append, replace, or abort
    ↓
[Analyze spec and decompose into phases/tasks]
    ↓
[Launch review subagent] -> Validates atomicity, testability, dependencies
    ↓
[Run targeted deepening gate if risk signals are present]
    ↓
[Present phase plan to user] -> Confirm or request changes
    ↓
[Create issue files and update overview/log]
    ↓
[Report summary] -> Suggest /kramme:siw:issue-implement
```

Before Phase 1, parse `$ARGUMENTS` as shell-style arguments. If `--auto` is present, set `AUTO_MODE=true` and remove it before resolving the spec path. `--auto` accepts the final reviewed phase plan and creates issue files without the Phase 5 approval prompt. It does not bypass required input, in-progress implementation stops, dirty-file protection, subagent review failure handling, or destructive replacement of existing issue files.

## Shared Guardrails

Before executing Phase 2 or any later step, read `references/quality-gates.md` so the required output markers, hard gates, and final verification checklist are active throughout the workflow.

## Phase 1: Prerequisites & Input

### 1.1 Validate SIW Workflow Exists

Check for `siw/OPEN_ISSUES_OVERVIEW.md`:

```bash
ls siw/OPEN_ISSUES_OVERVIEW.md 2> /dev/null
```

**If not found:** Inform user and suggest running `/kramme:siw:init` first. Stop.

### 1.2 Find Spec File(s)

**If `$ARGUMENTS` provided:** Use as spec path. If the path does not exist, stop and surface the missing path; do not silently fall back to a glob.

**Otherwise:** Glob for candidate spec files (anything under `siw/` that is not a workflow artifact):

```bash
# Synced SIW spec-exclusion contract (keep aligned across SIW spec detectors): `LOG.md`, `OPEN_ISSUES_OVERVIEW.md`, `DISCOVERY_BRIEF.md`, `SPEC_STRENGTHENING_PLAN.md`, `AUDIT_*.md`, `PRODUCT_AUDIT.md`, `SIW_*.md`.
ls siw/*.md 2> /dev/null | grep -v -E '/(LOG|OPEN_ISSUES_OVERVIEW|DISCOVERY_BRIEF|SPEC_STRENGTHENING_PLAN|PRODUCT_AUDIT)\.md$|/AUDIT_.*\.md$|/SIW_.*\.md$'
```

Also check for supporting and contract specs:

```bash
for dir in siw/supporting-specs siw/contracts; do
  if [ -d "$dir" ]; then
    find "$dir" -maxdepth 1 -type f -name "*.md"
  fi
done
```

**Main-spec selection:**

Synced SIW main-spec ambiguity contract (keep aligned across SIW spec detectors): when multiple spec candidates remain after deterministic heading/filename matching, auto mode stops with MISSING REQUIREMENT and interactive mode asks the user which file is the main spec.

- **Zero candidates:** stop. Surface `MISSING REQUIREMENT: no spec file found under siw/` and suggest the user run `/kramme:siw:discovery` or pass an explicit `$ARGUMENTS` path. Do not invent a spec.
- **One candidate:** use it as the main spec.
- **Multiple candidates:** read the first `## Project` (or `# `) heading of `siw/LOG.md` to find the initiative name; build a deterministic match set from candidates whose filename or first `#` heading matches that name (case-insensitive, hyphen/underscore-insensitive). If exactly one candidate matches, use it. If zero or multiple candidates remain after matching and `AUTO_MODE=true`, stop with `MISSING REQUIREMENT: multiple spec candidates found; rerun without --auto and choose the main spec or pass an explicit $ARGUMENTS path`. If zero or multiple candidates remain after matching and `AUTO_MODE` is false, use AskUserQuestion to present the candidates and ask which file is the main spec. Do not pick the first candidate as a fallback.

### 1.3 Check Implementation Status

Implementation is considered in progress when **either** signal is present. Normalize legacy title-case `In Progress` to `IN PROGRESS` before checking these signals:

- Any row in `siw/OPEN_ISSUES_OVERVIEW.md` has status `IN PROGRESS` or `IN REVIEW`.
- `siw/LOG.md` contains an entry dated within the last 7 days under `## Current Progress` or an active task list.

**Status Legend:** READY | IN PROGRESS | IN REVIEW | DONE

Do not infer in-progress from generic `git log` keywords or unrelated uncommitted changes — those produce false positives. The two signals above are authoritative.

**If implementation appears in progress and `AUTO_MODE=true`:** do not ask. Stop with `MISSING REQUIREMENT: implementation appears to be in progress; rerun without --auto to decide whether to continue`.

**If implementation appears in progress and `AUTO_MODE` is false:** Use AskUserQuestion:

```yaml
header: "Implementation In Progress"
question: "It looks like implementation may already be underway. Generating phases now could disrupt the current workflow. How should I proceed?"
options:
  - label: "Continue anyway"
    description: "Generate phases despite ongoing work (use with caution)"
  - label: "Abort"
    description: "Cancel and continue with current workflow"
```

**If "Abort":** Stop the workflow.

### 1.4 Check for Existing Issues

List files in `siw/issues/`:

```bash
ls siw/issues/ISSUE-*.md 2> /dev/null
```

**If issues exist:** show the matched filenames inline so the user sees exactly what is on disk before choosing. If `AUTO_MODE=true`, choose **Append** automatically and continue; never choose Replace or delete existing issue files under `--auto`. Otherwise use AskUserQuestion:

```yaml
header: "Existing Issues"
question: "Found {N} existing issues in siw/issues/ (listed above). How should I proceed?"
options:
  - label: "Append"
    description: "Add new phase issues alongside existing ones"
  - label: "Replace"
    description: "Delete existing issues and create fresh phase breakdown"
  - label: "Abort"
    description: "Cancel and keep existing issues"
```

**If "Abort":** Stop the workflow.

**If "Append":** preserve all existing issue IDs exactly as written. New issues use the next unused number within their prefix group based on both `siw/OPEN_ISSUES_OVERVIEW.md` and on-disk `siw/issues/ISSUE-{prefix}-*.md` files. Do not backfill gaps unless the user explicitly runs `/kramme:siw:issue-reindex`.

**If "Replace":** Verify nothing is at risk, but defer deletion to Phase 6 so no mutation happens before the final serialized publication boundary.

1. Check for uncommitted changes under `siw/issues/`:

   ```bash
   git status --porcelain -- siw/issues/ 2> /dev/null
   ```

   If output is non-empty, list the dirty paths and re-prompt with AskUserQuestion options "Proceed and discard changes" / "Abort". Abort by default if the user does not pick "Proceed".

2. Verify `trash` is available for recoverability. If it is unavailable, stop instead of planning a permanent deletion. Store `REPLACE_MODE=true`; do not delete anything yet:

   ```bash
   if ! command -v trash &> /dev/null; then
     echo "MISSING REQUIREMENT: trash is required to replace existing SIW issues safely. Install with 'brew install trash' (macOS) or your distro's 'trash-cli' package, then rerun."
     exit 1
   fi
   ```

3. After the user approves Replace (including any dirty-file confirmation), capture `REPLACE_APPROVED_SNAPSHOT` as sorted `git hash-object` plus path pairs for every matching issue file. This records both the approved file set and its contents:

   ```bash
   REPLACE_APPROVED_SNAPSHOT="$(
     for path in siw/issues/ISSUE-*.md; do
       if [ ! -e "$path" ] && [ ! -L "$path" ]; then
         continue
       fi
       if [ -L "$path" ] || [ ! -f "$path" ]; then
         echo "MISSING REQUIREMENT: replacement issue path must be a non-symlink regular file: $path" >&2
         exit 1
       fi
       path_hash="$(git hash-object "$path")" || exit 1
       printf '%s  %s\n' "$path_hash" "$path"
     done
   )" || exit 1
   REPLACE_APPROVED_SNAPSHOT="$(printf '%s\n' "$REPLACE_APPROVED_SNAPSHOT" | LC_ALL=C sort)" || exit 1
   ```

## Phase 2: Spec Analysis

### 2.1 Extract Work Context

After finding spec files, look for a `## Work Context` section in the spec files:

1. Parse the markdown table to extract: Work Type, Priority Dimensions, Deprioritized dimensions
   - If multiple spec files define Work Context, use the selected main spec from Phase 1.2. If Phase 1.2 cannot select one deterministically, it must stop or ask before Phase 2; do not use the first found as a fallback.
2. If not found or malformed, default to Production Feature (3-5 phases, standard sizing)
3. Store as `work_context`

### 2.2 Read Spec Content

Read the main spec file and any supporting or contract specs found in Phase 1.2.

**Read failure:** if any spec file fails to read (permission error, missing file, empty file), stop and surface the path and the error. Do not silently skip the file or paraphrase what the spec "probably" said.

### 2.3 Extract Key Elements

Identify and extract:

- **Overview/objectives** - What is the project trying to achieve?
- **Scope** - What's in and out of scope?
- **Success criteria** - How do we know we're done?
- **Technical design** - Architecture, data model, API contracts
- **Existing task breakdowns** - Any phases or tasks already defined
- **Implementation phases** - Natural groupings or milestones

Classify input readiness after extraction across the selected spec set: the main spec plus any supporting or contract specs found in Phase 1.2. Proceed only when that full set is `planning-ready`: concrete objective, scope/non-goals, success criteria, relevant technical context, and no blocking open questions that would force invented issue scope. Supporting and contract specs may satisfy technical context, dependencies, API, data-model, or planning-detail requirements; do not reject a main spec solely because those details live in the supporting documents. If the selected spec set is `product-only` or `requirements-only`, stop with `MISSING REQUIREMENT` and recommend the smallest spec-hardening step.

## Phase 3: Phase Decomposition

### 3.1 Identify Phase Boundaries

Analyze the spec to find natural phase boundaries:

- Look for milestones, logical groupings, or dependency chains
- Each phase should result in a **demoable or reviewable outcome** appropriate to the work type
- Default phase count depends on Work Context:
  - **Production Feature** (default): 3-5 phases. Each phase results in demoable, tested software.
  - **Prototype / Spike**: 2-3 phases. Larger, more exploratory phases. Phase 1 proves the core concept. Acceptance criteria focus on "does it work" over "is it production-ready." Skip polish and documentation phases.
  - **Internal Tool**: 3-4 phases. Prioritize getting to a working tool fast. Phase 1 is the happy-path core workflow.
  - **Tech Debt / Refactor**: 2-4 phases ordered by risk. Phase 1 tackles the highest-risk transformation with rollback capability. Include explicit rollback verification in phase acceptance criteria.
  - **Documentation / Process**: Phases map to document sections or workflow stages. Each phase produces a reviewable deliverable.
- Identify cross-cutting concerns for the "General" category (setup, tooling, docs)

### 3.1.5 Detect Prefactoring Needs

Before finalizing phase boundaries, check whether a behavior-preserving prefactoring slice should be first:

- Add a prefactoring issue when current structure would otherwise force an L/XL task, duplicate implementation work, broad cross-module edits, or hidden refactor scope inside a feature slice.
- Make the prefactoring issue the earliest dependency that unlocks cleaner feature work, usually `G` for cross-cutting prep or `P1` when it belongs to the first phase.
- Acceptance criteria must prove behavior is preserved and the later work is easier to slice; do not include new product behavior in the prefactoring issue.
- Do not add speculative cleanup. If the prep work is nice-to-have rather than unlocking cleaner implementation, leave it out or mark it as a separate non-blocking follow-up.

### 3.2 Break Into Atomic Tasks

For each phase, decompose into atomic tasks:

**Each task should be:**

- **Committable independently** - A single focused change
- **Testable** - Has clear acceptance criteria and validation
- **Sized XS, S, M, or L** per `references/task-sizing.md`. XL tasks MUST be decomposed further before approval.
- **Clearly defined** - Unambiguous scope with explicit boundaries
- **Mode-tagged** - `AUTO` or `HITL` (see Mode taxonomy below)
- **Prefactoring-aware** - Any necessary preparatory refactor is explicit as its own first slice or dependency, not hidden inside a feature task

**Mode taxonomy (AUTO vs HITL — load-bearing for autonomous-agent pickup):**

- **AUTO** — an autonomous agent can pick up, implement, verify, and prepare for review without human input.
- **HITL** — human-in-the-loop is required for at least one of: an unsettled architectural decision, design review, a genuine product/judgment call, manual testing that cannot be automated, external-system access an agent cannot perform. HITL tasks MUST carry a one-line reason (e.g., "needs architectural decision", "involves manual UAT").

Tag each task during decomposition. **Default to `AUTO`**; reserve `HITL` for tasks with a concrete human-input requirement from the list above, and when unclear choose `AUTO`. The subagent in Phase 4 will flag any task without a Mode label, any HITL task without a reason, and any task marked HITL whose stated reason is weak or speculative rather than a real blocking requirement.

**Draft ID handling:** assign provisional phase-prefixed issue IDs while drafting so dependencies can be reviewed. Existing IDs from append mode are immutable. New draft IDs may still be reordered or reshaped before files are written; Phase 6 remaps them to exclusively reserved final IDs if concurrent publication advanced a prefix. Once Phase 6 creates issue files, later refinement must preserve IDs per the Issue Identifier Stability rules above.

**Sizing and triggers:**

Read sizing grammar, break-down triggers, and the context-appropriate slicing rule from `references/task-sizing.md` and apply them during decomposition. Every task gets an explicit size (XS/S/M/L); any task that hits a break-down trigger — especially one that bundles multiple independently reviewable outcomes — splits before leaving this step.

**Slicing shape (context-aware — load-bearing):** apply the vertical-vs-horizontal rule and wide-refactor exception from `references/task-sizing.md` to each task in the chosen Work Context. Each task must leave the smallest reviewable end-to-end outcome for its context.

**Identify dependencies:**

- Which tasks block other tasks within the same phase?
- Which phases depend on completing previous phases?
- Does a prefactoring task need to block later feature or migration tasks?
- Does a wide-refactor sequence need explicit expand, migrate, and contract blockers?

### 3.3 Generate Phase Plan Structure

For each phase:

- **Phase goal** - What milestone does this achieve?
- **Outcome description** - What can be demonstrated or reviewed after this phase?
- **Tasks** - List of atomic issues with titles, sizes, and brief descriptions
- **Dependencies** - What blocks what
- **Parallelization** - Group category plus any gating note from Phase 3.4
- **Validation** - How to verify the phase is complete

For general tasks:

- Setup/scaffolding that doesn't fit a specific phase
- Tooling and configuration
- Documentation tasks

### 3.4 Parallelization Assessment

Annotate each task group with one of the three parallelization categories defined in `references/task-sizing.md` (Safe to parallelize / Must be sequential / Needs coordination). The categorization surfaces safe-to-run-in-parallel work explicitly instead of defaulting to serial execution.

Record the chosen category per group (e.g., "Phase 1 tasks: Safe to parallelize after P1-001") so Phase 5's user-facing plan reflects it, the generated issue files keep the exact approved guidance, and `siw/OPEN_ISSUES_OVERVIEW.md` stores the same decision as one section-level summary per task group.

## Phase 4: Subagent Review

Run a host-neutral review pass over the proposed breakdown. Use the current host runtime's subagent mechanism when available; if no subagent mechanism is available, perform the same review inline in the main thread:

Before running the review pass, read `references/breakdown-review-prompt.md`. It contains the prompt template and the required substitution rule for inlining `references/task-sizing.md` into `{task_sizing_grammar}`.

**Incorporate feedback:** Update the phase plan based on subagent suggestions.

**Loopback gate (max 3 iterations):** If the review pass reports any XL task, any context-inappropriate horizontal / over-bundled slice, any wide-refactor sequencing error, any missing prefactoring-first split where prep work is necessary, or any Mode-coverage issue per criterion 9 (unlabeled task, HITL-without-reason, or HITL whose reason is too weak to justify it), re-run Phase 3.2 decomposition and re-run the review pass. Only proceed to Phase 5 once the review confirms zero XL tasks, zero slicing-shape issues, no required hidden prefactoring, and complete, correctly-defaulted Mode coverage.

If the gate is still failing after **3 review passes**, stop looping. Surface the remaining flagged items to the user as `POTENTIAL CONCERNS` and use AskUserQuestion to choose: "Proceed to Phase 5 with remaining concerns" / "Abort and let me edit the spec first". Do not loop a fourth time.

If `AUTO_MODE=true`, do not proceed with remaining concerns after 3 failed review passes. Stop and report the unresolved `POTENTIAL CONCERNS`.

**Review failure handling:** If the review pass does not return structured feedback (empty response, unstructured text, or tool error), surface the raw response, treat the iteration as inconclusive, and ask the user how to proceed via AskUserQuestion: "Re-run review" / "Proceed without review" / "Abort". Re-runs count toward the 3-iteration cap.

If `AUTO_MODE=true` and the subagent response is inconclusive, re-run once if the 3-iteration cap leaves room; otherwise stop. Never proceed without review in auto mode.

### Phase 4.5: Planning Confidence Deepening Gate

After Phase 4 passes the hard gates and before Phase 5 user approval, read `references/deepening-gate.md` and apply its selective risk-signal check. Small, clear plans with no risk signals proceed directly to Phase 5; risky plans get exactly one targeted confidence deepening pass unless the reference's loopback or blocker rules apply.

## Phase 5: User Approval

Present the proposed structure using `assets/phase-plan-template.md`. Preserve the `PLAN:` output marker, include each issue's size and Mode inline, include one `Parallelization:` line per task group, and include HITL reasons in brackets.

Use AskUserQuestion:

```yaml
header: "Phase Plan"
question: "Does this phase breakdown look correct? You can request specific changes."
options:
  - label: "Looks good - create issues"
    description: "Proceed to create all issue files"
  - label: "Need changes"
    description: "I'll describe what needs to be adjusted"
```

**If "Need changes":** Gather feedback and revise the plan. Repeat Phase 5.

If `AUTO_MODE=true`, do not ask for approval. Print the same `PLAN:` block, add `AUTO: creating issue files from this phase plan`, and continue directly to Phase 6.

## Phase 6: File Creation

### 6.0 Acquire Publication Ownership and Finalize IDs

Resolve `scripts/siw-issue-reservation.sh` relative to this `SKILL.md`. Generate a collision-resistant owner token once with `sh <helper> new-owner`, retain it in this workflow's session state, and use it for the workflow's full publication and recovery lifetime. During normal contention, never copy or reuse a token observed in an existing lock or reservation.

1. Immediately before the first mutation, run `sh <helper> acquire siw <owner-token> 30`. If it reports that another writer owns publication, preserve the lock and reservations unchanged and stop for owner-guided recovery without exposing its token. For malformed state or operational failures, preserve state and surface the helper's diagnostic exactly instead of describing the failure as contention.
2. Re-read `siw/OPEN_ISSUES_OVERVIEW.md`, `siw/LOG.md`, and all matching on-disk issue files while holding publication ownership. Never publish from the Phase 1 or draft-plan snapshot.
3. In append mode, group approved provisional IDs by prefix and call `sh <helper> reserve-batch siw <prefix> <owner-token> 100 <provisional-id>...` once per prefix. Each output line maps one provisional request key to its final ID, and retrying the same batch with the retained token returns the same mappings after interrupted output. Build the complete provisional-to-final map, then update filenames, headings, dependencies, related IDs, overview rows, and log ranges before writing. Each batch scans the prefix high-water mark once, preserves gaps, and retries collisions with exclusive atomic claims. Existing append-mode IDs remain unchanged.
4. In replace mode, recompute the snapshot under the lock with the exact fail-closed path validation, hash-status checks, and separate sort shown in Phase 1, then compare it with `REPLACE_APPROVED_SNAPSHOT`, regardless of `git status`. If it differs, run `sh <helper> release-publication siw <owner-token>` because no replacement IDs have been reserved yet, list the current issue files, and require fresh explicit approval before deletion; auto mode must stop only after publication ownership is released. After approval, replace `REPLACE_APPROVED_SNAPSHOT` with the newly approved snapshot, reacquire with the retained token, re-read all three SIW views, and recompute the snapshot. If it changed again, release ownership and repeat approval. Reserve every approved replacement ID first with `sh <helper> reserve-exact siw <issue-id> <owner-token>`; the helper accepts either `ISSUE-G-001` or canonical `G-001` form and same-owner retries return the canonical ID. A foreign collision stops publication without deleting anything. Set `REPLACE_DELETION_STARTED=true` immediately before running the newly approved `trash siw/issues/ISSUE-*.md`, then replace the corresponding overview rows in this same publication.

Hold publication ownership only through Phase 6.1-6.3 and the verification/release steps below; never hold it during analysis, review, or user approval.

### 6.1 Create Issue Files

For each issue, create `siw/issues/ISSUE-{prefix}-{number}-{title}.md`:

**File naming:**

- Prefix: `P1`, `P2`, `P3`... for phases, `G` for general
- Number: 3-digit padded (001, 002, 003)
- Title: lowercase, hyphens, max ~40 characters

**Number assignment in append mode:** use only the final IDs returned by Phase 6.0. Existing gaps remain gaps unless `/kramme:siw:issue-reindex` is explicitly run.

**Path references:** generated issue files must use repo-relative paths for affected files, tests, and pattern references. Do not embed absolute local paths; they break portability across workspaces and teammates.

**Issue template:** Read `references/issue-template.md` and use it for each generated issue file.

### 6.2 Update Overview Table

Read `references/tracker-schema.md` and apply its modern and legacy schema rules when updating `siw/OPEN_ISSUES_OVERVIEW.md`. The synced tracker status vocabulary is `READY | IN PROGRESS | IN REVIEW | DONE`.

### 6.3 Update siw/LOG.md

Update `siw/LOG.md` Current Progress with the generated issue count, affected prefix ranges, and date. If `siw/LOG.md` is missing, create a minimal Current Progress section before reporting success.

If any issue file, overview, or log write fails after issue creation starts, surface the partial state in the completion summary and offer rollback guidance instead of reporting the phase issues as cleanly created.

### 6.4 Verify and Release Publication Ownership

Re-read every created issue file, `siw/OPEN_ISSUES_OVERVIEW.md`, and `siw/LOG.md`. Verify each final ID appears once on disk, every overview row and dependency uses the final mapping, the log records the complete generated set, and accurate entries from other writers remain intact. Release each completed reservation with `sh <helper> release siw <issue-id> <owner-token>`, then run `sh <helper> release-publication siw <owner-token>`. These release commands are postcondition-idempotent, so the retained owner may safely retry them after interrupted output.

Before replacement deletion starts, a failed multi-ID reservation attempt must unwind every exact reservation created by that attempt before releasing publication: run `release` for a replacement ID whose old issue file still exists and `abandon` for an ID with no issue file. Other failures before a reserved issue file exists may use `abandon` while `REPLACE_DELETION_STARTED` is not true. If cleanup fails, preserve the remaining reservation and publication lock for owner-guided recovery instead of reporting the collision as cleanly stopped. Once replacement deletion starts, never abandon any replacement reservation even when its new issue file does not exist: reacquire with the retained token, restore or repair all three views from current state, verify, and then release. A later recovery session may use the retained token only after the user explicitly confirms it is resuming that interrupted workflow. Never delete a reservation based on age or filename, and never clean up a different owner's token.

## Phase 7: Summary

Read `references/summary-template.md` and report the results using that standard end-of-turn triplet.

**STOP HERE.** Wait for the user's next instruction.
