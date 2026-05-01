---
name: kramme:pr:generate-description
description: Write a structured PR title and body from git diff, commit log, and Linear context. Outputs markdown for copy-paste or updates the existing PR automatically in auto mode.
argument-hint: "[--auto] [--visual] [--base <ref>]"
disable-model-invocation: false
user-invocable: true
---

# PR Description Generator

## Parse Arguments

Parse `$ARGUMENTS` for flags:

- `--auto`: Preferred hands-off mode. Skip clarification prompts (Phase 2.5) and the save-to-file prompt (Phase 4). If a PR already exists for the current branch, update it directly. If no PR exists yet, generate the title and description for copy-paste without pausing for user input.
- `--visual`: Auto-detect a running dev server and capture screenshots to embed in the PR description. Requires a browser MCP to be available (claude-in-chrome, chrome-devtools, or playwright).
- `--base <ref>`: Use `<ref>` as the base branch for diff computation instead of auto-detecting.

If `--auto` is present, set `AUTO_MODE=true` and `NON_INTERACTIVE=true`, and remove the flag from remaining arguments.
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

- You only need a tiny manual wording edit to an existing PR description
- You're creating a draft PR that doesn't need a full description yet
- The changes are trivial (typo fixes, formatting) and don't warrant detailed documentation

### Context

High-quality PR descriptions are essential for:

- Code reviewers to understand the context and intent of changes
- Future developers investigating the history of a feature
- Product/project managers tracking feature delivery
- Creating an audit trail of technical decisions

This skill automates the process of gathering context from multiple sources (git history, Linear issues, code changes) and generating a structured, comprehensive description following best practices for Pull Requests.

Read the guideline keyword glossary from `references/guideline-keywords.md`.

## Workflow

### Phase 1: Branch Setup

1. **ALWAYS** confirm the current branch:

   ```bash
   git branch --show-current
   ```

2. **ALWAYS** detect and identify the base/target branch dynamically using a 3-tier strategy:

   **Tier 1: Explicit override**
   If `BASE_BRANCH_OVERRIDE` was set from `--base`, use that value directly.

   **Tier 2: PR target branch detection**
   ```bash
   BASE_BRANCH=$(gh pr view --json baseRefName --jq '.baseRefName' 2>/dev/null)
   ```

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
   echo "Base branch: $BASE_BRANCH"
   ```
   - **NOTE**: Tier 2 ensures correct scope when the PR targets a non-default branch (e.g., a feature branch stacked on another PR)
   - **CAN** ask user if unclear or override needed

3. **If `AUTO_MODE=true`**, check whether a PR exists for the current branch:

   ```bash
   gh pr view --json number,url
   ```

   **If a PR exists**, set `DIRECT_UPDATE=true` and capture the PR URL for Phase 4.

   **If no PR exists**, continue in generated-output mode:
   - Keep `NON_INTERACTIVE=true` if auto mode is enabled
   - Leave `DIRECT_UPDATE=false`
   - Present the generated title and body for copy-paste in Phase 4

### Phase 2: Context Gathering

Read the context-gathering procedure from `references/context-gathering.md` and apply every step in that document before continuing. It covers:

- **2.1 Git Changes Analysis** — diff between current branch and `origin/$BASE_BRANCH`, file categorization, optional GitHub tool use.
- **2.2 Commit History Analysis** — commit log and message bodies, narrative arc extraction.
- **2.3 Linear Issue Context** — branch-name parsing, `mcp__linear__get_issue`, divergence tracking.
- **2.4 Code Structure Analysis** — scope (frontend/backend/full-stack), change characteristics, breaking-change indicators.
- **2.5 Conversation History and Specification Files Analysis** — SIW spec files, conversation review, decision capture. Spec files and conversation context are for YOUR analysis only and **NEVER** referenced in the final PR body.

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

If `VISUAL_MODE=true`, read `${CLAUDE_PLUGIN_ROOT}/skills/kramme:pr:generate-description/references/visual-capture.md` and follow **Phase 2.6** in that document to detect a browser MCP and discover the running dev server URL.

### Phase 3: Description Generation

**ALWAYS** generate a structured PR title and description.

#### 3.0 Title Generation

Generate a PR title using [Conventional Commits](https://www.conventionalcommits.org/) format: `<type>(<scope>): <description>`

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

Read the section templates and worked examples from `assets/section-templates.md`. It covers Summary, Technical Details (implementation approach, scope changes, changes by area, reviewer landmarks), Test Plan, and Breaking Changes — each with structural guidance and a complete example.

#### 3.2 Change Summary Pattern

Every generated PR body **MUST** include a "Change Summary" block immediately after the `## Summary` section and before `## Technical Details`. Emit these three H3s verbatim, in this order, each with concrete bullets:

