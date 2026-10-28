# Platform-Specific Notes

## GitHub

- **PREFER** using `gh` CLI via Bash for GitHub operations.
- **ALWAYS** link Linear issues using magic words for automatic linking:
  - **Magic words that auto-close**: `Fixes`, `Closes`, `Resolves` (use when the PR completes the issue).
  - **Magic words that link only**: `Related to`, `Refs`, `References` (use for partial or tangential work).
  - **Format**: `{magic word} {TEAM}-{number}` or `{magic word} {full Linear URL}`. `{TEAM}` is any uppercase Linear team prefix (e.g. `WAN`, `HEA`, `BLOG`, `ENG`). Do not hard-code a fixed list — accept whatever Linear validates.
  - **EXAMPLE**: `Fixes WAN-123`, `Closes BLOG-456`, `Related to ENG-789`.
- **ALSO** link GitHub issues using: `Fixes #123` / `Closes #123` / `Related to #123`.
