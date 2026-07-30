# Comparison Prompt

Use this prompt when a source's hash has changed since the last baseline. The goal is to surface valuable guidance that the current skill does not yet represent. The previous source body is intentionally not retained.

## Inputs to gather before prompting

- The freshly fetched, normalized content of the source.
- The full text of the target skill's current `SKILL.md`.
- The source's `rationale` field from `sources.yaml` (what the skill derives from this source).

## Prompt

> You are auditing the plugin skill `<SKILL_NAME>` against an upstream source of inspiration that has changed since the last review.
>
> **Source rationale (what the skill derives from this source):**
>
> > <RATIONALE>
>
> Two documents follow:
>
> 1. `CURRENT_SOURCE` — the source content as it is now.
> 2. `CURRENT_SKILL_MD` — the skill's current `SKILL.md`.
>
> The stored hash proves the source changed since the last review, but the previous source body was deliberately not retained. Identify content in `CURRENT_SOURCE` that is:
>
> 1. **Not already represented** in `CURRENT_SKILL_MD`; and
> 2. **Valuable to add** given the source's rationale.
>
> Ignore: cosmetic edits, navigation/footer changes, version bumps in unrelated examples, dead links being fixed, prose polish, and content unrelated to the rationale.
>
> Copyright boundary: write every suggestion in original words. Do not quote, closely paraphrase, or reproduce source prose, code, examples, tables, or distinctive phrasing. Name the relevant source heading or link so a maintainer can verify the suggestion at the source.
>
> Output strictly in this format:
>
> ```
> ## Suggestion summary
> <One paragraph (≤3 sentences) describing the change and why it matters for this skill. If nothing is actionable, write exactly "Nothing actionable." and stop.>
>
> ## Specific additions
> 1. <Concrete addition #1 — what to add to SKILL.md, ideally with a target section.>
>    - Source location: <heading or link, without an excerpt>
> 2. <Concrete addition #2…>
>
> ## Notes
> <Optional. Caveats, conflicts with current SKILL.md content, or open questions.>
> ```
>
> Be concrete. "The source has a new section on X" is not useful — say what guidance, rule, example, or constraint should be added and where, using original wording.
>
> If the source changed only in ways that are already represented or unrelated to the rationale, output "Nothing actionable."

## After the model responds

- Capture the model's original response into the report under the per-skill section for this source. Reject and regenerate any response that reproduces source passages.
- Do not auto-edit `SKILL.md` — that's the user's call after reading the report.
