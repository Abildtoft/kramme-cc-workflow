# Inline-offer pattern

For other skills that resolve decisions during their own workflow (discovery interviews, refactor explorations, architecture critiques): use this pattern to surface an ADR opportunity without inline-authoring the ADR. Read this file only when implementing that handoff in another skill.

## When to offer

The decision must meet **all three** criteria. If any one is missing, no offer:

- **Hard to reverse** — undoing it later would be costly or destructive.
- **Surprising without context** — a future maintainer would reasonably ask "why this?" and not be able to infer the answer from the code alone.
- **Result of a real tradeoff** — a credible alternative was rejected for a stated reason.

## The canonical offer message

Surface the offer with `AskUserQuestion`. Use three options so the user can record intent (not just yes/no). Name all three criteria inline so the user can sanity-check whether the test was applied loosely. Before presenting the question, replace each evidence placeholder with a concrete one-line reason from the current workflow:

```yaml
AskUserQuestion
header: "ADR offer"
question: |
  This decision looks ADR-worthy:
  - Hard to reverse: {hard_to_reverse_evidence}
  - Surprising without context: {surprising_without_context_evidence}
  - Result of a real tradeoff: {real_tradeoff_evidence}

  Record as an ADR?
options:
  - label: "Author ADR"
    description: "Invoke /kramme:docs:adr now"
  - label: "Skip"
    description: "Don't author, and don't ask again about this decision"
  - label: "Defer"
    description: "Don't author now; allow re-offer if the decision recurs"
multiSelect: false
```

Copy this payload structure verbatim. Substitute only the three `{...}` evidence values unless the surrounding structure forces a different question format.

## Handoff rule

The offering skill MUST NOT author the ADR inline. It hands off to `/kramme:docs:adr`, which runs its own 5-step authoring workflow. The offering skill MAY pre-load a decision title and a short context summary as `$ARGUMENTS` so the user does not have to retype them.

## De-duplication

The offering skill SHOULD track which decisions have already been offered in the current session (by title or stable identifier) and not re-offer the same decision. `Skip` and `Defer` differ here: `Skip` suppresses re-offers for the lifetime of the session; `Defer` allows re-offer only if the same decision resurfaces in a later workflow step.
