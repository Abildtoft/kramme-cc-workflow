# Ranked Weakness Audit Adapter

Loaded from `SKILL.md` only when `--ranked` was honored. Ranked mode audits full, path, or feature scopes. With `pr` scope, stop with: `For PR review run /kramme:pr:code-review, or run this skill with pr and without --ranked.`

Reuse Phase 1's `SCOPE_MODE`, `SCOPE_TARGET`, resolved file list, conventions, glossary, `KNOWN_ADRS`, `KNOWN_OUT_OF_SCOPE`, `HOT_SPOTS`, and `CO_CHANGE`. The shared workflow writes `CODEBASE_WEAKNESS_REPORT.md` by default and parses `--output <path>` and `--max-findings N`. Use Phase 1's `HISTORY_BASE_REF` for churn, co-change, and other history signals, and pass it to reviewers as the history baseline; it defaults to `HEAD` when no `--base` was supplied. `--base <ref>` is only change-history context and never changes the ranked file scope. Reject `--team`.

Set `AUDIT_MODE=solo` when `--solo` was passed, otherwise `AUDIT_MODE=team`. Remove `--ranked` and `--solo` before passing the remaining report options through.

## Execution Setup

In team mode, use parallel read-only subagents (the Claude Code Agent tool or Codex `spawn_agent`). Agent Teams are not required: reviewers never message each other. If parallel subagents are unavailable, print the following and stop:

```text
Parallel subagents are unavailable. Re-run with --ranked --solo for the lower-coverage fallback.
```

Launch through the resumable fan-out resolved in `SKILL.md`: the active research reviewers the shared Team Workflow selects are stage 1 (their `launch` records the reviewer role and any tiny-scope omission) and the challenge reviewer is stage 2. When resuming, reuse the recorded reviewer set instead of selecting it again. Evaluate the shared workflow's research quorum over persisted stage 1 results. `--solo` launches no agents and keeps no run directory.

## Shared Workflow

Read `${CLAUDE_PLUGIN_ROOT}/shared/codebase-audit/references/audit-workflow.md` and follow it. Supply Phase 3 steps 4-5 as the caller's rejection policy: filter against `KNOWN_OUT_OF_SCOPE` and `KNOWN_ADRS`, reopening only with concrete new evidence. The Governance & conventions reviewer retains its evidence-backed ADR exception. These filters run at the shared workflow's Filter Hard stage, before final ranking.

After the shared workflow writes the report, mark the run complete. When results were reused, add the `Agents reused:` line from the resumable fan-out contract after its `Agents launched: N` line.

After the workflow returns, apply Phase 4 step 9 to any declined candidate to close the rejection loop.
