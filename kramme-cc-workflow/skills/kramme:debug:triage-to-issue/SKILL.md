---
name: kramme:debug:triage-to-issue
description: "(experimental) Triage a bug end-to-end: orchestrate root-cause investigation, design a TDD fix plan with RED-GREEN cycles, and file a refactor-durable Linear or local SIW issue in one mostly-hands-off pass. Use when a bug needs to become an implementation-ready ticket without manually chaining kramme:debug:investigate, kramme:test:tdd, and kramme:linear:issue-define. Composes those skills through normal skill invocation. Not for the full interactive investigation with confidence gates (use kramme:debug:investigate alone), not for conversational bug-reporting QA sessions (the planned kramme:qa:intake sibling), not for implementing the fix (use kramme:linear:issue-implement or kramme:siw:issue-implement after this skill files the ticket)."
argument-hint: "[bug description, error message, or Linear/SIW issue ref] [--yes | --afk]"
disable-model-invocation: true
user-invocable: true
---

# Triage a Bug to an Implementation-Ready Issue

One command, one ticket. Take a bug description, run a root-cause investigation, design a TDD fix plan, and file a refactor-durable issue an AFK agent can pick up and implement. The composed result is what manually chaining `kramme:debug:investigate` → `kramme:test:tdd` → `kramme:linear:issue-define` would produce, but in one orchestrated pass.

## When to use

- A user reports a bug and you want a single ticket containing root-cause + TDD plan + acceptance criteria.
- The bug needs to be parked for an AFK agent or another contributor to implement later.
- The repo uses Linear, SIW, or both — this skill auto-detects sinks.

## When to skip

- The bug needs interactive investigation with multiple confidence gates → use `kramme:debug:investigate` directly.
- You want to discuss the bug conversationally before deciding whether to file → use the planned `kramme:qa:intake` sibling (not yet built).
- You're going to implement the fix yourself in the same session → run `kramme:debug:investigate` then `kramme:test:tdd` (Prove-It); skip the ticket overhead.
- The "bug" is actually a feature request, scope question, or design proposal → use `kramme:linear:issue-define` directly.

---

## Process

### Phase 1 — Capture

1. Read `$ARGUMENTS`. Strip any trailing `--yes` or `--afk` flag — both bypass the approval gate.
2. If the description is empty, ask exactly ONE question:

```yaml
header: Bug Description
question: What's the problem you're seeing?
options:
  - (freeform) Describe the bug, paste an error message, or provide a Linear/SIW issue ref
```

3. Otherwise, do not ask. Proceed silently.

Emit `PLAN: triage to issue — investigate, design TDD plan, draft, gate, file`.

### Phase 2 — Detect sinks

Probe in order:

1. Check for `mcp__linear__create_issue` MCP tool availability.
2. Check for `siw/OPEN_ISSUES_OVERVIEW.md` in the repo root.

Decision table:

| Linear MCP | SIW present | Action |
|---|---|---|
| Yes | Yes | Ask the user once which sink (Linear / SIW / Markdown at repo root). |
| Yes | No | Use Linear, no question. |
| No | Yes | Use SIW, no question. |
| No | No | Use a markdown file at the project root, no question. |

The runtime question (when it fires):

```yaml
header: Issue Sink
question: Both Linear and SIW are available. Where should the issue land?
options:
  - Linear — create via mcp__linear__create_issue and return the URL
  - SIW — write to siw/issues/ and update OPEN_ISSUES_OVERVIEW.md + LOG.md
  - Markdown — write a standalone file at the repo root and surface the path
```

### Phase 3 — Investigation

Invoke `kramme:debug:investigate` via the Skill tool with the captured bug description as `$ARGUMENTS`.

When the sub-skill reaches its **Step 6 — Propose Fix** gate, choose the **"Report findings only, do not change code"** option. This stops investigate at Step 8 (Summary) and returns the investigation log without applying any fix.

Capture from the returned log:

- The `[ROOT CAUSE]` line — the mechanism description.
- The `Root Cause Analysis` block — `What / Where / Why / When introduced`.
- The `Evidence` block.
- The confidence rating (`High / Medium / Low`).
- Any `[REPRODUCE]` line and whether reproduction succeeded.

If the investigation could not reproduce the bug, mark this in the draft body as `UNVERIFIED: bug could not be reproduced from the report; implementer must verify the failure scenario before merging`.

### Phase 4 — TDD plan

Invoke `kramme:test:tdd` via the Skill tool, framed as a **planning-only** call: ask it to produce the Prove-It cycle structure for the bug just analyzed, but do **not** write or run tests in this session — the goal is the plan that will live in the issue body.

