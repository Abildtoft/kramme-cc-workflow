---
name: kramme:git:recreate-commits
description: Use when asked to recreate commits with narrative-quality history on the current branch.
disable-model-invocation: true
user-invocable: true
---

Reimplement the current branch with a clean, narrative-quality git commit history suitable for reviewer comprehension. By default, recreate commits on the current branch (not a new clean branch).

### Steps

1. **Validate the source branch**
   - Identify the current branch name and the base branch (`master` or `main`).
   - If on `main` or `master`, stop and ask the user to switch to a feature branch first.
   - **Fetch and update the local base branch** to ensure it matches the remote:
     ```bash
     git fetch origin <base-branch>
     git checkout <base-branch>
     git merge --ff-only origin/<base-branch>
     git checkout -  # return to feature branch
     ```
     If the fast-forward merge fails (local base branch has diverged from remote), abort and ask the user to resolve manually before retrying.
   - Ensure the current branch has no merge conflicts, uncommitted changes, or other issues.
   - Confirm it is up to date with the base branch.

2. **Analyze the diff**
   - Study all changes between the current branch and `master` (or `main` depending on your repository).
   - Form a clear understanding of the final intended state.

3. **Prepare the branch**
   - By default, work on the current branch. Do NOT create a `{branch_name}-clean` branch unless explicitly requested.
   - If explicitly asked to use a clean branch, create `{branch_name}-clean` from the merge base with main/master.

4. **Plan the commit storyline**

   **Assess diff size and ask about granularity.** After analyzing the diff, assess whether the PR is large (many files changed, significant lines added/removed, multiple distinct features or areas touched). If the diff is large, ask the user which granularity level they want before planning:

   - **Coarse** — One commit per major grouping (~5-15 commits)
   - **Medium (recommended)** — Break each major grouping into several commits (~15-30 commits)
   - **Fine** — Recursively break down until each commit is a significant, self-standing change (~30-60+ commits)

   For normal-sized PRs, skip this question and plan as usual.

   **Use recursive decomposition to plan commits:**

   1. **First pass:** Identify the major groupings of work (e.g., "add auth middleware", "implement user API", "add tests"). For **coarse** granularity, stop here — each grouping becomes one commit.
   2. **Second pass:** Break each major grouping into sub-steps (e.g., "add auth middleware" becomes: add dependencies, implement token validation, add middleware registration, add config). For **medium** granularity, stop here.
   3. **Third pass (fine only):** Selectively break sub-steps further, but only where a piece is a significant, self-standing addition (e.g., a substantial new function or module). Do not split trivial one-liner changes or tightly coupled changes that belong together.

   Flatten the tree into a linear commit sequence that tells a coherent narrative — each step should reflect a logical stage of development, as if writing a tutorial.

5. **Reimplement the work**
   - Reset the branch to the merge base with main/master.
   - Recreate the changes, committing step by step according to your plan.
   - Each commit must:
     - Introduce a single coherent idea.
     - Include a clear commit message and description.
     - Add comments or inline GitHub comments when needed to explain intent.

6. **Verify correctness**
   - Confirm that the final state of the branch exactly matches the final intended state (same as before the reset).
   - Use `--no-verify` only when necessary (e.g., to bypass known issues). Individual commits do not need to pass tests, but this should be rare.

There may be cases where you will need to push commits with --no-verify in order to avoid known issues. It is not necessary that every commit pass tests or checks, though this should be the exception if you're doing your job correctly. It is essential that the end state of the branch be identical to the original end state before the reset.

### Misc

1. Never add yourself as an author or contributor on any branch or commit.
2. Write your pull reuqest following the same instructions as in the pr.md command file.
3. In your pull request, include a link to the original branch.

Your commit should never include lines like:

```md
🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

or

```md
Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

Or else I'll get in trouble with my boss.