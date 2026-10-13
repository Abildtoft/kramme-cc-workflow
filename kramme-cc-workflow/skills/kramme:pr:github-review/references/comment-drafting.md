# Drafting and humanizing review comments

Load this reference after review findings and the existing conversation map are complete.

## 1. Draft findings

Sort findings into **Blocking**, **Important**, **Suggestions / Nits**, **Questions for the author**, and **Strengths**. Anchor each actionable finding to a concrete `path:line`. Drop or label claims the diff cannot prove with `UNVERIFIED` (plausible but not traced) or `NOTICED BUT NOT TOUCHING` (pre-existing).

Dedupe against the conversation. Do not draft a fresh comment when an existing thread already raises the same root concern. Move it to **Already Raised** with its author and state. If new evidence materially extends the concern, draft a reply to the existing thread instead of another top-level comment.

For every actionable finding, keep the full trace or reasoning in `Evidence` and put only the author-facing prose in `Draft comment`. The author reads that prose next to the anchored line and the few diff lines just above it, often later and without your trace. Apply these rules:

- **Make the comment stand on its own.** If the concern depends on code outside that view, such as a caller, a callee, another file, a branch further up or down, or behavior the diff removed, name that code explicitly by file and symbol. Add `path:line` when the symbol alone is ambiguous. Do not use "this", "here", "it", "above", or "the other check" for anything the author cannot see at the anchor.
- **Anchor where the fix belongs.** When a concern spans two locations, anchor on the changed line where the author would make the fix and name the other location in the comment. If the fix belongs in code outside the diff, anchor on the changed line that introduces the problem and name the fix location by file and symbol.
- **Say concretely what goes wrong.** Name the input, state, or sequence that triggers the problem and the result the author would see. Use plain words, not just a category label such as "race condition" or "leak".
- **Sound like a person, not a report.** Use plain, natural reviewer language without finding structure, severity labels, or bullet lists inside the comment.
- **Lead with a question, not a verdict.** Prefer a Socratic question that lets the author inspect the concern over a demand. The question must carry enough context to be answerable: ask "what happens when `items` is empty?", not "is this right?"
- **Keep the trace out and the context in.** Leave the full trace, reproduction, and reasoning in `Evidence`. Include the one or two facts the author needs to see the concern without opening your report.
- **Calibrate confidence.** State traced failures plainly but politely. Phrase `UNVERIFIED` concerns as questions or with an explicit hedge.
- **Be brief, not cryptic.** Usually write one to three sentences with one concern per comment, and no preamble, padding, AI attribution, or meta-process text.
- **Keep comments actionable.** Preserve necessary function, file, and variable names plus a useful direction.
- **Keep tone independent of severity.** Blocking comments remain concise questions or statements, not demands.

Before finalizing, run a cold-read check on each draft. Reread it as if you could see only that view. If the author would have to ask "which one?", "where?", or "why does that matter?", add the missing reference or consequence. Record the outside code each comment depends on in the report's `Refers to` field. Use `—` when the comment is fully explained by its anchor.

Keep genuine `Strengths` in the local report only; never post them as a GitHub review body, and give each anchored question its own `Draft comment` body so it is eligible with the other inline comments.

## 2. Draft replies and recommend a verdict

For each thread that needs input, draft a concise reply grounded in its live-tree verification:

- `awaiting-you` / `author-responded` — lead with where you land. For `addressed`, name what changed and note you would resolve it. For `still-open`, ask about the remaining behavior. For `cant-tell`, answer directly or ask the one question that would settle it.
- `peer-comment` — reply only to add material value; otherwise surface it for awareness.
- `your-open` — surface it without redrafting.
- `new-from-others` — surface it; reply only when it asks something of you.

Name the code you actually read. When the change landed somewhere other than the thread's anchor, or the anchor is outdated, give the file and symbol or `path:line` so the author does not have to guess.

Do not draft acknowledgement-only replies. Recommend:

- `REQUEST CHANGES` for Blocking findings or unresolved Blocking threads you opened.
- `COMMENT` when no Blocking finding remains but Important findings, open questions, or threads awaiting you remain.
- `APPROVE` when no Blocking or Important findings or unresolved concerns you raised remain, and the change improves code health.

For ongoing reviews, let verified thread outcomes affect the recommendation. Always state it as a recommendation with one-line rationale; the user chooses and posts the verdict.

## 3. Humanize safely

Run draft comment and reply bodies through `/kramme:text:humanize` in one batch before writing the report. Send only the prose bodies, separated by stable item indexes, as raw text; paths and identifiers inside bodies are prose, not files to read. Do not send report metadata such as `Location`, `Refers to`, snippets, finding IDs, reviewer quotes, or evidence. Identifiers and code references inside a body stay in that body and must come back unchanged.

Map results back by index. If the count differs or a mapping is ambiguous, retain the original body. Accept humanized text only when it preserves question framing, confidence, factual claims, `UNVERIFIED` hedges, necessary identifiers, explicit references to code outside the anchor (never swapped for a vague pointer such as "this" or "the other function"), the consequence the comment states, and no added length. Mark accepted items `Humanized: yes`; otherwise keep the original and mark `Humanized: no`.
