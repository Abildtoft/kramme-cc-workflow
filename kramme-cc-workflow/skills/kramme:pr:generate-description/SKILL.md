---
name: kramme:pr:generate-description
description: Write a structured PR title and body from git diff, commit log, and Linear context. Outputs markdown for copy-paste or updates the PR directly with --direct.
argument-hint: "[--non-interactive] [--direct] [--visual] [--base <ref>]"
disable-model-invocation: true
user-invocable: true
---

# PR Description Generator

## Parse Arguments

Parse `$ARGUMENTS` for flags:

- `--non-interactive`: Skip clarification prompts (Phase 2.5) and save-to-file prompt (Phase 4). Generate the description directly from gathered context without pausing for user input.
- `--direct`: Find the existing PR for the current branch and update its title and description directly. Skips copy-paste output and save-to-file prompt. Implies `--non-interactive`.
- `--visual`: Auto-detect a running dev server and capture screenshots to embed in the PR description. Requires a browser MCP to be available (claude-in-chrome, chrome-devtools, or playwright).
- `--base <ref>`: Use `<ref>` as the base branch for diff computation instead of auto-detecting.

If `--non-interactive` is present, set `NON_INTERACTIVE=true` and remove the flag from remaining arguments.
If `--direct` is present, set `DIRECT_UPDATE=true` and `NON_INTERACTIVE=true`, and remove the flag from remaining arguments.
If `--visual` is present, set `VISUAL_MODE=true` and remove the flag from remaining arguments.
If `--base <ref>` is present, set `BASE_BRANCH_OVERRIDE=<ref>` and remove the flag and value from remaining arguments.

## Instructions

### When to Use This Skill

**Use this skill when:**

- You're ready to create a Pull Request
- You want a well-structured, comprehensive description for your changes
- You need to document what changed, why it changed, and how to test it
- You want to analyze multiple sources (git diff, commits, Linear issues) to create complete context

**When NOT to use this skill:**

- The PR already has a description and you just need to update it
- You're creating a draft PR that doesn't need a full description yet
- The changes are trivial (typo fixes, formatting) and don't warrant detailed documentation

### Context

High-quality PR descriptions are essential for:

- Code reviewers to understand the context and intent of changes
- Future developers investigating the history of a feature
- Product/project managers tracking feature delivery
- Creating an audit trail of technical decisions

This skill automates the process of gathering context from multiple sources (git history, Linear issues, code changes) and generating a structured, comprehensive description following best practices for Pull Requests.

### Guideline Keywords

When used, these keywords indicate the strength and requirement level of guidelines:

- **ALWAYS** — Mandatory requirement, exceptions are very rare and must be explicitly approved
- **NEVER** — Strong prohibition, exceptions are very rare and must be explicitly approved
- **PREFER** — Strong recommendation, exceptions allowed with justification
- **CAN** — Optional, developer's discretion
- **NOTE** — Context, rationale, or clarification
- **EXAMPLE** — Illustrative example

Strictness hierarchy: ALWAYS/NEVER > PREFER > CAN > NOTE/EXAMPLE

## Workflow

### Phase 1: Platform Detection

**ALWAYS** detect which platform is being used:

1. Check git remote URL:

   ```bash
   git remote get-url origin
   ```

   - Contains `gitlab.com` or `consensusaps` → GitLab
   - Contains `github.com` → GitHub

2. **ALWAYS** verify you have access to the appropriate tools:

   - GitLab: GitLab MCP server tools (`mcp__gitlab__*`)
   - GitHub: `gh` CLI tools via Bash

3. **ALWAYS** confirm the current branch:

   ```bash
   git branch --show-current
   ```

