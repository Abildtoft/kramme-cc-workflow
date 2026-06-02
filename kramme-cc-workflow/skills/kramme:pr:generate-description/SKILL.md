---
name: kramme:pr:generate-description
description: Write a structured PR title and body from git diff, commit log, and Linear context. Outputs markdown for copy-paste or, when explicitly invoked with --auto, updates an existing PR.
argument-hint: "[--auto] [--visual] [--base <ref>]"
disable-model-invocation: true
user-invocable: true
---

# PR Description Generator

## Parse Arguments

Parse `$ARGUMENTS` for flags:

- `--auto`: Preferred hands-off mode for explicit user invocation. Skip clarification prompts (Phase 2.5) and the save-to-file prompt (Phase 4). If a PR already exists for the current branch, update its title/body directly. If no PR exists yet, generate the title and description for copy-paste without pausing for user input.
- `--visual`: Auto-detect a running dev server and capture screenshots to embed in the PR description. Requires an available browser automation capability; if none is available, continue with the placeholder Screenshots/Videos section.
- `--base <ref>`: Use `<ref>` as the base branch for diff computation instead of auto-detecting.

If `--auto` is present, set `AUTO_MODE=true` and `NON_INTERACTIVE=true`, and remove the flag from remaining arguments. If `--visual` is present, set `VISUAL_MODE=true` and remove the flag from remaining arguments. If `--base <ref>` is present, set `BASE_BRANCH_OVERRIDE=<ref>` and remove the flag and value from remaining arguments.

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

1. **ALWAYS** confirm the current branch:

   ```bash
   git branch --show-current
   ```

2. **ALWAYS** detect and identify the base/target branch dynamically using a 3-tier strategy:

   **Tier 1: Explicit override** If `BASE_BRANCH_OVERRIDE` was set from `--base`, use that value directly.

   **Tier 2: PR target branch detection**

   ```bash
   BASE_BRANCH=$(gh pr view --json baseRefName --jq '.baseRefName' 2> /dev/null)
   ```

   **Tier 3: Fallback**

   ```bash
   BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2> /dev/null | sed 's@^refs/remotes/origin/@@')
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
   if ! git check-ref-format --branch "$BASE_BRANCH" > /dev/null 2>&1; then
     echo "Error: Base branch '$BASE_BRANCH' is not a valid branch name. Re-run with --base <ref>." >&2
     exit 1
   fi
   if ! git fetch origin "refs/heads/${BASE_BRANCH}:refs/remotes/origin/${BASE_BRANCH}" 2> /dev/null; then
     echo "Error: Failed to fetch origin/$BASE_BRANCH. Check remote access and re-run with --base <ref>." >&2
     exit 1
   fi
   if ! git rev-parse --verify --quiet "origin/$BASE_BRANCH" > /dev/null; then
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

### Phase 2.6: Browser Detection and App Discovery

**Skip this phase if `VISUAL_MODE` is not set.** Proceed directly to Phase 3.

If `VISUAL_MODE=true`, read `references/visual-capture.md` and follow **Phase 2.6** in that document to detect an available browser automation capability and discover the running dev server URL.

### Phase 3: Description Generation

Before drafting, evaluate whether any **MISSING REQUIREMENT** conditions hold (see the Output markers section below). Emit a `MISSING REQUIREMENT: …` line in the skill's conversation output whenever:

- The branch name has no detectable issue ID and commits reference none — non-blocking; confirm the intended ticket or proceed without one.
- The diff contains a database migration but no rationale is present in commits, Linear, or conversation — blocking for direct update; request the migration's purpose/rollback plan.
- The diff toggles a feature flag's default but no rollout context is available — blocking for direct update; request the rollout plan.

Surface the marker even when `NON_INTERACTIVE=true`; do not prompt the user, but make the gap visible in the run output so it appears alongside the generated description.

If any blocking missing requirement is present, set `DIRECT_UPDATE=false` even when `--auto` found an existing PR. Continue by generating copy-paste output so the user can supply the missing context before publication. Do not publish a PR body that invents migration rationale, rollback plans, or rollout context.

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

Read the section templates and worked examples from `assets/section-templates.md`. It covers Summary, Technical Details (implementation approach, scope changes, optional area notes, reviewer landmarks), Test Plan, and Breaking Changes — each with structural guidance and a complete example.

When drafting the Test Plan, make it a reviewer/QA execution plan first:

- **ALWAYS** lead with manual or reviewer-run scenarios that exercise the changed behavior.
- **NEVER** substitute commands you ran (`npm test`, lint, typecheck, build, etc.) for the manual steps needed to validate the PR.
- Treat `### Automated verification` as optional evidence, not a transcript of local commands.
- **OMIT** `### Automated verification` when it would only repeat routine checks already covered by CI, such as format, lint, typecheck, build, or the normal unit-test suite.
- **CAN** add commands already run only in a separate `### Automated verification` subsection after the scenarios when they add PR-specific signal beyond CI, such as a targeted regression command not run by CI, a migration dry-run, a local smoke test requiring seeded data, or visual capture verification.
- **NEVER** list missing command targets under `### Automated verification` (for example, "No unit-test target exists"). If the missing target creates a real coverage risk, surface it in `### Potential concerns` or the Manual QA rationale; otherwise omit it.
- If the change has no meaningful manual path, include `### Manual QA` with a concrete reason and the closest reviewer-run validation path, then list automated verification separately.

