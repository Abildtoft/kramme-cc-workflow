# Hook Helper Library

This directory contains shared helpers used by hook scripts in
`kramme-cc-workflow/hooks/`. Keep hook-specific policy in the hook script; keep
cross-hook parsing and toggle behavior here.

## Files

| File | Responsibility |
| --- | --- |
| `check-enabled.sh` | Reads `hooks/hook-state.json`, honors disabled hooks, drains stdin on disabled hooks, and optionally emits `{}` for JSON hook events. |
| `git-parse-utils.sh` | Shell helpers for token cleanup, wrapper parsing, command-substitution tracking, and simple git command classification used by hook tests and shell hooks. |
| `git_command_parser.py` | Broad parser for command-safety hooks. It handles shell wrappers, environment propagation, command substitutions, heredocs, and git subcommands, then emits JSON with allow/block details. |

## Boundary Rules

- Every hook script should source `check-enabled.sh` and call
  `exit_if_hook_disabled` before doing real work.
- Helpers must fail open only where the hook policy already treats missing or
  malformed local state as non-blocking.
- Parser changes need regression tests for the hook that consumes the parser,
  not just direct helper tests.
- Do not add repository-specific workflow policy here. For example, deciding
  which review artifacts require confirmation belongs in
  `confirm-review-responses.sh` and `confirm-review-artifacts.txt`.

## Verification

Run the helper tests after touching this directory:

```bash
bats kramme-cc-workflow/tests/check-enabled.bats kramme-cc-workflow/tests/git-parse-utils.bats
```

For parser behavior, also run the consuming hook suites:

```bash
bats kramme-cc-workflow/tests/noninteractive-git.bats kramme-cc-workflow/tests/confirm-review-responses.bats kramme-cc-workflow/tests/block-rm-rf.bats
```