4. **ALWAYS** detect and identify the base/target branch dynamically using a 3-tier strategy:

   **Tier 1: Explicit override**
   If `BASE_BRANCH_OVERRIDE` was set from `--base`, use that value directly.

   **Tier 2: PR/MR target branch detection**
   Query the platform for the actual target branch:
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
   - GitLab MCP alternative if `glab` is unavailable: use `mcp__gitlab__get_merge_request` and extract `target_branch`

   **Tier 3: Fallback**
   ```bash
   BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
   [ -z "$BASE_BRANCH" ] && BASE_BRANCH=$(git branch -r | grep -E 'origin/(main|master)$' | head -1 | sed 's@.*origin/@@')
   ```
   Normalize before using `origin/$BASE_BRANCH`:
   ```bash
   BASE_BRANCH=${BASE_BRANCH#refs/heads/}
   BASE_BRANCH=${BASE_BRANCH#refs/remotes/origin/}
   BASE_BRANCH=${BASE_BRANCH#origin/}
   if [ -z "$BASE_BRANCH" ]; then
     echo "Error: Could not determine base branch. Re-run with --base <ref>." >&2
     exit 1
   fi
   if ! git rev-parse --verify --quiet "origin/$BASE_BRANCH" >/dev/null; then
     echo "Error: Base branch 'origin/$BASE_BRANCH' not found. Re-run with --base <ref>." >&2
     exit 1
   fi
   echo "Base branch: $BASE_BRANCH"
   ```
   - **NOTE**: Tier 2 ensures correct scope when MR targets a non-default branch (e.g., a feature branch with other merged MRs)
   - **CAN** ask user if unclear or override needed

5. **If `DIRECT_UPDATE=true`**, verify a PR exists for the current branch:

   **GitHub:**
   ```bash
   gh pr view --json number,url
   ```

   **GitLab:**
   ```bash
   glab mr view
   ```
   Or use MCP: `mcp__gitlab__list_merge_requests` filtered to the current branch.

   **If no PR exists**, abort:
   ```
   Error: No PR found for the current branch.

   The --direct flag requires an existing PR to update.
   Either create a PR first, or run without --direct to generate a description for copy-paste.
   ```

### Phase 2: Context Gathering

**ALWAYS** gather comprehensive context from all available sources.

**IMPORTANT**: Use `origin/$BASE_BRANCH` for all comparisons to ensure you compare against the remote's state, not a potentially stale local branch.

**IMPORTANT**: Spec files and conversation history are for YOUR analysis only to understand implementation decisions. The final PR description should ONLY reference Linear issues as the source of original requirements, since reviewers have access to Linear but not to spec files or conversation history.

#### 2.1 Git Changes Analysis

1. **ALWAYS** get the diff between current branch and base branch:

   ```bash
   git diff origin/$BASE_BRANCH...HEAD
   ```

   - **NOTE**: Use three dots (`...`) to compare from merge base
   - **NOTE**: Use `origin/` prefix to compare against remote state

2. **ALWAYS** get the list of changed files with stats:

   ```bash
   git diff origin/$BASE_BRANCH...HEAD --stat
   ```

3. **ALWAYS** categorize changed files by area:

   - **Frontend**: Files under `Connect/ng-app-monolith/`
   - **Backend**: Files under `Connect/Connect.Api/`, `Connect/Connect.Core/`, etc.
   - **Tests**: Files matching `*.spec.ts`, `*.test.ts`, or under `tests/` directories
   - **Migrations**: Files under `Connect/Connect.Api/Migrations/`
   - **Documentation**: `*.md` files
   - **Configuration**: `*.json`, `*.config.*`, `*.yml` files

4. **CAN** use GitLab/GitHub tools to get branch diffs if available:
   - GitLab: `mcp__gitlab__get_branch_diffs`
   - GitHub: `gh pr diff` (if PR already exists)

#### 2.2 Commit History Analysis

1. **ALWAYS** get commit history for the current branch:

   ```bash
   git log origin/$BASE_BRANCH..HEAD --oneline
   ```

2. **ALWAYS** get detailed commit messages:

   ```bash
   git log origin/$BASE_BRANCH..HEAD --format="%h %s%n%b%n"
   ```

