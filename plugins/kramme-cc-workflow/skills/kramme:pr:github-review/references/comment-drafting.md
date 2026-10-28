# Drafting and humanizing review comments

Load this reference after review findings and the existing conversation map are complete.

## 1. Draft findings

Sort findings into **Blocking**, **Important**, **Suggestions / Nits**, **Questions for the author**, and **Strengths**. Anchor each actionable finding to a concrete `path:line`. Drop or label claims the diff cannot prove with `UNVERIFIED` (plausible but not traced) or `NOTICED BUT NOT TOUCHING` (pre-existing).

Dedupe against the conversation. Do not draft a fresh comment when an existing thread already raises the same root concern. Move it to **Already Raised** with its author and state. If new evidence materially extends the concern, draft a reply to the existing thread instead of another top-level comment.

For every actionable finding, keep the full trace or reasoning in `Evidence` and put only the author-facing prose in `Draft comment`. The author reads that prose next to the anchored line and the few diff lines just above it, often later and without your trace. Apply these rules:

- **Make the comment stand on its own.** If the concern depends on code outside that view, such as a caller, a callee, another file, a branch further up or down, or behavior the diff removed, name that code explicitly by file and symbol. Add `path:line` when the symbol alone is ambiguous. Do not use "this", "here", "it", "above", or "the other check" for anything the author cannot see at the anchor. GitHub shows no lines below the anchor either, so when a pointer such as "this message" refers to code below it, move the anchor to that line or name the code.
- **Anchor where the fix belongs.** When a concern spans two locations, anchor on the changed line where the author would make the fix and name the other location in the comment. If the fix belongs in code outside the diff, anchor on the changed line that introduces the problem and name the fix location by file and symbol.
- **Say concretely what goes wrong.** Name the input, state, or sequence that triggers the problem and the result the author would see. Use plain words, not just a category label such as "race condition" or "leak".
- **Use the code's and ticket's words, not your own labels.** Do not invent names for categories or test suites. Say "a call for a missing user", "this file", "the service unit spec". Name the exact prop, string, or key the comment is about: `emptyLabel`, not "the placeholder".
- **Sound like a person, not a report.** Use plain, natural reviewer language without finding structure, severity labels, or bullet lists inside the comment. Many authors read English as a second language, so avoid idioms and phrasal verbs such as "keep in step", "drop back", or "could go".
- **Context first, ask last.** Open with one plain sentence saying what's wrong: what the ticket or code expects, and what is missing or broken. Then give the reasons, and end with the ask as a question, in its own paragraph when more than one sentence comes before it. The question must still be answerable on its own: "what happens when `items` is empty?", not "is this right?" A comment that is one question naming the trigger and the result needs no opening sentence.
- **Make the ask concrete.** When you ask for a test or a change, name the setup and each expected result: "sets `deletedAt` on `sameOrganisationUserId` and expects `deleteAllClaimsForUser` to return `false`, keep the claim and write no audit entry". When the ask removes code, say what stays, so no reading of the comment leads the author to delete code that must remain.
- **Keep the trace out and the context in.** Leave the full trace, reproduction, and reasoning in `Evidence`. Include the one or two facts the author needs to see the concern without opening your report. Finding and requirement IDs such as `CR-001` or `ENG-217/LREQ-001` mean nothing to the author, so keep them in `Evidence`; naming the Linear issue a comment cites is fine.
- **Calibrate confidence.** State traced failures plainly but politely. Phrase `UNVERIFIED` concerns as questions or with an explicit hedge.
- **Claim only what ran.** When a comment says a test would still pass, or would fail, under some change, make that change in a disposable checkout of `HEAD_OID`, run the affected specs, revert it, and word the claim to exactly what ran. A fresh worktree usually has no installed dependencies, so the user's checkout at `ORIG_ROOT` may stand in, but only when it has no tracked changes and its `HEAD` is `HEAD_OID`; after reverting there, confirm `git status` shows no tracked changes. If neither can run the specs, do not claim the result.
- **Short sentences, one concern.** One point per sentence and one concern per comment. Split a comment that asks for changes in two files, and anchor each part where its fix belongs. No preamble, padding, AI attribution, or meta-process text.
- **Keep comments actionable.** Preserve necessary function, file, and variable names plus a useful direction.
- **Keep tone independent of severity.** Blocking comments remain concise questions or statements, not demands.

