---
name: kramme:verify
description: Run verification checks (tests, formatting, builds, linting, type checking) for affected code based on the project's configuration.
---

# Verify Affected Code

Run verification checks (tests, formatting, builds, linting, type checking) for affected code based on the project's configuration.

## Instructions

### 1. Read Project Configuration

**First, read the project's CLAUDE.md** to understand how checks should be run. Look for:

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

If CLAUDE.md doesn't specify commands, check CI configuration files:
- `.github/workflows/*.yml` (GitHub Actions)
- `.gitlab-ci.yml` (GitLab CI)
- `azure-pipelines.yml` (Azure DevOps)
- `Jenkinsfile` (Jenkins)
- `.circleci/config.yml` (CircleCI)

Extract the test, build, lint, and format commands from these files.

### 3. Detect Project Type

If no configuration specifies commands, detect the project type:
- **Nx workspace**: Check for `nx.json` or `project.json`
- **C#/.NET**: Check for `*.csproj` or `*.sln` files
- **Node.js**: Check for `package.json`

### 4. Determine Base Branch

For affected detection and format checks, determine the base branch:

1. **Check CLAUDE.md** for a specified base branch
2. **Check `nx.json`** for `defaultBase` setting (Nx projects)
3. **Auto-detect from git**: `git symbolic-ref refs/remotes/origin/HEAD | sed 's|refs/remotes/origin/||'`
4. **Fallback**: Check if `main` exists, otherwise use `master`

```bash
# Auto-detect base branch
BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||') || BASE_BRANCH="main"
```

### 5. Discover Available Targets (Nx)

For Nx projects, discover available targets before running:
```bash
# List affected projects
nx show projects --affected

# Check what targets are available for a project
nx show project <project-name> --json | jq '.targets | keys'

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

### Nx Workspace (TypeScript/JavaScript)

```bash
# First, determine base branch (see step 4 above)
# Use detected BASE_BRANCH for all affected commands

# Check affected projects first
nx show projects --affected --base=$BASE_BRANCH

# Formatting (note: format:check doesn't use --affected flag)
nx format:check --base=$BASE_BRANCH  # Checks files changed from base branch

# Run affected targets (use --parallel for speed)
nx affected -t lint --parallel --base=$BASE_BRANCH
nx affected -t typecheck --parallel --base=$BASE_BRANCH  # If typecheck target exists
nx affected -t build --parallel --base=$BASE_BRANCH

# Tests - run different test targets as available
nx affected -t test --parallel --base=$BASE_BRANCH           # Unit tests
nx affected -t component-test --parallel --base=$BASE_BRANCH # Component tests (if exists)
nx affected -t integration-test --base=$BASE_BRANCH          # Integration tests (if exists)
nx affected -t e2e --base=$BASE_BRANCH                       # E2E tests (if exists)
```

### C#/.NET Project

```bash
# Restore dependencies if needed
dotnet restore

# Formatting and style
dotnet format --verify-no-changes

# Build
dotnet build --no-restore

# Tests (use --parallel for faster execution)
# Run all tests if no categories defined:
dotnet test --no-build

# Or run by category if they exist:
dotnet test --no-build --filter "Category=Unit"
dotnet test --no-build --filter "Category=Integration"
dotnet test --no-build --filter "Category=E2E"
```

### Standard Node.js Project

```bash
# Check package.json scripts for available commands
cat package.json | jq '.scripts | keys'

# Common patterns:
npm run format:check   # or: npx prettier --check .
npm run lint           # or: npx eslint .
npm run typecheck      # or: npx tsc --noEmit
npm run build

# Tests - check package.json for available test scripts
npm run test           # Unit tests
npm run test:component # Component tests (if available)
npm run test:integration # Integration tests (if available)
npm run test:e2e       # E2E tests (if available)
```

## Critical Requirements

### Error Output

- **ALWAYS capture and display the FULL error output** when any check fails
- Do NOT truncate or summarize error messages
- Include file paths, line numbers, and specific error descriptions
- This allows immediate identification and fixing of issues

### Test Suite Discovery

Before running tests, discover what's available:

**For Nx:**
```bash
# See all targets across affected projects (use detected BASE_BRANCH)
nx show projects --affected --base=$BASE_BRANCH -t test
nx show projects --affected --base=$BASE_BRANCH -t component-test
nx show projects --affected --base=$BASE_BRANCH -t integration-test
nx show projects --affected --base=$BASE_BRANCH -t e2e
```

**For C#:**
- Check test project files for `[Category("Unit")]` etc. attributes
- Check CI configuration for test filter patterns

**For Node.js:**
- Check `package.json` scripts section for test variations

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

- Always prefer commands from CLAUDE.md over defaults
- Use `--affected` or equivalent to minimize scope when possible
- Do NOT automatically fix issues - this is a verification command only
- If CLAUDE.md specifies a base branch for affected detection, use it; otherwise auto-detect (see step 4)
- If a test suite/target doesn't exist, mark it as SKIPPED, don't fail
- For faster iteration, E2E tests can be skipped with user confirmation
- Always verify targets exist before running them to avoid confusing errors
