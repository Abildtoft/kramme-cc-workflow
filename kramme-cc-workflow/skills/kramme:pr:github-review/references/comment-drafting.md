# Drafting and humanizing review comments

Load this reference after review findings and the existing conversation map are complete.

## 1. Draft findings

Sort findings into **Blocking**, **Important**, **Suggestions / Nits**, **Questions for the author**, and **Strengths**. Anchor each actionable finding to a concrete `path:line`. Drop or label claims the diff cannot prove with `UNVERIFIED` (plausible but not traced) or `NOTICED BUT NOT TOUCHING` (pre-existing).

Dedupe against the conversation. Do not draft a fresh comment when an existing thread already raises the same root concern. Move it to **Already Raised** with its author and state. If new evidence materially extends the concern, draft a reply to the existing thread instead of another top-level comment.

For every actionable finding, keep the full trace or reasoning in `Evidence` and put only the author-facing prose in `Draft comment`. Apply these rules:

- **Sound like a person, not a report.** Use plain, natural reviewer language without finding structure, severity labels, or bullet lists inside the comment.
- **Lead with a question, not a verdict.** Prefer a Socratic question that lets the author inspect the concern over a demand.
- **Keep evidence out of the comment.** Include only what the author needs to investigate or act, usually a question and the relevant identifier.
- **Calibrate confidence.** State traced failures plainly but politely. Phrase `UNVERIFIED` concerns as questions or with an explicit hedge.
- **Be brief and focused.** Use one or two sentences, one concern per comment, and no preamble, padding, AI attribution, or meta-process text.
- **Keep comments actionable.** Preserve necessary function, file, and variable names plus a useful direction.
- **Keep tone independent of severity.** Blocking comments remain concise questions or statements, not demands.

Keep genuine `Strengths` in the local report only; never post them as a GitHub review body, and give each anchored question its own `Draft comment` body so it is eligible with the other inline comments.

## 2. Draft replies and recommend a verdict

For each thread that needs input, draft a concise reply grounded in its live-tree verification:

- `awaiting-you` / `author-responded` — lead with where you land. For `addressed`, name what changed and note you would resolve it. For `still-open`, ask about the remaining behavior. For `cant-tell`, answer directly or ask the one question that would settle it.
- `peer-comment` — reply only to add material value; otherwise surface it for awareness.
- `your-open` — surface it without redrafting.
- `new-from-others` — surface it; reply only when it asks something of you.

Do not draft acknowledgement-only replies. Recommend:

- `REQUEST CHANGES` for Blocking findings or unresolved Blocking threads you opened.
- `COMMENT` when no Blocking finding remains but Important findings, open questions, or threads awaiting you remain.
- `APPROVE` when no Blocking or Important findings or unresolved concerns you raised remain, and the change improves code health.

For ongoing reviews, let verified thread outcomes affect the recommendation. Always state it as a recommendation with one-line rationale; the user chooses and posts the verdict.

## 3. Humanize safely

Run draft comment and reply bodies through `/kramme:text:humanize` in one batch before writing the report. Send only the prose bodies, separated by stable item indexes. Do not send file paths, line numbers, snippets, finding IDs, reviewer quotes, or evidence.

Map results back by index. If the count differs or a mapping is ambiguous, retain the original body. Accept humanized text only when it preserves question framing, confidence, factual claims, `UNVERIFIED` hedges, necessary identifiers, and brevity. Mark accepted items `Humanized: yes`; otherwise keep the original and mark `Humanized: no`.
