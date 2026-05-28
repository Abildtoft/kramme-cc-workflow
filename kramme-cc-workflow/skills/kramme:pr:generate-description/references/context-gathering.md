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

   - Use this for analysis and scoping only. Do not reproduce the changed-file list in the final PR body unless a specific file is a non-obvious review landmark.

3. **ALWAYS** categorize changed files by area using generic heuristics. Prefer file extensions and conventional directory names; only escalate to repo-specific knowledge when the heuristic is ambiguous.
   - **Frontend**: `*.ts`/`*.tsx`/`*.jsx`/`*.vue`/`*.svelte`/`*.html`/`*.css`/`*.scss` outside test directories, or files under conventional UI directories (`app/`, `src/`, `pages/`, `components/`, `views/`, `screens/`, `web/`, frontend-named monorepo packages).
   - **Backend**: Server-side language files (`*.cs`, `*.go`, `*.py`, `*.rb`, `*.java`, `*.kt`, `*.rs`, server-side `*.ts`/`*.js`) outside test directories, or files under `api/`, `server/`, `services/`, `backend/`, or backend-named monorepo packages.
   - **Tests**: Files matching `*.spec.*`, `*.test.*`, `*_test.*`, or under `tests/`, `test/`, `__tests__/`, `e2e/`, `spec/`.
   - **Migrations**: Files under `migrations/`, `db/migrate/`, `prisma/migrations/`, or matching ORM migration naming conventions (e.g. EF Core `*.Designer.cs` pairs, Rails timestamp-prefixed Ruby files).
   - **Documentation**: `*.md`, `*.mdx`, `*.rst`, `*.adoc` files; `docs/` directory contents.
   - **Configuration**: `*.json`, `*.yaml`/`*.yml`, `*.toml`, `*.ini`, `.env.*`, `*.config.*`, and tool dotfiles (`.eslintrc*`, `.prettierrc*`, etc.).

   If the consumer repository uses a non-standard layout the agent cannot infer, fall back to "Other" rather than guessing.

4. **CAN** use `gh pr diff` to get branch diffs if a PR already exists.

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

1. **ALWAYS** check if the branch name or commit messages contain a Linear-style issue ID. Match the generic pattern `[A-Z]{2,5}-\d+` (case-insensitive at extraction time; normalize to uppercase). Do not hard-code a team prefix list — accept any prefix that Linear validates in step 2.
   - Branch-name pattern: `{initials}/{team-issue-id}-{description}` or `{team-issue-id}-{description}` at the root.
   - **EXAMPLE**: `mab/wan-521-ensure-platform-picker-only-shown-once` → `WAN-521`.
   - **EXAMPLE**: `jd/hea-123-fix-header-bug` → `HEA-123`.
   - **EXAMPLE**: `ab/mel-456-add-new-feature` → `MEL-456`.
   - **EXAMPLE**: `eng/blog-87-launch-rss` → `BLOG-87`.

2. **ALWAYS** attempt to fetch Linear issue details if a candidate ID is found:

   ```
   mcp__linear__get_issue with issue ID
   ```

   If `mcp__linear__list_teams` is available, **CAN** use it to validate that the extracted prefix maps to a real team before fetching. Treat a lookup failure as "no Linear context" rather than an error — continue and note the unresolved ID.

3. **ALWAYS** include in context (when the lookup succeeds):
   - Issue title
   - Issue description
   - Issue state
   - Related project/labels

4. **ALWAYS** compare implementation against the Linear issue description:
   - Check if the actual changes align with what was described in the issue.
   - **ALWAYS** note significant divergences from the original issue scope.
   - **ALWAYS** identify if features were added or removed relative to the issue.
   - **ALWAYS** note if the approach differs from what the issue requested.
   - **EXAMPLE**: Issue asked for A, but implementation delivers A + B, or implements A differently.

5. **CAN** scan commit messages for additional issue references using the same generic `[A-Z]{2,5}-\d+` pattern.
   - **EXAMPLE**: `WAN-123`, `Fixes HEA-456`, `Related to BLOG-789`.

### 2.4 Code Structure Analysis

1. **ALWAYS** analyze the scope of changes using the categorization from §2.1.3:
   - **Frontend-only**: All non-test, non-config changes fall into the Frontend bucket.
   - **Backend-only**: All non-test, non-config changes fall into the Backend bucket.
   - **Full-stack**: Both Frontend and Backend buckets have non-trivial changes.
   - **Tests-only**: Only Test bucket changes.
   - **Documentation-only**: Only Documentation bucket changes.
   - **Other**: Falls outside the buckets above; describe the scope in prose.

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
