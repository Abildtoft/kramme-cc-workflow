---
name: kramme:visual:diff-review
description: Generate a visual HTML diff review with before/after architecture comparison, KPI dashboard, Mermaid dependency graphs, and code review analysis
argument-hint: "[branch|commit|PR#|range]"
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code]
---

# Visual Diff Review

Generate a comprehensive visual diff review as a self-contained HTML page.

**Arguments:** "$ARGUMENTS"

## Prerequisites

Read the shared visual references before generating:
- `${CLAUDE_PLUGIN_ROOT}/skills/kramme:visual:diagram/resources/references/css-patterns.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/kramme:visual:diagram/resources/references/libraries.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/kramme:visual:diagram/resources/references/responsive-nav.md`

Select the appropriate template to absorb patterns:
- `${CLAUDE_PLUGIN_ROOT}/skills/kramme:visual:diagram/resources/templates/architecture.html`
- `${CLAUDE_PLUGIN_ROOT}/skills/kramme:visual:diagram/resources/templates/data-table.html`
- `${CLAUDE_PLUGIN_ROOT}/skills/kramme:visual:diagram/resources/templates/mermaid-flowchart.html`

Follow the visual-explainer workflow from `${CLAUDE_PLUGIN_ROOT}/skills/kramme:visual:diagram/SKILL.md` (Think, Structure, Style, Deliver). Use a GitHub-diff-inspired aesthetic with red/green before/after panels, but vary fonts and palette from previous diagrams.

## Scope Detection

Determine what to diff based on the argument:
- Branch name (e.g. `main`, `develop`): working tree vs that branch
- Commit hash: that specific commit's diff (`git show <hash>`)
- `HEAD`: uncommitted changes only (`git diff` and `git diff --staged`)
- PR number (e.g. `#42`): `gh pr diff 42`
- Range (e.g. `abc123..def456`): diff between two commits
- No argument: detect default branch from `origin/HEAD`; fallback to `main`, then `master`

## Data Gathering

Run these first to understand the full scope:
- `git diff --stat <ref>` for file-level overview
- `git diff --name-status <ref> --` for new/modified/deleted files (separate src from tests)
- Line counts: compare key files between `<ref>` and working tree
- New public API surface: grep added lines for exported symbols, public functions, classes, interfaces
- Feature inventory: grep for new actions, keybindings, config fields, event types on both sides
- Read all changed files in full — include surrounding code paths needed to validate behavior
- Check whether `CHANGELOG.md` has an entry for these changes
- Check whether `README.md` or docs need updates given new or changed features
- Reconstruct decision rationale: mine conversation history, progress docs, commit messages, PR descriptions

## Verification Checkpoint

Before generating HTML, produce a structured fact sheet of every claim you will present:
- Every quantitative figure: line counts, file counts, function counts, test counts
- Every function, type, and module name you will reference
- Every behavior description: what code does, what changed, before vs. after
- For each, cite the source: the git command output or the file:line where you read it
- If something cannot be verified, mark it as uncertain rather than stating it as fact

## Page Sections

1. **Executive summary** — lead with the *intuition*: why do these changes exist? What was the core insight? Then factual scope (X files, Y lines, Z new modules). *Hero depth: larger type 20-24px, accent-tinted background.*
2. **KPI dashboard** — lines added/removed, files changed, new modules, test counts. Include housekeeping indicator: CHANGELOG updated (green/red), docs need changes (green/yellow/red).
3. **Module architecture** — Mermaid dependency graph of the current state. Wrap in `.mermaid-wrap` with zoom controls.
4. **Major feature comparisons** — side-by-side before/after panels for each significant area of change.
5. **Flow diagrams** — Mermaid flowchart, sequence, or state diagrams for new lifecycle/pipeline/interaction patterns. Same zoom controls.
6. **File map** — full tree with color-coded new/modified/deleted indicators. Use `<details>` collapsed by default.
7. **Test coverage** — before/after test file counts and what's covered.
8. **Code review** — structured Good/Bad/Ugly analysis:
   - **Good**: Solid choices, improvements, clean patterns
   - **Bad**: Bugs, regressions, missing error handling, logic errors
   - **Ugly**: Tech debt introduced, maintainability concerns
   - **Questions**: Anything unclear or needing author's clarification
   - Styled cards with green/red/amber/blue left-border accents. Reference specific files and line ranges.
9. **Decision log** — for each significant design choice:
   - **Decision**: one-line summary
   - **Rationale**: why this approach
   - **Alternatives considered**: what was rejected and why
   - **Confidence**: High (sourced, green border), Medium (inferred, blue border), Low (not recoverable, amber border)
10. **Re-entry context** — note from present-you to future-you. Use `<details>` collapsed by default.
    - Key invariants the changed code relies on
    - Non-obvious coupling between files/behaviors
    - Gotchas that would surprise someone modifying this code later
    - Follow-up work required (migration, config update, docs)

**Visual hierarchy**: Sections 1-3 dominate the viewport (hero depth). Sections 6+ are reference material (flat/recessed, compact, collapsible).

**Visual language**: Red for removed/before, green for added/after, yellow for modified, blue for neutral context.

## Output

Write to `~/.kramme-cc-workflow/diagrams/diff-review-{descriptive-name}.html`. Create the directory if needed.
Open in browser:
- macOS: `open ~/.kramme-cc-workflow/diagrams/{filename}.html`
- Linux: `xdg-open ~/.kramme-cc-workflow/diagrams/{filename}.html`
Report the file path to the user.

Include responsive section navigation.

Ultrathink.
