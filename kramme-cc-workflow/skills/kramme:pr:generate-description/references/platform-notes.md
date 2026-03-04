# Platform-Specific Notes

## GitLab

- **PREFER** using GitLab MCP server tools when available:
  - `mcp__gitlab__get_branch_diffs` for diff analysis
  - `mcp__gitlab__list_commits` for commit history
  - `mcp__gitlab__get_merge_request` if PR already exists
- **ALWAYS** link Linear issues using magic words for automatic linking:
  - **Magic words that auto-close**: `Fixes`, `Closes`, `Resolves` (use when PR completes the issue)
  - **Magic words that link only**: `Related to`, `Refs`, `References` (use for partial/related work)
  - **Format**: `{magic word} {TEAM}-{number}` or `{magic word} {full Linear URL}`
  - **EXAMPLE**: `Fixes WAN-123`, `Closes HEA-456`, `Related to MEL-789`
  - **NOTE**: Team abbreviations: WAN, HEA, MEL, POT, FIR, FEG

## GitHub

- **PREFER** using `gh` CLI via Bash for GitHub operations
- **ALWAYS** link issues using: `Fixes #123` or `Closes #123` or `Related to #123`
