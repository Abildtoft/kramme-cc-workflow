---
name: kramme:code:cleanup-ai
description: Remove AI-generated code slop from a branch. Use when cleaning up AI-generated code, removing unnecessary comments, defensive checks, or type casts. Checks diff against main and fixes style inconsistencies.
disable-model-invocation: true
user-invocable: true
---

# Remove AI Code Slop

This command uses the `kramme:deslop-reviewer` agent to identify AI slop, then fixes the identified issues.

## Process

1. **Scan for slop**
   - Launch `kramme:deslop-reviewer` in code review mode
   - Detect the base branch using a 3-tier strategy and get the diff:
     1. If the caller provided a base branch explicitly (for example, "Use `develop` as the base"), use it directly
     2. Otherwise, query the PR/MR target branch with explicit host/CLI checks:
     ```bash
     REMOTE_URL=$(git remote get-url origin 2>/dev/null)
     if printf '%s' "$REMOTE_URL" | grep -q 'github.com' && command -v gh >/dev/null 2>&1; then
       BASE_BRANCH=$(gh pr view --json baseRefName --jq '.baseRefName' 2>/dev/null)
     elif printf '%s' "$REMOTE_URL" | grep -qi 'gitlab' && command -v glab >/dev/null 2>&1; then
       BASE_BRANCH=$(glab mr view --json target_branch --jq '.target_branch' 2>/dev/null)
     elif command -v glab >/dev/null 2>&1; then
       BASE_BRANCH=$(glab mr view --json target_branch --jq '.target_branch' 2>/dev/null)
     fi
     ```
     3. If no PR/MR or query fails, fall back:
     ```bash
     BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
     [ -z "$BASE_BRANCH" ] && BASE_BRANCH=$(git branch -r | grep -E 'origin/(main|master)$' | head -1 | sed 's@.*origin/@@')
     ```
     Normalize before diffing:
     ```bash
     BASE_BRANCH=${BASE_BRANCH#refs/heads/}
     BASE_BRANCH=${BASE_BRANCH#refs/remotes/origin/}
     BASE_BRANCH=${BASE_BRANCH#origin/}
     if [ -z "$BASE_BRANCH" ]; then
       echo "Error: Could not determine base branch. Re-run with --base <ref>." >&2
       exit 1
     fi
     if ! git check-ref-format --branch "$BASE_BRANCH" >/dev/null 2>&1; then
       echo "Error: Base branch '$BASE_BRANCH' is not a valid branch name. Re-run with --base <ref>." >&2
       exit 1
     fi
     if ! git fetch origin "refs/heads/${BASE_BRANCH}:refs/remotes/origin/${BASE_BRANCH}" 2>/dev/null; then
       echo "Error: Failed to fetch origin/$BASE_BRANCH. Check remote access and re-run with --base <ref>." >&2
       exit 1
     fi
     if ! git rev-parse --verify --quiet "origin/$BASE_BRANCH" >/dev/null; then
       echo "Error: Base branch 'origin/$BASE_BRANCH' not found. Re-run with --base <ref>." >&2
       exit 1
     fi
     ```
     Then get the diff:
     ```bash
     git diff origin/$BASE_BRANCH...HEAD
     ```
   - Agent identifies slop patterns in changed files

2. **Review findings**
   - Present the slop findings to understand what will be changed
   - Findings include file:line references and explanations

3. **Fix identified slop**
   - For each slop finding, edit the file to remove the pattern:
     - Remove unnecessary comments
     - Remove excessive defensive checks/try-catch blocks
     - Replace `any` casts with proper types where possible
     - Align style with the rest of the file

4. **Report summary**
   - Provide a 1-3 sentence summary of what was changed
   - List files that were modified

## Slop Patterns (Quick Reference)

- **Unnecessary comments**: Comments describing obvious code or over-documenting
- **Defensive overkill**: Try-catch/null checks where not needed
- **Type workarounds**: `any` casts, `@ts-ignore` without justification
- **Style inconsistencies**: Different patterns than the rest of the file
- **Over-engineering**: Unnecessary abstractions for simple operations
