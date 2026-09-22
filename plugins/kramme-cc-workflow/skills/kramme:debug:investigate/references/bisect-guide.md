# Git Bisect Automation Guide

Reference for Step 4: automating regression finding with `git bisect`.

## Basic Workflow

```bash
git bisect start
git bisect bad              # current (broken) commit
git bisect good <hash>      # known-good commit
# Git checks out a midpoint — test it, then:
git bisect good             # bug NOT present
git bisect bad              # bug IS present
# Repeat until git identifies the first bad commit
git bisect reset            # clean up
```

## Automated Bisect

When a test reliably detects the bug:

```bash
git bisect start
git bisect bad HEAD
git bisect good <known-good>
git bisect run <test-command>
```

Exit codes: 0 = good, non-zero = bad, 125 = skip.

### Examples

```bash
# Jest
git bisect run npx jest --testPathPattern="auth.spec.ts" --no-coverage --bail

# Custom script
git bisect run bash -c 'npm run build && npm test -- --grep "specific test"'

# Pytest
git bisect run python -m pytest tests/test_specific.py::test_function -x

# Go
git bisect run go test ./pkg/affected/... -run TestSpecificCase
```

## Finding a Known-Good Commit

```bash
# Recent tags
git tag --sort=-creatordate | head -10

# By time
git log --before="2 weeks ago" --oneline -1

# By deploy
git log --oneline origin/production -1
```

## Bisect with Skip

```bash
# Skip untestable commits (exit 125)
git bisect run bash -c '
  npm run build 2>/dev/null || exit 125
  npm test -- --testPathPattern="specific" || exit 1
'
```

## Handling Merge Commits

```bash
# Bisect only main branch merge points
git bisect start --first-parent
```

## Cleanup

Always reset when done: `git bisect reset`
