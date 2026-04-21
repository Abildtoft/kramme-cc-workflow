# Spec Strengthening Plan

**Generated:** {date}
**Confidence before:** {initial}% -> **After:** {final}%
**Interview Rounds:** {N}

## What Changed

{Summary: what was weak, what the interview revealed, how understanding shifted}

## What You Don't Want

Every entry must pair a non-goal with its rationale. Format: `- {non-goal} — {why excluded}`.

- {non-goal} — {why excluded: scope drift / known failure mode / competing priority / stakeholder objection / deferred-for-later}
- {non-goal} — {why excluded: ...}

If the interview revealed that a previously-assumed goal is actually a non-goal, list it here with the rationale that surfaced during refinement.

## Where Stated and Actual Wants Diverged

{If the spec said one thing but the interview revealed something different — document it here.
Skip this section if spec and interview were aligned.}

## Decisions Made

| Decision | Choice | Rationale | Affected Section |
|---|---|---|---|
| {area} | {what} | {why} | {spec file:section} |

## Spec Patch Plan

### {spec-file-1}
- [ ] {Section}: {specific edit description}
- [ ] {Section}: {specific edit description}

### {spec-file-2}
- [ ] {Section}: {specific edit description}

## Open Questions

{Unresolved items that need more context or stakeholder input}

## Suggested Next Command

{One of:}
- `/kramme:siw:spec-audit` — validate improvements
- `/kramme:siw:generate-phases` — ready to plan implementation
- `/kramme:siw:issue-define` — ready to define specific work items
