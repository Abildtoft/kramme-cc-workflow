# Probing Techniques

Techniques for uncovering what the user actually wants, not what they think they should want. The gap between those two is where most failed projects begin.

## Core Principle

People describe solutions, not problems. They say "I need a dashboard" when they actually need "visibility into system health." Every technique below is designed to strip away the solution layer and find the real need underneath.

## Technique Library

### 1. Solution Stripping

**When:** User describes a solution ("I need X") without explaining the problem it solves. **How:** "What problem does [X] solve for you?" or "If [X] didn't exist, what would go wrong?" **Reveals:** The actual problem, which may have better solutions than what was proposed. **Example:** User says "I need a caching layer." Ask "What's slow right now and who notices?"

### 2. Inversion

**When:** Priorities are unclear or everything seems equally important. **How:** "What would make this project a failure?" or "Six months from now, what would make you regret building this?" **Reveals:** True priorities — people protect what they actually care about. **Example:** "If this launched but [X] didn't work, would that be a failure or an acceptable tradeoff?"

### 3. Forced Tradeoff

**When:** User says multiple things are high priority, or scope feels unlimited. **How:** Present two reasonable options and ask which they'd choose if forced. "If you could only ship feature A or feature B this quarter, which one?" **Reveals:** True priority ordering when pressure is applied. **Example:** "Speed or correctness — if the system could be fast with occasional wrong answers, or slow but always right, which matters more here?"

### 4. Constraint Removal

**When:** Trying to distinguish real constraints from assumed ones. **How:** "If [constraint] didn't exist, would you do this differently?" or "If you had unlimited [time/budget/people], what would change?" **Reveals:** Which constraints are hard (regulatory, technical) vs. assumed (tradition, habit). **Example:** "If the deadline weren't a factor, would you still build it this way?"

### 5. Why Chain

**When:** Surface-level answer that needs deeper motivation. **How:** Ask "Why does that matter?" 2-3 times (gently, not interrogatively). Stop when you hit bedrock motivation. **Reveals:** Root motivation behind surface requests. The third "why" usually gets to truth. **Example:** "We need real-time updates." → "Why?" → "Users complain about stale data." → "What happens when they see stale data?" → "They make wrong trading decisions." (Now you know the real stakes.)

### 6. Negative Space

**When:** Scope feels unbounded or user hasn't mentioned what's excluded. **How:** "What did you explicitly decide NOT to include?" or "What's the most obvious feature you're intentionally leaving out?" **Reveals:** Hidden scope decisions, past debates, and deferred work. **Example:** "Is multi-tenant support intentionally out of scope, or something you haven't decided yet?"

### 7. Past Failure

**When:** User is building something similar to a past project, or the domain has known pitfalls. **How:** "Has anything like this been tried before? What happened?" or "What went wrong with the last version?" **Reveals:** Real constraints, hidden requirements, organizational scar tissue. **Example:** "The last time someone built a notification system here, what broke?"

### 8. Stakeholder Lens

**When:** Trying to understand external pressures or decision dynamics. **How:** "How would [specific person/team] react to this?" or "Who would push back on this approach?" **Reveals:** Political constraints, approval requirements, external dependencies. **Example:** "If we shipped this tomorrow, what would the security team say?"

### 9. Restatement Challenge

**When:** Validating your understanding — especially for nuanced answers. **How:** Deliberately rephrase their answer slightly differently (not wrong, just different emphasis) and present it back. If they correct you, you found precision. If they accept a bad restatement, your understanding is shallower than you thought. **Reveals:** Whether your mental model matches theirs. Mismatches are high-signal. **Example:** User says "We need fast search." You restate: "So sub-second response time is a hard requirement?" They might say "No, I mean the results need to be relevant, speed is fine at 2-3 seconds." Now you know it's about relevance, not latency.

### 10. Minimum Viable Test

**When:** Trying to find the core value proposition or smallest useful increment. **How:** "What's the smallest thing we could build to know if this is on the right track?" **Reveals:** The core value — what actually matters stripped of nice-to-haves. **Example:** "If we could only ship one screen/endpoint/flow, which one would tell you if the whole project is worth continuing?"

## Technique Selection Guide

Pick techniques based on which confidence dimension needs work:

| Dimension | Primary Techniques | Secondary |
| --- | --- | --- |
| Problem Understanding | Solution Stripping, Why Chain | Past Failure |
| Stakeholder Clarity | Stakeholder Lens, Restatement Challenge | Constraint Removal |
| Outcome Vision | Minimum Viable Test, Inversion | Restatement Challenge |
| Scope Boundaries | Negative Space, Forced Tradeoff | Constraint Removal |
| Constraint Awareness | Constraint Removal, Past Failure | Stakeholder Lens |
| Priority Alignment | Forced Tradeoff, Inversion | Minimum Viable Test |
| Risk Awareness | Inversion, Past Failure | Stakeholder Lens |

## Question Round Contract

Use AskUserQuestion. Ask 1-3 high-value questions per round; default to 2 when the questions are independent, and 1 when the answer changes the next question. Keep rounds small; run more rounds instead of one large batch.

For each question:

- Apply the Codebase-as-Answer-Source Rule before asking.
- State why you're asking in one sentence, naming the confidence dimension it targets.
- Include your current assumption so the user can correct instead of explain from scratch.
- Offer concrete options when forcing tradeoffs: 2-4 options plus Other.
- Use freeform when probing for narrative or motivation.
- For high-stakes questions where the answer shapes the next question, ask only one question in the round.
- If a round would only ask confirmation questions, replace one with a stress probe unless the coverage floor is already satisfied.

