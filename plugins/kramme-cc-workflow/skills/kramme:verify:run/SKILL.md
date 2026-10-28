---
name: kramme:verify:run
description: Run tests, lint, formatting, builds, and type checks configured by the project; --fast picks the iteration tier. Use when asked, before claiming completion, or when a workflow delegates.
argument-hint: "[--fast | --full] [--force] [--base <branch> [--base-commit <oid>]]"
disable-model-invocation: false
user-invocable: true
---

# Verify Affected Code

Discover the project's verification commands, run the selected tier against affected code, and report results with the working-tree ID they cover. It also states the evidence every completion claim needs; its checks never modify files or auto-fix issues, and only the optional red-green check in `references/completion-claims.md` temporarily removes and restores a fix.

## Discovery Cache

Before step 1, run `"${CODEX_HOME:-$HOME/.codex}/plugins/cache/kramme-cc-workflow/kramme-cc-workflow/0.90.0/skills/kramme:verify:run/scripts/discovery-cache.sh" key`; it keys repository-root discovery inputs and this skill's own files by content hash. Unless `--force` is present and while `enabled` is true, run its `read <key>`:

- **Hit** (exit 0): the record's checks, tiers, base branch, and skipped notes replace steps 1-3, the root-file base lookups in step 5, and the static suite list from Test Suite Discovery. Still read nested instruction files for the affected paths, resolve the base (step 5), and run Nx affected discovery, target-existence checks, and Skill Security Scan Discovery every run.
- **Miss** (exit 3, or exit 4 for a rejected record, which you report): run steps 1-3, then save the result with `write <key> <record-file>` before running checks. `--force` also discovers fresh and saves.

Report one line: `Discovery: cached (<first 12 key characters>)`, `Discovery: fresh (saved)`, `Discovery: fresh (cache disabled: <reason>)`, or `Discovery: fresh (not saved: <reason>)` when `write` refuses the record. Read `references/discovery-cache.md` for the record format and trust rule before writing a record.

## Instructions

### 1. Read Project Configuration

**First, read all applicable project instruction files**: read repo-root `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, and any markdown instruction files in repo-root `.claude/` when present, then any relevant nested instruction files (`AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, markdown instruction files in a nearby `.claude/` directory, or equivalents). If both `AGENTS.md` and `CLAUDE.md` exist, read both. Look for:

- **Formatting** commands (e.g., `nx format:check`, `dotnet format`, `prettier --check`)
- **Linting** commands (e.g., `nx lint`, `eslint`, `dotnet format --verify-no-changes`)
- **Type checking** commands (e.g., `tsc --noEmit`, `nx typecheck`)
- **Build** commands (e.g., `nx build`, `dotnet build`, `npm run build`)
- **Test commands** for different suites:
  - Unit tests (e.g., `nx test`, `dotnet test --filter Category=Unit`)
  - Component tests (e.g., `nx component-test`, Cypress component, Storybook)
  - Integration tests (e.g., `nx integration-test`, `dotnet test --filter Category=Integration`)
  - E2E tests (e.g., `nx e2e`, `dotnet test --filter Category=E2E`)
- **Verification tiers and cadence**: a fast iteration loop (e.g., `verify:fast`, affected-only tests) versus a full pre-push or pre-PR sweep (e.g., `yarn verify`, `make verify`), and any rule for when each runs

### 2. Fallback: Check CI Configuration

If project instructions do not specify commands, check CI configuration files:

- `.github/workflows/*.yml` (GitHub Actions)
- `azure-pipelines.yml` (Azure DevOps)
- `Jenkinsfile` (Jenkins)
- `.circleci/config.yml` (CircleCI)

Extract **only** the test, build, lint, type-check, and format commands. CI files interleave verification with deploy, publish, release, and other state-mutating steps — never run those, and never run steps that push to a remote, write to a registry, or modify infrastructure. If a step's intent is ambiguous, skip it and note it in the report rather than running it.

### 3. Detect Project Type

If no configuration specifies commands, detect the project type:

- **Nx workspace**: Check for `nx.json` or `project.json`
- **C#/.NET**: Check for `*.csproj` or `*.sln` files
- **Node.js**: Check for `package.json`
- **Python**: Check for `pyproject.toml` or `pytest.ini` (defaults: `pytest`, `ruff check`)
- **Go**: Check for `go.mod` (defaults: `go test ./...`, `go vet ./...`)
- **Rust**: Check for `Cargo.toml` (defaults: `cargo test`, `cargo clippy`, `cargo fmt --check`)

If none of these match and no commands were found in steps 1-2, report "No verification commands found" with the locations checked, then stop. Do not invent commands.

