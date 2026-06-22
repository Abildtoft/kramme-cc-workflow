---
name: kramme:pr:generate-description
description: Write a structured PR title and body from git diff, commit log, and Linear context. Outputs markdown for copy-paste or, when explicitly invoked with --auto, updates an existing PR.
argument-hint: "[--auto] [--no-update] [--visual] [--base <ref>]"
disable-model-invocation: true
user-invocable: true
---

# PR Description Generator

## Parse Arguments

Parse `$ARGUMENTS` for flags:

- `--auto`: Preferred hands-off mode for explicit user invocation. Skip clarification prompts (Phase 2.5) and the save-to-file prompt (Phase 4). If a PR already exists for the current branch, update its title/body directly. If no PR exists yet, generate the title and description for copy-paste without pausing for user input.
- `--no-update`: Output-only automation mode for orchestrators that need generated title/body content but must not mutate an existing PR. Valid with `--auto`; it skips prompts but keeps `DIRECT_UPDATE=false` even if `gh pr view` finds a PR.
- `--visual`: Delegate demo evidence capture to `kramme:visual:demo-reel` and include the resulting Screenshots/Videos section when local or embeddable evidence is available. If capture cannot run, continue with the placeholder Screenshots/Videos section.
- `--base <ref>`: Use `<ref>` as the base branch for diff computation instead of auto-detecting.

If `--auto` is present, set `AUTO_MODE=true` and `NON_INTERACTIVE=true`, and remove the flag from remaining arguments. If `--no-update` is present, set `OUTPUT_ONLY=true` and remove the flag from remaining arguments. If `--visual` is present, set `VISUAL_MODE=true` and remove the flag from remaining arguments. If `--base <ref>` is present, set `BASE_BRANCH_OVERRIDE=<ref>` and remove the flag and value from remaining arguments.

### Sub-Skill Invocation Contract

When another skill invokes this one as an orchestration step, it must pass `--auto` (and should pass `--base <ref>` when it already resolved the base branch). If the caller only needs generated title/body content and owns the eventual publish gate, it must also pass `--no-update`. In `--auto` mode, Phase 2.5 clarification prompts and the Phase 4 save-to-file prompt are skipped. Missing context is surfaced as `MISSING REQUIREMENT:` output instead of prompting mid-orchestration; blocking missing requirements disable direct PR updates and produce copy-paste output.

## Instructions

### When to Use This Skill

**Use this skill when:**

- You're ready to create a Pull Request
- You want a well-structured, focused description for your changes
- You need to document what changed, why it changed, and how to test it
- You want to analyze multiple sources (git diff, commits, Linear issues) to create reviewer-relevant context

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

This skill automates the process of gathering context from multiple sources (git history, Linear issues, code changes) and generating a structured, focused description following best practices for Pull Requests.

Read the guideline keyword glossary from `references/guideline-keywords.md`.

## Workflow

### Phase 1: Branch Setup

1. Read `references/base-branch-resolution.md` and follow it to confirm the current branch and compute `BASE_BRANCH`.

2. **If `AUTO_MODE=true` and `OUTPUT_ONLY` is not true**, check whether a PR exists for the current branch:

   ```bash
   gh pr view --json number,url
   ```

   **If a PR exists**, set `DIRECT_UPDATE=true` and capture the PR URL for Phase 4.

   **If no PR exists**, continue in generated-output mode:
   - Keep `NON_INTERACTIVE=true` if auto mode is enabled
   - Leave `DIRECT_UPDATE=false`
   - Present the generated title and body for copy-paste in Phase 4

   **If `OUTPUT_ONLY=true`**, skip the PR existence check for direct-update purposes, leave `DIRECT_UPDATE=false`, and continue in generated-output mode. The caller is responsible for any later PR creation or update.

### Phase 2: Context Gathering

Read the context-gathering procedure from `references/context-gathering.md` and apply every step in that document before continuing. It covers:

- **2.1 Git Changes Analysis** — diff between current branch and `origin/$BASE_BRANCH`, file categorization, optional GitHub tool use.
- **2.1.5 GitHub PR Template Analysis** — supported GitHub template locations, template selection, and template-following constraints.
- **2.2 Commit History Analysis** — commit log and message bodies, narrative arc extraction.
- **2.3 Linear Issue Context** — branch-name parsing, optional Linear integration lookup, divergence tracking.
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

