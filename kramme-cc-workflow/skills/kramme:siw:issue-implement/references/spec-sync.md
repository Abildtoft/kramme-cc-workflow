# Spec Sync — Routing, Templates, and Worked Examples (Step 10 detail)

`SKILL.md` Step 10 keeps the ordered gate: review the decision log, classify and route, present candidates and ask, apply the selected updates, confirm. This file holds the detail behind each of those actions — what counts as a decision, how decisions are classified and routed, where updates belong, and the exact prompts and output templates.

---

## Reviewing the Decision Log (10.1)

Check siw/LOG.md for decisions recorded during implementation:

- New decisions not in the spec
- Changes to the originally planned approach
- Discovered constraints
- Technical choices that affect future work

---

## Classifying and Routing Decisions (10.2)

For each decision, check whether it aligns with the spec, supporting specs, or contract specs, then classify it:

- **Contradicts the spec** → spec needs updating
- **Adds new information** → spec needs expanding
- **Clarifies an ambiguity** → spec needs refinement

**If supporting or contract specs exist (`siw/supporting-specs/`, `siw/contracts/`)**, route decisions by topic:

- Data model decisions → `*-data-model*.md`
- API decisions → `*-api*.md`
- Contract/interface decisions → `siw/contracts/*.md`
- UI/frontend decisions → `*-ui*.md` or `*-frontend*.md`
- Architecture decisions → `*-architecture*.md` or another matching architecture spec
- User story updates → `*-user-stories*.md`
- Default → main spec if no matching supporting or contract spec

### Identifying the Main Spec

The main spec is the project-named uppercase markdown file at the top of `siw/` (chosen at `kramme:siw:init` time — common names include `FEATURE_SPECIFICATION.md`, `API_DESIGN.md`, `SYSTEM_DESIGN.md`, `PROJECT_PLAN.md`). Synced SIW spec-exclusion contract (keep aligned across SIW spec detectors): `LOG.md`, `OPEN_ISSUES_OVERVIEW.md`, `DISCOVERY_BRIEF.md`, `SPEC_STRENGTHENING_PLAN.md`, `AUDIT_*.md`, `PRODUCT_AUDIT.md`, `SIW_*.md`.

Synced SIW main-spec ambiguity contract (keep aligned across SIW spec detectors): when multiple spec candidates remain after deterministic heading/filename matching, auto mode stops with MISSING REQUIREMENT and interactive mode asks the user which file is the main spec.

Build a deterministic match set by project filename or first `#` heading when available. If exactly one candidate matches, use it. If zero or multiple candidates remain after matching and the current workflow is running in `AUTO_MODE=true`, stop with `MISSING REQUIREMENT: multiple spec candidates found; rerun interactively or pass an explicit main spec path`. Otherwise ask the user which file is the main spec before editing it.

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
   - Target file: {main spec filename or relevant supporting spec path}
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

## Applying the Selected Updates (10.4)

For supporting and contract specs, update the actual spec content the decision changes — entity definitions, endpoint contracts, component specs, architecture diagrams and descriptions — in the file the routing rules selected. Do not just append to a "Design Decisions" section: supporting and contract specs should always reflect current reality.

**Example:** A decision changes an API endpoint from POST to PUT.

- **Wrong:** Add "Decision #5: Changed to PUT" to a Design Decisions section.
- **Right:** Update the endpoint definition in the API spec to show PUT, and add a brief inline note about why.

**When to use the main spec's `## Design Decisions` section instead:**

- Cross-cutting decisions that affect multiple areas
- High-level architectural choices
- Decisions that don't map to a specific spec section

### Migration format for the main spec's `## Design Decisions` section

```markdown
### Decision #5: Make ActionByUserId Nullable

**Date:** 2025-11-05 | **Source:** ISSUE-G-003 implementation

**Context:** Not all entities undergo this action, so the field shouldn't be required at the database level. **Decision:** Nullable at storage; required parameter when calling PerformAction(). **Rationale:** Matches existing ActionAt pattern; semantically correct representation.
```

The spec version is more concise than LOG.md — omit alternatives and detailed impact (those stay in LOG.md for historical reference).

---

## Confirm Sync Output (10.5)

After updating, confirm with the user:

```
Specification(s) Updated

Main spec ({spec_filename}):
- Decision #{n}: {title}

Supporting/contract specs:
- siw/supporting-specs/01-data-model.md: Decision #{n}: {title}
- siw/supporting-specs/02-api-specification.md: Decision #{n}: {title}
- siw/contracts/01-api-contract.md: Decision #{n}: {title}

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
