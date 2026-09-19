# Merge the code-review security and cleanup reviewers

- Status: ACCEPTED
- Date: 2026-09-19
- Deciders: repository maintainer (explicit implementation request)

## Context

A default `/kramme:pr:code-review` run could launch fifteen distinct agents and sixteen invocations. Four of them formed a security bundle that the skill always launched together: `kramme:injection-reviewer`, `kramme:auth-reviewer`, `kramme:data-reviewer`, and `kramme:logic-reviewer` shared one trigger, one `security` aspect token, one read-only mandate, and one output shape, and differed only in which sink or flaw category each hunted. Three more overlapped in substance: `kramme:lean-reviewer`'s `existing` tag duplicated `kramme:code-simplifier`'s reuse check, its `delete` tag duplicated `kramme:removal-planner`'s whole mission, and the skill gave lean and simplifier near-identical instruction blocks, the same collision label, the same advisory subordination, and the same `--no-cleanup` drop. Removal-planner was a codebase-audit tool carrying 150 lines of removal-plan templates that never applied to a PR diff. The execution contract had pinned the opposite position ("the four security reviewers remain separate") without recording why.

The repository's catalog rule already says to merge adjacent components when intent, inputs, output, side effects, and safety gates overlap and only a technique or mode differs.

## Decision

Replace the seven agents with two:

- `kramme:security-reviewer` runs four named lenses (injection and XSS; authentication, authorization, CSRF, and sessions; secrets, cryptography, disclosure, and DoS; business logic, races, and numeric edge cases) in one invocation and reports the lens on every finding.
- `kramme:cleanup-reviewer` owns the `lean`, `removal`, `refactor`, and `simplify` dimensions in one invocation, labels every finding with its dimension, keeps lean's tags and safety boundaries, keeps removal-planner's reference-trace tiers (Safe to Remove Now, Requires Investigation, Defer) because the dead-code auto-removal rule depends on them, and drops the removal-plan templates.

Aspect tokens, `--emphasize`, `--no-cleanup`, the execution ledger's dimension coverage, the dead-code ask shape, and the correctness/security precedence pass are unchanged. Emphasis on a single cleanup dimension applies only to findings carrying that dimension label. Neither merged agent may be split into parent-run checks or partial lens execution; the execution contract now states this in place of the old "remain separate" rule.

## Consequences

- A default review launches up to ten invocations instead of sixteen, with the same dimension coverage recorded in the ledger.
- Sibling skills that named the security agents (`kramme:code:harden-security`, `kramme:code:audit-security`, `kramme:code:api-design`) now point at `kramme:security-reviewer` and, where useful, the lens.
- One reviewer covering four lenses on a very large diff may lose recall across passes; the numbered lens structure and the per-lens coverage line at the end of its report are the mitigation, and Team Mode can still shard by file group.
- Prompts and automation that named any of the seven removed agents must migrate; this ships as a breaking change.

## Alternatives Considered

### Keep the security agents separate for recall

Rejected because the bundle already ran as one unit with no independent triggering, so the only thing four processes bought was four context windows, at the cost of four launches, four boilerplate copies, and a fifteen-agent roster to maintain.

### Merge only lean and simplifier, keep removal-planner

Rejected because removal-planner's PR-time job (verify that a deletion is safe) is the `delete` tag with a reference trace, and its remaining content was plan templates for standalone audits that no workflow invoked.

### Fold comment-analyzer into code-reviewer at the same time

Deferred. It is a weaker overlap and conditional, so it is cheap; revisit after the two merges have run for a while.