When the technique calls for it, deliberately restate something the user said earlier with slightly different emphasis to test whether your model matches theirs.

## Codebase-as-Answer-Source Rule

Before asking any question in either mode, decide whether the answer can be found by exploring the workspace, target spec, existing SIW docs, or provided artifacts.

- If yes, explore first, report the finding with the source, and ask only for confirmation or correction if meaningful uncertainty remains.
- If no, ask the user.
- Skip exploration when the question is genuinely preference-, priority-, or business-context-based and no artifact could answer it.

## ADR-Offer Hook

After each resolved decision in either mode, evaluate the ADR test. Offer `/kramme:docs:adr` only when it is installed in the environment; otherwise skip the hook silently.

Offer once when all three are true:

1. The decision is hard to reverse.
2. It would be surprising later without context.
3. It came from a real tradeoff, not a default.

Prompt once: "This looks ADR-worthy because it is hard to reverse, surprising without context, and tradeoff-driven. Record it via `/kramme:docs:adr`?" Do not author the ADR inside this skill.

## Coverage Mode Loop

Repeat until the confidence target is met, the user explicitly says "that's enough" or "I think you've got it", or 10+ rounds are complete. At 10+ rounds, suggest stopping without forcing it, and offer to continue if the user wants.

### Select Focus

Pick the 1-2 highest-value focus dimensions, weighted by coverage gaps before confidence score:

1. Critical dimensions missing direct validation or a stress probe
2. Normal dimensions missing direct validation
3. Dimensions whose evidence contradicts another answer or artifact
4. Critical dimensions below Confident
5. Normal dimensions below High
6. Deprioritized dimensions below Medium or missing any evidence, only if others are satisfied

### Select Technique

Use the technique selection guide to pick 1-2 techniques appropriate for the focus dimensions.

- Early rounds 1-3: prefer Solution Stripping, Why Chain, and Minimum Viable Test.
- Middle rounds 4-6: prefer Forced Tradeoff, Negative Space, and Constraint Removal.
- Late rounds 7+: prefer Restatement Challenge, Inversion, and Stakeholder Lens.

### Process Answers

After each round:

1. Map answers to confidence dimensions.
2. Check for stated-vs-actual want divergence:
   - Answer contradicts earlier answer -> emit `CONFUSION:` and probe.
   - Implementation details without problem statement -> apply Solution Stripping next round.
   - Enthusiasm does not match stated priority -> name the discrepancy.
3. If divergence is detected, reset affected dimensions to at most Medium until reconciled.
4. Update the evidence ledger. Mark a stress probe only when the answer tested a tradeoff, boundary, inversion, past failure, why-chain, or restatement challenge; a simple "yes, correct" does not count.
5. Update confidence levels using rubric indicators and ledger coverage.
6. If a dimension remains unanswerable because the required information is not in the spec or user answers, emit `MISSING REQUIREMENT:` before asking the targeted follow-up.
7. Run the ADR-Offer Hook for any resolved decision.

Show the confidence dashboard after each round. Mark focus areas for next round with `◄`, include round number and overall percentage, and explicitly note any dimension that dropped because of contradiction or new information.

## Interview Pacing

- Rounds 1-2: broad, establishing. Cover Problem Understanding and Outcome Vision first.
- Rounds 3-5: sharpening. Focus on Scope Boundaries, Priority Alignment, and Constraint Awareness.
- Rounds 6+: validating. Stress-test with Restatement Challenge and Inversion. Fill remaining gaps.
- If a round produces a surprise, pause the plan and follow the surprise.
- Greenfield discovery should rarely synthesize before 4 rounds unless the user stops early.
- Refinement should rarely synthesize before 2 rounds unless the target artifacts already answer most dimensions and the interview only validates narrow gaps.

## Anti-Patterns

### Do NOT:

- **Ask what they already told you.** Track what's been said. Rephrase to validate, don't re-ask.
- **Ask generic setup questions.** "Tell me about your project" is lazy. Frame a hypothesis and validate it.
- **Accept the first answer.** The first answer is what they think you want to hear. The third answer is closer to truth.
- **Interrogate.** This is a conversation, not a deposition. Probing is done with genuine curiosity, not suspicion.
- **Ask more than 3 questions per round.** Cognitive load kills honesty. 1-2 high-value questions per round is ideal; ask more rounds, not giant batches.
- **Stop after the first satisfactory answer.** A good first answer is the start of discovery. Follow it with a tradeoff, negative-space probe, or restatement challenge before treating it as settled.
- **Stack all techniques at once.** Pick 1-2 per round based on the lowest confidence dimension.
- **Ignore surprises.** When an answer contradicts earlier answers, that's gold — dig in immediately.
- **Confuse solution preferences with requirements.** "We use Postgres" is a constraint. "We need relational data" is a requirement. One can change, the other defines the problem.

### Recognizing Stated vs. Actual Wants

Signals that stated want ≠ actual want:

- User describes implementation details before the problem
- Answers change when you ask "why" vs. "what"
- Enthusiasm doesn't match stated priority (they say X is important but light up talking about Y)
- Constraints are mentioned defensively ("we have to use X because...") — probe whether the constraint is real
- Scope keeps expanding — the real project is bigger than what they're asking for
- Hedging language ("I think we need...", "probably should...") — they're unsure but presenting certainty

When you detect this divergence: name it explicitly. "You mentioned [stated want], but your answers suggest the real priority is [actual want]. Which is closer?" This moment of reconciliation is the highest-value moment in the interview.