#### 3.1.5 GitHub UI Duplication Guard

Before drafting the body, decide what the PR description adds beyond GitHub's review UI.

**ALWAYS** include context GitHub cannot infer from the diff browser:

- Why the change exists
- Non-obvious implementation decisions and trade-offs
- Scope boundaries and deliberate exclusions
- Risks, rollout constraints, migrations, feature-flag defaults, or partial coverage
- Test scenarios reviewers or QA should run
- Review landmarks only when the diff has a non-obvious entry point or coupled files that should be reviewed together

**NEVER** include description content whose main value is already provided by GitHub:

- A changed-file list, file tree, or file-by-file inventory
- File counts, line counts, or `git diff --stat` summaries
- A commit-by-commit changelog
- Branch, author, or review metadata already visible in the PR chrome
- A generic "Changes by Area" section that only groups modified files by Frontend/Backend/Tests

If a section would merely prove that files changed, omit it or replace it with one or two review-relevant notes that explain behavior, coupling, risk, or review order.

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

- **Changes made** is a reviewer-facing outcome summary, not a file inventory or commit log. One clear verb per bullet (`add`, `extract`, `rename`, `remove`, `wire`, `gate`).
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

**If `VISUAL_MODE=true` and a browser automation capability and dev server were detected:**

Read `references/visual-capture.md` and follow **Phase 3.5** to capture screenshots, prepare them for embedding or manual attachment, and build the Screenshots/Videos section.

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

**Skip copy-paste output and save-to-file prompt.** Use this sequence to avoid both shell-interpolation and heredoc-terminator collisions in LLM-generated content:

1. **Anchor to repo root and prepare the workspace directory.** Run this bash block first:

   ```bash
   REPO_ROOT=$(git rev-parse --show-toplevel)
   BACKUP_DIR="$REPO_ROOT/.kramme-cc-workflow/pr-description"
   mkdir -p "$BACKUP_DIR"

   # Ensure the namespace is locally excluded so backups and saved descriptions are
   # not accidentally committed. Use git's local exclude file; do not mutate tracked files.
   GIT_EXCLUDE=$(git rev-parse --git-path info/exclude)
   mkdir -p "$(dirname "$GIT_EXCLUDE")"
   touch "$GIT_EXCLUDE"
   if ! grep -qxF ".kramme-cc-workflow/" "$GIT_EXCLUDE"; then
     printf '\n.kramme-cc-workflow/\n' >> "$GIT_EXCLUDE"
   fi

   # Snapshot the prior PR body. Real failure leaves no backup; empty backup is discarded.
   PR_BACKUP="$BACKUP_DIR/pr-body.backup.$(date -u +%Y%m%dT%H%M%SZ).$$.md"
   gh pr view --json body --jq '.body' > "$PR_BACKUP" 2> /dev/null
   if [ ! -s "$PR_BACKUP" ]; then
     PR_BACKUP=""
   fi
   echo "BACKUP_DIR=$BACKUP_DIR"
   echo "PR_BACKUP=${PR_BACKUP:-<none>}"
   ```

2. **Write the generated title and body to files using the runtime's file-write capability, keeping generated Markdown out of the shell parser.** Targets:
   - `$BACKUP_DIR/new-title.txt` — the conventional-commit title, single line, no trailing newline.
   - `$BACKUP_DIR/new-body.md` — the full description markdown.

   Prefer a native file-write/edit capability. If unavailable, use an equivalent safe file-write method that does not pass generated Markdown through shell interpolation or a heredoc.

3. **Apply the edit:**

   ```bash
   gh pr edit \
     --title "$(cat "$BACKUP_DIR/new-title.txt")" \
     --body-file "$BACKUP_DIR/new-body.md"
   ```

   - `"$(cat …)"` substitutes the literal file contents into one argv element; `gh` does not re-evaluate the argument as shell.
   - `--body-file` reads the body straight from disk; nothing in it flows through the shell.

**After updating**, confirm success. Include the backup line only when a backup actually exists:

