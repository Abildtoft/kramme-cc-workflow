# Usage examples

Load this only when the user asks for examples or when validating argument parsing behavior.

## Full review

```text
/trackbed:pr:code-review
# Runs all applicable reviewers, including lean/refactor/simplify cleanup dimensions
```

## Specific aspects

```text
/trackbed:pr:code-review tests errors
# Reviews only test coverage and error handling

/trackbed:pr:code-review comments
# Reviews only code comments

/trackbed:pr:code-review performance
# Performance and scalability review only

/trackbed:pr:code-review architecture
# Module design only: interface depth, public-interface changes, internal imports, and locality

/trackbed:pr:code-review lean
# Deletion-focused review: existing-code, stdlib, native, dependency, and YAGNI opportunities

/trackbed:pr:code-review refactor
# Focus only on reuse, composition, and codebase-fit cleanup findings

/trackbed:pr:code-review simplify
# Focus only on clarity and maintainability simplification findings
```

## Parallel review

```text
/trackbed:pr:code-review all parallel
# Deprecated alias for --parallel

/trackbed:pr:code-review all --parallel
# LAUNCH_MODE=parallel; spawns all applicable agents simultaneously
```

## Emphasize specific dimensions

```text
/trackbed:pr:code-review --emphasize security
# Run all applicable agents, elevating security findings without downgrading other validated issues

/trackbed:pr:code-review --emphasize security errors
# Elevate both security and error-handling findings

/trackbed:pr:code-review tests errors --emphasize errors
# Run only test+error agents, elevate error findings

/trackbed:pr:code-review comments --emphasize security
# Invalid: security is not in the active review set, so the command should stop with an error
```

## Custom base branch

```text
/trackbed:pr:code-review --base develop
# Diffs against develop instead of auto-detecting the base
```

## Previous review artifact

```text
/trackbed:pr:code-review --previous-review ../old-workspace/REVIEW_OVERVIEW.md
# Uses an explicit previous-cycle report for addressed-finding filtering and open-finding carry-forward
```

## Inline report

```text
/trackbed:pr:code-review --inline
# Replies with the full report instead of writing REVIEW_OVERVIEW.md
```