```markdown
### Changes made

- <verb-led statement of what moved, scoped to a feature, behavior, or implementation area>
- <one bullet per distinct change; do not lump multiple changes together>

### Things I didn't touch

- <adjacent work considered during this change and deliberately left out of scope>
- <use "None" if nothing was considered and skipped>

### Potential concerns

- <ship-risk items reviewers should know: data migrations, feature flags off by default, partial coverage, known follow-ups>
- <use "None" if nothing of note>
```

Rules:

- **Changes made** is a diff readout in English, not a narrative. One clear verb per bullet (`add`, `extract`, `rename`, `remove`, `wire`, `gate`).
- **Changes made** is not a file inventory. Keep it to the distinct reviewer-relevant changes, usually 2-5 bullets.
- **PREFER** describing capabilities, components, data flow, or review-critical behavior over naming files.
- **ONLY** name a file when the file name itself helps the reviewer find a non-obvious entry point, risk, migration, generated artifact, or cross-area coupling.
- **Things I didn't touch** is the honest scope line. It is not a "future work" backlog — only items that came up during this work and were deliberately deferred.
- **Potential concerns** surfaces risk the reviewer wouldn't otherwise see. Not the same as "open questions" and not a place to hedge with "maybe fine".
- **ALL THREE** H3s must be present even when one block is `None`. An empty block signals "considered and skipped", not "forgotten".

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

Read `${CLAUDE_PLUGIN_ROOT}/skills/kramme:pr:generate-description/references/visual-capture.md` and follow **Phase 3.5** to capture screenshots, upload them, and build the Screenshots/Videos section.

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

**Skip copy-paste output and save-to-file prompt.** Update the existing PR's title and description:

```bash
gh pr edit --title "<title>" --body "$(cat <<'EOF'
<description>
EOF
)"
```

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
- [ ] Changes are categorized by area (Frontend/Backend/Tests) without repeating the GitHub file list
- [ ] File names appear only when they add reviewer context that is not obvious from the GitHub diff
- [ ] Test plan includes actionable scenarios
- [ ] Breaking changes are documented (or marked as "None")
- [ ] `### Changes made` block lists concrete change verbs — not vague verbs like `update` or `improve` with no object
- [ ] `### Things I didn't touch` block captures adjacent work considered and deliberately deferred (or states `None`)
- [ ] `### Potential concerns` block captures ship-risk items reviewers need (migrations, feature-flag defaults, partial coverage) or states `None`
- [ ] Screenshots/Videos section is included (populated when visual capture succeeds; placeholder allowed when `--visual` is not used or capture is unavailable)
- [ ] Markdown is properly formatted
- [ ] No placeholders or TODOs in the output (except Screenshots section when visual capture is unavailable)
- [ ] Description is ready to copy-paste
- [ ] No file-by-file inventory or "Key Files" section that mostly mirrors the GitHub UI
- [ ] No listing of the amount of lines changed
- [ ] No AI attribution or "Generated with Claude Code" badges included
- [ ] Updated an existing PR directly when `DIRECT_UPDATE=true`, otherwise presented copy-paste output and only asked about saving when `NON_INTERACTIVE=false`

## Best Practices

Read the best practices guidelines from `references/best-practices.md`. Covers context gathering, writing style, technical details, and test plan rules.

## Anti-Patterns

Read the anti-pattern examples from `references/anti-patterns.md`. Includes title anti-patterns, vague-summary patterns (rejects titles like `Fix bug`, `Fix build`, `Phase 1`, `Add convenience functions`), and 6 paired WRONG/CORRECT examples covering vague summaries, missing context, missing tests, tone, hidden breaking changes, and AI attribution.

