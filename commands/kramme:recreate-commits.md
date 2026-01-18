---
name: kramme:recreate-commits
description: Recreate current branch with narrative-quality commits. Creates a clean branch with logical, reviewer-friendly commit history.
---

# Recreate Commits

Invoke the `kramme:recreate-commits` skill to create a clean branch with narrative-quality commits from the current branch.

## What This Does

1. Validates the source branch (no conflicts, uncommitted changes)
2. Analyzes all changes against main/master
3. Creates a new `{branch}-clean` branch
4. Reimplements changes with logical, self-contained commits
5. Verifies the final state matches the original

## Usage

Run `/kramme:recreate-commits` on any feature branch to create a clean version with reviewer-friendly commits.

## Invoke

Use the Skill tool to invoke `kramme:recreate-commits`:

```
skill: "kramme:recreate-commits"
```
