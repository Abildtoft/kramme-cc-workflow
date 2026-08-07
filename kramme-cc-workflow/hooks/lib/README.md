# Hook Helper Library

This directory contains shared helpers used by hook scripts in
`kramme-cc-workflow/hooks/`. Keep hook-specific policy in the hook script; keep
cross-hook parsing and toggle behavior here.

## Files

| File | Responsibility |
| --- | --- |
| `check-enabled.sh` | Reads the resolved hook state file, honors disabled hooks, drains stdin on disabled hooks, and optionally emits `{}` for JSON hook events. |
| `git_command_parser.py` | Executable entry point for the command-safety parser. Holds no parsing logic; it re-exports the dispatcher from `command_safety/` so both `python3 -m git_command_parser` and the direct script path keep working. The module form is the hook-facing one and the only form that works under `PYTHONSAFEPATH=1`, because `safety-hook-parser.sh` passes an explicit `PYTHONPATH=.`. |
| `command_safety/` | The parser itself. Handles shell wrappers, environment propagation, command substitutions, heredocs, and git subcommands, then emits JSON with allow/block details. See the module map below. |
| `safety-hook-parser.sh` | Provides fail-closed dependency checks, hook input extraction, parser invocation, and parser-output validation for command-safety hook wrappers. |

### `command_safety/` module map

Modules depend strictly downward in this table, so a mode can be read, changed,
and tested without loading the other two. Do not add an upward import: a cycle
here would break every gate at once.

| Module | Responsibility |
| --- | --- |
| `structs.py` | `_StructValue`, the `__slots__` value-object base the result types share instead of `dataclasses`. |
| `syntax.py` | Shell syntax primitives: quoting and ANSI-C decoding, command-substitution readers, heredoc scanning, basename and assignment helpers, and the shared shell keyword/executable/option sets. Imports nothing else in the package. |
| `vocabulary.py` | How `xargs` and `git` consume their own options, so no two modes can resolve the same prefix to different subcommands. |
| `prefix.py` | `normalize_command_prefix()` and one handler per execution wrapper (`env`, `sudo`, `nice`, `timeout`, `time`, `nohup`, `exec`, `command`/`builtin`). Reports what actually runs; applies no policy. |
| `lexer.py` | Heredoc stripping, newline folding, tokenization, segment splitting, and command-substitution placeholders. Uses `prefix.py` to decide whether a heredoc body is executable. |
| `noninteractive.py` | The `noninteractive` mode: editor- and prompt-opening git detection, plus `run_noninteractive()`. |
| `rm_rf.py` | The `rm-rf` mode: recursive-deletion detection through wrappers, `find`/`xargs`, `eval`, and substitutions, plus `run_rm_rf()`. |
| `commit.py` | The `commit-contexts` mode: `CommitContext`, replay environment, content-selection parsing, plus `run_commit_contexts()`. |
| `cli.py` | `main()`, dispatching one mode per invocation. Imports the chosen mode inside its branch so a gate never pays the other modes' import cost. |

## Git command parser mode contracts

The hook-facing entry point is
`git_command_parser.py <mode> <command> [parse-error-reason]`. The shared
[`safety-hook-parser.sh`](safety-hook-parser.sh) wrapper extracts
`.tool_input.command`, invokes the selected mode, validates its JSON, and turns
block decisions into hook exit status 2. Known modes emit one JSON value and
exit 0; missing or unknown modes exit 2.

| Mode and caller | Accepted command shapes | JSON stdout | Nested parsing | Failure posture |
| --- | --- | --- | --- | --- |
| `noninteractive` — [`noninteractive-git.sh`](../noninteractive-git.sh) | Command lists containing direct or prefixed Git commands, `env`/`sudo`/execution wrappers, `find`/`xargs` execution, inline shell commands, and command substitutions. Policy covers editor- or prompt-opening `git commit`, `rebase`, `add`, `merge`, and `cherry-pick` forms. | `{"block": null}` to allow, or `{"block": "<reason>"}` to block. | Follows inline shell commands and command substitutions through depth 4. | Tokenization, prefix-normalization, alias, or depth ambiguity returns the parser-error block reason. Unrecognized non-Git commands and Git forms outside the interactive policy pass. |
| `commit-contexts` — [`confirm-review-responses.sh`](../confirm-review-responses.sh) | Command lists containing `git commit`, including normalized wrappers, repository-selection options and environment, inline shell commands, command substitutions, and index/worktree/pathspec selection forms. | An ordered array of commit-context objects; `[]` means no commit was found. See the field contract below. | Follows inline shell commands and command substitutions through depth 4 while carrying replayable repository state. | Parse ambiguity returns `[{"parse_error": "<reason>"}]`; unsupported commit selection adds `selection_error` to that context. The caller blocks on either error, dynamic repository selection, malformed fields, or replay failure. |
| `rm-rf` — [`block-rm-rf.sh`](../block-rm-rf.sh) | Command lists containing recursive-and-forced `rm`, `find -delete`, `find -exec`/`-execdir`, `xargs`, `shred`, or `unlink`, including normalized wrappers, inline shell commands, `eval`, shell functions, executable heredocs, and command/process substitutions. | `{"block": null}` to allow, or `{"block": "<reason>"}` to block. | Inspects supported destructive shapes through depth 5; content beyond that bound is not classified. | Tokenization, prefix-normalization, or Python recursion failure returns the generic `rm -rf` block reason. Commands with no recognized destructive shape, including shapes only beyond the nesting bound, pass. |

