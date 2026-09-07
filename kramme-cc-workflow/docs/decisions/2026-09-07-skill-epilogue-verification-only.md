# Skill Epilogue Keeps a Trimmed Verification Section Only

- Status: ACCEPTED
- Date: 2026-09-07
- Deciders: repository maintainers

## Context

Skills ported from `addyosmani/agent-skills` adopted two upstream conventions on 2026-04-20: the output-marker vocabulary (`SIMPLICITY CHECK`, `NOTICED BUT NOT TOUCHING`, `UNVERIFIED`, and similar) and a three-section epilogue that closes each `SKILL.md` with `## Common Rationalizations`, `## Red Flags`, and `## Verification`. By 2026-09-07 sixteen shipped skills carried the full epilogue in `SKILL.md`, three more carried a `Red Flags` section alone, and two (`kramme:qa`, `kramme:pr:generate-description`) delegated it to a reference file. The `epilogue_order` lint check enforced that the three headings appeared together and in order whenever the first one was present.

An audit of every skill on 2026-09-07 against current-model instruction practice found that the epilogue is almost entirely a second and third copy of rules already stated in the skill body. In `kramme:pr:rebase`, for example, every one of the eleven Verification checkboxes maps to an earlier step, and the Rationalizations bullets restate the same rules a third time as rebuttals to objections. The sections were written for models that skipped steps, rationalized their way past gates, or lost the top of the file by the time they reached the final action. Those failure modes no longer justify the cost:

- Roughly forty lines per skill are loaded on every invocation without adding a rule.
- Repeating every rule with equal emphasis flattens the hierarchy that tells the model which gates are actually dangerous, such as force-pushing to a protected branch or writing to an external tracker.
- A handful of Red Flags bullets carry facts that appear nowhere else, such as "migration files and generated artifacts are unsafe to auto-resolve". Those facts are useful but are buried among restatements.

The output markers are unaffected. They are a parsed contract for downstream tooling and remain plugin-wide.

## Decision

- Remove `## Common Rationalizations` and `## Red Flags` from every shipped `SKILL.md`, and from any reference file a `SKILL.md` instructs the model to apply as its epilogue.
- Keep `## Verification` only as a short done-specification containing items that are not already stated as a step or rule in the body: artifact and output contracts, consumer expectations, and test-pinned sentences. If nothing survives that filter, remove the section.
- Fold any fact or gate from a removed section that the body does not already state into the step where the model would apply it, as a plain sentence in the surrounding style, never as a reconstituted list. Test-pinned sentences are relocated verbatim even when that forces a short nested list.
- New Addy ports follow the same shape: adopt the output markers, do not adopt the three-section epilogue.
- Replace the `epilogue_order` lint check with `epilogue_forbidden`, which fails when a `Common Rationalizations` or `Red Flags` heading appears in any shipped `SKILL.md`. The Verification filter is applied by review judgment; no lint inspects that section's contents.

## Scope and follow-up

The lint covers `SKILL.md` files only. Five reference files still contain checklist material under the retired headings and are loaded by their skill as a final checklist rather than named as an epilogue: `kramme:pr:code-review/references/review-discipline.md`, `kramme:code:breakdown-findings/references/generation-checks.md`, `kramme:discovery:interview/references/interview-operations.md`, `kramme:siw:generate-phases/references/quality-gates.md`, and `kramme:siw:discovery/references/synthesis-checklist.md`. They fall under the same rule and are the next pass; until then they are the only remaining carriers.

## Consequences

- Each affected skill loses roughly forty lines of restatement; the real gates become easier to see because they are stated once, where they apply.
- `AGENTS.md`, the root `README.md` credits, the affected `sources.yaml` rationales, and the maintainer memory note that told authors to end Addy ports with the three-section epilogue are updated to the single trimmed Verification section.
- Tests that pin sentences from a removed section keep those sentences by relocation rather than deletion, so no test contract changes as part of this decision beyond the lint check's own fixtures.

## Alternatives Considered

### Keep all three sections

Rejected. The audit showed they triplicate body rules and provide no enforcement a current model needs.

### Delete all three sections

Rejected. A short list of contract items that are stated nowhere else is a useful final check for the model, and a few skills have consumers that depend on those items being called out.

### Decide per skill whether to keep the three-section epilogue

Rejected. Whether a given Verification item survives is a per-skill judgment, but whether the Rationalizations and Red Flags sections exist at all is a plugin-wide shape question. Mixed shapes across skills would be harder to maintain, harder to lint, and would keep the retired convention alive as a template for new ports.
