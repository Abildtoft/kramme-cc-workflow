# Probing Techniques

Techniques for uncovering what the user actually wants, not what they think they should want. The gap between those two is where most failed projects begin.

## Core Principle

People describe solutions, not problems. They say "I need a dashboard" when they actually need "visibility into system health." Every technique below is designed to strip away the solution layer and find the real need underneath.

## Technique Library

### 1. Solution Stripping

**When:** User describes a solution ("I need X") without explaining the problem it solves.
**How:** "What problem does [X] solve for you?" or "If [X] didn't exist, what would go wrong?"
**Reveals:** The actual problem, which may have better solutions than what was proposed.
**Example:** User says "I need a caching layer." Ask "What's slow right now and who notices?"

### 2. Inversion

**When:** Priorities are unclear or everything seems equally important.
**How:** "What would make this project a failure?" or "Six months from now, what would make you regret building this?"
**Reveals:** True priorities — people protect what they actually care about.
**Example:** "If this launched but [X] didn't work, would that be a failure or an acceptable tradeoff?"

### 3. Forced Tradeoff

**When:** User says multiple things are high priority, or scope feels unlimited.
**How:** Present two reasonable options and ask which they'd choose if forced. "If you could only ship feature A or feature B this quarter, which one?"
**Reveals:** True priority ordering when pressure is applied.
**Example:** "Speed or correctness — if the system could be fast with occasional wrong answers, or slow but always right, which matters more here?"

### 4. Constraint Removal

**When:** Trying to distinguish real constraints from assumed ones.
**How:** "If [constraint] didn't exist, would you do this differently?" or "If you had unlimited [time/budget/people], what would change?"
**Reveals:** Which constraints are hard (regulatory, technical) vs. assumed (tradition, habit).
**Example:** "If the deadline weren't a factor, would you still build it this way?"

### 5. Why Chain

**When:** Surface-level answer that needs deeper motivation.
**How:** Ask "Why does that matter?" 2-3 times (gently, not interrogatively). Stop when you hit bedrock motivation.
**Reveals:** Root motivation behind surface requests. The third "why" usually gets to truth.
**Example:** "We need real-time updates." → "Why?" → "Users complain about stale data." → "What happens when they see stale data?" → "They make wrong trading decisions." (Now you know the real stakes.)

### 6. Negative Space

**When:** Scope feels unbounded or user hasn't mentioned what's excluded.
**How:** "What did you explicitly decide NOT to include?" or "What's the most obvious feature you're intentionally leaving out?"
**Reveals:** Hidden scope decisions, past debates, and deferred work.
**Example:** "Is multi-tenant support intentionally out of scope, or something you haven't decided yet?"

### 7. Past Failure

**When:** User is building something similar to a past project, or the domain has known pitfalls.
**How:** "Has anything like this been tried before? What happened?" or "What went wrong with the last version?"
**Reveals:** Real constraints, hidden requirements, organizational scar tissue.
**Example:** "The last time someone built a notification system here, what broke?"

### 8. Stakeholder Lens

**When:** Trying to understand external pressures or decision dynamics.
**How:** "How would [specific person/team] react to this?" or "Who would push back on this approach?"
**Reveals:** Political constraints, approval requirements, external dependencies.
**Example:** "If we shipped this tomorrow, what would the security team say?"

### 9. Restatement Challenge

**When:** Validating your understanding — especially for nuanced answers.
**How:** Deliberately rephrase their answer slightly differently (not wrong, just different emphasis) and present it back. If they correct you, you found precision. If they accept a bad restatement, your understanding is shallower than you thought.
**Reveals:** Whether your mental model matches theirs. Mismatches are high-signal.
**Example:** User says "We need fast search." You restate: "So sub-second response time is a hard requirement?" They might say "No, I mean the results need to be relevant, speed is fine at 2-3 seconds." Now you know it's about relevance, not latency.

### 10. Minimum Viable Test

**When:** Trying to find the core value proposition or smallest useful increment.
**How:** "What's the smallest thing we could build to know if this is on the right track?"
**Reveals:** The core value — what actually matters stripped of nice-to-haves.
**Example:** "If we could only ship one screen/endpoint/flow, which one would tell you if the whole project is worth continuing?"

## Technique Selection Guide

Pick techniques based on which confidence dimension needs work:

| Dimension | Primary Techniques | Secondary |
|---|---|---|
| Problem Understanding | Solution Stripping, Why Chain | Past Failure |
| Stakeholder Clarity | Stakeholder Lens, Restatement Challenge | Constraint Removal |
| Outcome Vision | Minimum Viable Test, Inversion | Restatement Challenge |
| Scope Boundaries | Negative Space, Forced Tradeoff | Constraint Removal |
| Constraint Awareness | Constraint Removal, Past Failure | Stakeholder Lens |
| Priority Alignment | Forced Tradeoff, Inversion | Minimum Viable Test |
| Risk Awareness | Inversion, Past Failure | Stakeholder Lens |

## Anti-Patterns

### Do NOT:
- **Ask what they already told you.** Track what's been said. Rephrase to validate, don't re-ask.
- **Ask generic setup questions.** "Tell me about your project" is lazy. Frame a hypothesis and validate it.
- **Accept the first answer.** The first answer is what they think you want to hear. The third answer is closer to truth.
- **Interrogate.** This is a conversation, not a deposition. Probing is done with genuine curiosity, not suspicion.
- **Ask more than 3 questions per round.** Cognitive load kills honesty. 1-2 high-value questions per round is ideal.
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