Capture:

- An ordered list of RED-GREEN cycles. Each RED is a behavior assertion through a public interface. Each GREEN is the minimal change to pass.
- The Prove-It test sketch (one explicit "this test should FAIL before the fix and PASS after" cycle).

If the sub-skill output contains implementation details (private function names, internal class names), strip them in Phase 6.

> **Caveat (v1 honesty).** `kramme:test:tdd` is written as instructions for a TDD session, not a pure planner. In v1, treat its output as guidance for the cycle list above; if the sub-skill insists on driving an interactive cycle, abort the sub-skill call and produce the cycle list inline using the Prove-It conventions from `kramme:test:tdd` (RED-GREEN, behavior through public interface, Prove-It regression test). A future `--lite` flag will skip this handoff entirely.

### Phase 5 — Acceptance criteria

Compose 3–6 acceptance criteria as checkboxes. Each criterion is a behavior statement, not an implementation step. Examples:

- `[ ] Expired tokens are rejected at the auth boundary with a 401 response.`
- `[ ] The Prove-It regression test passes after the fix and would have failed before.`
- `[ ] No existing test in the auth-middleware suite regresses.`

If reproduction was `UNVERIFIED`, add: `[ ] Fix is verified by reproducing the original failure scenario before merging.`

### Phase 6 — Strip implementation specifics (durability rule)

Take the merged context from Phases 3–5 and rewrite it for the issue body. The body must remain useful after a major refactor.

**Forbidden in the body:**

- File paths (`src/`, any directory + filename).
- Line numbers and `:\d+` patterns.
- File extensions in prose (`.ts`, `.tsx`, `.py`, `.go`, `.rs`).
- Internal helper, class, or private-function names.
- Module-internal symbol references.

**Allowed:**

- Module names by their public role ("the auth middleware", "the rate limiter").
- Public API surfaces ("the `/api/login` endpoint", "the `validateToken` exported function").
- Behaviors and contracts ("the middleware should reject expired tokens").
- Test commands and CLI invocations inside fenced code blocks (these are repro instructions, not implementation references).

> See `references/durability-examples.md` for good-vs-bad rewrites of common patterns.

### Phase 7 — Draft

Read `assets/issue-body-template.md` and populate it. The structure is:

1. **Title** — `Fix [observable behavior] in [public surface]` (action verb + behavior + surface). No file paths.
2. **Problem** — 1–3 sentences of durable behavior description + reproduction steps if known.
3. **Root Cause Analysis** — 2–4 sentences. Module / behavior / contract language only. Confidence rating.
4. **TDD Fix Plan** — numbered RED-GREEN cycles from Phase 4.
5. **Acceptance Criteria** — checkboxes from Phase 5.
6. **Out of Scope** — what this ticket is **not** trying to fix.

Show the drafted body to the user.

### Phase 8 — Approval gate

Skip if the user passed `--yes` or `--afk`. Otherwise:

```yaml
header: Approval
question: Create this issue?
options:
  - Create — file as-is at the chosen sink
  - Edit — let me revise specific sections
  - Cancel — abort without creating anything
```

If the user picks **Edit**, ask which section, take their changes, re-render the draft, and re-ask.

### Phase 9 — Create

Branch on the sink chosen in Phase 2.

**Linear:** call `mcp__linear__create_issue` with title, description (the drafted body), and any auto-detectable team/labels/project. Return the issue URL.

**SIW:** write three files in lockstep:

1. `siw/issues/ISSUE-{prefix}-{NNN}-{slug}.md` — full issue body. Use the prefix and number scheme already in use in the repo's `siw/issues/` directory (typically `G` for general or `P{N}` for phased; pad to 3 digits). Slug is a kebab-case fragment of the title.
2. `siw/OPEN_ISSUES_OVERVIEW.md` — append a row to the index table with status `OPEN`.
3. `siw/LOG.md` — add an entry under the current progress / decision-log section noting the new issue and the date.

All three updates must succeed atomically. If any write fails, surface the error and offer the user a chance to roll back the partial create.

**Markdown fallback:** write `BUG-{slug}-{YYYY-MM-DD}.md` to the project root with the full body. Surface the absolute path.

### Phase 10 — Verification

Grep the created body for durability violations:

```
:\d+ | src/ | \.ts | \.tsx | \.py | \.go | \.rs
```

Matches inside fenced code blocks (`` ``` ... ``` ``) are allowed (they are repro commands). Matches in prose are a `RED FLAG` — surface them and prompt the user to edit. Do not silently rewrite.

Emit a final block:

