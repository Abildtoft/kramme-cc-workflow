# Suggested Permissions

For the best experience with this plugin, add these permissions to your Claude Code `settings.json`. This reduces approval prompts for common operations.

## Core

Safe permissions for status checks and analysis only:

```json
{
  "permissions": {
    "allow": [
      "Bash(git status *)",
      "Bash(git diff *)",
      "Bash(git log *)",
      "Bash(git branch *)",
      "Bash(git rev-parse *)",
      "Bash(git show *)",
      "Bash(git show-ref *)",
      "Bash(git show-branch *)",
      "Bash(git ls-files *)",
      "Bash(git ls-remote *)",
      "Bash(git remote *)",
      "Bash(git symbolic-ref *)",
      "Bash(git symbolic-ref * | sed *)",
      "Bash(git merge-base *)",
      "Bash(git rev-list *)",
      "Bash(gh pr view *)",
      "Bash(gh pr checks *)",
      "Bash(gh pr diff *)",
      "Bash(gh run list *)",
      "Bash(gh run view *)",
      "Bash(glab mr view *)",
      "Bash(glab mr list *)",
      "Bash(glab ci status *)",
      "Bash(glab ci list *)",
      "Bash(glab ci view *)",
      "mcp__linear__get_issue",
      "mcp__linear__list_issues",
      "mcp__linear__list_comments",
      "mcp__linear__list_teams",
      "mcp__linear__get_team",
      "mcp__linear__list_projects",
      "mcp__linear__get_project",
      "mcp__linear__list_issue_labels",
      "mcp__linear__list_issue_statuses",
      "mcp__linear__list_cycles",
      "mcp__linear__list_users",
      "mcp__linear__get_user",
      "mcp__linear__get_document",
      "mcp__linear__list_documents",
      "mcp__linear__search_documentation"
    ]
  }
}
```

## Extended

Additional permissions that build on Core. Enables full plugin workflows including PR creation, commit management, and verification. **Add these alongside the Core permissions above.**

> **Warning:** This set gives Claude Code significant autonomy, including destructive git operations (`git push`, `git reset`, `git rebase`). Only use these permissions on projects where you have full control, or scope them to specific projects in your settings.

```json
{
  "permissions": {
    "allow": [
      "Bash(git add *)",
      "Bash(git commit *)",
      "Bash(git checkout *)",
      "Bash(git stash *)",
      "Bash(git fetch *)",
      "Bash(git push *)",
      "Bash(git reset *)",
      "Bash(git rebase *)",
      "Bash(git branch -D *)",
      "Bash(GIT_SEQUENCE_EDITOR=true git rebase *)",
      "Bash(gh pr create *)",
      "Bash(gh api *)",
      "Bash(glab mr create *)",
      "Bash(glab mr note *)",
      "Bash(glab ci trace *)",
      "Bash(glab ci retry *)",
      "Bash(glab ci run *)",
      "Bash(glab api *)",
      "Bash(nx show *)",
      "Bash(nx affected *)",
      "Bash(nx format *)",
      "Bash(nx lint *)",
      "Bash(nx build *)",
      "Bash(nx test *)",
      "Bash(nx typecheck *)",
      "Bash(nx e2e *)",
      "Bash(nx run *)",
      "Bash(yarn exec nx *)",
      "Bash(corepack yarn nx *)",
      "Bash(dotnet restore *)",
      "Bash(dotnet build *)",
      "Bash(dotnet test *)",
      "Bash(dotnet format *)",
      "Bash(dotnet ef *)",
      "Bash(npm run test *)",
      "Bash(npm run lint *)",
      "Bash(npm run format *)",
      "Bash(npm run typecheck *)",
      "Bash(npm run build *)",
      "Bash(prettier *)",
      "Bash(eslint *)",
      "Bash(tsc *)",
      "Bash(cat package.json *)",
      "Bash(find *)",
      "mcp__gitlab__get_merge_request",
      "mcp__gitlab__create_merge_request",
      "mcp__gitlab__list_pipelines",
      "mcp__gitlab__get_pipeline",
      "mcp__gitlab__list_pipeline_jobs",
      "mcp__gitlab__get_pipeline_job_output",
      "mcp__gitlab__mr_discussions",
      "mcp__gitlab__get_branch_diffs",
      "mcp__gitlab__list_commits"
    ]
  }
}
```