This skill relies on `git`, plus the toolchain for the detected project type (`nx`, `dotnet`, `npm`, `pytest`/`ruff`, `go`, or `cargo`) and `jq` for the JSON-inspection snippets below and the discovery cache helper. If a required tool is missing, mark the checks that need it as `SKIPPED` with the reason (same handling as a missing target) rather than failing the run.

### 4. Select the Tier

Parse `$ARGUMENTS` for `--fast`, `--full`, `--force`, `--base <branch>`, and `--base-commit <oid>`. Reject `--fast` combined with `--full`, and `--base-commit` without `--base`.

- **Fast tier**: the project's documented iteration loop. Without one, run formatting, linting, type checking, and unit tests scoped to affected code, and skip build, component, integration, and E2E suites.
- **Full tier**: the project's documented pre-push or pre-PR sweep. Without one, run every applicable check in step 8.

`--fast` or `--full` selects the tier. Without either flag, run the full tier for compatibility with callers that require a complete verification battery. A green full-tier result also covers a fast-tier claim on the same tree when it includes all fast-tier checks.

### 5. Determine Base Branch

For affected detection and format checks, determine the base branch:

Synced base/diff scope contract (keep aligned across base-aware and diff-aware skills): use the shared resolve-base.sh script for base refs; use the shared collect-review-diff.sh script for unified changed-file scope; canonical base priority is explicit --base, PR target branch, repository kramme.baseBranch, CONDUCTOR_DEFAULT_BRANCH, then origin/HEAD, origin/main, or origin/master, and canonical diff scope is committed PR diff from MERGE_BASE...HEAD plus staged, unstaged, and untracked paths.