3. **ALWAYS** analyze commits to understand:
   - The narrative/journey of the implementation
   - Key technical decisions mentioned in commit bodies
   - Any referenced issues or tickets

#### 2.3 Linear Issue Context

1. **ALWAYS** check if branch name contains a Linear issue ID:

   - Pattern: `{initials}/{team-issue-id}-{description}`
   - **Known team abbreviations**: WAN, HEA, MEL, POT, FIR, FEG
   - **EXAMPLE**: `mab/wan-521-ensure-that-platform-picker-page-is-only-shown-if-the-user`
   - Extract issue ID: `wan-521` → `WAN-521` (uppercase)
   - **EXAMPLE**: `jd/hea-123-fix-header-bug` → Extract: `HEA-123`
   - **EXAMPLE**: `ab/mel-456-add-new-feature` → Extract: `MEL-456`

2. **ALWAYS** attempt to fetch Linear issue details if issue ID found:

   ```
   mcp__linear__get_issue with issue ID
   ```

3. **ALWAYS** include in context:

   - Issue title
   - Issue description
   - Issue state
   - Related project/labels

4. **ALWAYS** compare implementation against Linear issue description:

   - Check if the actual changes align with what was described in the issue
   - **ALWAYS** note any significant divergences from the original issue scope
   - **ALWAYS** identify if features were added/removed compared to issue description
   - **ALWAYS** note if approach differs from what was requested in the issue
   - **EXAMPLE**: Issue asked for A, but implementation delivers A + B, or implements A differently

5. **CAN** check commit messages for Linear issue references:
   - Pattern: `{TEAM}-{number}` where TEAM is one of: WAN, HEA, MEL, POT, FIR, FEG
   - **EXAMPLE**: `WAN-123`, `Fixes HEA-456`, `Related to MEL-789`

#### 2.4 Code Structure Analysis

1. **ALWAYS** analyze the scope of changes:

   - Frontend-only: Only files under `ng-app-monolith/`
   - Backend-only: Only files under `Connect/` (excluding `ng-app-monolith/`)
   - Full-stack: Changes in both areas
   - Tests-only: Only test files modified
   - Documentation-only: Only `.md` files modified

2. **ALWAYS** identify change characteristics:

   - **New feature**: New files created, new functionality added
   - **Bug fix**: Primarily modifications to existing files, issue mentions "bug" or "fix"
   - **Refactor**: Code reorganization without behavior change
   - **Chore**: Config, dependencies, tooling updates

3. **ALWAYS** check for breaking changes indicators:
   - Database migrations created
   - API endpoint signature changes (parameter changes, return type changes)
   - Public interface/contract changes
   - Configuration schema changes
   - Environment variable additions/removals

#### 2.5 Conversation History and Specification Files Analysis

**ALWAYS** check for implementation decisions and context from the development process:

1. **Specification Files** (commonly created by Structured Implementation Workflow/SIW):

   - **ALWAYS** search for these files in the `siw/` directory:
     - `siw/SPEC.md` - Main specification document
     - `siw/LOG.md` - Implementation log/journal
     - `siw/OPEN_ISSUES_OVERVIEW.md` - Known issues and decisions
     - `siw/IMPLEMENTATION.md` - Implementation notes

   ```bash
   # Search for specification files
   find siw -maxdepth 3 -name "SPEC.md" -o -name "LOG.md" -o -name "OPEN_ISSUES_OVERVIEW.md" -o -name "IMPLEMENTATION.md"
   ```

2. **Read specification files if found**:

   - Extract key technical decisions made during implementation
   - Identify scope changes or refinements
   - Note any deviations from original plan with rationale
   - **ALWAYS** capture divergences from Linear issue description with explanation
   - Capture important constraints or limitations
   - Look for reviewer-relevant context (performance considerations, security implications, etc.)

