---
name: kramme:recreate-commits
description: Recreate current branch with narrative-quality commits in-place, creating logical, reviewer-friendly commit history.
---

# Recreate Commits

Invoke the `kramme:recreate-commits` skill to recreate your current branch with narrative-quality commits.

## What This Does

1. Validates the source branch (no conflicts, uncommitted changes)
2. Analyzes all changes against main/master
3. Resets the current branch to merge base and recreates commits in-place
4. Reimplements changes with logical, self-contained commits
5. Verifies the final state matches the original

## Usage

Run `/kramme:recreate-commits` on any feature branch to rewrite it with reviewer-friendly commits.

## Invoke

Use the Skill tool to invoke `kramme:recreate-commits`:

```
skill: "kramme:recreate-commits"
```
