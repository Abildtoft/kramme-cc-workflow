---
name: kramme:code:zoom-out
description: "Map the modules and call relationships in an area in focus. Use when the user is unfamiliar with a section of code and wants a one-shot orientation — modules involved, what they do, who calls what. Not for full-repo scans (use kramme:code:refactor-opportunities); not for bug investigation (use kramme:debug:investigate); not for visualizations (use kramme:visual:diagram)."
argument-hint: "[path, topic, or symbol — optional]"
disable-model-invocation: true
user-invocable: true
---

# Zoom Out

Produce a one-shot orientation map for an area of the codebase: which modules live there, what each one does, and how they call each other.

## Inputs

- **`$ARGUMENTS`** (optional): a path, topic, or symbol naming the area to map.
- If `$ARGUMENTS` is empty, infer the focus area from the most recently discussed file or symbol in the conversation. If no reliable focus exists, ask the user for a path, topic, or symbol before continuing.

## Workflow

1. **Identify the focus area.** If `$ARGUMENTS` is non-empty, treat it as the entry point. Otherwise infer from recent conversation context. If no reliable focus exists, ask the user for a path, topic, or symbol before continuing. State the focus area at the top of the output.
2. **List the relevant modules** in that area (≤15). For each, write `**ModuleName** — one-line role`. Use the project's domain language if `UBIQUITOUS_LANGUAGE.md` exists at the repo root.
3. **Describe call relationships** as directed bullets: `**Caller** calls **Callee** to <reason>`. Cover both inbound (who calls into the area) and outbound (what the area calls).

## Output Format

```markdown
**Focus area:** <path or topic>

## Modules
- **<Name>** — <one-line role>

## Relationships
- **<Caller>** calls **<Callee>** to <reason>
```

## Rules

- **Cap at ~15 modules.** If the area is larger, list the top entries by inbound-call count and add a final line `**Omitted:** N more modules — narrow the scope to see them.`
- **Do not propose changes.** This skill produces orientation only. No fixes, refactors, or recommendations.
- **No diagrams.** Text map only. Use `kramme:visual:diagram` for visualizations.
- **Stay inside the focus area.** Do not chase callers more than one hop out.

## Verification

- [ ] At least one relationship listed.
- [ ] No recommended-changes section in the output.
- [ ] Output ≤ 50 lines for typical scope.