```
PR updated successfully.

URL: {pr-url}
Title: {title}
{when PR_BACKUP is non-empty: "Previous body backed up to: {PR_BACKUP}"}
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

#### Optional: Save to a markdown file

**Skip this step if `NON_INTERACTIVE=true`.**

After presenting the description, ask: "Would you like me to save this description to a markdown file?"

If yes, save to `$REPO_ROOT/.kramme-cc-workflow/pr-description/PR_DESCRIPTION.md` where `REPO_ROOT=$(git rev-parse --show-toplevel)`. Add `.kramme-cc-workflow/` to git's local exclude file first if it is not already listed (use the same idempotent check as the `DIRECT_UPDATE` block above), so the saved file is not accidentally committed without mutating tracked files. Confirm the absolute file path after saving.

### Phase 5: Pre-publish Verification

Run the consolidated checklist in the Verification section near the end of this file. Phases 1–4 do not have their own checklist; the Verification section is the single source of truth.

## Best Practices

Read the best practices guidelines from `references/best-practices.md`. Covers context gathering, writing style, technical details, and test plan rules.

## Anti-Patterns

Read the anti-pattern examples from `references/anti-patterns.md`. Includes title anti-patterns, vague-summary patterns (rejects titles like `Fix bug`, `Fix build`, `Phase 1`, `Add convenience functions`), and 6 paired WRONG/CORRECT examples covering vague summaries, missing context, missing tests, tone, hidden breaking changes, and AI attribution.

## Examples

Read the complete PR examples from `references/pr-examples.md`. Includes 3 examples: frontend-only feature, full-stack with database migration, and frontend with visual capture (`--visual`).

## Platform-Specific Notes

Read the platform-specific notes from `references/platform-notes.md`. Covers magic words for issue linking, team abbreviations, and GitHub conventions.

## Notes

- **NOTE**: This skill generates PR title/body content and does NOT create a new PR. When explicitly invoked with `--auto`, an existing PR is found, and no blocking missing requirement is present, it may update that PR's title/body through `gh pr edit`. When saving output, it may write local files under `.kramme-cc-workflow/pr-description/` and add `.kramme-cc-workflow/` to git's local exclude file if missing.
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

## Common Rationalizations and Red Flags

Read `references/red-flags.md` before finalizing. Covers common rationalizations that under-serve the reviewer and stop-and-regenerate red flags (vague summary nouns, file-list mirroring, missing migration warnings, automated-only Test Plan, spec-file references, AI-attribution badges).

## Verification

Single pre-publish checklist. Run this before presenting copy-paste output, before `gh pr edit`, and before saving to file.

**Title**

- [ ] Follows `<type>(<scope>): <description>` with a valid type (`feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `style`, `build`, `ci`, `revert`).
- [ ] Under 72 characters total. Imperative mood (`add`, not `added`). No trailing period.

**Summary and Change Summary block**

- [ ] Summary restates the _why_ in business terms, not just the _what_.
- [ ] Linear (or GitHub) issue linked with the correct magic word (`Fixes`, `Closes`, `Resolves`, `Related to`, `Refs`, `References`).
- [ ] `### Changes made` lists distinct verb-led bullets — no vague verbs (`update`, `improve`) without an object.
- [ ] `### Things I didn't touch` reflects adjacent work considered and deliberately deferred (or `None` after consideration).
- [ ] `### Potential concerns` flags migrations, feature-flag defaults, partial coverage, and rollout risk (or `None`).

**Technical Details and Test Plan**

- [ ] Implementation approach explains key decisions. Divergences from the Linear issue have a clear rationale.
- [ ] No file-by-file inventory, "Key Files" section, "Changes by Area" file-grouping, line counts, or anything that just mirrors the GitHub diff.
- [ ] File names appear only when they identify a non-obvious entry point, migration, generated artifact, or cross-area coupling.
- [ ] Test Plan leads with reviewer/QA scenarios. `### Automated verification` is omitted unless the listed commands add signal beyond CI; missing targets are not listed as verification.
- [ ] Breaking changes section is present (`None` is a valid value after consideration).
- [ ] Screenshots/Videos section is included — populated when `--visual` produced embeddable remote assets, local-only table when copy-paste output can reference captured files, placeholder when capture failed or direct-update mode only has local files.

**Boundary, tone, and operational hygiene**

- [ ] Objective tone — no superlatives, no advocacy, no invented statistics.
- [ ] No references to spec files (`siw/SPEC.md`, `LOG.md`, etc.) or conversation history. Linear is the only external source the body may cite.
- [ ] No AI-attribution badges, "Generated with Claude Code", or `Co-Authored-By: Claude` lines.
- [ ] No placeholder `[TODO]` / `[Fill this in]` strings (except the documented Screenshots placeholder).
- [ ] Markdown headings, code blocks, and lists are well-formed.

**Output routing**

- [ ] `DIRECT_UPDATE=true` → no blocking missing requirements are present, then ran the Phase 4 sequence in order: repo-root anchored backup → local git exclude update → title/body files written outside shell interpolation → `gh pr edit --title "$(cat …)" --body-file …`. The success message includes the backup line only when the backup file is non-empty.
- [ ] `DIRECT_UPDATE=false` → presented copy-paste output; only asked about saving when `NON_INTERACTIVE=false`.
- [ ] Any `MISSING REQUIREMENT`, `UNVERIFIED`, `CONFUSION`, or `NOTICED BUT NOT TOUCHING` markers are emitted in the run output, not embedded in the PR body.
- [ ] Workflow artifact setup did not modify tracked files solely to ignore generated PR-description files.

**Final conciseness pass**

- [ ] Removed repeated phrasing or duplicated facts across Summary, Change Summary, Technical Details, Test Plan, and Breaking Changes.
- [ ] Shortened paragraphs and bullets that do not add reviewer value while preserving the why, risks, scope boundaries, and test instructions.
