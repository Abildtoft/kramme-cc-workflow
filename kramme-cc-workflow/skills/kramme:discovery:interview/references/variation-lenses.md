# Variation Lenses & Stress-Test Axes

Reference for Phase 0 (Divergent) of the interview skill. Load this only when Phase 0 runs — either via the `--ideate` flag or when the initial framing is too vague to interview against.

## When Phase 0 applies

Phase 0 is a **breadth** pre-stage before the depth-first interview. It fits when the user's framing is shaped like:

- "I want to improve X" (no clear what/why)
- "We should do something about Y" (no direction)
- "Help me think through Z" (exploratory, no candidate solution)

Phase 0 does **not** apply when the user arrives with a concrete ask (e.g., "Add email-based 2FA to the login flow"). Skip directly to Step 3 of the interview.

## The Seven Variation Lenses

Apply 4–7 of these lenses to the user's stated idea. Produce 5–8 candidate variations — not all seven need to apply to every topic. Pick the lenses most likely to generate meaningfully distinct framings.

### 1. Inversion — flip the premise

Ask: *what if the opposite were true?* If the user wants to reduce friction in signup, invert to "what if friction were the product?" (e.g., a deliberately slow, high-commitment signup that pre-qualifies users).

**Worked example** — "Improve onboarding for new users":
- Inversion: What if onboarding were *removed* entirely? Users land in a working state with zero setup. What does the product look like?

### 2. Constraint removal — drop the "must have X"

Identify the constraint the user treats as fixed, then remove it. Often reveals that the "hard constraint" was soft.

**Worked example**:
- If onboarding "must" use email capture, what if it didn't? Anonymous onboarding with identity deferred until value is delivered.

### 3. Audience shift — same idea for a different user

Keep the mechanism; change who it serves. Surfaces whether the value is in the mechanism or in the specific audience.

**Worked example**:
- Onboarding aimed at non-technical admins instead of end-users — how does it change?

### 4. Combination — merge with an adjacent concept

Fuse the idea with something nearby in the problem space.

**Worked example**:
- Onboarding + community: new users are paired with an existing user for the first session, turning setup into a social hook.

### 5. Simplification — strip to the smallest viable form

What's the *one* thing the idea must do? Remove everything else.

**Worked example**:
- Onboarding reduced to: "user types one command and sees one working output." Everything else is post-onboarding.

### 6. 10× version — dramatically bigger/faster/cheaper

What if this were 10× faster, or 10× cheaper, or 10× broader in scope? Forces out the boundaries of what's possible.

**Worked example**:
- 10× faster: onboarding completes in <5 seconds. What has to go?
- 10× broader: onboarding serves users across 10 adjacent products simultaneously.

### 7. Expert lens — how would a domain expert reshape it?

Pick an expert from an adjacent domain (UX researcher, SRE, customer-support lead, security engineer) and reshape the idea through their priorities.

**Worked example**:
- A security engineer's onboarding: identity verification and threat-surface minimization come first; everything else is layered on after trust is established.

## The Three Stress-Test Axes

After generating variations, use these axes to **converge**. Each axis is one pass over the candidates.

### 1. User value — painkiller vs vitamin

For each variation, answer: *is this a painkiller (solves a present, felt pain) or a vitamin (a nice-to-have that compounds over time)?*

- Painkillers: user would pay today to make the pain stop. High urgency.
- Vitamins: user would enjoy but can defer. Low urgency, easy to de-prioritize.

Neither is inherently better, but mixing them in one project is usually a mistake. Pick the frame the user actually operates in.

### 2. Feasibility — what breaks first?

For each variation, name the *first thing to break* under real conditions. If you can't name one, you haven't thought about it hard enough — flag it with `UNVERIFIED` and note what evidence you'd need.

Concrete failure modes: scale, latency, data consistency, team capacity, dependency availability, cost, compliance, user expectations.

### 3. Differentiation — what does this do that alternatives don't?

For each variation, state the alternative that already exists (inside the product, in competing products, or "do nothing") and what this variation does *that the alternative cannot*. If the answer is "nothing distinct," drop the variation.

## Convergence protocol

1. List each surviving variation with: `{name} — {painkiller|vitamin} — {first-failure-mode} — {differentiator}`.
2. Present to the user via AskUserQuestion. Options: 2–4 strongest variations + "None of these — let's iterate."
3. When the user picks one, restate it as the concrete problem statement that feeds Step 3 (the existing interview). Use the `FRAMING` marker in the hand-off:

```text
FRAMING: Interview will proceed on the following framing — {chosen variation restated concretely}.
```

4. If the user picks "None of these," apply 2 fresh lenses and re-run convergence.
