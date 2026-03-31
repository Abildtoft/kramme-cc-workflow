# Classification Rubric: Mechanical vs Requires Decision

A finding is **mechanical** when two competent spec authors would produce the same fix using only information already present in the spec. The fix corrects form, not substance.

## Core Rule

ALL of these conditions must hold for a finding to be `MECHANICAL`:

1. The correct fix is deterministic — one obvious right answer exists
2. The information needed for the fix is already present elsewhere in the spec
3. The fix does not change the meaning, scope, or intent of any requirement
4. The fix does not require choosing between valid alternatives

If ANY condition fails → `REQUIRES_DECISION`.

## Mechanical Categories

| Category | What to Look For | Fix Pattern |
|----------|-----------------|-------------|
| **Cross-reference errors** | Section/task refs that don't match actual headings, broken internal links | Update reference to match the actual heading |
| **Terminology inconsistency** | One term used N times, a synonym used 1-2 times for the same concept | Replace outlier(s) with the dominant term |
| **Numbering/ordering errors** | Task lists with gaps (2.3 → 2.5), duplicate numbers, wrong sequence | Renumber to correct sequence |
| **Passive voice with obvious actor** | "The request will be validated" in a section clearly about a specific component | Rewrite with the actor named in the surrounding context |
| **Formatting inconsistencies** | Mixed list styles, inconsistent heading levels, inconsistent bold/italic usage | Standardize to the dominant format in the spec |
| **Weasel words with specifics available** | "various endpoints" when the spec lists exact endpoints nearby, "etc." when all items are enumerable | Replace vague term with the specific items from the spec |
| **Missing Out of Scope section** | No explicit out-of-scope section, but boundaries are deducible from in-scope items and context | Add section with items clearly derivable from existing content |
| **Duplicate content** | Same information stated identically in two places, one clearly the canonical location | Remove the duplicate, keep the canonical instance |
| **Broken markdown formatting** | Unclosed code blocks, malformed tables, broken link syntax | Fix the markdown syntax |

## REQUIRES_DECISION Indicators

A finding is `REQUIRES_DECISION` if ANY of these apply:

1. **Missing requirement** — The finding identifies something the spec should say but doesn't, and the correct content cannot be deduced from existing spec text
2. **Multiple valid fixes** — More than one reasonable fix exists and the choice would affect implementation decisions
3. **External information needed** — The fix requires knowledge not present in the spec (stakeholder preferences, technical constraints, user research)
4. **Architecture or design trade-off** — The finding involves choosing between design patterns, technology options, or structural approaches
5. **Scope boundary change** — The fix would add or remove items from the spec's scope
6. **Success criteria substance** — The finding involves defining what success looks like (not just making existing criteria measurable)
7. **Recommendation language signals** — The finding's recommendation uses "consider", "decide whether", "choose between", "discuss with", "evaluate options"
8. **Severity is Critical + dimension is Completeness, Scope, or Value Proposition** — Critical gaps in these dimensions almost always require product judgment

## Edge Cases

- **Terminology inconsistency where both terms are used frequently** (e.g., 8x vs 5x) → `REQUIRES_DECISION` — no clear dominant term, choosing one is a judgment call
- **Missing section that requires only a stub** (e.g., empty "Testing" section) → `REQUIRES_DECISION` — what goes in it requires decisions
- **Missing section where content is fully derivable** (e.g., "Out of Scope" when in-scope is comprehensive) → `MECHANICAL`
- **Passive voice where the actor is ambiguous** (could be frontend or backend) → `REQUIRES_DECISION`
- **Passive voice where the actor is obvious from the section header** → `MECHANICAL`