```
CHANGES MADE
- Created issue at {sink}: {URL or path}
- Body length: {chars}; durability grep: {clean | <count> matches in code blocks only}

THINGS I DIDN'T TOUCH
- The fix itself — implementation belongs to kramme:linear:issue-implement / kramme:siw:issue-implement.
- Any related issues or follow-ups noticed during investigation (logged below).

POTENTIAL CONCERNS
- {confidence rating from Phase 3 if Medium or Low}
- {NOTICED BUT NOT TOUCHING entries from investigate output, if any}
```

---

## Output markers

Adopt the kramme plugin-wide vocabulary verbatim, one per line, uppercase, no decoration:

- `STACK DETECTED` — language / framework / test runner identified during investigation.
- `UNVERIFIED` — assumption flagged in the issue body or in this skill's reasoning that has not been confirmed.
- `NOTICED BUT NOT TOUCHING` — out-of-scope observation surfaced in the final summary, not in the issue body.
- `CONFUSION` — clarification needed before proceeding.
- `MISSING REQUIREMENT` — decision/input needed from the user.
- `PLAN` — announce next phases before acting.
- `CHANGES MADE / THINGS I DIDN'T TOUCH / POTENTIAL CONCERNS` — end-of-turn triplet.
- `RED FLAG` — used in Phase 10 when the durability grep finds matches in prose.

Reuse from `kramme:debug:investigate`:

- `[REPRODUCE]`, `[ISOLATE]`, `[ROOT CAUSE]`, `[VERIFY]` — these markers may appear in the captured investigate output. Keep them in working notes but do **not** include `:\d+` content from these markers in the issue body.

---

## Common rationalizations

Watch for these — they signal the durability rule is about to break.

| Excuse | Reality |
|---|---|
| "The file path is the clearest way to point at the bug." | Paths rot. The reader six months from now needs the *behavior* the bug breaks, not yesterday's filename. |
| "Line numbers are pinned to a commit, so they're stable." | They're stable until the next refactor. The issue is supposed to outlive that. |
| "The internal helper name is the actual root cause." | If the bug is "this private helper is wrong," the fix is also rename-stable: describe the contract the helper represents. |
| "If I strip everything internal, the issue is too vague." | Then the investigation isn't done. The contract-level statement *should* exist; if it doesn't, return to Phase 3. |
| "I'll just include the file path in a code block — that's allowed." | Code blocks are for repro commands. A bare path is still a path; readers parse it the same way. |

---

## Red flags — STOP

- The drafted body contains any `:\d+` pattern outside a fenced code block.
- The drafted body references a private function or internal class by name.
- No acceptance criteria block, or the criteria are implementation steps rather than behavior assertions.
- A RED step asserts on internal state instead of an observable through a public interface.
- The investigation came back with `Low` confidence and no clarifying question was asked.
- The user passed `--yes` but the durability grep returned matches in prose — bypass the gate would file a leaky issue. Halt and require explicit approval.

---

## Integration points

- **`kramme:debug:investigate`** — source of the investigation phase (Steps 1–6 + Step 8 reporting). The orchestrator stops it at the propose-fix gate via the "Report only" option.
- **`kramme:test:tdd`** — source of the Prove-It cycle conventions and RED-GREEN structure used in Phase 4. v1 captures the patterns; the sub-skill itself may not be invocable as a pure planner (see Phase 4 caveat).
- **`kramme:linear:issue-define`** — source of issue-creation conventions (title format, template selection, metadata). v1 issues the create call directly via `mcp__linear__create_issue` for predictable interception, but the body shape mirrors the `Simple Bug Template` and `Comprehensive Template` from issue-define's assets (without copying the `**File:** path/to/affected/file.ts` line, which violates the durability rule).
- **`kramme:linear:issue-implement` / `kramme:siw:issue-implement`** — downstream consumers. The ticket body produced here is designed to be picked up by these flows without re-investigation.

---

## Verification (before declaring the run complete)

- [ ] Capture happened with at most one question (zero if `$ARGUMENTS` had a description).
- [ ] Sink chosen via auto-detection or one runtime question (per Phase 2 decision table).
- [ ] Investigation returned a `[ROOT CAUSE]` line and a confidence rating.
- [ ] TDD plan has at least one RED-GREEN cycle and one Prove-It cycle.
- [ ] Issue body has all six template sections.
- [ ] Durability grep on the body returns zero matches in prose (matches in fenced code blocks allowed).
- [ ] Approval gate fired (or `--yes` was passed).
- [ ] Issue URL or path was surfaced in the `CHANGES MADE` block.
- [ ] No fix was applied — implementation is out of scope.
