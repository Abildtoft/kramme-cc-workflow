---
name: kramme:iterate-pr
description: Iterate on a PR until CI passes. Use when you need to fix CI failures, address review feedback, or continuously push fixes until all checks are green. Automates the feedback-fix-push-wait cycle. Works with both GitHub and GitLab.
---

# Iterate on PR Until CI Passes

Continuously iterate on the current branch until all CI checks pass and review feedback is addressed.

**Requires**: GitHub CLI (`gh`) or GitLab CLI (`glab`) authenticated and available.

## Step 0: Detect Platform

Determine whether this is a GitHub or GitLab repository:

```bash
git remote -v | head -1
```

- If remote contains `github.com` → use **GitHub** commands
- If remote contains `gitlab.com` or other GitLab instance → use **GitLab** commands

---

## GitHub Flow

### Step 1: Identify the PR

```bash
gh pr view --json number,url,headRefName,baseRefName
```

If no PR exists for the current branch, stop and inform the user.

### Step 2: Check CI Status First

```bash
gh pr checks --json name,state,bucket,link,workflow
```

The `bucket` field categorizes state into: `pass`, `fail`, `pending`, `skipping`, or `cancel`.

**Important:** If any of these checks are still `pending`, wait before proceeding:
- `sentry` / `sentry-io`
- `codecov`
- `cursor` / `bugbot` / `seer`
- Any linter or code analysis checks

These bots may post additional feedback comments once their checks complete. Waiting avoids duplicate work.

### Step 3: Gather Review Feedback

**Review Comments and Status:**
```bash
gh pr view --json reviews,comments,reviewDecision
```

**Inline Code Review Comments:**
```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments
```

**PR Conversation Comments (includes bot comments):**
```bash
gh api repos/{owner}/{repo}/issues/{pr_number}/comments
```

### Step 4: Investigate Failures

```bash
# List recent runs for this branch
gh run list --branch $(git branch --show-current) --limit 5 --json databaseId,name,status,conclusion

# View failed logs for a specific run
gh run view <run-id> --log-failed
```

Do NOT assume what failed based on the check name alone. Always read the actual logs.

### Step 5-7: Fix, Commit, Push

See common steps below.

### Step 8: Wait for CI

```bash
gh pr checks --watch --interval 30
```

This waits until all checks complete. Exit code 0 means all passed, exit code 1 means failures.

---

## GitLab Flow

### Step 1: Identify the PR

**Using GitLab MCP server (preferred if available):**
```
mcp__gitlab__get_merge_request with source_branch: <current-branch>
```

**Using glab CLI:**
```bash
glab mr view --web=false
```

**Using glab to list PRs for current branch:**
```bash
glab mr list --source-branch=$(git branch --show-current)
```

If no PR exists for the current branch, stop and inform the user.

### Step 2: Check CI Status First

**Using GitLab MCP server (preferred):**
```
mcp__gitlab__list_pipelines with ref: <current-branch>
mcp__gitlab__get_pipeline with pipeline_id: <id>
mcp__gitlab__list_pipeline_jobs with pipeline_id: <id>
```

**Using glab CLI:**
```bash
# View pipeline status for current branch
glab ci status

# List recent pipelines
glab ci list --branch $(git branch --show-current)

# View specific pipeline
glab ci view <pipeline-id>
```

Pipeline statuses: `created`, `waiting_for_resource`, `preparing`, `pending`, `running`, `success`, `failed`, `canceled`, `skipped`, `manual`, `scheduled`.

**Important:** If pipeline is still `running` or `pending`, wait before proceeding.

### Step 3: Gather Review Feedback

**Using GitLab MCP server (preferred):**
```
mcp__gitlab__get_merge_request with merge_request_iid: <iid>
mcp__gitlab__mr_discussions with merge_request_iid: <iid>
```

**Using glab CLI:**
```bash
# View PR details including approval status
glab mr view <mr-iid>

# View PR notes/comments
glab mr note list <mr-iid>
```

### Step 4: Investigate Failures

**Using GitLab MCP server (preferred):**
```
mcp__gitlab__list_pipeline_jobs with pipeline_id: <id>, scope: "failed"
mcp__gitlab__get_pipeline_job_output with job_id: <id>
```

**Using glab CLI:**
```bash
# List jobs in a pipeline
glab ci list --pipeline <pipeline-id>

# View job log (trace)
glab ci trace <job-id>

# Or view the entire pipeline's failed jobs
glab ci view <pipeline-id> --web=false
```

Do NOT assume what failed based on the job name alone. Always read the actual logs.

### Step 5-7: Fix, Commit, Push

See common steps below.

### Step 8: Wait for CI

**Using glab CLI:**
```bash
# Watch pipeline status
glab ci status --live

# Or poll manually
glab ci status --branch $(git branch --show-current)
```

---

## Common Steps (Both Platforms)

### Step 5: Validate Feedback

For each piece of feedback (CI failure or review comment):

1. **Read the relevant code** - Understand the context before making changes
2. **Verify the issue is real** - Not all feedback is correct; reviewers and bots can be wrong
3. **Check if already addressed** - The issue may have been fixed in a subsequent commit
4. **Skip invalid feedback** - If the concern is not legitimate, move on

### Step 6: Address Valid Issues

Make minimal, targeted code changes. Only fix what is actually broken.

### Step 7: Commit and Push

```bash
git add -A
git commit -m "<descriptive message of what was fixed>"
git push origin $(git branch --show-current)
```

### Step 9: Repeat

Return to Step 2 if:
- Any CI checks failed
- New review feedback appeared

Continue until all checks pass and no unaddressed feedback remains.

---

## Exit Conditions

**Success:**
- All CI checks are green
- No unaddressed human review feedback

**Ask for Help:**
- Same failure persists after 3 attempts (likely a flaky test or deeper issue)
- Review feedback requires clarification or decision from the user
- CI failure is unrelated to branch changes (infrastructure issue)

**Stop Immediately:**
- No PR exists for the current branch
- Branch is out of sync and needs rebase (inform user)

---

## Tips

**GitHub:**
- Use `gh pr checks --required` to focus only on required checks
- Use `gh run view <run-id> --verbose` to see all job steps, not just failures
- If a check is from an external service, the `link` field provides the URL

**GitLab:**
- Use `glab ci retry <job-id>` to retry a single failed job
- Use `glab ci run` to trigger a new pipeline manually
- Check for `allow_failure: true` jobs that don't block the pipeline
- Use the GitLab MCP server tools when available for richer data access
