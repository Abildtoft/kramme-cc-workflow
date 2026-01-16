---
name: kramme:resolve-review-findings
description: Resolve findings from code reviews by implementing fixes and documenting changes
---

# Resolve Review Findings

## Workflow

### Step 0: Check for input

Before searching for reviews, check if the user provided input directly with the command:

1. **Check for arguments after the command** — If the user wrote `/kramme:resolve-review-findings <something>`:
   - If `<something>` looks like review content (e.g., contains code comments, file references, or review-like text) → treat it as the **review to resolve**
   - If `<something>` looks like instructions (e.g., "focus on security issues", "only address high priority items") → store as **additional instructions** to apply during evaluation and implementation
   - If `<something>` is a URL → treat as **external review** source (fetch from that URL)

2. **Apply additional instructions throughout** — If the user provided instructions (not review content), keep them in mind when:
   - Prioritizing which findings to address
   - Evaluating whether to implement a fix
   - Deciding how to implement fixes

### Step 1: Find the review

If no review content was provided in Step 0:

1. **Check chat context first** — Scan recent messages for:
   - Code review content from the agent → **internal review**
   - A PR URL provided by the user → **external review** (fetch from that URL)
2. **If no review in chat, fetch from current branch's PR:**
   - Detect hosting platform: check for `.gitlab-ci.yml` (GitLab) or `.github/` directory (GitHub)
   - For **GitHub**: Use `gh pr view --json reviews,comments` and `gh api repos/{owner}/{repo}/pulls/{number}/comments` to fetch unresolved review comments
   - For **GitLab**: Use the GitLab MCP tools or API to fetch unresolved discussions
   - Note that this is an **external review**
3. **If no review found anywhere** — Ask the user to either provide review content, a PR URL, or confirm there's nothing to resolve
4. **List all findings** — Present each comment with its file location, line number, and content

### Step 2: Evaluate findings

For each finding, before implementing any fix:

#### 2a. Check for scope creep

First, determine the **PR's intended scope** by examining:
- The PR title and description
- The types of files changed (feature code, tests, configs, etc.)
- The commit messages on the branch
- Any linked issues or tickets

Then, for each finding, ask: **"Is this within the PR's scope?"**

**In scope** — Implement if valid:
- Bug/issue in code that this PR modified
- Missing error handling for new functionality
- Test coverage gaps for the PR's changes
- Documentation for new/changed behavior
- Security or correctness issues in the PR's code

**Out of scope** — Do NOT implement, document for later:
- Refactoring requests for code the PR didn't touch
- Suggestions to add features beyond the PR's goal
- "While you're here, also fix X" in unrelated files
- Style/naming changes in untouched code
- Performance optimizations unrelated to the PR's changes
- Requests to expand the PR's scope significantly

**Gray area** — Use judgment:
- Small fixes in adjacent code that make the PR's changes cleaner
- Consistency improvements that affect a few lines near the PR's changes
- If unclear, **ask the user** whether to include or defer

#### 2b. Assess validity (for in-scope findings only)

For external reviews:
- **Assess validity** — Determine if you agree with the reviewer's comment
- **If you disagree** — Note your reasoning; you may still implement if it's a matter of preference, or skip if the suggestion would harm code quality
- **If you agree** — Proceed with the fix

For internal reviews (self-generated): Skip this substep and proceed directly to implementation.

#### 2c. Prioritize by severity

- **High**: Security issues, data loss risks, broken functionality, blocking bugs
- **Medium**: Performance problems, maintainability concerns, missing error handling
- **Low**: Style preferences, naming suggestions, minor refactors

### Step 3: Implement fixes

Work through each finding in priority order, applying the guidelines below.

### Step 4: Validate and summarize

- **Validate** — Check for and fix any new linting, formatting, and testing issues
- **Do NOT resolve or reply to comments** — Never mark review comments as resolved or post replies on the platform
- **Generate summary** — Create `REVIEW_RESPONSE.md` in the project root (see Output format below)

## Guidelines

### General principles

- **Write clear, maintainable code** — prioritize readability and simplicity; prefer straightforward solutions over clever ones, but do not be lazy.
- **Add comments where needed** — if a fix involves non-obvious logic or trade-offs, include concise comments explaining the reasoning.
- **Ask questions if unsure** — if any aspect of the fix or the related business logic is unclear, seek clarification before proceeding.
- **Follow project conventions** — ensure fixes align with the best practices outlined in AGENTS.md.
- **Stay focused** — limit changes to what's necessary for the fix; avoid unrelated refactors or improvements.

### For each fix

- **Understand the root cause** — before making changes, ensure you fully grasp why the issue exists.
- **Be comprehensive within scope** — don't just patch the specific lines mentioned; briefly investigate and apply the same fix pattern wherever the same issue exists in the code touched by this branch.
- **Update tests** — add or adjust appropriate tests to cover any new logic or edge cases.

### When handling errors or external data

- **Consider graceful degradation** — where it makes sense, prefer non-fatal error paths that preserve partial success. However, if failing hard is the safer or more appropriate choice, do that instead and explain why in succinct code comments.
- **Be defensive at boundaries** — when parsing responses from third-party services, external APIs, or user input, normalize/fallback rather than assuming a single format. However, don't over-engineer defensiveness against internal code — trust our own contracts unless there's evidence they're being violated.

## Output format

Create `REVIEW_RESPONSE.md` in the project root.

### For external reviews

Use this format for each comment:

#### Comment #N: [Brief description]

**File:** `path/to/file.ts:123`

**Reviewer's comment:**

> [Quote the original review comment]

**Assessment:** Agree / Agree With Modifications / Disagree

**Rationale:** [Why you agree or disagree with this feedback]

**Action taken:** [Description of the fix implemented, or "No action" with explanation]

**Draft reply:**

> [Suggested response to post to the reviewer]

---

### For internal reviews

Use this simplified format for each finding:

#### Finding #N: [Brief description]

**File:** `path/to/file.ts:123`

**Issue:** [Description of the issue]

**Action taken:** [Description of the fix implemented]

---

### Out-of-scope section

If any findings were identified as scope creep, document them:

#### Deferred: [Brief description]

**File:** `path/to/file.ts:123`

**Finding:**

> [Quote the original finding/comment]

**Reason deferred:** [Why this is out of scope for this PR]

**Recommendation:** [Suggested follow-up: create a separate PR, open an issue, discuss with team, etc.]

---

### Summary section

At the end, include:

- Summary of changes made
- Count of findings: N addressed, M deferred as out-of-scope
- Note any breaking changes to API contracts or config behavior
- Flag areas that need manual verification due to potential edge cases or risk