All modes bound recursive `env -S`/`--split-string` expansion to 64 expansions
and 100,000 characters of expanded payload. Exceeding either bound is a parse
failure and therefore blocks in every mode. Independently of mode, the shared
wrapper blocks when hook input is malformed, Python or `jq` is unavailable,
parser execution fails, or the parser output has the wrong top-level JSON type.
For `noninteractive` and `rm-rf`, a missing or null `block` value allows the
command; any non-null value must be a string. An absent or empty command is
allowed before parser invocation (`commit-contexts` emits `[]` for that case).

### Commit-context fields

[`CommitContext`](command_safety/commit.py) and `parse_commit_selection()` own
the parser schema; `confirm-review-responses.sh` validates every field before
replaying the selection:

| Field | Contract |
| --- | --- |
| `git_args` | Ordered string array of Git arguments captured before `commit`, including repository selectors and other global options. `confirm-review-responses.sh` rejects dynamic selectors and replays only an allowlisted safe subset, such as `-C`, `--git-dir`, or `--work-tree`; config-bearing arguments are never replayed. Present on normal commit contexts. |
| `git_env` | Ordered string array of replayable `GIT_*` assignments that select repository, index, object, namespace, or pathspec behavior. Present on normal commit contexts. |
| `selection_mode` | Effective commit content selection: `index` when absent, otherwise `all`, `include`, or `only`. |
| `pathspecs` | Ordered command-line pathspecs. Present with non-index selection, including an empty array when the mode itself selects content. |
| `pathspec_from_file` | Optional path to a line- or NUL-delimited pathspec file. `-` and dynamically substituted paths are rejected. |
| `pathspec_file_nul` | Boolean delimiter flag emitted with `pathspec_from_file`; defaults to `false`. |
| `selection_error` | Modeled commit with content-selection arguments that cannot be replayed safely. The consuming hook blocks with this reason. |
| `parse_error` | Standalone fail-closed sentinel carrying the caller-supplied parse-error reason. |

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

Representative cross-mode wrapper cases live in
[`git-command-parser-cases.json`](../../tests/fixtures/git-command-parser-cases.json).
The direct CLI contract tables live in
[`test_git_command_parser.py`](../../tests/python/test_git_command_parser.py):
`GitCommandParserCliTest.CASES` covers `noninteractive` and `commit-contexts`,
while `RmRfParserCliTest.CASES` covers `rm-rf`. The consuming-hook suites add
policy fixtures for each mode:

| Mode | Representative consuming fixtures |
| --- | --- |
| `noninteractive` | `git commit` without a message blocks; `git commit -m ...` and safe prefixed variants allow. |
| `commit-contexts` | `git -C repo commit`, worktree/index selection, pathspec files, dynamic repository selection, and malformed context fields. |
| `rm-rf` | Direct and wrapped `rm -rf`, `find`/`xargs`, substitutions and shell heredocs, plus quoted text and `git rm` allow cases. |

Run the helper toggle tests after changing `check-enabled.sh`:

```bash
bats kramme-cc-workflow/tests/check-enabled.bats
```

For parser contracts or changes to `safety-hook-parser.sh`, run the direct CLI
suite and all three consumers:

```bash
python3 -m unittest discover -s kramme-cc-workflow/tests/python -p test_git_command_parser.py
bats kramme-cc-workflow/tests/noninteractive-git.bats kramme-cc-workflow/tests/confirm-review-responses.bats kramme-cc-workflow/tests/block-rm-rf.bats
```

For documentation-only changes, also check the scoped diff:

```bash
git diff --check -- kramme-cc-workflow/hooks/lib/README.md kramme-cc-workflow/hooks/lib/git_command_parser.py kramme-cc-workflow/hooks/lib/command_safety
```