3. **Review conversation history**:

   - **ALWAYS** scan the current conversation for:
     - Architecture or design decisions discussed with the user
     - Trade-offs explicitly considered (e.g., "chose approach A over B because...")
     - Scope clarifications or boundary decisions
     - **Divergences from Linear issue with reasoning** (e.g., "Changed from X to Y because...")
     - Performance, security, or scalability considerations
     - Known limitations or future work mentioned
     - Any "why" explanations that would help reviewers understand the approach

4. **Capture important decisions and divergences**:
   - **ALWAYS** include significant decisions in the Technical Details section
   - **ALWAYS** document any divergences from the Linear issue description with clear rationale
   - **PREFER** explaining "why" over just "what" for non-obvious choices
   - **EXAMPLE**: "Used debouncing instead of throttling because platform data changes infrequently and we want to avoid unnecessary API calls"
   - **EXAMPLE**: "Linear issue requested email notifications, but implemented push notifications instead after discovering email delivery was unreliable in testing"
   - **NEVER** include trivial decisions or over-explain obvious choices
   - **IMPORTANT**: Spec files (SPEC.md, LOG.md, etc.) and conversation history are for YOUR analysis only
   - **NEVER** reference spec files or conversation history in the PR description (reviewers don't have access to them)
   - **ALWAYS** reference only Linear issues as the source of original requirements when documenting divergences

### Phase 2.5: Analysis and Clarification

**Skip this phase entirely if `NON_INTERACTIVE=true`.** Proceed directly to Phase 3.

**ALWAYS** pause after gathering context and before generating the description:

1. **Present initial analysis**:

   - Summarize what you've found:
     - Change type (feature, bug fix, refactor, etc.)
     - Scope (frontend-only, backend-only, full-stack)
     - Key technical decisions identified
     - **Any divergences from Linear issue description**
     - Any breaking changes detected

2. **Ask clarification questions**:

   - **ALWAYS** ask the user if there's anything specific they want emphasized
   - **ALWAYS** ask if there are any concerns or considerations reviewers should know about
   - **CAN** ask about:
     - Specific areas that need more detailed explanation
     - Known limitations or trade-offs to document
     - Performance or security implications to highlight
     - Future work or follow-up tasks to mention

3. **Example clarification prompt**:

   ```
   I've analyzed the changes and identified this as a [type] that [brief summary].

   Key decisions I found:
   - [Decision 1]
   - [Decision 2]

   Divergences from Linear issue (if any):
   - [Divergence 1 and why]
   - [Divergence 2 and why]

   Before generating the description:
   - Is there anything specific you'd like me to emphasize or explain in detail?
   - Are there any concerns, limitations, or trade-offs reviewers should be aware of?
   - Should I highlight any particular aspects of the implementation?
   - Should I explain any divergences from the original Linear issue in more detail?
   ```

4. **Wait for user response** before proceeding to Phase 3

### Phase 2.6: Browser Detection and App Discovery

**Skip this phase if `VISUAL_MODE` is not set.** Proceed directly to Phase 3.

If `VISUAL_MODE=true`, read `${CLAUDE_PLUGIN_ROOT}/skills/kramme:pr:generate-description/resources/visual-capture.md` and follow **Phase 2.6** in that document to detect a browser MCP and discover the running dev server URL.

### Phase 3: Description Generation

**ALWAYS** generate a structured PR title and description.

#### 3.0 Title Generation

Generate a PR title using [Conventional Commits](https://www.conventionalcommits.org/) format: `<type>(<scope>): <description>`

**NOTE**: Check the project's CLAUDE.md for any project-specific conventional commit rules.

**Types** (based on Phase 2.4 analysis):

| `feat` | `fix` | `refactor` | `docs` | `test` | `build`/`ci` | `chore` | `perf` | `style` | `revert` |

**Rules**:
- **Scope**: Optional. Use component/module name, lowercase, hyphenated (e.g., `auth`, `platform-picker`). Omit if changes span multiple areas.
- **Description**: Imperative mood ("add", not "added"), specific, under 50 chars. Total title under 72 chars. No trailing period.

**Examples**: `feat(auth): add OAuth2 support` · `fix: resolve null pointer in user lookup` · `refactor(api): extract validation utilities`

#### 3.1 Summary Section

**ALWAYS** include:

1. **What changed** (1-2 sentences, high-level, user/business-focused)

   - **PREFER** non-technical language when possible
   - **EXAMPLE**: "Added ability for users to export their survey results to PDF format"

2. **Why it changed** (1-2 sentences, business context)

   - Pull from Linear issue description if available
   - **EXAMPLE**: "Users requested this feature to share results with stakeholders who don't have system access"

3. **Link to Linear issue** (if available):

   - **ALWAYS** use a "magic word" + issue ID for automatic linking
   - **Magic words**: `Fixes`, `Closes`, `Resolves` (marks issue as done when PR merges)
   - **Alternative**: `Related to`, `Refs`, `References` (links without auto-closing)
   - **CAN** use either issue ID or full Linear URL

   **Format options:**
   ```markdown
   Fixes WAN-521
   ```
   or
   ```markdown
   Closes https://linear.app/consensusaps/issue/WAN-521/title
   ```
   or (for related but not closing):
   ```markdown
   Related to WAN-521
   ```

   - **PREFER** `Fixes` or `Closes` when the PR completes the work for the issue
   - **PREFER** `Related to` when the PR is partial work or tangentially related

Read the section templates and worked examples from `resources/templates/section-templates.md`. It covers Summary, Technical Details (implementation approach, scope changes, changes by area, files summary), Test Plan, and Breaking Changes — each with structural guidance and a complete example.

#### 3.5 Screenshots and Videos Section

**If `VISUAL_MODE` is not set or browser/app detection failed (Phase 2.6):**

Include a placeholder section for visual aids:

```markdown
## Screenshots / Videos

<!-- Add screenshots or videos here to help reviewers visualize the changes -->
<!-- Consider including: -->
<!-- - Before/after UI comparisons -->
<!-- - New features in action -->
<!-- - Error states or edge cases -->
<!-- - Mobile/responsive views -->
```

**NOTE**: This is a placeholder section for the PR creator to populate with relevant visuals.

**If `VISUAL_MODE=true` and a browser MCP and dev server were detected:**

Read `${CLAUDE_PLUGIN_ROOT}/skills/kramme:pr:generate-description/resources/visual-capture.md` and follow **Phase 3.5** to capture screenshots, upload them, and build the Screenshots/Videos section.

### Phase 4: Output Formatting

**ALWAYS** format the output as clean Markdown:

1. **ALWAYS** use proper heading hierarchy (##, ###)
2. **ALWAYS** use code blocks with language hints for code snippets
3. **ALWAYS** use bullet points and numbered lists for readability
4. **PREFER** using tables for structured data (if applicable)
5. **NEVER** include meta-commentary or placeholders like `[TODO]` or `[Fill this in]`
6. **NEVER** include AI attribution or badges such as:
   - `🤖 Generated with [Claude Code](https://claude.ai/code)`
   - `Generated with Claude Code`
   - `Co-Authored-By: Claude` or similar
   - Any mention of AI assistance in the description

#### If `DIRECT_UPDATE=true`: Update PR directly

**Skip copy-paste output and save-to-file prompt.** Update the existing PR's title and description using platform tools:

**GitHub:**
```bash
gh pr edit --title "<title>" --body "$(cat <<'EOF'
<description>
EOF
)"
```

**GitLab (using glab CLI):**
```bash
glab mr update --title "<title>" --description "$(cat <<'EOF'
<description>
EOF
)"
```

**GitLab (using MCP tools, if available):**
Use `mcp__gitlab__update_merge_request` with the new title and description.

**After updating**, confirm success:
```
PR updated successfully.

URL: {pr-url}
Title: {title}
```

**If the update fails**, fall back to presenting the description for copy-paste (same as the default flow below) and show the error.

#### Default: Present for copy-paste

**ALWAYS** present the final PR title and description in a clear, copy-paste-ready format:

```markdown
Here is your generated PR:

**Title:** `<type>(<scope>): <description>`

---

[DESCRIPTION CONTENT HERE]

---
```

**NOTE**: The title is formatted with backticks for easy copying. The description follows the standard markdown format.

7. **ALWAYS** ask if the description should be saved to a markdown file (**skip if `NON_INTERACTIVE=true`**):

   - After presenting the description, ask: "Would you like me to save this description to a markdown file?"
   - If yes, save to a file named `PR_DESCRIPTION.md` in the repository root
   - Confirm the file location after saving

### Phase 5: Final Checklist

**ALWAYS** verify before presenting the PR:

- [ ] **Title** follows conventional commit format (`<type>(<scope>): <description>`)
- [ ] **Title** uses correct type (feat, fix, refactor, docs, test, chore, etc.)
- [ ] **Title** is concise (under 72 characters total)
- [ ] **Title** uses imperative mood ("add", not "added")
- [ ] Summary clearly explains what and why (objective tone, no excessive praise)
- [ ] Linear issue is linked with appropriate magic word (Fixes/Closes vs. Related to)
- [ ] Technical details cover implementation approach and key decisions from conversation/spec files
- [ ] **Divergences from Linear issue are documented with clear rationale** (if applicable)
- [ ] Changes are categorized by area (Frontend/Backend/Tests)
- [ ] Key files are listed (not line counts)
- [ ] Test plan includes actionable scenarios
- [ ] Breaking changes are documented (or marked as "None")
- [ ] Screenshots/Videos section is included (populated when visual capture succeeds; placeholder allowed when `--visual` is not used or capture is unavailable)
- [ ] Markdown is properly formatted
- [ ] No placeholders or TODOs in the output (except Screenshots section when visual capture is unavailable)
- [ ] Description is ready to copy-paste
- [ ] No listing of the amount of lines changed
- [ ] No AI attribution or "Generated with Claude Code" badges included
- [ ] Updated PR directly (if `--direct`) OR asked user if they want to save to markdown file

## Best Practices

Read the best practices guidelines from `resources/references/best-practices.md`. Covers context gathering, writing style, technical details, and test plan rules.

## Anti-Patterns

Read the anti-pattern examples from `resources/examples/anti-patterns.md`. Includes title anti-patterns and 6 paired WRONG/CORRECT examples covering vague summaries, missing context, missing tests, tone, hidden breaking changes, and AI attribution.

## Examples

Read the complete PR examples from `resources/examples/pr-examples.md`. Includes 3 examples: frontend-only feature, full-stack with database migration, and frontend with visual capture (`--visual`).

## Reference Files

**ALWAYS** refer to these files for context:

- `AGENTS.md` - Authoritative development guidelines for this codebase
- `CLAUDE.md` - AI-specific instructions, including GitLab vs GitHub guidance
- Existing PR descriptions in the repository for style reference

## Platform-Specific Notes

Read the platform-specific notes from `resources/references/platform-notes.md`. Covers GitLab MCP tools, magic words for issue linking, team abbreviations, and GitHub conventions.

## Notes

- **NOTE**: This skill generates the description text only - it does NOT create the PR
- **NOTE**: After generation, review the description and adjust as needed before using it
- **NOTE**: The skill follows Connect project conventions (AGENTS.md) but may need customization for other projects
- **NOTE**: If Linear issue lookup fails, continue anyway and note the issue ID in the summary without detailed context
- **NOTE**: Spec files (siw/SPEC.md, siw/LOG.md, siw/OPEN_ISSUES_OVERVIEW.md, etc.) and conversation history are for context gathering ONLY
  - Use them to understand what happened during implementation
  - **NEVER** reference them in the PR description - reviewers don't have access to them
  - Only reference Linear issues when documenting divergences or original requirements
  - **WRONG**: "As mentioned in LOG.md..." or "Based on our earlier discussion..."
  - **RIGHT**: "Linear issue WAN-123 requested X, but implemented Y because..."
