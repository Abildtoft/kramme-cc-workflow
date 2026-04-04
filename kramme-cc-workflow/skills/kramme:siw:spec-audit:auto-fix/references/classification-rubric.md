# Classification Rubric: Confidence-Based Scoring

A finding's **fix confidence** (0-100) measures how deterministic and safe an auto-fix would be. Score each finding on four conditions (0-25 each). The sum determines whether the finding is auto-fixable at the current threshold.

## Core Rule

Score all four conditions. Sum the scores (0-100). Compare against the active threshold (50-100, default 80). Findings at or above the threshold are auto-fixable only if they are not safety-capped and both `Determinism` and `Alternative Absence` score at least 15.

### Condition 1: Determinism (0-25)

| Score | Criteria |
|-------|----------|
| 25 | One obvious right answer. No reasonable person would fix it differently. |
| 15 | One clearly-best answer exists, though a minor alternative is conceivable. |
| 5 | A reasonable fix exists but requires choosing a specific approach. |
| 0 | Multiple valid approaches with no clear winner. |

### Condition 2: Information Availability (0-25)

| Score | Criteria |
|-------|----------|
| 25 | All information needed is explicitly present in the spec. |
| 15 | Information is present but requires combining content from multiple sections. |
| 5 | Most information is present but a small inference is needed. |
| 0 | Significant information is missing from the spec. |

### Condition 3: Meaning Preservation (0-25)

| Score | Criteria |
|-------|----------|
| 25 | Fix changes only form, not substance. Zero meaning change. |
| 15 | Fix primarily changes form; any meaning shift is trivially small and clearly intended. |
| 5 | Fix has minor meaning implications that are almost certainly positive. |
| 0 | Fix would change meaning, scope, or intent of requirements. |

### Condition 4: Alternative Absence (0-25)

| Score | Criteria |
|-------|----------|
| 25 | No choosing between alternatives. The fix is the only reasonable option. |
| 15 | One alternative exists but is clearly inferior. |
| 5 | Two alternatives exist; one is moderately better than the other. |
| 0 | Multiple equally valid alternatives exist. |

## Confidence Tiers

| Tier | Range | Label |
|------|-------|-------|
| MECHANICAL | 90-100 | Deterministic fix, fully mechanical |
| HIGH_CONFIDENCE | 75-89 | Clearly-best fix, near-mechanical |
| MODERATE_CONFIDENCE | 50-74 | Reasonable fix, some judgment involved |
| REQUIRES_DECISION | 0-49 | Needs human decision |

## Auto-Fix Guardrails

Lowering the threshold does **not** override these two guardrails:

1. `Determinism < 15` → `REQUIRES_DECISION`. The fix still needs a chosen approach instead of having one clearly best answer.
2. `Alternative Absence < 15` → `REQUIRES_DECISION`. The fix still requires choosing between valid alternatives.

These guardrails keep `--threshold 50` and `--threshold 60` runs from auto-fixing findings that still need human judgment.

## Fix Categories with Typical Confidence

| Category | What to Look For | Fix Pattern | Typical Confidence |
|----------|-----------------|-------------|-------------------|
| **Cross-reference errors** | Section/task refs that don't match actual headings, broken internal links | Update reference to match the actual heading | 95-100 |
| **Terminology inconsistency** | One term used N times, a synonym used 1-2 times for the same concept | Replace outlier(s) with the dominant term | 85-100 (drops if frequencies are close) |
| **Numbering/ordering errors** | Task lists with gaps (2.3 → 2.5), duplicate numbers, wrong sequence | Renumber to correct sequence | 95-100 |
| **Passive voice with obvious actor** | "The request will be validated" in a section clearly about a specific component | Rewrite with the actor named in the surrounding context | 80-95 |
| **Formatting inconsistencies** | Mixed list styles, inconsistent heading levels, inconsistent bold/italic usage | Standardize to the dominant format in the spec | 90-100 |
| **Weasel words with specifics available** | "various endpoints" when the spec lists exact endpoints nearby, "etc." when all items are enumerable | Replace vague term with the specific items from the spec | 75-95 |
| **Missing Out of Scope section** | No explicit out-of-scope section, but boundaries are deducible from in-scope items and context | Add section with items clearly derivable from existing content | 70-85 |
| **Duplicate content** | Same information stated identically in two places, one clearly the canonical location | Remove the duplicate, keep the canonical instance | 85-95 |
| **Broken markdown formatting** | Unclosed code blocks, malformed tables, broken link syntax | Fix the markdown syntax | 95-100 |

## Score Depressors

These indicators pull confidence scores down. The more that apply, the lower the score:

1. **Missing requirement** — The finding identifies something the spec should say but doesn't, and the correct content cannot be deduced from existing spec text → Condition 2 scores 0-5
2. **Multiple valid fixes** — More than one reasonable fix exists and the choice would affect implementation decisions → Condition 4 scores 0-5
3. **External information needed** — The fix requires knowledge not present in the spec (stakeholder preferences, technical constraints, user research) → Condition 2 scores 0
4. **Architecture or design trade-off** — The finding involves choosing between design patterns, technology options, or structural approaches → Condition 1 and 4 both score 0-5
5. **Scope boundary change** — The fix would add or remove items from the spec's scope → Condition 3 scores 0
6. **Success criteria substance** — The finding involves defining what success looks like (not just making existing criteria measurable) → Condition 1 scores 0-5
7. **Recommendation language signals** — The finding's recommendation uses "consider", "decide whether", "choose between", "discuss with", "evaluate options" → typically pushes total below 50

## Safety Caps

Certain findings are **capped at confidence 0** regardless of their condition scores. These always require human decision at every allowed threshold.

A finding is safety-capped if ANY of these apply:

1. Severity is Critical AND dimension is Completeness, Scope, or Value Proposition
2. Recommendation uses decision-signal language: "consider", "decide whether", "choose between", "discuss with", "evaluate options"
3. Finding explicitly involves adding or removing items from scope
4. Finding involves defining success criteria substance (not just making existing criteria measurable)

## Edge Cases

- **Terminology inconsistency where both terms are used frequently** (e.g., 8x vs 5x) → Score 30-40 (Condition 1: 5, Condition 4: 0). Below default threshold.
- **Missing section that requires only a stub** (e.g., empty "Testing" section) → Score 20-30. Below default threshold.
- **Missing section where content is fully derivable** (e.g., "Out of Scope" when in-scope is comprehensive) → Score 70-85. Auto-fixable at default only if score >= 80.
- **Passive voice where the actor is ambiguous** (could be frontend or backend) → Score 40-50. Below default threshold.
- **Passive voice where the actor is obvious from section header** → Score 85-95. Auto-fixable at default threshold.
