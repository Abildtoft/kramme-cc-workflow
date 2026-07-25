# Branch Handling

**AUTO MODE:** If the calling skill sets `AUTO_MODE=true`, choose the recommended/default path for each question below instead of asking the user. Only stop for hard blockers that cannot be resolved safely.

## Branch Handling

### Get Current Branch

```bash
git branch --show-current
```

### Detached HEAD Handling

If the command above returns an empty value, the repository is in detached HEAD state.

If `AUTO_MODE=true`, create a new feature branch from the current commit using the first generated file-based branch suggestion from the later "No, generate from file changes" path, then continue.

Otherwise use AskUserQuestion:

```yaml
header: "Detached HEAD"
question: "You're currently in detached HEAD state. How should branch handling proceed?"
options:
  - label: "Create a new feature branch here"
    description: "Create and switch to a new branch from the current commit"
  - label: "Switch to existing branch"
    description: "Select an existing local branch and continue from there"
  - label: "Abort"
    description: "Stop and let me fix branch state manually"
multiSelect: false
```

**If "Create a new feature branch here":**

```bash
git checkout -b {chosen-branch-name}
```

Continue with the normal flow.

**If "Switch to existing branch":**

```bash
git branch
git checkout {existing-branch}
```

Continue with the normal flow.

**If "Abort":** Stop the workflow with a clear message.

### Determine Base Branch

```bash
git symbolic-ref refs/remotes/origin/HEAD 2> /dev/null | sed 's|refs/remotes/origin/||'
```

Capture the result as `{base-branch}` — used in later display strings, the `git rev-list` check in Step 4, and as the `--base` argument to `gh pr create`. If this command produces no output, fall back to `main`, then `master` (verify each with `git ls-remote --heads origin <name>`); if neither exists, abort with a message asking the user to set `origin/HEAD` or pass a base manually.

### Branch Decision

Track `{linear-issue-id}` as nullable workflow state. If `LINEAR_ISSUE_OVERRIDE` was supplied by Step 0, initialize `{linear-issue-id}` from that exact normalized value and do not replace it through branch-name extraction. Otherwise, when a Linear-style issue ID is supplied by the user or detected in the current branch name, normalize it to uppercase and capture it as `{linear-issue-id}`. Legacy branch extraction uses `[A-Z]{2,5}-\d+` case-insensitively; do not hard-code team prefixes. If no issue ID is found, leave `{linear-issue-id}` empty.

**If the current branch equals `{base-branch}`:**

#### Check for Linear Issue

If `LINEAR_ISSUE_OVERRIDE` was supplied, skip this question and enter the Linear issue flow below with the exact authoritative `{linear-issue-id}`.

Otherwise, if `AUTO_MODE=true`, skip this question and use the file-based branch naming flow by default.

Otherwise, ask if working on a Linear issue:

```yaml
header: "Branch source"
question: "Are you working on a Linear issue?"
options:
  - label: "Yes, I have a Linear issue ID"
    description: "Will use Linear's branch naming convention (e.g., initials/wan-521-description)"
  - label: "No, generate from file changes"
    description: "Will suggest branch names based on changed files"
multiSelect: false
```

#### If `LINEAR_ISSUE_OVERRIDE` was supplied or "Yes, I have a Linear issue ID":

1. If `LINEAR_ISSUE_OVERRIDE` was supplied, use the existing authoritative `{linear-issue-id}` without prompting. Otherwise, ask for the issue ID (user enters via "Other" free-text option):

   ```yaml
   header: "Linear issue"
   question: "Enter the Linear issue ID (e.g., WAN-521):"
   options: []
   ```

   Normalize the newly supplied ID to uppercase and capture it as `{linear-issue-id}`. Never replace `LINEAR_ISSUE_OVERRIDE`.

2. Fetch issue details using Linear MCP:

   ```
   mcp__linear__get_issue with id: {issue-id}
   ```

