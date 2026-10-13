# Regeneration Triggers

## Regeneration Triggers

Pause and regenerate the description if any of these are true:

- The summary says "various changes" or "multiple improvements" without nouns.
- The Summary says what changed but not why, or it lacks the pointer sentence for a breaking change, required rollout steps, or a departure from the linked issue.
- A `## Changes` bullet uses vague verbs like `update` or `improve` with no object, or crams the details of several changes into one bullet.
- `## Changes` has more than ten bullets, or the Test plan more than eight scenarios, when grouping by theme or combining and sampling scenarios would say the same.
- The same claim appears in multiple sections without adding new context, risk, rationale, or test value, or one section points to another instead of stating its own fact.
- A section in the default structure says only "None", "N/A", or "Not applicable", or the body keeps a screenshots placeholder for a change with no visible UI.
- The body includes a "Key Files", "Files Changed", or similar section that mostly repeats the GitHub file list.
- The body includes a "Changes by Area" section whose bullets could be reconstructed from GitHub's file tree without reading the prose.
- A migration, feature-flag default, or breaking change is present in the diff but absent from the body's `## Breaking changes`, `## Rollout`, or `## Review notes`.
- A keep-list item from `references/best-practices.md` applies but is missing, for example because an edit cut the only sentence that stated it.
- A term this PR introduces appears without an explanation a reviewer new to the change could follow.
- The Test Plan includes automated commands, an automated testing subsection, or CI-owned checks such as format, lint, typecheck, build, or the standard unit-test suite.
- The body mentions local setup failures such as missing `node_modules`, failed package installs, unavailable Postgres, absent Docker services, or port conflicts.
- The Test Plan lists missing targets such as "No unit-test target exists" instead of surfacing a real coverage risk in `## Review notes` or omitting the noise.
- The description references spec files, conversation history, or `siw/LOG.md` (reviewers can't see them).
- An AI-attribution badge is about to land in the body.
