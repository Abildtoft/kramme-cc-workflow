---
name: kramme:pr:generate-description
description: Write a structured PR title and body from git diff, commit log, and Linear context when requested or delegated by a PR workflow. Model callers use output-only mode; a direct --auto invocation may update an existing PR.
argument-hint: "[--auto] [--no-update] [--visual] [--base <ref>] [--base-commit <oid>] [--linear-issue <ISSUE-ID>]"
disable-model-invocation: false
user-invocable: true
---

# PR Description Generator

## Parse Arguments

Parse `$ARGUMENTS` for flags:

- `--auto`: Preferred hands-off mode for explicit user invocation. Skip clarification prompts (Phase 2.5) and the save-to-file prompt (Phase 4). If a PR already exists for the current branch, update its title/body directly. If no PR exists yet, generate the title and description for copy-paste without pausing for user input.
- `--no-update`: Output-only automation mode for orchestrators that need generated title/body content but must not mutate an existing PR. Valid with `--auto`; it skips prompts but keeps `DIRECT_UPDATE=false` even if `gh pr view` finds a PR.
- `--visual`: Delegate best-effort demo evidence capture to `kramme:visual:demo-reel` and include the resulting Screenshots/Videos section. If capture cannot run, continue with the placeholder section.
- `--for-pr-create`: Internal publishing-parent mode. Accept it only with `--auto --no-update --visual --base-commit <oid>`; it exposes the validated-manifest handoff consumed by `kramme:pr:create`.
- `--start-if-easy`: Internal environment-startup capability. Accept it only with valid `--for-pr-create` mode; it may be supplied only by `kramme:pr:create --auto`.
- `--base <ref>`: Use `<ref>` as the base branch for diff computation instead of auto-detecting.
- `--base-commit <oid>`: Pin diff computation to a caller-validated full commit OID while retaining branch metadata from `--base`.
- `--linear-issue <ISSUE-ID>`: Use a caller-validated Linear identifier as the authoritative issue context. Validate `[A-Za-z0-9]+-[0-9]+`, normalize it to uppercase, and do not replace it with a branch-name substring.

If `--auto` is present, set `AUTO_MODE=true` and `NON_INTERACTIVE=true`, and remove the flag from remaining arguments. If `--no-update` is present, set `OUTPUT_ONLY=true` and remove the flag from remaining arguments. If `--visual` is present, set `VISUAL_MODE=true` and remove the flag from remaining arguments. If `--for-pr-create` is present, set `PUBLISHING_PARENT=true` and remove the flag. If `--start-if-easy` is present, set `START_IF_EASY=true` and remove the flag. If `--base <ref>` is present, set `BASE_BRANCH_OVERRIDE=<ref>` and remove the flag and value from remaining arguments. If `--base-commit <oid>` is present, require a full 40-character lowercase commit OID, set `BASE_COMMIT_OVERRIDE=<oid>`, and remove the flag and value. If `--linear-issue <ISSUE-ID>` is present, set `LINEAR_ISSUE_OVERRIDE` to the validated normalized value and remove the flag and value. Reject a missing or invalid value before Phase 1. Reject `PUBLISHING_PARENT=true` unless `AUTO_MODE`, `OUTPUT_ONLY`, `VISUAL_MODE`, and `BASE_COMMIT_OVERRIDE` are all set. Reject `START_IF_EASY=true` unless `PUBLISHING_PARENT=true`.

### Sub-Skill Invocation Contract

When another skill invokes this one as an orchestration step, it must pass `--auto` (and should pass `--base <ref> --base-commit <oid>` when it already resolved and pinned the base branch). If the caller already validated a Linear issue, it should pass `--linear-issue <ISSUE-ID>` so this skill does not depend on lossy branch-name extraction. If the caller only needs generated title/body content and owns the eventual publish gate, it must also pass `--no-update`. The exact `kramme:pr:create` parent additionally passes `--for-pr-create` with `--visual` so only that caller receives the publication manifest handoff, and its own `--auto` mode adds `--start-if-easy`. In `--auto` mode, Phase 2.5 clarification prompts and the Phase 4 save-to-file prompt are skipped. Missing context is surfaced as `MISSING REQUIREMENT:` output instead of prompting mid-orchestration; blocking missing requirements disable direct PR updates and produce copy-paste output.

Every model-initiated invocation must include `--no-update`. Omitting `--no-update` is reserved for a direct user invocation because that mode may mutate an existing Pull Request. Model invocation changes routing only; it never supplies permission to publish generated content.

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
     - Release impact when the diff changes a versioned artifact surface or durable public contract such as a public API, package, CLI, integration contract, or data contract

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
- The diff changes a versioned artifact surface or durable public contract such as a public API, package, CLI, integration contract, or data contract, and a breaking change is present, but no SemVer rationale or migration/upgrade note is available — blocking for direct update; request the intended version impact and consumer migration guidance.
- One or more selectable GitHub PR templates are present, no default template is selected, and no template can be selected from user input, existing PR body, branch name, or change type — blocking for direct update; request which template to follow.

