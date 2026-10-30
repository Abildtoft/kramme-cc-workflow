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
- **Problem first, ask last.** Open with one plain sentence that says what's wrong, as its own paragraph. State the conclusion, not the evidence that leads to it, and use at most one code identifier: "If I understand correctly, this test doesn't check what its name says.", not "This test is named X, but this assertion compares `a` with `B`." A reader who stops after that sentence should know what's wrong. Then give the reasons in a short paragraph of at most four sentences, each making one point. When it isn't obvious why the problem matters, explain that in its own short paragraph. End with the ask as a question in its own paragraph. The question must still be answerable on its own: "what happens when `items` is empty?", not "is this right?" A comment that is one question naming the trigger and the result needs no opening sentence.
- **Hedge a little, so the comment invites a reply.** Open the problem sentence with one light lead-in, such as "If I understand correctly,", "Based on my reading of the code," or "It looks like". Phrase the ask as an open question, such as "Could you…?" or "Would it make sense to…?" Hedge with the lead-in only, and keep the claim itself plain: "If I understand correctly, `parseItems()` drops empty rows", not "`parseItems()` might drop some empty rows". Add no other hedges, such as "may", "in practice", or "could matter", to the facts. State results you ran without a hedge. Phrase `UNVERIFIED` concerns as questions.
- **Make the ask concrete.** When you ask for a test or a change, name the setup and each expected result: "sets `deletedAt` on `sameOrganisationUserId` and expects `deleteAllClaimsForUser` to return `false`, keep the claim and write no audit entry". When the ask removes code, say what stays, so no reading of the comment leads the author to delete code that must remain.
- **Keep the trace out and the context in.** Leave the full trace, reproduction, and reasoning in `Evidence`. Include only the facts the author needs to see the problem and act on it. Facts the concern does not depend on belong in `Evidence` too, such as commit titles, the files where a value is read, exact counts, and a full file name when a number already identifies the file, as "ADR 0010" does. Finding and requirement IDs such as `CR-001` or `ENG-217/LREQ-001` mean nothing to the author, so keep them in `Evidence`; naming the Linear issue a comment cites is fine.
- **Claim only what ran.** When a comment says a test would still pass, or would fail, under some change, make that change in a disposable checkout of `HEAD_OID`, run the affected specs, revert it, and word the claim to exactly what ran. A fresh worktree usually has no installed dependencies, so the user's checkout at `ORIG_ROOT` may stand in, but only when it has no tracked changes and its `HEAD` is `HEAD_OID`; after reverting there, confirm `git status` shows no tracked changes. If neither can run the specs, do not claim the result.
- **Short sentences, one concern.** One point per sentence and one concern per comment. Split a comment that asks for changes in two files, and anchor each part where its fix belongs. No preamble, padding, AI attribution, or meta-process text. A comment may grow a little when one dense paragraph becomes several short ones; judge density, not length.
- **Keep comments actionable.** Preserve necessary function, file, and variable names plus a useful direction.
- **Keep tone independent of severity.** Blocking comments remain concise questions or statements, not demands.

Before finalizing, run a cold-read check on each draft. Reread it as if you could see only that view. If the author would have to ask "which one?", "where?", or "why does that matter?", add the missing reference or consequence. Then run two checks that cut instead of add:

- **First-line test:** read only the first sentence. If you can't say from it what's wrong, rewrite it.
- **Fact cut:** for each fact, ask whether the author would miss it: do they need it to see the problem or act on it? If not, move it to `Evidence`.

Record the outside code each comment depends on in the report's `Refers to` field. Use `—` when the comment is fully explained by its anchor.

Keep genuine `Strengths` in the local report only; never post them as a GitHub review body, and give each anchored question its own `Draft comment` body so it is eligible with the other inline comments.

### Worked examples

First draft:

> Could we add a case like this one for a soft-deleted target user? SER-1574 says a missing-user call deletes nothing, and soft-deleting a user leaves their `license_claim` rows in place, so the only guard is `isNull(userTable.deletedAt)` in `hardDeleteAllClaimsForUserInOrganisation` (license-claim.repo.ts). I removed that line locally and every test in the dal and service suites, this file included, still passed. Setting `deletedAt` on `sameOrganisationUserId` and expecting `false`, one claim left and no audit row would catch it.

Rewrite:

> If I understand correctly, no test checks that a call for a soft-deleted user deletes nothing.
>
> SER-1574 says a call for a missing user should delete nothing. Soft-deleting a user keeps their `license_claim` rows, so the only thing stopping the delete is `isNull(userTable.deletedAt)` in `hardDeleteAllClaimsForUserInOrganisation` (license-claim.repo.ts). I removed that line locally, and every test in this file, the service unit spec and the repo spec still passed.
>
> Could you add a test like this one that sets `deletedAt` on `sameOrganisationUserId` and expects `deleteAllClaimsForUser` to return `false`, keep the claim and write no audit entry?

