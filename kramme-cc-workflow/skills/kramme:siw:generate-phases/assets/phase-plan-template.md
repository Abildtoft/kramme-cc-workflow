# Phase Plan Template

Present the proposed structure clearly, prefixed with the `PLAN:` output marker so downstream tooling can parse this block as the generated plan. Show each issue's size and Mode inline, and include one `Parallelization:` line per task group. HITL tasks include the one-line reason in the bracket.

Status legend: `READY | IN PROGRESS | IN REVIEW | DONE`.

```text
PLAN: Phase Plan for {Project Name}
═══════════════════════════════════

General Tasks ({N} tasks)
─────────────────────────
  Parallelization: {Safe to parallelize | Must be sequential | Needs coordination}
  ISSUE-G-001: {Title} [READY | Size: XS|S|M|L | AUTO]
  ISSUE-G-002: {Title} [READY | Size: XS|S|M|L | HITL — needs architectural decision]

Phase 1: {Goal} ({N} tasks)
───────────────────────────
  Parallelization: {Safe to parallelize after P1-001 | Must be sequential | Needs coordination}
  ISSUE-P1-001: {Title} [READY | Size: XS|S|M|L | AUTO]
  ISSUE-P1-002: {Title} [Blocked by P1-001 | Size: XS|S|M|L | AUTO]
  ISSUE-P1-003: {Title} [READY | Size: XS|S|M|L | HITL — needs design review]

  Outcome: {What can be demonstrated or reviewed}
  Tests: {What tests validate this phase}

Phase 2: {Goal} ({N} tasks)
───────────────────────────
  Parallelization: {Safe to parallelize | Must be sequential after Phase 1 | Needs coordination}
  ISSUE-P2-001: {Title} [Blocked by Phase 1 | Size: XS|S|M|L | HITL — manual UAT]
  ISSUE-P2-002: {Title} [READY | Size: XS|S|M|L | AUTO]

  Outcome: {What can be demonstrated or reviewed}
  Tests: {What tests validate this phase}

...

Total: {X} issues across {Y} phases + {Z} general
AUTO: {n} | HITL: {m}
```

