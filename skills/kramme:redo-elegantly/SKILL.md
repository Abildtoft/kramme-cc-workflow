---
name: kramme:redo-elegantly
description: Scrap a working-but-mediocre fix and reimplement elegantly. Use after making a fix that works but feels hacky.
disable-model-invocation: true
user-invocable: true
---

# Elegant Refactor

Knowing everything you know now, scrap this and implement the elegant solution.

## Step 0: Validate Context

Before proceeding, review the current conversation to confirm:

1. **Implementation work exists** - We've written or modified code in this session
2. **The work is complete enough** - The fix/feature works (even if inelegantly)
3. **There's something to improve** - The implementation has identifiable inelegance

**If any of these are missing, STOP and explain:**

- No implementation work? → "There's no implementation in this conversation to refactor. This command is for redoing existing work more elegantly."
- Work isn't complete? → "Let's finish the current implementation first, then we can evaluate whether it needs an elegant refactor."
- Nothing obviously inelegant? → "The current implementation looks reasonable. What specifically feels hacky or inelegant to you?"

Only proceed if all three conditions are met.

## The Core Insight

First implementations often solve the problem but in a hacky way. Having solved the problem once, you now understand it deeply enough to implement it properly from scratch.

**Do not preserve the mediocre code.** The whole point is to start fresh.

## Process

### 1. Extract What You Learned

Before touching any code, articulate:

- What was the actual problem? (Not what you thought it was initially)
- What constraints did you discover?
- What edge cases matter?
- What dependencies or interactions exist?

### 2. Identify the Inelegance

Be specific about what's wrong with the current solution:

- Unnecessary complexity?
- Wrong abstraction level?
- Coupling that shouldn't exist?
- Duplicated logic?
- Hard to understand or maintain?

### 3. Design the Elegant Solution

Think before coding:

- What's the simplest approach that handles all discovered cases?
- What abstraction, if any, makes this clearer?
- How would you explain this solution to someone else?

### 4. Scrap and Reimplement

1. **Save the current state** - Note the files and behavior to verify against
2. **Revert the changes** - Go back to before the mediocre fix
3. **Implement the elegant solution** - Write it fresh, properly
4. **Verify equivalence** - Ensure same behavior (unless explicitly improving)

## When to Use This

- After a fix that works but makes you wince
- When you realize mid-implementation there's a better way
- When the solution has grown tentacles
- When explaining the code would be embarrassing

## When NOT to Use This

- The solution is fine, just unfamiliar
- Time pressure makes "good enough" acceptable
- The inelegance is inherent to the problem domain
