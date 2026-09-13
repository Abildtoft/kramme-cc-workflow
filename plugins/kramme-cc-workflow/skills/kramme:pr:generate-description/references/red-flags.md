# Red Flags — STOP

## Red Flags — STOP

Pause and regenerate the description if any of these are true:

- The summary says "various changes" or "multiple improvements" without nouns.
- `Changes made` contains vague verbs like `update` or `improve` with no object.
- The same claim appears in multiple sections without adding new context, risk, rationale, or test value.
- The body includes a "Key Files", "Files Changed", or similar section that mostly repeats the GitHub file list.
- The body includes a "Changes by Area" section whose bullets could be reconstructed from GitHub's file tree without reading the prose.
- A migration, feature-flag default, or breaking change is present in the diff but absent from `Potential concerns`.
- The Test Plan includes automated commands, an automated testing subsection, or CI-owned checks such as format, lint, typecheck, build, or the standard unit-test suite.
- The body mentions local setup failures such as missing `node_modules`, failed package installs, unavailable Postgres, absent Docker services, or port conflicts.
- The Test Plan lists missing targets such as "No unit-test target exists" instead of surfacing a real coverage risk in `Potential concerns` or omitting the noise.
- The description references spec files, conversation history, or `siw/LOG.md` (reviewers can't see them).
- An AI-attribution badge is about to land in the body.