### Phase 2.6: Visual Evidence Delegation Prep

**Skip this phase if `VISUAL_MODE` is not set.** Proceed directly to Phase 3.

If `VISUAL_MODE=true`, read `references/visual-capture.md` and follow **Phase 2.6** in that document. This prepares the target summary for `kramme:visual:demo-reel`; it does not duplicate browser capture or dev-server heuristics inside this PR-description skill.

### Phase 3: Description Generation

Before drafting, evaluate whether any **MISSING REQUIREMENT** conditions hold (see the Output markers section below). Emit a `MISSING REQUIREMENT: …` line in the skill's conversation output whenever:

- The branch name has no detectable issue ID and commits reference none — non-blocking; confirm the intended ticket or proceed without one.
- The diff contains a database migration but no rationale is present in commits, Linear, or conversation — blocking for direct update; request the migration's purpose/rollback plan.
- The diff toggles a feature flag's default but no rollout context is available — blocking for direct update; request the rollout plan.
- One or more selectable GitHub PR templates are present, no default template is selected, and no template can be selected from user input, existing PR body, branch name, or change type — blocking for direct update; request which template to follow.

Surface the marker even when `NON_INTERACTIVE=true`; in that mode, report the gap in the run output so the caller can collect the missing context before publication.

If any blocking missing requirement is present, set `DIRECT_UPDATE=false` even when `--auto` found an existing PR. Generate copy-paste output that names the missing context, and leave publication to the caller or user after they provide it. Do not publish a PR body that invents migration rationale, rollback plans, or rollout context.

(Phase 1 already aborts hard when the base branch cannot be resolved, so there is no Phase 3 trigger for that case.)

**ALWAYS** generate a structured PR title and description after that check.

#### 3.0 Title Generation

