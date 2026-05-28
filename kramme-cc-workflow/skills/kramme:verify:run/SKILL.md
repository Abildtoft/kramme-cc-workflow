---
name: kramme:verify:run
description: Run verification checks (tests, formatting, builds, linting, type checking) for affected code based on the project's configuration.
disable-model-invocation: false
user-invocable: true
---

# Verify Affected Code

Discover the project's verification commands, run them against affected code, and report results. This is a verification command only: it never modifies files or auto-fixes issues.

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

If none of these match and no commands were found in steps 1-2, report "No verification commands found" with the locations checked, then stop. Do not invent commands.

This skill relies on `git`, plus the toolchain for the detected project type (`nx`, `dotnet`, or `npm`) and `jq` for the JSON-inspection snippets below. If a required tool is missing, mark the checks that need it as `SKIPPED` with the reason (same handling as a missing target) rather than failing the run.

### 4. Determine Base Branch

For affected detection and format checks, determine the base branch:

1. **Check the applicable project instruction files** (`AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, markdown instruction files in a nearby `.claude/` directory, or equivalent) for a specified base branch
2. **Check `nx.json`** for `defaultBase` setting (Nx projects)
3. **Auto-detect from git**: read `origin/HEAD`
4. **Fallback**: if `origin/HEAD` is unset, use `main` if it exists, otherwise `master`

```bash
# Auto-detect base branch. --short strips the refs/remotes/origin/ prefix.
# Branch off git's own exit status, not the pipeline's, so the fallback fires when origin/HEAD is unset.
BASE_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2> /dev/null)
BASE_BRANCH=${BASE_BRANCH#origin/}
if [ -z "$BASE_BRANCH" ]; then
  if git show-ref --verify --quiet refs/heads/main; then
    BASE_BRANCH=main
  else
    BASE_BRANCH=master
  fi
fi
```

### 5. Discover Available Targets (Nx)

For Nx projects, discover available targets before running:

```bash
# List affected projects
nx show projects --affected

# Check what targets are available for a project (quote the name; the brackets are a placeholder)
PROJECT=my-app
nx show project "$PROJECT" --json | jq '.targets | keys'

# Or inspect project.json files directly
```

### 6. Run Verification

Run checks in this order (continue through ALL checks even if some fail):

1. **Formatting** - Check code formatting without modifying files
2. **Linting** - Run static analysis/linting
3. **Type checking** - Verify TypeScript types compile
4. **Build** - Compile/build the project
5. **Unit tests** - Fast, isolated tests
6. **Component tests** - UI component tests (if available)
7. **Integration tests** - Tests with dependencies (if available)
8. **E2E tests** - End-to-end tests (if available)

## Default Commands by Project Type

When project instructions and CI config don't specify commands, read `references/commands-by-project-type.md` for default check-only command sets (Nx, C#/.NET, Node.js) and per-ecosystem test-suite discovery. Read only the section for the project type you detected in step 3, and use the `$BASE_BRANCH` from step 4.

## Critical Requirements

### Error Output

- **ALWAYS capture and display the FULL error output** when any check fails
- Do NOT truncate or summarize error messages
- Include file paths, line numbers, and specific error descriptions
- This allows immediate identification and fixing of issues

### Test Suite Discovery

Before running tests, discover which suites exist so you can run only those and mark the rest `SKIPPED`. Per-ecosystem discovery commands are in `references/commands-by-project-type.md`.

### Handling Failures

- Run ALL verification steps even if earlier steps fail
- Collect ALL errors from ALL failed steps
- Present a comprehensive summary with all issues at the end
- Format errors clearly so they can be acted upon immediately

### Parallelization

Use parallel execution where possible for faster feedback:

- **Nx**: Use `--parallel` flag (e.g., `nx affected -t lint --parallel`)
- **dotnet**: Tests run in parallel by default, can configure with `--parallel`
- **npm**: Check if scripts support parallel execution

## Output Format

After running all checks, provide:

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
```

## Important Notes

- Always prefer explicitly documented commands from the applicable project instruction files over defaults
- Use `--affected` or equivalent to minimize scope when possible
- Do NOT automatically fix issues - this is a verification command only
- If any applicable project instruction file specifies a base branch for affected detection, use it; otherwise auto-detect (see step 4)
- If a test suite/target doesn't exist, mark it as SKIPPED, don't fail
- Always verify targets exist before running them to avoid confusing errors
- Integration and E2E suites often mutate state (databases, queues) or require running services. Treat them as potentially side-effecting: skip them when the environment isn't prepared, and confirm with the user before running them when in doubt. E2E can also be skipped for faster iteration.
- This skill only discovers and runs checks. To gate completion claims on fresh evidence (before committing or opening a PR), that policy lives in the `kramme:verify:before-completion` skill.
