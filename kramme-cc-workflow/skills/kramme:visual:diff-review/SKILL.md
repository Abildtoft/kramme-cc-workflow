---
name: kramme:visual:diff-review
description: Use when you want a shareable visual walkthrough of an existing branch, PR, commit, or range diff. Generates a self-contained HTML artifact with before/after architecture comparison, KPI dashboard, Mermaid dependency graphs, explanatory review notes, and decision log. Not an actionable PR/code review workflow; use kramme:pr:code-review for inline code findings or kramme:pr:ux-review for live UX/product review.
argument-hint: "[branch|commit|PR#|range]"
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code, codex]
---

# Visual Diff Review

Generate a comprehensive visual diff review as a self-contained HTML page.

This produces a visual before/after artifact. It is not an actionable code review workflow: use `kramme:pr:code-review` for fix-oriented code findings and `kramme:pr:ux-review` for live UX, product, visual, and accessibility review.

**Arguments:** "$ARGUMENTS"

## Prerequisites

Confirm the environment before gathering data:

- Run from inside a git work tree. If the working directory is not a git repository, report that and stop.
- For a PR-number argument, `gh` must be installed and authenticated. If it is missing, report the exact tool needed and stop, or ask for a branch or range instead.

Read the local `references/` and `assets/` files just-in-time, as step 2 below directs — each entry there names the file that covers each need. Use a GitHub-diff-inspired aesthetic with red/green before/after panels, but vary fonts and palette from previous diagrams.

## Workflow

1. **Think (ultrathink).** Decide what changed, who needs the explanation, and which comparisons deserve the most visual weight. Choose diagram types that make before/after changes legible, not just pretty.

2. **Structure.** Use the local templates and references to choose the rendering approach:
   - `assets/architecture.html` for text-heavy architecture comparisons
   - `assets/mermaid-flowchart.html` for dependency graphs, pipelines, state changes, and behavioral flows
   - `assets/data-table.html` for KPI dashboards, file maps, and review tables
   - `references/css-patterns.md` for layout patterns, zoom controls, depth tiers, and collapsible sections
   - `references/responsive-nav.md` when the diff review spans 4+ sections and needs responsive navigation
   - `references/libraries.md` for Mermaid theming, Chart.js, anime.js, and CDN usage

3. **Style.** Use typography, palette, and depth to clearly distinguish before, after, neutral context, and risks. Avoid generic default styling. Respect `prefers-reduced-motion`.

4. **Deliver.** Write a single self-contained HTML file to `~/.kramme-cc-workflow/diagrams/`, open it in the browser, and report the file path to the user.

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
- Check whether project documentation needs updates given new or changed features
- Reconstruct decision rationale: mine conversation history, progress docs, commit messages, PR descriptions

## Verification Checkpoint

Before generating HTML, produce a structured fact sheet of every claim you will present:

- Every quantitative figure: line counts, file counts, function counts, test counts
- Every function, type, and module name you will reference
- Every behavior description: what code does, what changed, before vs. after
- For each, cite the source: the git command output or the file:line where you read it
- If something cannot be verified, mark it as uncertain rather than stating it as fact
- Do not embed secrets, credentials, tokens, or personal data surfaced in diffs, commit messages, or source. Summarize sensitive areas instead of quoting them — the output is written to disk and opened in a browser
- Escape repo-derived text (code snippets, names, paths, commit messages) before embedding it in HTML

## Page Sections

1. **Executive summary** — lead with the _intuition_: why do these changes exist? What was the core insight? Then factual scope (X files, Y lines, Z new modules). _Hero depth: larger type 20-24px, accent-tinted background._
2. **KPI dashboard** — lines added/removed, files changed, new modules, test counts. Include housekeeping indicator: CHANGELOG updated (green/red), docs need changes (green/yellow/red).
3. **Module architecture** — Mermaid dependency graph of the current state. Wrap in `.mermaid-wrap` with zoom controls.
4. **Major feature comparisons** — side-by-side before/after panels for each significant area of change.
5. **Flow diagrams** — Mermaid flowchart, sequence, or state diagrams for new lifecycle/pipeline/interaction patterns. Same zoom controls.
6. **File map** — full tree with color-coded new/modified/deleted indicators. Use `<details>` collapsed by default.
7. **Test coverage** — before/after test file counts and what's covered.
8. **Review notes** — explanatory Good/Bad/Ugly analysis for the visual artifact, not authoritative inline findings. For actionable code review, use `kramme:pr:code-review`; for live UX/product review, use `kramme:pr:ux-review`.
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

Write to `~/.kramme-cc-workflow/diagrams/diff-review-{descriptive-name}.html`. Create the directory if needed. Re-running with the same scope reuses the same descriptive name and overwrites the previous file by design — vary the name only when you want to keep an earlier review.

Open in browser:

- macOS: `open ~/.kramme-cc-workflow/diagrams/{filename}.html`
- Linux: `xdg-open ~/.kramme-cc-workflow/diagrams/{filename}.html`

Report the file path to the user. Include responsive section navigation.