The first draft asks before the author knows what's wrong, only implies that no test covers the case, chains the requirement, the surviving rows, and the only guard into one sentence, and uses made-up labels ("missing-user call", "the dal and service suites"). The rewrite's first sentence names the problem with no identifiers, so an author who reads only that sentence knows what's wrong. The reasons follow in their own paragraph, which reports exactly the specs that ran.

A second pair, anchored on an assertion in a spec file:

First draft:

> This test is named "takes the values and default of %s from its definition", but this assertion compares `setting.default` with `SOAP_TEMPLATE_DEFAULT_OPTIONS`, the same constant `templateSetting` reads. `prompt-template-options.ts` declares every template default twice: as `default` on each `SOAP_TEMPLATE_OPTION_DEFINITIONS` entry, which the settings page reads (`settings-page/src/lib/utils/template-options.ts`), and in `SOAP_TEMPLATE_DEFAULT_OPTIONS`, which the SOAP prompt reads (`sandwich-soap-prompt-constructor.ts`). The two lists agree on all 13 keys today. If they ever differ, the catalogue's Default column would match the prompt but not the settings page, and nothing in this spec compares it with the definition's `default`.
>
> Could you add `expect(setting.default).toBe(String(definition.default));` to this `it.each`?

Rewrite:

> Based on my reading of the code, this test doesn't check what its name says.
>
> The name says the default comes "from its definition", but the assertion compares it with `SOAP_TEMPLATE_DEFAULT_OPTIONS`. That is the same constant the catalogue reads, so the test compares the catalogue with its own source.
>
> This matters because `prompt-template-options.ts` declares each template default twice: on each `SOAP_TEMPLATE_OPTION_DEFINITIONS` entry, which the settings page uses, and in `SOAP_TEMPLATE_DEFAULT_OPTIONS`, which the SOAP prompt uses. They match today. I changed the `planVerbosity` default in `SOAP_TEMPLATE_OPTION_DEFINITIONS` only, and all three catalogue specs still passed.
>
> Could you add `expect(setting.default).toBe(String(definition.default));` to this `it.each`? With that line, my change fails the `planVerbosity` case, and the test still passes on the current code.

The first draft opens with the test's full name and three identifiers, and leaves the author to work out that the test compares the catalogue with its own source. In the rewrite, each paragraph has one job: the problem, what the test does, why that matters, and the ask. The fact cut moved the two file paths that only show where each list is read, and "all 13 keys", to `Evidence`, and a test run replaced the draft's guess about what would happen if the lists differed. Both rewrites are longer than their drafts but far less dense: judge density, not length.

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

For ongoing reviews, let verified thread outcomes affect the recommendation. A delta review's fresh findings cover only the commits after `REVIEW_BASE`. With `REVIEW_SCOPE=unchanged` there are no fresh code findings, so the recommendation rests on your open threads, their live verification, and the Linear results, and its rationale says that no code in this PR changed since your last review. Always state it as a recommendation with one-line rationale; the user chooses and posts the verdict.

Draft `PREPARED_REVIEW_BODY`: one to three plain sentences addressed to the author that say where the review lands and point to the inline comments, for example "A few questions inline, mainly about the empty-list case in `parseItems()`. The rest looks good to me." Leave out Strengths lists, Evidence, finding or requirement IDs, coverage notes, and the verdict label, because the user picks the event when they confirm. The body stays in the local report and the pending review never carries it; it is posted only by a confirmed Step 14 submission.

## 3. Humanize safely

Run draft comment and reply bodies and `PREPARED_REVIEW_BODY` through `/kramme:text:clarify --humanize` in one batch before writing the report. Send only the prose bodies, separated by stable item indexes, as raw text; paths and identifiers inside bodies are prose, not files to read. Do not send report metadata such as `Location`, `Refers to`, snippets, finding IDs, reviewer quotes, or evidence. Identifiers and code references inside a body stay in that body and must come back unchanged. Say in the request that each comment's paragraph breaks and the lead-in on its first sentence, such as "If I understand correctly,", are deliberate and must stay.

Map results back by index. If the count differs or a mapping is ambiguous, retain the original body. Apply accepted wording to your own copy of each body; never copy a body back from the skill's echo of its input, which can carry shell escaping such as `\!!` for `!!`. Accept humanized text only when it preserves question framing, confidence, factual claims, `UNVERIFIED` hedges, necessary identifiers, explicit references to code outside the anchor (never swapped for a vague pointer such as "this" or "the other function"), the consequence the comment states, and the problem sentence as its own first paragraph with its lead-in. Judge density, not length: reject text that adds a fact or claim, or gives a sentence more identifiers than the densest sentence of the original. Growth from splitting sentences or paragraphs is fine. Mark accepted items `Humanized: yes`; otherwise keep the original and mark `Humanized: no`.