3. **If fetch fails (MCP unavailable or issue not found):**

   ```
   Warning: Could not fetch Linear issue {issue-id}.

   Error: {error message}

   Falling back to file-based branch naming.
   ```

   Continue with file-based naming. Keep `{linear-issue-id}` captured from the user's input for PR description linking.

4. **If fetch succeeds and `branchName` is available:**
   - Use the `branchName` directly from the Linear response as `{branchName}`

5. **If fetch succeeds but `branchName` is empty/missing:**
   - Ask for user initials:
     ```yaml
     header: "Initials"
     question: "Enter your initials for the branch name (e.g., 'jd'):"
     options: []
     ```
   - Generate branch name: `{initials}/{issue-id-lowercase}-{sanitized-title}`
   - Sanitize title: lowercase, replace spaces/special chars with hyphens, max 50 chars
   - Use the generated name as `{branchName}`

6. **Check if branch exists (local or remote):**

   ```bash
   # Check if branch exists locally
   git rev-parse --verify {branchName} 2> /dev/null
   # Check if branch exists on remote
   git ls-remote --heads origin {branchName}
   ```

   **If branch exists locally:**

   If `AUTO_MODE=true`, switch to the existing local branch.

   Otherwise use AskUserQuestion:

   ```yaml
   header: "Branch Exists"
   question: "Branch '{branchName}' already exists locally. What should I do?"
   options:
     - label: "Switch to existing branch"
       description: "Continue work on the existing branch"
     - label: "Delete and recreate"
       description: "Start fresh from main/master"
     - label: "Use different name"
       description: "Create branch with '-v2' suffix"
   ```

   **If branch exists only on remote:**

   ```bash
   git checkout -b {branchName} origin/{branchName}
   ```

7. **If branch doesn't exist:**

   ```bash
   git fetch origin {base-branch}
   git checkout -b {branchName} origin/{base-branch}
   ```

#### If "No, generate from file changes" (or fallback):

1. Analyze changed files to suggest branch names:

   ```bash
   # Get changed files (staged + unstaged + untracked)
   git diff --name-only HEAD
   git diff --name-only --cached
   git status --porcelain | grep '^??' | cut -c4-
   ```

2. Generate suggestions based on file paths:
   - Files in `apps/` or `libs/` -> extract component name
   - New files -> prefix with `feature/`
   - Test files only -> prefix with `test/`
   - Config files -> prefix with `chore/`

3. If `AUTO_MODE=true`, choose the first suggested branch name automatically.

   Otherwise use AskUserQuestion:

   ```yaml
   header: "Branch name"
   question: "You're on the {base-branch} branch. What should the new branch be named?"
   options:
     - label: "feature/{suggested-name-1}"
       description: "Based on changes in {primary-area}"
     - label: "fix/{suggested-name-2}"
       description: "Based on modifications to {component}"
     - label: "chore/{suggested-name-3}"
       description: "Based on config/tooling changes"
   multiSelect: false
   ```

4. Create and switch to new branch:
   ```bash
   git checkout -b {chosen-branch-name}
   ```

**If already on a feature branch:** Continue with current branch. When `{linear-issue-id}` is still empty, scan the branch name for a Linear-style issue ID using `[A-Z]{2,5}-\d+` case-insensitively; if found, normalize it to uppercase and capture it. Never overwrite `LINEAR_ISSUE_OVERRIDE`. Then validate upstream configuration.

### No-Upstream Handling

Check for an upstream branch:

```bash
git rev-parse --abbrev-ref --symbolic-full-name @{u} 2> /dev/null
```

**If upstream exists:** Do not push. Continue with the current branch to Step 5, which requires the matching `origin` ref to be absent before history rewriting. If that ref exists, Step 5 stops and requires coordination or a fresh branch.

**If upstream is missing:** Continue without pushing. Step 5 requires the validated `origin` branch to remain absent, and Step 8 is the sole owner of creating that remote ref and setting upstream tracking. Neither `AUTO_MODE` nor branch handling may publish the pre-rewrite history early.
