# Critique Rubric

Structured review checklist and scoring lens for product design critique.

## Teardown Structure

When critiquing a design, work through these layers in order:

### 1. Job Clarity
- Is the user's job-to-be-done obvious within 5 seconds?
- Does the interface communicate what just happened, what's happening now, and what to do next?
- Is there a single, clear primary action?

### 2. Information Architecture
- Is the hierarchy of information correct (most important = most prominent)?
- Are related elements grouped and unrelated elements separated?
- Does the layout support scanning rather than requiring reading?

### 3. Interaction Model
- Is it clear what is clickable versus static?
- Do interactions have visible, immediate feedback?
- Are destructive or high-consequence actions protected appropriately?
- Can the user undo or recover from mistakes?

### 4. State Coverage
- Are empty, loading, error, partial, and success states all designed?
- Do edge states feel intentional or like afterthoughts?
- Does the design degrade gracefully when data is missing or unexpected?

### 5. Trust and Governance
- Is it clear who is acting and with what authority?
- Are permissions, ownership, and audit trails surfaced where decisions happen?
- Can the user verify what the system did on their behalf?

### 6. Consistency
- Do similar elements behave the same way across views?
- Are naming conventions, icon usage, and spacing consistent?
- Does the design follow established platform conventions where appropriate?

### 7. Craft
- Is typography hierarchy clear and intentional?
- Is spacing rhythmic and purposeful?
- Are colors used meaningfully (not decoratively)?
- Do animations or transitions add clarity or just delay?

## Severity Levels

| Level | Label | Meaning |
|-------|-------|---------|
| P0 | Broken | Users cannot complete the job or are actively misled |
| P1 | Friction | Users can complete the job but with unnecessary difficulty or confusion |
| P2 | Weakness | The design works but misses an opportunity for clarity or trust |
| P3 | Polish | Minor refinement that would improve perceived quality |

## Scoring Lens

For each layer, assess:
- **Does it work?** (functional correctness)
- **Is it clear?** (cognitive load and legibility)
- **Is it trustworthy?** (governance, transparency, recoverability)
- **Is it opinionated?** (has the design made a choice, or is it hedging?)
