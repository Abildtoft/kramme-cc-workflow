---
name: kramme:learn:verify-understanding
description: Guides topic-level understanding verification for a PR, branch, feature, document, spec, design decision, bug fix, or other concrete subject. Use when the user asks to confirm, quiz, drill, teach-and-check, or verify that they understand a topic. Maintains a topic-specific checklist artifact and requires demonstrated understanding before marking the topic complete. Not for ordinary explanations without verification, end-of-session summaries, or code/test correctness checks.
argument-hint: "[topic: PR, branch, feature, document, spec, etc.]"
disable-model-invocation: true
user-invocable: true
---

# Verify Understanding

Verify that the human deeply understands a specific topic. The unit of work is the topic, not the chat session.

Use a running markdown artifact to track what the human should understand, what they have demonstrated, and which gaps remain.

## Topic Scope

Treat the invocation argument or user-provided topic as the topic. In Claude-compatible harnesses, `$ARGUMENTS` is that argument. Topics may be a PR, branch, feature, document, spec, implementation plan, bug, design decision, incident, API, module, or code path.

If no topic argument is provided, infer the topic only when the current conversation has one clear subject. If there are multiple plausible topics, ask the user to name the topic before continuing.

Derive a short slug from the topic and store the artifact at:

```text
.context/verify-understanding/<topic-slug>.md
```

If no repository root is available, use the current working directory as the root and say so. Create `.context/verify-understanding/` if needed.

Normalize the slug by lowercasing the topic, replacing each run of non-alphanumeric characters with one hyphen, trimming leading and trailing hyphens, and limiting the result to 80 characters. If the slug is empty, use `verify-understanding`. Before creating a new artifact, check `.context/verify-understanding/` for an existing artifact with the same topic title or source and continue that artifact. If the slug path exists for a different topic, append `-2`, `-3`, and so on.

This skill may create or update only the topic artifact under `.context/verify-understanding/`.

If `.context/verify-understanding/` cannot be created, is not a directory, or the artifact cannot be read or written, stop and report the exact path plus the action needed. If an existing artifact is malformed or missing expected sections, preserve all existing content and append missing required sections instead of overwriting it.

## Artifact Format

Create or update the topic artifact with this structure:

```markdown
# Verify Understanding: <Topic>

## Topic

- Source: <PR/branch/file/spec/document/link/current conversation>
- Last updated: <ISO date>

## Understanding Checklist

- [ ] Problem: <topic-specific problem statement>
- [ ] Why: <topic-specific cause, motivation, or importance>
- [ ] Solution: <topic-specific change, proposal, or argument>
- [ ] Rationale: <topic-specific reason this solution or framing was chosen>
- [ ] Design decisions: <topic-specific tradeoffs and rejected alternatives>
- [ ] Business logic: <topic-specific domain rules, invariants, and expected behavior>
- [ ] Edge cases: <topic-specific failure modes, boundaries, and confusing cases>
- [ ] Impact: <topic-specific users, systems, data, workflows, or future work affected>
- [ ] Evidence: <topic-specific code, tests, specs, docs, debugger output, or examples>

## Demonstrated Understanding

- <empty until verified>

## Gaps To Revisit

- <empty until found>

## Quiz Log

- <empty until asked>
```

When updating an existing artifact, preserve checked items, demonstrated understanding, gaps, and quiz log entries. Merge new checklist items with existing ones instead of replacing the artifact. Add or rename checklist items when the topic needs more specific coverage. Do not remove unchecked items merely because they are inconvenient.

## Evidence Safety

Do not write secrets, credentials, tokens, private customer data, raw production data, or sensitive logs into the artifact. When evidence is sensitive, summarize the relevant behavior and redact values. Only include concrete code, diffs, logs, debugger output, or external content when it is needed to verify understanding and the trust boundary is clear.

## Source Tracking

`references/sources.yaml` records provenance for the skill itself. Do not load it during normal use unless auditing the skill or updating source attribution.

## Workflow

1. **Establish the topic.** Name the topic and artifact path. Gather enough context to explain it accurately: inspect the PR/branch diff, source files, spec, document, issue, or conversation as appropriate.

2. **Build the checklist.** Replace template placeholders with topic-specific checklist items. Cover both high-level motivation and low-level mechanics, including business logic and edge cases.

3. **Ask for the human's current understanding first.** Before explaining a stage, ask the human to restate what they currently understand about that checklist area. Use this to calibrate the explanation.

4. **Fill gaps, then drill into why.** Explain only what is missing or shaky. Keep asking "why" until the human can connect cause, decision, behavior, and impact. If the human asks for a level such as ELI5, ELI14, or "explain like I'm an intern", adapt the depth without skipping correctness.

5. **Verify before advancing.** Do not move to the next checklist area until the human demonstrates understanding of the current one. Demonstration can be a restatement, comparison, prediction, code walkthrough, debugger observation, or answer to an open-ended question.

6. **Quiz when useful.** Use open-ended questions for reasoning and multiple-choice questions for discriminating similar concepts. When asking multiple choice, vary the position of the correct answer and do not reveal the answer until the human has answered.

7. **Use concrete artifacts.** Show code, diffs, specs, diagrams, examples, debugger steps, logs, or tests when abstractions are not enough. Tie every concrete artifact back to the checklist item it proves or clarifies.

8. **Update the artifact incrementally.** After each verified area, mark the checklist item complete and add a concise note under `Demonstrated Understanding`. If the human struggles, add the gap under `Gaps To Revisit` and continue teaching that area.

9. **Complete only after demonstration.** Do not mark the topic complete, close the workflow, or claim the human understands until every checklist item has evidence in `Demonstrated Understanding`.

## Question Patterns

Use prompts like these, adapted to the topic:

- "Before I explain, restate what you think the problem is and why it mattered."
- "What would break if this edge case were handled differently?"
- "Why was this design chosen instead of the obvious alternative?"
- "Trace this input through the code path and predict the output."
- "Which of these statements is true, and why?"
- "What impact would this change have on users, data, or future work?"

## Completion Report

When every checklist item is verified, report:

- The topic and artifact path
- The checklist items verified
- Any remaining caveats or areas that should be revisited later

If verification stops early, report the unchecked items and the next question or exercise that should continue the topic.
