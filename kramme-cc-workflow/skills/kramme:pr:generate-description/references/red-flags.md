# Common Rationalizations and Red Flags

## Common Rationalizations

Watch for these — they signal the description is about to under-serve the reviewer:

- _"The diff is small; a one-line summary is enough."_ → Small diffs still need the _why_. A one-line summary forces the reviewer to reconstruct intent from code.
- _"I'll leave `Things I didn't touch` blank because nothing comes to mind."_ → If nothing comes to mind, re-read the diff. `None` is a valid answer only after you've looked.
- _"The Linear issue covers the context — no need to restate it."_ → The PR body is read in isolation during review. Restate the essentials and link the issue.
- _"I'll fold the migration warning into the body text."_ → `Potential concerns` is a dedicated block for a reason; a buried warning is a missed warning.
- _"The tests passed, so the Test Plan can just list the commands I ran."_ → Passing commands are evidence, not reviewer/QA instructions. Add them only after manual scenarios.

## Red Flags — STOP

Pause and regenerate the description if any of these are true:

- The summary says "various changes" or "multiple improvements" without nouns.
- `Changes made` contains vague verbs like `update` or `improve` with no object.
- The body includes a "Key Files", "Files Changed", or similar section that mostly repeats the GitHub file list.
- The body includes a "Changes by Area" section whose bullets could be reconstructed from GitHub's file tree without reading the prose.
- A migration, feature-flag default, or breaking change is present in the diff but absent from `Potential concerns`.
- The Test Plan is only automated commands, or starts with commands before explaining the manual/reviewer scenarios.
- The description references spec files, conversation history, or `siw/LOG.md` (reviewers can't see them).
- An AI-attribution badge is about to land in the body.
