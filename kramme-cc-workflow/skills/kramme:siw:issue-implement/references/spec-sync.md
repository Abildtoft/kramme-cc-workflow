# Spec Sync — Templates and Worked Examples (Step 10 detail)

Use these alongside the inline summary in `SKILL.md` Step 10. The main skill keeps the routing rules and the "update content, not Design Decisions section" rule inline so the flow is readable without this file; this file holds the longer prompts, examples, and output templates.

---

## Spec Update Candidates Presentation (10.3)

When misalignments between siw/LOG.md and the spec are found, present them like this:

```
Spec Sync Check

The following decisions from implementation don't match the current specification:

Decisions needing spec update:
1. Decision #{n}: {title}
   - siw/LOG.md says: {decision}
   - Spec says: {current spec content or "not mentioned"}
   - Target file: {main spec or relevant supporting spec}
   - Recommendation: {update/add/clarify}

2. Decision #{n}: {title}
   ...
```

Then ask the user how to proceed:

```yaml
header: "Update Specification"
question: "Should I update the specification to reflect these implementation decisions?"
options:
  - label: "Update spec with all decisions"
    description: "Add all listed decisions to the specification"
  - label: "Review each decision"
    description: "Let me choose which decisions to include"
  - label: "Skip spec update"
    description: "Keep spec as-is (decisions remain only in siw/LOG.md)"
```

---

## Updating Supporting Specs (10.4) — Worked Example

Supporting specs should always reflect current reality. Update the actual spec content, not a "Design Decisions" section.

**Example:** A decision changes an API endpoint from POST to PUT.

- **Wrong:** Add "Decision #5: Changed to PUT" to a Design Decisions section.
- **Right:** Update the endpoint definition in the API spec to show PUT, and add a brief inline note about why.

**Routing reminders (kept inline in SKILL.md but repeated here for context):**
- Data model changes → Update entity definitions in `*-data-model*.md`
- API changes → Update endpoint contracts in `*-api*.md`
- UI changes → Update component specs in `*-ui*.md`
- Architecture changes → Update diagrams/descriptions in architecture specs

**When to use the main spec's `## Design Decisions` section instead:**
- Cross-cutting decisions that affect multiple areas
- High-level architectural choices
- Decisions that don't map to a specific spec section

### Migration format for the main spec's `## Design Decisions` section

```markdown
### Decision #5: Make ActionByUserId Nullable
**Date:** 2025-11-05 | **Source:** ISSUE-G-003 implementation

**Context:** Not all entities undergo this action, so the field shouldn't be required at the database level.
**Decision:** Nullable at storage; required parameter when calling PerformAction().
**Rationale:** Matches existing ActionAt pattern; semantically correct representation.
```

The spec version is more concise than LOG.md — omit alternatives and detailed impact (those stay in LOG.md for historical reference).

---

## Confirm Sync Output (10.5)

After updating, confirm with the user:

```
Specification(s) Updated

Main spec ({spec_filename}):
- Decision #{n}: {title}

Supporting specs:
- siw/supporting-specs/01-data-model.md: Decision #{n}: {title}
- siw/supporting-specs/02-api-specification.md: Decision #{n}: {title}

Sections updated:
- Design Decisions
- {other sections if applicable}

Specs and siw/LOG.md are now aligned.
```

If no updates were needed:

```
Spec Sync Check: All implementation decisions align with the specifications.
No updates needed.
```
