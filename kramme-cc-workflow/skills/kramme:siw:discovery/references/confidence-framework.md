# Confidence Framework

Track understanding across 7 dimensions. The interview continues until overall confidence reaches the target threshold (default: 95% — all critical dimensions at Confident, all others at High or above).

## Dimensions

### 1. Problem Understanding

What pain point exists? Why does it matter? Who feels it?

| Level | Indicators |
|-------|-----------|
| **Low** (0-40%) | User described a solution, not a problem. Motivation unclear. |
| **Medium** (40-70%) | Problem identified but root cause or impact is fuzzy. |
| **High** (70-90%) | Problem, root cause, and impact are clear. Could explain to someone outside the project. |
| **Confident** (90%+) | Could explain the problem to a stranger and they'd agree it matters. Stated problem and actual problem have been reconciled. |

### 2. Stakeholder Clarity

Who benefits? Who decides? Who can block? Who pays?

| Level | Indicators |
|-------|-----------|
| **Low** | "Someone" or "users" need this. No specifics. |
| **Medium** | Primary user identified but decision-makers or blockers are unknown. |
| **High** | Users, decision-makers, and constraints are clear. Power dynamics understood. |
| **Confident** | Could predict each stakeholder's reaction to the proposed solution. |

### 3. Outcome Vision

What does success look like concretely? How will we measure it?

| Level | Indicators |
|-------|-----------|
| **Low** | Vague goal ("make it better", "improve performance"). |
| **Medium** | Measurable outcome stated but criteria are fuzzy or untestable. |
| **High** | Concrete success criteria with observable indicators. |
| **Confident** | Could write acceptance tests from current understanding alone. |

### 4. Scope Boundaries

What's in? What's out? What's deferred? Where are the edges?

| Level | Indicators |
|-------|-----------|
| **Low** | Open-ended, no boundaries discussed. |
| **Medium** | Some boundaries exist but gaps remain. In-scope is clearer than out-of-scope. |
| **High** | In-scope, out-of-scope, and deferred are all defined. |
| **Confident** | Could reject a reasonable feature request with clear rationale grounded in the scope. |

### 5. Constraint Awareness

Time, technology, political, resource, regulatory limits.

| Level | Indicators |
|-------|-----------|
| **Low** | No constraints discussed. |
| **Medium** | Some constraints known but haven't distinguished hard constraints from preferences. |
| **High** | Hard constraints vs. preferences are distinguished. Workarounds identified for soft constraints. |
| **Confident** | Could make tradeoff decisions within known constraints without asking. |

### 6. Priority Alignment

When tradeoffs arise, what wins? What can be sacrificed?

| Level | Indicators |
|-------|-----------|
| **Low** | Everything is "important" or "high priority". |
| **Medium** | Some ordering exists but not tested under pressure. |
| **High** | Top priorities are explicit, ordered, and have been tested with forced tradeoffs. |
| **Confident** | Could resolve a scope conflict autonomously and be right. |

### 7. Risk Awareness

What could go wrong? What's the blast radius? What's the recovery plan?

| Level | Indicators |
|-------|-----------|
| **Low** | No risks discussed or only obvious ones ("it might be late"). |
| **Medium** | Key risks identified but likelihood/impact unclear. |
| **High** | Risks ranked by likelihood and impact. Mitigations exist for top risks. |
| **Confident** | Could explain to stakeholders what might fail and why the risk is acceptable. |

## Initial Confidence Assessment

### Greenfield Mode (no spec)

Start all dimensions at **Low** unless the user's topic statement contains enough signal to bump specific dimensions.

If a topic statement is rich (e.g., "I need to migrate our auth from Firebase to Clerk because our SOC2 audit flagged session token storage"), you can start some dimensions at Medium based on what's implied.

### Refinement Mode (existing spec)

Map spec content to dimensions:

| Spec Section | Confidence Dimension |
|---|---|
| Overview / Problem statement | Problem Understanding |
| User/stakeholder mentions | Stakeholder Clarity |
| Success Criteria / Acceptance Criteria | Outcome Vision |
| Scope / Non-Goals | Scope Boundaries |
| Constraints / Requirements | Constraint Awareness |
| Priority ordering / Tradeoffs | Priority Alignment |
| Risks / Mitigations | Risk Awareness |

Score each dimension based on section quality: missing → Low, present but vague → Medium, concrete and specific → High. Confident requires interview validation.

## Work Context Adjustments

First normalize the profile name from the `siw:init` Work Context table:

| Work Context value in spec | Normalized profile |
|---|---|
| `Production` | Production Feature |
| `Prototype` | Prototype / Spike |
| `Internal Tool` | Internal Tool |
| `Refactor` | Tech Debt / Refactor |
| `Documentation` | Documentation / Process |

If the spec already uses the normalized profile names directly, use them as-is.

Treat legacy `Priority Dimensions` and `Deprioritized` fields from `siw:init` as hints for interview ordering only. Those labels belong to the older 8-dimension audit model, so they should not control the 7-dimension discovery stop thresholds directly.

When a normalized Work Context profile exists, adjust which dimensions are critical:

| Profile | Critical Dimensions | Can Deprioritize |
|---|---|---|
| Production Feature | All | None |
| Prototype / Spike | Problem Understanding, Outcome Vision, Scope Boundaries | Risk Awareness, Constraint Awareness |
| Internal Tool | Problem Understanding, Scope Boundaries, Priority Alignment | Stakeholder Clarity (beyond immediate team) |
| Tech Debt / Refactor | Scope Boundaries, Constraint Awareness, Risk Awareness | Stakeholder Clarity, Priority Alignment |
| Documentation / Process | Problem Understanding, Outcome Vision, Scope Boundaries | Constraint Awareness, Risk Awareness |

**Critical dimensions** must reach Confident (90%+) for overall confidence to hit the target.
**Deprioritized dimensions** only need Medium (40%+). Skip interview rounds for them unless they're at Low.
**Normal dimensions** (neither critical nor deprioritized) must reach High (70%+).

## Confidence Dashboard Format

Display after each interview round:

```
┌─ Confidence Dashboard (Round N) ────────────┐
│                                              │
│ Problem Understanding   ████████░░  High     │
│ Stakeholder Clarity     ██████████  Confident │
│ Outcome Vision          ██████░░░░  Medium ◄  │
│ Scope Boundaries        ████████░░  High     │
│ Constraint Awareness    ████░░░░░░  Medium ◄  │
│ Priority Alignment      ██████░░░░  Medium   │
│ Risk Awareness          ████░░░░░░  Low    ◄  │
│                                              │
│ Overall: 64%  Target: 95%                    │
│ ◄ = Next focus                               │
└──────────────────────────────────────────────┘
```

Bar segments: each █ = ~10%. Use ░ for unfilled. Mark focus areas with ◄.

## When to Stop

**Stop interviewing when ALL of:**
- Critical dimensions are at Confident (90%+)
- Normal dimensions are at High (70%+)
- Deprioritized dimensions are at Medium (40%+)
- Probing questions produce confirmations, not revelations

**Continue when ANY of:**
- Any critical dimension is below Confident
- Recent answers revealed something surprising or contradictory
- Stated wants and probed underlying needs don't align
- The user's initial framing and discovered reality have diverged significantly

## Updating Confidence

After each interview round:

1. Review answers against dimension rubrics
2. Adjust levels up (or down if answers revealed confusion)
3. Note any dimension where stated vs. actual wants diverged — this resets that dimension to at most Medium until reconciled
4. Display updated dashboard
5. Select next focus dimensions (lowest confidence first, weighted by criticality)
