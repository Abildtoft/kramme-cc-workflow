# Usage examples

Load this only when the user asks for examples or when validating argument parsing behavior.

## Full review

```text
/kramme:pr:code-review
```

## Specific aspects

```text
/kramme:pr:code-review tests errors
# Reviews only test coverage and error handling

/kramme:pr:code-review comments
# Reviews only code comments

/kramme:pr:code-review performance
# Performance and scalability review only

/kramme:pr:code-review refactor
# Review-only reuse, composition, and codebase-fit cleanup findings

/kramme:pr:code-review simplify
# Opt-in simplifier pass. Run after the main review is clean.
```

## Parallel review

```text
/kramme:pr:code-review all parallel
# Deprecated alias for --parallel

/kramme:pr:code-review all --parallel
# LAUNCH_MODE=parallel; spawns all applicable agents simultaneously
```

## Emphasize specific dimensions

```text
/kramme:pr:code-review --emphasize security
# Run all applicable agents, elevating security findings without downgrading other validated issues

/kramme:pr:code-review --emphasize security errors
# Elevate both security and error-handling findings

/kramme:pr:code-review tests errors --emphasize errors
# Run only test+error agents, elevate error findings

/kramme:pr:code-review comments --emphasize security
# Invalid: security is not in the active review set, so the command should stop with an error
```

## Custom base branch

```text
/kramme:pr:code-review --base develop
# Diffs against develop instead of auto-detecting the base
```

## Inline report

```text
/kramme:pr:code-review --inline
# Replies with the full report instead of writing REVIEW_OVERVIEW.md
```