Before finalizing, run a cold-read check on each draft. Reread it as if you could see only that view. If the author would have to ask "which one?", "where?", or "why does that matter?", add the missing reference or consequence. Could the author tell what's wrong before reaching the ask? If not, move the problem statement to the front. Record the outside code each comment depends on in the report's `Refers to` field. Use `—` when the comment is fully explained by its anchor.

Keep genuine `Strengths` in the local report only; never post them as a GitHub review body, and give each anchored question its own `Draft comment` body so it is eligible with the other inline comments.

### Worked example

First draft:

> Could we add a case like this one for a soft-deleted target user? SER-1574 says a missing-user call deletes nothing, and soft-deleting a user leaves their `license_claim` rows in place, so the only guard is `isNull(userTable.deletedAt)` in `hardDeleteAllClaimsForUserInOrganisation` (license-claim.repo.ts). I removed that line locally and every test in the dal and service suites, this file included, still passed. Setting `deletedAt` on `sameOrganisationUserId` and expecting `false`, one claim left and no audit row would catch it.

Rewrite:

> SER-1574 says a call for a missing user should delete nothing, but no test checks that for a soft-deleted user. Soft-deleting a user keeps their `license_claim` rows, so the only thing stopping the delete is `isNull(userTable.deletedAt)` in `hardDeleteAllClaimsForUserInOrganisation` (license-claim.repo.ts). I removed that line locally, and every test in this file, the service unit spec and the repo spec still passed.
>
> Could you add a test like this one that sets `deletedAt` on `sameOrganisationUserId` and expects `deleteAllClaimsForUser` to return `false`, keep the claim and write no audit entry?

The first draft asks before the author knows what's wrong, only implies that no test covers the case, chains the requirement, the surviving rows, and the only guard into one sentence, and uses made-up labels ("missing-user call", "the dal and service suites"). The rewrite fixes each, and its third sentence reports exactly the specs that ran. Both have four sentences; the rewrite is 13% longer, so order and density made the difference, not length.

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

Apply the linked-issue coverage gate from `references/linear-review.md`: incomplete discovery or an incomplete/blocked in-scope Linear audit prevents `APPROVE`. Recommend `COMMENT` with the precise gap unless proven Blocking findings require `REQUEST CHANGES`. Cite Linear requirements in issue-derived comments, and keep verification gaps as questions rather than claiming defects.

For ongoing reviews, let verified thread outcomes affect the recommendation. Always state it as a recommendation with one-line rationale; the user chooses and posts the verdict.

Draft `PREPARED_REVIEW_BODY`: one to three plain sentences addressed to the author that say where the review lands and point to the inline comments, for example "A few questions inline, mainly about the empty-list case in `parseItems()`. The rest looks good to me." Leave out Strengths lists, Evidence, finding or requirement IDs, coverage notes, and the verdict label, because the user picks the event when they confirm. The body stays in the local report and the pending review never carries it; it is posted only by a confirmed Step 14 submission.

## 3. Humanize safely

Run draft comment and reply bodies and `PREPARED_REVIEW_BODY` through `$kramme:text:clarify --humanize` in one batch before writing the report. Send only the prose bodies, separated by stable item indexes, as raw text; paths and identifiers inside bodies are prose, not files to read. Do not send report metadata such as `Location`, `Refers to`, snippets, finding IDs, reviewer quotes, or evidence. Identifiers and code references inside a body stay in that body and must come back unchanged.

Map results back by index. If the count differs or a mapping is ambiguous, retain the original body. Apply accepted wording to your own copy of each body; never copy a body back from the skill's echo of its input, which can carry shell escaping such as `\!!` for `!!`. Accept humanized text only when it preserves question framing, confidence, factual claims, `UNVERIFIED` hedges, necessary identifiers, explicit references to code outside the anchor (never swapped for a vague pointer such as "this" or "the other function"), the consequence the comment states, and the problem stated before the ask. Reject added length, except a modest increase from splitting a sentence or moving the ask into its own paragraph. Mark accepted items `Humanized: yes`; otherwise keep the original and mark `Humanized: no`.