The "no Linear ID" condition is the only non-blocking `MISSING REQUIREMENT:` marker. Treat every other `MISSING REQUIREMENT:` marker emitted by this skill or its references as blocking, including future marker types not yet listed here. This stable classification lets non-interactive callers stop safely without duplicating and drifting behind this list.

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
   - **ALWAYS** make this opening answer to “What does this PR do?” the simplest part of the description—almost ELI10: use everyday language that an intelligent ten-year-old unfamiliar with the codebase could follow
   - **ALWAYS** lead with the user-visible or business outcome, not files, classes, APIs, or implementation mechanics
   - **PREFER** short sentences and familiar words; save unavoidable technical terms and implementation detail for later sections
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
- Risks, release impact, rollout constraints, migrations, feature-flag defaults, SemVer implications, or partial coverage
- Manual test scenarios reviewers or QA should perform
- Review landmarks only when the diff has a non-obvious entry point or coupled files that should be reviewed together

**NEVER** include description content whose main value is already provided by GitHub:

- A changed-file list, file tree, or file-by-file inventory
- File counts, line counts, or `git diff --stat` summaries
- A commit-by-commit changelog
- Branch, author, or review metadata already visible in the PR chrome
- A generic "Changes by Area" section that only groups modified files by Frontend/Backend/Tests
- Local environment failure notes such as missing `node_modules`, unavailable Postgres, missing services, or other reasons a command could not run on the agent machine; CI is the source of truth for build, lint, typecheck, formatting, and automated test status

If a section would merely prove that files changed, omit it or replace it with one or two review-relevant notes that explain behavior, coupling, risk, or review order.

#### 3.1.6 Release Impact Contract

When the diff changes a versioned artifact surface or durable public contract, make the release story explicit in the PR body:

- State the release impact in reviewer language: public API behavior, package/CLI surface, integration contract, or schema/data contract.
- Name the SemVer implication when the repo publishes a versioned artifact (`patch`, `minor`, or `major`) and explain breaking-change rationale when applicable.
- Include migration or upgrade notes for breaking changes, removed behavior, required env/config changes, or consumer action.
- Mention the curated changelog/release-note entry when the PR is expected to feed one, but do not paste a raw commit log.

If there is no versioned artifact or durable public contract change, say so briefly only when reviewers might otherwise infer a release impact.

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

Read `references/visual-capture.md` and follow **Phase 3.5** to delegate evidence capture to `kramme:visual:demo-reel`, expose its manifest only when `PUBLISHING_PARENT=true`, and build the Screenshots/Videos section. Do not implement a separate screenshot/GIF capture flow here.

### Phase 4: Output Formatting

Use the selected GitHub template or `assets/section-templates.md` as the Markdown structure. Never include meta-commentary, placeholders such as `[TODO]` or `[Fill this in]`, AI attribution, AI badges, or AI co-author lines.

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

If yes, prepare the save-only namespace with this self-contained procedure. It is intentionally separate from `references/direct-update.md`, whose private update storage must remain outside the repository:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel) || exit 1
SAVE_NAMESPACE="$REPO_ROOT/.kramme-cc-workflow"
SAVE_DIR="$SAVE_NAMESPACE/pr-description"
PR_DESCRIPTION_FILE="$SAVE_DIR/PR_DESCRIPTION.md"
if [ -L "$SAVE_NAMESPACE" ] || [ -L "$SAVE_DIR" ] || [ -L "$PR_DESCRIPTION_FILE" ]; then
  echo "Error: PR description save path is indirect; no file was written." >&2
  exit 1
fi
mkdir -p "$SAVE_DIR" || exit 1
if [ ! -d "$SAVE_DIR" ] || [ -L "$SAVE_DIR" ]; then
  echo "Error: PR description save directory is invalid; no file was written." >&2
  exit 1
fi
GIT_EXCLUDE=$(git rev-parse --git-path info/exclude) || exit 1
mkdir -p "$(dirname "$GIT_EXCLUDE")" || exit 1
touch "$GIT_EXCLUDE" || exit 1
if ! grep -qxF ".kramme-cc-workflow/" "$GIT_EXCLUDE"; then
  printf '\n.kramme-cc-workflow/\n' >> "$GIT_EXCLUDE" || {
    echo "Error: Could not update Git's local exclude file; the description was not saved." >&2
    exit 1
  }
fi
printf '%s\n' "$PR_DESCRIPTION_FILE"
```

Capture the single printed absolute path, require it to remain below the validated `SAVE_DIR`, and write the description there with the runtime's native file-write capability. Confirm the absolute path after saving.

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
- **MISSING REQUIREMENT** — context the user must provide before a faithful description can be generated. The exact no-Linear-ID advisory is non-blocking; every other marker is blocking. Example: `MISSING REQUIREMENT: no Linear ID in branch name and no issue mentioned in commits — confirm the intended ticket or proceed without one`.

## Common Rationalizations

Before finalizing, read `references/red-flags.md` once. It owns both common rationalizations and red-flag stop conditions.

## Red Flags

Apply the `Red Flags — STOP` section from the already-loaded reference and regenerate when any condition matches.

## Verification

Read `references/verification-checklist.md` and complete it before presenting copy-paste output, before `gh pr edit`, and before saving to file.