1. **Use `--base` when passed.** Set `BASE_BRANCH_OVERRIDE` to it, skip items 2 and 3, and set `PINNED_BASE_COMMIT` to any `--base-commit` value.
2. **Check the applicable project instruction files** (`AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, markdown instruction files in a nearby `.claude/` directory, or equivalent) for a specified base branch. If one is specified, set `BASE_BRANCH_OVERRIDE` to that value.
3. **Check `nx.json`** for `defaultBase` setting (Nx projects). If present and no project instruction already specified a base, set `BASE_BRANCH_OVERRIDE` to that value.
4. **Resolve with the shared plugin script.** Let the script perform PR-target and remote-default fallback detection; do not duplicate that logic in this skill.

```bash
RESOLVE_ARGS=(--strict)
[ -n "${BASE_BRANCH_OVERRIDE:-}" ] && RESOLVE_ARGS+=(--base "$BASE_BRANCH_OVERRIDE")
[ -n "${PINNED_BASE_COMMIT:-}" ] && RESOLVE_ARGS+=(--base-commit "$PINNED_BASE_COMMIT")

RESOLVED=$("${CODEX_HOME:-$HOME/.codex}/plugins/cache/kramme-cc-workflow/kramme-cc-workflow/0.90.0/scripts/resolve-base.sh" "${RESOLVE_ARGS[@]}") || {
  echo "Base resolution failed; see the message above and stop." >&2
  exit 1
}
eval "$RESOLVED"
```

The script exports `BASE_REF`, `BASE_BRANCH`, and `MERGE_BASE`. Use `BASE_REF` for affected comparisons (for example Nx `--base=$BASE_REF`), because it is the fetched remote-tracking ref that the resolver guarantees exists. Use `BASE_BRANCH` only for display or tools that truly require a branch name. A pinned commit becomes `BASE_REF` without a Pull Request lookup or fetch, after the resolver confirms it resolves locally, so reuse compares that commit OID.

### 6. Reuse a Green Run on the Same Tree

Capture the working-tree ID before running anything. It names the exact content being checked, including staged, unstaged, and untracked non-ignored files, and stays the same when that content is later committed:

```bash
TREE_ID=$("${CODEX_HOME:-$HOME/.codex}/plugins/cache/kramme-cc-workflow/kramme-cc-workflow/0.90.0/scripts/worktree-tree-id.sh") || TREE_ID=""
```

Unless `--force` is present, do not run the checks again when this session already holds a green result from this skill that recorded the same non-empty `TREE_ID`, the same resolved `BASE_REF` commit OID and `MERGE_BASE` when any check was base-scoped (for example `--affected`), and the selected tier or a broader one. Resolve the base anew through step 5 before comparing; a matching ref name is insufficient, and missing base evidence forbids reuse. Report `REUSED` with the earlier summary, tree ID, and base evidence instead. Run the checks anyway when ignored inputs they read have changed since, such as a dependency install, regenerated code, or an edited local env file. An empty `TREE_ID` never matches.

Never reuse a failed or partial run as a green tier result. This skill reports failures without fixing them. After the caller fixes a failure, it may use the narrowed retry procedure below; a new unqualified or `--full` invocation still selects the full tier.

### Narrowed Retry by the Caller

Keep each executed check's command, working directory, scope, exit status, tree ID, and resolved `BASE_REF`/`MERGE_BASE` in the session result. A caller may retry without a new flag:

1. Rerun the exact failed check commands from that result directly, preserving their working directory and scope. Reconstruct commands from the trusted project configuration, never from error output.
2. Invoke `kramme:verify:run --fast` using its normal affected scope, which includes the fix. There is no file-scope argument to this skill.
3. Carry an earlier passing check only after proving the intervening changes cannot affect its inputs or dependent behavior, with unchanged base scope and ignored inputs. Otherwise rerun that check too, including build, integration, or E2E checks affected by the fix. If prior commands, scope, or dependency coverage cannot be established, invoke `kramme:verify:run --full` instead.
4. Report carried evidence as `PASS (carried from <tree ID>)` with its independence proof. Call the combined result `full coverage after retry` only when every required full-tier check has current passing evidence or this explicit carry proof; otherwise report partial coverage. A partial retry cannot satisfy a caller's full-verification gate.

### 7. Discover Available Targets (Nx)

For Nx projects, discover available targets before running:

```bash
# List affected projects
nx show projects --affected

# Check what targets are available for a project (quote the name; the brackets are a placeholder)
PROJECT=my-app
nx show project "$PROJECT" --json | jq '.targets | keys'

# Or inspect project.json files directly
```

### 8. Run Verification

Run the selected tier's checks in this order (continue through ALL checks even if some fail):

1. **Formatting** - Check code formatting without modifying files
2. **Linting** - Run static analysis/linting
3. **Type checking** - Verify TypeScript types compile
4. **Build** - Compile/build the project
5. **Unit tests** - Fast, isolated tests
6. **Component tests** - UI component tests (if available)
7. **Integration tests** - Tests with dependencies (if available)
8. **E2E tests** - End-to-end tests (if available)

## Default Commands by Project Type

When project instructions and CI config don't specify commands, read `references/commands-by-project-type.md` for default check-only command sets (Nx, C#/.NET, Node.js, Python, Go, Rust) and per-ecosystem test-suite discovery. Read only the section for the project type you detected in step 3, and use the `$BASE_REF` from step 5 for affected comparisons.

## Output Requirements

### Error Output

- When a check fails, quote its errors verbatim rather than paraphrasing them
- Include file paths, line numbers, and specific error descriptions, so each issue can be located and fixed immediately
- For very long output, show every distinct error and state how many repeated errors or lines you omitted

### Test Suite Discovery

Before running tests, discover which suites exist so you can run only those and mark the rest `SKIPPED`. Per-ecosystem discovery commands are in `references/commands-by-project-type.md`.

### Skill Security Scan Discovery

Before running checks, inspect changed and untracked paths for skill directories in top-level or nested plugin roots (`skills/*/SKILL.md`, `*/skills/*/SKILL.md`, `*/skills/*/references/**`, `*/skills/*/assets/**`, or `*/skills/*/scripts/**`). When skill files changed, include a static-only SkillSpector scan in the verification set:

- Prefer a project wrapper when present, such as `make -C kramme-cc-workflow skill-security-changed`, because wrappers can map nested plugin paths like `kramme-cc-workflow/skills/...` to the owning skill directory.
- Otherwise run `skillspector scan <changed-skill-dir> --no-llm` for each changed skill directory when the CLI is available.
- Mark the scan `SKIPPED` when no skill files changed, the scanner is unavailable, or no safe static-only command is discoverable.
- Do not run semantic scanning unless the user explicitly asks and confirms the provider/privacy tradeoff.

### Handling Failures

- Run ALL verification steps even if earlier steps fail
- Collect ALL errors from ALL failed steps
- Present a comprehensive summary with all issues at the end
- Format errors clearly so they can be acted upon immediately

### Long-Running Checks

A killed or truncated run proves nothing and costs another full run:

- Run a check that can outlast the shell tool's timeout in the background, or with an explicit timeout above its expected duration, and poll its log rather than restarting it.
- Redirect output to a log file and read its tail after the command exits. Piping a check through `tail`, `head`, or `grep` reports the filter's exit status instead of the check's unless `set -o pipefail` is active.
- Let a running check finish before editing the tree for an unrelated fix. Interrupting it discards the evidence for every other check.

### Parallelization

Use parallel execution where possible for faster feedback:

- **Nx**: Use `--parallel` flag (e.g., `nx affected -t lint --parallel`)
- **dotnet**: Tests run in parallel by default, can configure with `--parallel`
- **npm**: Check if scripts support parallel execution

## Output Format

After running all checks, provide:

Include each check's command, working directory, scope, exit status, tree ID, and resolved `BASE_REF`/`MERGE_BASE` so callers can verify reuse or retry it. Recapture the tree ID after the checks; if content changed during execution, do not label the run green or reusable until the affected checks cover the resulting tree.

### 1. Individual Step Results with Errors

```
## Formatting
Status: PASS

## Linting
Status: FAIL
Errors:
src/components/Button.tsx:15:3
  error: 'unused' is defined but never used  @typescript-eslint/no-unused-vars

src/utils/helpers.ts:42:10
  error: Missing return type on function      @typescript-eslint/explicit-function-return-type

## Type Checking
Status: PASS

## Build
Status: PASS

## Unit Tests
Status: FAIL
Errors:
FAIL src/utils/helpers.test.ts
  ● calculateTotal › should handle empty array
    Expected: 0
    Received: undefined

    at Object.<anonymous> (src/utils/helpers.test.ts:25:14)

## Component Tests
Status: SKIPPED (no component-test target found)

## Integration Tests
Status: PASS

## E2E Tests
Status: SKIPPED (not running E2E for this verification)
```

### 2. Summary

```
Verification Summary:
- Formatting: PASS
- Linting: FAIL (2 errors)
- Type Checking: PASS
- Build: PASS
- Unit Tests: FAIL (1 error)
- Component Tests: SKIPPED
- Integration Tests: PASS
- E2E Tests: SKIPPED

Issues Found: 2 steps failed - see errors above for details
Tier: full
Verified tree: <TREE_ID> (merge-base <MERGE_BASE>)
Base ref: <BASE_REF> (commit <resolved BASE_REF commit OID>)
```

Callers compare `Verified tree` against a fresh `worktree-tree-id.sh` result to decide whether this run still covers the current content.

## Evidence Before Claims

A claim that work is done, fixed, or passing needs evidence that covers the current working tree. Before you make such a claim, or commit, push, or open a Pull Request because of it:

1. Name the check whose result would prove the claim.
2. Run it now, or show that a green run from this session still covers the tree under step 6. For a command run outside this skill, capture `"${CODEX_HOME:-$HOME/.codex}/plugins/cache/kramme-cc-workflow/kramme-cc-workflow/0.90.0/scripts/worktree-tree-id.sh"` immediately before it; reuse that result only when both IDs are non-empty and equal, the base evidence and ignored inputs are unchanged, and the run covered every check the claim needs.
3. Read the whole result, including its exit status and failure count, then state the claim with that evidence and the tree ID, or report the actual state when the result contradicts the claim.

When no check can prove the claim, because none exists or it cannot run here, say which change remains unverified and why. For claims about user experience (UX), developer experience (DX), or agent experience (AX), choose evidence that fits the affected workflow, check established behavior outside the intended change with relevant regression coverage, verify intentional changes against their new expectations, and report material tradeoffs and verification limits; unchanged or inapplicable dimensions need no invented work. Before claiming that a regression test protects a fix, that a delegated agent finished, or that requirements are met, read `references/completion-claims.md`.

Match the tier to the moment, following the project's documented cadence when it has one:

- **While iterating**: `--fast`, or a focused check that covers the change.
- **Before the first push or Pull Request**: the full sweep once, with `--full`.
- **After a failure**: the Narrowed Retry by the Caller procedure above.
- **After the branch is pushed**: CI can supply the full sweep when its successful jobs on that commit demonstrably cover every required check; cite those jobs. Skipped jobs and status-only checks prove nothing, so run missing checks locally when coverage is absent, incomplete, or unknown.

Never run two overlapping full sweeps on the same tree.

## Important Notes

- Always prefer explicitly documented commands from the applicable project instruction files over defaults
- Use `--affected` or equivalent to minimize scope when possible
- Do NOT automatically fix issues - this is a verification command only
- If any applicable project instruction file specifies a base branch for affected detection, pass it to the shared resolver as `BASE_BRANCH_OVERRIDE`; otherwise let the shared resolver auto-detect in step 5
- If a test suite/target doesn't exist, mark it as SKIPPED, don't fail
- Always verify targets exist before running them to avoid confusing errors
- Integration and E2E suites often mutate state (databases, queues) or require running services. Treat them as potentially side-effecting: skip them when the environment isn't prepared, and confirm with the user before running them when in doubt. E2E can also be skipped for faster iteration.
- Completion claims follow Evidence Before Claims above.
