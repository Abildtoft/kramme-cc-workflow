# Platform Detection and Branch Handling

## Platform Detection

Parse the remote URL from the pre-validation step:

```bash
REMOTE_URL=$(git remote get-url origin)
```

**Detection logic:**

| URL Contains | Platform | CLI Tool |
|--------------|----------|----------|
| `github.com` | GitHub | `gh` |
| `gitlab.com` | GitLab | `glab` or MCP |
| `consensusaps` | GitLab | `glab` or MCP |

**If platform cannot be determined:**

Use AskUserQuestion:
```yaml
header: "Platform"
question: "Could not detect platform from remote URL. Which platform are you using?"
options:
  - label: "GitHub"
    description: "Will create a Pull Request using the gh CLI"
  - label: "GitLab"
    description: "Will create a Pull Request using glab CLI or MCP tools"
multiSelect: false
```

Store the detected platform for later steps.

---

## Branch Handling

### Get Current Branch

```bash
git branch --show-current
```

### Determine Main Branch

```bash
git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||'
```

If this fails, try `main` then `master`.

### Branch Decision

**If current branch is `main` or `master`:**

#### Check for Linear Issue

First, ask if working on a Linear issue:

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

#### If "Yes, I have a Linear issue ID":

1. Ask for the issue ID (user enters via "Other" free-text option):
   ```yaml
   header: "Linear issue"
   question: "Enter the Linear issue ID (e.g., WAN-521):"
   options: []
   ```

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
   Continue with file-based naming.

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
   git rev-parse --verify {branchName} 2>/dev/null

   # Check if branch exists on remote
   git ls-remote --heads origin {branchName}
   ```

   **If branch exists locally:**

   Use AskUserQuestion:

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
   # Determine base branch
   BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||') || BASE="main"

   # Fetch latest
   git fetch origin $BASE

   # Create branch from latest base
   git checkout -b {branchName} origin/$BASE
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

3. Use AskUserQuestion:
   ```yaml
   header: "Branch name"
   question: "You're on the main branch. What should the new branch be named?"
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

**If already on a feature branch:**
Continue with current branch. No action needed.
