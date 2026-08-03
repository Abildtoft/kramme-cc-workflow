---
name: kramme:text:clarify
description: "Rewrites prose so readers can understand and act on it quickly by front-loading the outcome, improving structure, and using concrete active language while preserving technical meaning. Use for reports, guidance, documentation, research notes, and summaries that need plain-language editing. Not for removing AI-writing patterns, marketing voice, code, quoted or legal text, or content that must remain verbatim."
argument-hint: "[file-path or text]"
disable-model-invocation: false
user-invocable: true
---

# Clarify Prose

Rewrite prose around the reader's task without reducing its substance, precision, or uncertainty. This skill improves comprehension and actionability; it does not judge whether writing sounds AI-generated or impose a new personality on the author.

## Boundaries

- **Does:** Reorder and rewrite reports, guidance, documentation, research notes, and summaries so their purpose, conclusion, or required action is clear early.
- **Does:** Preserve facts, qualifications, citations, technical terms, and the source's intended tone.
- **Does not:** Add unsupported facts, remove necessary nuance, invent an audience, or convert neutral prose into marketing copy.
- **Does not:** Rewrite source code, configuration, attributed quotations, legal or contractual language, exact interface labels, or other text that must remain verbatim.
- **Does not:** Treat vocabulary as forbidden. Prefer a simpler term only when it remains equally accurate.

## Input Handling

- Treat `$ARGUMENTS` as one existing file path or one block of raw text.
- If the argument resolves to a file, read the complete file before editing it.
- Treat a nonexistent argument as a path only when the complete single-line value is path-shaped, such as `notes/report.md` or `C:\notes\report.txt`. Multiline input, URLs, and sentences that merely contain slashes, backslashes, filenames, or prose extensions are raw text.
- If a complete single-line value could reasonably be either a missing path or prose, ask one focused disambiguation question instead of guessing.
- If no argument is present, use a single unambiguous prose passage from the conversation. Otherwise ask for a file path or the text to clarify.
- If the input is binary, structured data, source code, configuration, or mostly protected content, stop and explain why this skill cannot safely rewrite it. Suggest converting a document to Markdown first when appropriate.

## Workflow

1. **Establish the reader contract.**
   - Identify the intended reader and what they need to understand, decide, or do.
   - Identify the facts, constraints, uncertainty, tone, and required document structure that must survive the rewrite.
   - Infer the reader contract only when the input makes it clear. If different reasonable interpretations would materially change the rewrite, ask one focused question before continuing.

2. **Protect exact content.**
   - Mark quotations, citations, code blocks, inline code, URLs, link destinations, commands, paths, API names, exact interface labels, legal language, and required template headings as protected.
   - Preserve domain terminology when replacing it would reduce precision. Explain unfamiliar terms at first use when the source supports an explanation.

3. **Load the editing rubric.**
   - Read the plain-language rubric from `references/plain-language-rubric.md`.
   - Apply its priorities and genre guidance to the reader contract. Do not import locale-specific spelling, date, currency, or number conventions unless the user requests them.

4. **Restructure by reader value.**
   - Put the required action, conclusion, outcome, or answer before supporting background.
   - Order sections, paragraphs, and sentences by what the reader needs next rather than by the order in which the author discovered the information.
   - Remove repetition and throat-clearing only when doing so loses no meaning, evidence, qualification, or traceability.

5. **Rewrite for first-read comprehension.**
   - Use concrete subjects and active constructions when responsibility is known and relevant.
   - Prefer familiar, direct wording when it is equally accurate.
   - Give each sentence and paragraph one dominant job, but keep related qualifiers with the claim they constrain.
   - Vary sentence length naturally. Treat a long or nested sentence as a review signal, not an automatic failure.
   - Preserve the author's professional, casual, or technical tone. Do not add humor, enthusiasm, certainty, or opinions.

6. **Make the structure scannable.**
   - Use descriptive sentence-case headings when headings help navigation.
   - Use bullets for genuinely parallel items and numbered lists only for ordered actions.
   - Use descriptive link text while preserving every original destination.
   - Preserve required templates, tables, code formatting, and project-specific conventions.

7. **Validate the rewrite.**
   - Confirm that the opening states the point or next action a reader needs.
   - Compare the rewrite with the source for lost facts, altered uncertainty, unsupported claims, citation drift, changed technical meaning, and modified protected content.
   - Confirm that every heading and paragraph helps the reader understand, decide, or act.
   - Cut remaining words only when the result retains the same meaning and tone.

8. **Present and optionally save.**
   - Return the complete clarified text in a copy-ready block.
   - Add a short change summary only when structural edits or protected constraints would help the user review the result.
   - For file input, show the rewrite before writing. Ask whether to overwrite the source, save to a new path, or leave the result inline.
   - Before an approved write, reread the source. If it changed since Step 1, stop and ask whether to restart from the new version.
   - Never overwrite a different existing file or delete a file without explicit approval for that exact path.

## Error Handling

| Condition | Response |
| --- | --- |
| Missing or ambiguous input | Ask for one file path or prose passage. |
| Missing path | Report the exact unresolved path and stop. |
| Reader or purpose is materially ambiguous | Ask one focused question before rewriting. |
| Input is unsupported or mostly protected | Explain the boundary and leave the content unchanged. |
| Required meaning conflicts with a style preference | Preserve meaning and identify the style rule that was not applied. |
| Source file changes during review | Stop before writing and offer to restart from the new version. |
| Approved write fails | Keep the inline rewrite available and report the exact path and error. |

## Artifact Lifecycle

- **Produced by:** Step 8 updates the approved source file or creates the exact user-approved output path; otherwise the skill returns inline text only.
- **Consumed by:** The user and the workflow that owns the report, guidance, documentation, research note, or summary.
- **Refreshed by:** Re-run the skill when the source, audience, required action, or supporting facts change, then approve any new write explicitly.
- **Retired by:** The user may restore an overwritten file through its normal version history or delete or archive a separately saved rewrite. This skill never deletes artifacts.

## Source Tracking

`references/sources.yaml` records the conceptual sources behind the reader-focused workflow and rubric. Runtime use of this skill does not require network access or loading those sources.

## Output

Return the clarified text first. When useful, follow it with no more than five bullets describing material changes, preserved constraints, or unresolved ambiguity.
