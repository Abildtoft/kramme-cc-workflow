# Comparison Prompt

Use this prompt when a source's hash has changed since the last baseline. The goal is to surface *valuable additions* to the skill — not to summarize the diff.

## Inputs to gather before prompting

- The previous baseline snapshot at `<skill>/references/sources-snapshot/<id>.md` (may be empty on first audit).
- The freshly fetched, normalized content of the source.
- The full text of the target skill's current `SKILL.md`.
- The source's `rationale` field from `sources.yaml` (what the skill derives from this source).

## Prompt

> You are auditing the plugin skill `<SKILL_NAME>` against an upstream source of inspiration that has changed since the last review.
>
> **Source rationale (what the skill derives from this source):**
> > <RATIONALE>
>
> Three documents follow:
>
> 1. `PREVIOUS_SNAPSHOT` — the source content as it was when the skill was last reviewed. (May be empty if this is the first audit.)
> 2. `CURRENT_SOURCE` — the source content as it is now.
> 3. `CURRENT_SKILL_MD` — the skill's current `SKILL.md`.
>
> Your task: identify content in `CURRENT_SOURCE` that is **both**:
>
> 1. **Genuinely new or changed** relative to `PREVIOUS_SNAPSHOT` (not just rewording or reordering); and
> 2. **Valuable to add to `CURRENT_SKILL_MD`** given the source's rationale — i.e. it would improve the skill's guidance, accuracy, or coverage.
>
> Ignore: cosmetic edits, navigation/footer changes, version bumps in unrelated examples, dead links being fixed, prose polish, and content unrelated to the rationale.
>
> Output strictly in this format:
>
> ```
> ## Suggestion summary
> <One paragraph (≤3 sentences) describing the change and why it matters for this skill. If nothing is actionable, write exactly "Nothing actionable." and stop.>
>
> ## Specific additions
> 1. <Concrete addition #1 — what to add to SKILL.md, ideally with a target section.>
>    > <Verbatim excerpt from CURRENT_SOURCE supporting this addition (≤6 lines).>
> 2. <Concrete addition #2…>
>
> ## Notes
> <Optional. Caveats, conflicts with current SKILL.md content, or open questions.>
> ```
>
> Be concrete. "The source has a new section on X" is not useful — say what specific guidance, rule, example, or constraint should be added to which part of the skill, and quote the source briefly.
>
> If `PREVIOUS_SNAPSHOT` is empty, treat the entire `CURRENT_SOURCE` as new. In that case, output additions only for content that meaningfully extends the current `SKILL.md`; do not echo content that is already represented.

## After the model responds

- Capture the entire response verbatim into the report under the per-skill section for this source.
- Do not auto-edit `SKILL.md` — that's the user's call after reading the report.
