# Shared working tree

Loaded by `SKILL.md` Step 7 and `references/team-mode.md` Step 2 when instructing reviewer agents, and by the integrity check before findings are aggregated.

Reviewers read one working tree that is shared with every other reviewer in the same audit, and that tree usually holds uncommitted work. A file a reviewer edits stops being the code under audit and becomes false evidence for everyone else: the next reviewer reads the mutation, cannot see who made it, and reports it as a defect in the author's change. Findings fabricated this way are indistinguishable from real ones because they cite a real file and a real line.

**Every spawned reviewer is read-only.** This is not advice about scope; it is a hard constraint on the tools a reviewer may use.

- Never create, edit, delete, move, or rename a file. Never stage, commit, stash, reset, checkout, or apply a patch.
- Never run a command that rewrites files as a side effect: formatters, linters with `--fix`, codemods, dependency installs, build steps that write into the tree, or test runners that update snapshots, fixtures, or generated golden files.
- Read-only verification is encouraged: reading files, `git diff`, `git log`, `git show`, `grep`, and search tools all leave the tree untouched.
- Browser evidence is read-only too. Navigating, resizing, screenshotting, and reading the DOM or console are all fine, but a screenshot, recording, or trace must not be saved into the repository working tree. Keep it in the browser tool's own storage or a path outside the repository, and cite it in the finding by description.
- When a fix requires a code change, put the change in the finding as recommended text. Describing the edit is the deliverable; applying it is `/kramme:pr:resolve-review`'s job.
- A reviewer that genuinely must execute something that writes has to run alone or in an isolated worktree. It must never do so inside a parallel batch on the shared tree.

The orchestrator captures a working-tree manifest before launching reviewers and again after collecting their findings (`${CLAUDE_PLUGIN_ROOT}/scripts/review-tree-fingerprint.sh`). Each successful manifest contains exactly one metadata record followed by zero or more sorted path records:

- `@head<TAB><commit>` records the full commit OID resolved before path collection. It is metadata, never a filename.
- `<state><TAB><path>` records a mutable working-tree path and retains the existing state vocabulary.

Parse the single `@head<TAB><commit>` metadata record before interpreting any path record. If either manifest has missing, duplicate, or malformed HEAD metadata, stop without aggregating or writing a report. Compare the captured commits first. When they differ, the audit scope moved to another commit or branch: discard all findings from the stale batch, stop without writing `UX_REVIEW_OVERVIEW.md`, and require a fresh scope capture and complete audit. Do not derive `MUTATED_PATHS`, re-verify selected findings, or attribute the commit change to a reviewer. The helper also fails its capture if HEAD changes while it is collecting paths.

Only after both HEAD records are valid and equal, remove the metadata records and compare the sorted path records. A path-record difference means the tree changed mid-audit, so:

- Re-read every path that differs, from disk, and re-verify each finding that cites one of those paths against the current text.
- Drop any finding whose cited code does not reproduce. Do not keep it at reduced confidence — a finding formed against text that no longer exists is a fabrication, not a weak observation.
- Report the mutated paths in `## Coverage Status` so the human can inspect them. Never revert or clean them automatically; uncommitted work in that tree may be the user's, not a reviewer's.
- If the mutated paths cover most of the UI-relevant scope, stop without writing `UX_REVIEW_OVERVIEW.md` and report the mutation instead. An audit of a tree that changed underneath it is not an audit.

The path records cover tracked paths differing from the captured commit plus untracked, non-ignored paths. They do not cover ignored files, so build output, caches, and screenshots written into an ignored directory stay invisible to them.