## Examples

Read the complete PR examples from `references/pr-examples.md`. Includes 3 examples: frontend-only feature, full-stack with database migration, and frontend with visual capture (`--visual`).

## Reference Files

**ALWAYS** refer to these files for context:

- Existing PR descriptions in the repository for style reference

## Platform-Specific Notes

Read the platform-specific notes from `references/platform-notes.md`. Covers magic words for issue linking, team abbreviations, and GitHub conventions.

## Notes

- **NOTE**: This skill generates the description text only - it does NOT create the PR
- **NOTE**: After generation, review the description and adjust as needed before using it
- **NOTE**: This skill is self-contained. If a downstream installation needs custom PR-title policy, adapt this skill locally instead of depending on repo-root instruction files.
- **NOTE**: If Linear issue lookup fails, continue anyway and note the issue ID in the summary without detailed context
- **NOTE**: Spec files (siw/SPEC.md, siw/LOG.md, siw/OPEN_ISSUES_OVERVIEW.md, etc.) and conversation history are for context gathering ONLY
  - Use them to understand what happened during implementation
  - **NEVER** reference them in the PR description - reviewers don't have access to them
  - Only reference Linear issues when documenting divergences or original requirements
  - **WRONG**: "As mentioned in LOG.md..." or "Based on our earlier discussion..."
  - **RIGHT**: "Linear issue WAN-123 requested X, but implemented Y because..."

## Output markers

Use these uppercase markers when reasoning about the description generation. They do NOT appear in the final PR body — they go in the skill's conversation output so the user can track decisions.

- **UNVERIFIED** — a claim in the draft body you couldn't confirm from the diff. `UNVERIFIED: the migration is reversible — no down-migration present in the diff`.
- **NOTICED BUT NOT TOUCHING** — diff contents you deliberately left out of the description. `NOTICED BUT NOT TOUCHING: a test-only rename in an adjacent file — not part of this PR's narrative`.
- **CONFUSION** — diff evidence that contradicts the commit log or Linear issue. `CONFUSION: commits say "add feature flag", but the diff toggles it on by default`.
- **MISSING REQUIREMENT** — context the user must provide before a faithful description can be generated. `MISSING REQUIREMENT: no Linear ID in branch name and no issue mentioned in commits — confirm the intended ticket or proceed without one`.

## Common Rationalizations

Watch for these — they signal the description is about to under-serve the reviewer:

- *"The diff is small; a one-line summary is enough."* → Small diffs still need the *why*. A one-line summary forces the reviewer to reconstruct intent from code.
- *"I'll leave `Things I didn't touch` blank because nothing comes to mind."* → If nothing comes to mind, re-read the diff. `None` is a valid answer only after you've looked.
- *"The Linear issue covers the context — no need to restate it."* → The PR body is read in isolation during review. Restate the essentials and link the issue.
- *"I'll fold the migration warning into the body text."* → `Potential concerns` is a dedicated block for a reason; a buried warning is a missed warning.

## Red Flags — STOP

Pause and regenerate the description if any of these are true:

- The summary says "various changes" or "multiple improvements" without nouns.
- `Changes made` contains vague verbs like `update` or `improve` with no object.
- The body includes a "Key Files", "Files Changed", or similar section that mostly repeats the GitHub file list.
- A migration, feature-flag default, or breaking change is present in the diff but absent from `Potential concerns`.
- The description references spec files, conversation history, or `siw/LOG.md` (reviewers can't see them).
- An AI-attribution badge is about to land in the body.

## Verification

Before presenting or posting the description, self-check:

- [ ] Title follows `<type>(<scope>): <description>` and is under 72 characters.
- [ ] Summary restates the *why* in business terms.
- [ ] `Changes made` / `Things I didn't touch` / `Potential concerns` are all present, with `None` used only after consideration.
- [ ] Linear issue linked with the correct magic word (`Fixes`, `Closes`, `Related to`).
- [ ] No AI attribution, no placeholder TODOs, no references to spec files.
