# Platform-Specific Notes

## GitHub

- **PREFER** using `gh` CLI via Bash for GitHub operations
- **ALWAYS** link Linear issues using magic words for automatic linking:
  - **Magic words that auto-close**: `Fixes`, `Closes`, `Resolves` (use when PR completes the issue)
  - **Magic words that link only**: `Related to`, `Refs`, `References` (use for partial/related work)
  - **Format**: `{magic word} {TEAM}-{number}` or `{magic word} {full Linear URL}`
  - **EXAMPLE**: `Fixes WAN-123`, `Closes HEA-456`, `Related to MEL-789`
  - **NOTE**: Team abbreviations: WAN, HEA, MEL, POT, FIR, FEG
- **ALSO** link GitHub issues using: `Fixes #123` or `Closes #123` or `Related to #123`
