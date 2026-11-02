---
title: "{Title}"
date: "{YYYY-MM-DD}"
status: "active"
source: "{source-label}"
related_files:
  - "{repo-relative/path}"
last_checked: "{YYYY-MM-DD}"
---

# {Title}

## Problem

{What failed or kept recurring? Name the observable symptom and why it mattered.}

## Context

{What codebase area, workflow, environment, or constraint made this problem appear?}

## When this applies

- {Concrete signal or precondition that means this lesson is relevant.}
- {Another signal, command output, error shape, or workflow state.}

## Failed approaches

- {Approach tried or considered} — {why it failed, was risky, or was rejected.}
- {Another approach, including "do nothing" when applicable} — {reason rejected.}

## Final approach

{Describe the approach that worked. Keep this practical enough for a future agent or maintainer to repeat.}

## Code references

- `{repo-relative/path}` — {what to inspect or reuse there.}

## Tests / verification

- {Command, test, manual check, or evidence that proved the solution.}

## Reuse cautions

- {When not to reuse this solution.}
- {Assumption that must be checked before applying the pattern elsewhere.}
