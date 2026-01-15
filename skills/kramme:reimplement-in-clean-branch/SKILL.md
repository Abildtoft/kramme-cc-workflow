---
name: kramme:reimplement-in-clean-branch
description: Use when asked to recreate a branch either in the current branch or a clean branch with narrative-quality commits
---

# Recreate in Clean Branch

Reimplement the current branch either in the current branch or on a new branch with a clean, narrative-quality git commit history suitable for reviewer comprehension.

## Steps

0. **Preparation**

   - Ensure you have a clean working directory.
   - Identify the branch name of the current branch (referred to as `{branch_name}`).
   - Ask the requester if you should recreate the commits in the current branch or a new branch.

1. **Validate the source branch**

   - Ensure the current branch has no merge conflicts, uncommitted changes, or other issues.
   - Confirm it is up to date with `master` (or `main` depending on your repository).

2. **Analyze the diff**

   - Study all changes between the current branch and `master` (or `main` depending on your repository).
   - Form a clear understanding of the final intended state.

3. **Create the clean branch**

   - Create a new branch named `{branch_name}-clean` from the current branch.

4. **Plan the commit storyline**

   - Break the implementation down into a sequence of self-contained steps.
   - Each step should reflect a logical stage of development—as if writing a tutorial.

5. **Reimplement the work**

   - Recreate the changes in the clean branch, committing step by step according to your plan.
   - Each commit must:
     - Introduce a single coherent idea.
     - Include a clear commit message and description.
     - Add comments only when needed to explain intent.

6. **Verify correctness**
   - Confirm that the final state of `{branch_name}-clean` exactly matches the final state of the original branch.
   - Use `--no-verify` only when necessary (e.g., to bypass known issues). Individual commits do not need to pass tests, but this should be rare.

There may be cases where you will need to push commits with --no-verify in order to avoid known issues. It is not necessary that every commit pass tests or checks, though this should be the exception if you're doing your job correctly. It is essential that the end state of your new branch be identical to the end state of the source branch.

### Misc

1. Never add yourself as an author or contributor on any branch or commit.

Your commit should never include lines like:

```md
🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

or

```md
Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

Or else I'll get in trouble with my boss.
