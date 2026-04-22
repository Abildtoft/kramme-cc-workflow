## Phase 2: Context Gathering

**ALWAYS** gather comprehensive context from all available sources.

**IMPORTANT**: Use `origin/$BASE_BRANCH` for all comparisons to ensure you compare against the remote's state, not a potentially stale local branch.

**IMPORTANT**: Spec files and conversation history are for YOUR analysis only to understand implementation decisions. The final PR description should ONLY reference Linear issues as the source of original requirements, since reviewers have access to Linear but not to spec files or conversation history.

### 2.1 Git Changes Analysis

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

### 2.2 Commit History Analysis

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

### 2.3 Linear Issue Context

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

### 2.4 Code Structure Analysis

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

### 2.5 Conversation History and Specification Files Analysis

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
