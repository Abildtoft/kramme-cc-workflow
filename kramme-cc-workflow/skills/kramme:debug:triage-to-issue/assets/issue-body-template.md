# Issue Body Template

Use this template for the issue body produced by `kramme:debug:triage-to-issue`. Populate each section. Apply the **durability rule** throughout: no file paths, no line numbers, no internal helper or class names in prose.

---

## Title format

```
Fix [observable behavior] in [public surface]
```

Examples:

- `Fix expired tokens being accepted by the auth middleware`
- `Fix dialog reopening after cancel in the role-switch flow`
- `Fix null reference in user search when the query is empty`

The title should remain meaningful after a refactor that renames internal helpers.

---

## Body template

```markdown
## Problem

[1–3 sentences describing the observable behavior in module / contract language. No file paths, no line numbers.]

**Steps to reproduce:**
1. [Step 1 — user-visible action]
2. [Step 2 — user-visible action]
3. **Bug:** [What happens that shouldn't]

**Expected:** [What should happen instead]

## Root Cause Analysis

**What:** [The misbehavior, in contract language]
**Where:** [Public module / surface — e.g., "the auth middleware", "the rate limiter"]
**Why:** [The mechanism — what assumption fails or what state goes wrong]
**Confidence:** High / Medium / Low

[Optional 1–2 sentences of additional context if the mechanism is non-obvious.]

## TDD Fix Plan

Numbered RED-GREEN cycles. Each RED asserts on observable behavior through a public interface. Each GREEN is the minimal change to pass.

1. **RED:** [Behavior assertion — e.g., "Calling the auth middleware with an expired token returns a 401 response"]
   **GREEN:** [Minimal change description — e.g., "Add the expiry check before the signature check in the middleware's verify path"]

2. **RED:** [Next assertion]
   **GREEN:** [Next minimal change]

**Prove-It regression test:**

[One explicit test that fails before the fix and passes after. Describe what it asserts in behavior terms — not what file it lives in.]

## Acceptance Criteria

- [ ] [Behavior assertion 1]
- [ ] [Behavior assertion 2]
- [ ] [Behavior assertion 3]
- [ ] The Prove-It regression test passes after the fix and would have failed before.
- [ ] No existing test in the affected module's suite regresses.
- [ ] [If reproduction was UNVERIFIED] Fix is verified by reproducing the original failure scenario before merging.

## Out of Scope

- [Adjacent thing the implementer should NOT touch]
- [Refactor that would be tempting but belongs to a separate ticket]
- [NOTICED BUT NOT TOUCHING items surfaced during investigation]
```

---

## Notes

- Keep each section short. A reader scanning the issue should be able to identify the contract being broken in under 30 seconds.
- If the Root Cause Analysis cannot be written without naming an internal helper, the investigation is not done — return to Phase 3 of the SKILL.md process.
- Acceptance criteria are behaviors, not implementation steps. "Add expiry check" is an implementation step; "expired tokens are rejected" is a behavior.
- The Prove-It cycle is non-negotiable. Without it, the ticket has no regression guard and the same bug will return.