Generate a PR title using [Conventional Commits](https://www.conventionalcommits.org/) format: `<type>(<scope>): <description>`

**Types** (based on Phase 2.4 analysis):

| `feat` | `fix` | `refactor` | `docs` | `test` | `build`/`ci` | `chore` | `perf` | `style` | `revert` |

**Rules**:

- **Scope**: Optional. Use component/module name, lowercase, hyphenated (e.g., `auth`, `platform-picker`). Omit if changes span multiple areas.
- **Description**: Imperative mood ("add", not "added"), specific, under 50 chars. Total title under 72 chars. No trailing period.

**Examples**: `feat(auth): add OAuth2 support` · `fix: resolve null pointer in user lookup` · `refactor(api): extract validation utilities`

#### 3.0.5 Repository PR Template Contract

If Phase 2 found a GitHub PR template, treat it as the body structure contract before applying default section templates.

- Follow the selected template's heading order, checklist items, and required prompts.
- Map generated Summary, Change Summary, Technical Details, Test Plan, Breaking Changes, and Screenshots/Videos content into the closest matching template sections instead of creating duplicate default sections.
- Preserve mandatory checkboxes and compliance prompts; check a box only when the diff or gathered context supports it.
- Remove instructional HTML comments only when the generated content fully answers them; otherwise keep the prompt or emit a marker outside the PR body.
- If no GitHub PR template is found, use the standard structure from `assets/section-templates.md`.

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
   Fixes ABC-123
   ```

   or

   ```markdown
   Closes https://linear.app/your-workspace/issue/ABC-123/title
   ```

   or (for related but not closing):

   ```markdown
   Related to ABC-123
   ```

   - **PREFER** `Fixes` or `Closes` when the PR completes the work for the issue
   - **PREFER** `Related to` when the PR is partial work or tangentially related

Read the section templates and worked examples from `assets/section-templates.md`. It covers Summary, Technical Details (implementation approach, scope changes, optional area notes, reviewer landmarks), Test Plan, and Breaking Changes — each with structural guidance and a complete example.

When drafting the Test Plan, apply the Test Plan section in `assets/section-templates.md` and the Test Plans rules in `references/best-practices.md`.

#### 3.1.5 GitHub UI Duplication Guard

Before drafting the body, decide what the PR description adds beyond GitHub's review UI.

**ALWAYS** include context GitHub cannot infer from the diff browser:

- Why the change exists
- Non-obvious implementation decisions and trade-offs
- Scope boundaries and deliberate exclusions
- Risks, rollout constraints, migrations, feature-flag defaults, or partial coverage
- Manual test scenarios reviewers or QA should perform
- Review landmarks only when the diff has a non-obvious entry point or coupled files that should be reviewed together

**NEVER** include description content whose main value is already provided by GitHub:

- A changed-file list, file tree, or file-by-file inventory
- File counts, line counts, or `git diff --stat` summaries
- A commit-by-commit changelog
- Branch, author, or review metadata already visible in the PR chrome
- A generic "Changes by Area" section that only groups modified files by Frontend/Backend/Tests

If a section would merely prove that files changed, omit it or replace it with one or two review-relevant notes that explain behavior, coupling, risk, or review order.

#### 3.2 Change Summary Pattern

Build the Change Summary block from `assets/section-templates.md` and enforce the Change Summary Block rules in `references/best-practices.md`.

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

**If `VISUAL_MODE=true`:**

Read `references/visual-capture.md` and follow **Phase 3.5** to delegate evidence capture to `kramme:visual:demo-reel`, prepare any returned local artifacts for manual attachment or embeddable assets, and build the Screenshots/Videos section. Do not implement a separate screenshot/GIF capture flow here.

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

Read `references/direct-update.md` and follow it. If the update fails, fall back to presenting the description for copy-paste using the default flow below.

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

#### Optional: Save to a markdown file

**Skip this step if `NON_INTERACTIVE=true`.**

After presenting the description, ask: "Would you like me to save this description to a markdown file?"

If yes, save to `$REPO_ROOT/.kramme-cc-workflow/pr-description/PR_DESCRIPTION.md` where `REPO_ROOT=$(git rev-parse --show-toplevel)`. Add `.kramme-cc-workflow/` to git's local exclude file first if it is not already listed (use the same idempotent check as step 1 of `references/direct-update.md`), so the saved file is not accidentally committed without mutating tracked files. Confirm the absolute file path after saving.

### Phase 5: Pre-publish Verification

Run the consolidated checklist in `references/verification-checklist.md`. Phases 1–4 do not have their own checklist; that reference is the single source of truth.

## Best Practices

Read the best practices guidelines from `references/best-practices.md`. Covers context gathering, writing style, technical details, and test plan rules.

## Anti-Patterns

Read the anti-pattern examples from `references/anti-patterns.md`. Includes title anti-patterns, vague-summary patterns (rejects titles like `Fix bug`, `Fix build`, `Phase 1`, `Add convenience functions`), and 6 paired WRONG/CORRECT examples covering vague summaries, missing context, missing tests, tone, hidden breaking changes, and AI attribution.

## Examples

Read the complete PR examples from `references/pr-examples.md`. Includes 3 examples: frontend-only feature, full-stack with database migration, and frontend with visual capture (`--visual`).

## Platform-Specific Notes

Read the platform-specific notes from `references/platform-notes.md`. Covers magic words for issue linking, team abbreviations, and GitHub conventions.

## Notes

- **NOTE**: This skill generates PR title/body content and does NOT create a new PR. When explicitly invoked with `--auto`, an existing PR is found, `--no-update` is absent, and no blocking missing requirement is present, it may update that PR's title/body through `gh pr edit`. When saving output, it may write local files under `.kramme-cc-workflow/pr-description/` and add `.kramme-cc-workflow/` to git's local exclude file if missing.
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

Read `references/red-flags.md` before finalizing. It covers common rationalizations that under-serve the reviewer.

## Red Flags

Read `references/red-flags.md` before finalizing. Stop and regenerate when the draft uses vague summary nouns, mirrors a file list, hides migration risk, includes automated testing instructions in the Test Plan, references spec files, or includes AI-attribution badges.

## Verification

Read `references/verification-checklist.md` and complete it before presenting copy-paste output, before `gh pr edit`, and before saving to file.
