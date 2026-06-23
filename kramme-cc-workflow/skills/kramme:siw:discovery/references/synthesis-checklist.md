# Synthesis Checklist

Apply this before writing the brief, strengthening plan, or final hand-off.

## Output Quality Bar

Every finding must be:

- Tied to a specific confidence dimension.
- Grounded in something the user said: quote or paraphrase.
- Actionable: either a decision made or a question that needs answering.
- Clear about stated want versus actual want when they diverge.

Do not finish with generic advice like "improve clarity" or "add more detail." If you cannot point to a specific gap grounded in the interview, it is not a real finding.

## Common Rationalizations

- _"Confidence is high enough to stop."_ High confidence means nothing if it is high on the wrong dimensions. Re-check which dimensions are Critical for the current Work Context before stopping.
- _"The user agreed with my hypothesis, so we're aligned."_ Agreement is cheap. Restatement Challenge is cheaper than re-doing the project. Verify at least once mid-interview.
- _"I asked three good questions, so the interview is done."_ Question count is not coverage. Check the evidence ledger and keep going until the active dimensions have direct validation and probes.
- _"Stated and actual wants are the same here."_ They rarely are. If you have not surfaced any divergence by round 4, you probably have not probed hard enough.
- _"The spec covers it, so the dimension is Confident."_ A section can exist and still be vague. Score on specificity and actionability, not presence.

## Red Flags

- The user answers every question with "yes, that's right" and never corrects you. Likely you're asking leading questions or they're deferring. Force a tradeoff.
- You're about to write the brief and can't quote a single surprising thing the user said. The interview didn't do its job.
- You're about to synthesize after one question batch. Unless the user stopped you, that is almost always a coverage failure.
- You're defaulting a dimension to a guess instead of asking. Emit `MISSING REQUIREMENT:` and ask.
- The "What You Don't Want" list is empty or has no rationales. Non-goals without reasons become scope creep later.
- You're continuing past round 10 without a signal that anything new will surface. Suggest stopping.

## Verification

Before writing the brief or strengthening plan, confirm:

- [ ] All critical dimensions reached Confident; all normal dimensions reached High; all deprioritized dimensions reached Medium.
- [ ] The coverage ledger floor is complete, or uncovered items are preserved as `MISSING REQUIREMENT:`.
- [ ] Stated-vs-actual divergence was either surfaced and documented, or explicitly ruled out during the interview.
- [ ] The interview included a forced tradeoff, negative-space probe, and restatement challenge unless the user stopped early.
- [ ] Every entry in "What You Don't Want" has a rationale.
- [ ] Every unanswered dimension in the output carries a `MISSING REQUIREMENT:` marker, not a fabricated answer.
- [ ] The `PLAN:` marker is present at hand-off.
