# Weakness Audit Team Setup

Loaded by `SKILL.md` only for `AUDIT_MODE=team`. Check these prerequisites before orientation; then return to `SKILL.md` for scope resolution and the shared audit workflow.

## Prerequisites

This mode requires multi-agent execution.

- **Claude Code:** Agent Teams must be enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`).
- **Codex:** run in a Codex runtime with `multi_agent` enabled.

If multi-agent execution is not available, print:

```text
Multi-agent execution is not enabled. Re-run /kramme:code:weakness-audit --solo for the lower-coverage fallback.
Claude Code: add CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 to settings.json.
Codex: use a runtime with `multi_agent` enabled (for example, Conductor Codex runtime).
```

Then stop.
