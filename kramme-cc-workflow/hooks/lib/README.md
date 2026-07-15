# Hook Helper Library

This directory contains shared helpers used by hook scripts in
`kramme-cc-workflow/hooks/`. Keep hook-specific policy in the hook script; keep
cross-hook parsing and toggle behavior here.

## Files

| File | Responsibility |
| --- | --- |
| `check-enabled.sh` | Reads the resolved hook state file, honors disabled hooks, drains stdin on disabled hooks, and optionally emits `{}` for JSON hook events. |
| `git_command_parser.py` | Production parser for command-safety hooks. It handles shell wrappers, environment propagation, command substitutions, heredocs, and git subcommands, then emits JSON with allow/block details. |
| `safety-hook-parser.sh` | Provides fail-closed dependency checks, hook input extraction, parser invocation, and parser-output validation for command-safety hook wrappers. |

## Boundary Rules

- Every hook script should source `check-enabled.sh` and call
  `exit_if_hook_disabled` before doing real work. This is the "every hook
  supports toggling" decision; see
  [docs/decisions/README.md](../../docs/decisions/README.md).
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
bats kramme-cc-workflow/tests/check-enabled.bats
```

For parser behavior, also run the consuming hook suites:

```bash
python3 -m unittest discover -s kramme-cc-workflow/tests/python -p test_git_command_parser.py
bats kramme-cc-workflow/tests/noninteractive-git.bats kramme-cc-workflow/tests/confirm-review-responses.bats kramme-cc-workflow/tests/block-rm-rf.bats
```
