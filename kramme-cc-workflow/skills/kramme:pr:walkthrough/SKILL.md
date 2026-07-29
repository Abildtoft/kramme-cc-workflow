---
name: kramme:pr:walkthrough
description: "Generate a local visual walkthrough as a self-contained HTML artifact. Use the default guided D3 style for current-branch or open-PR orientation through system, data-flow, code-dependency, and user-action views; use --report with an optional branch, commit, PR, or range for a shareable before/after architecture comparison, KPI dashboard, Mermaid graphs, explanatory review notes, and decision log. Not for actionable code review findings, PR descriptions, publishing, or live UX audits."
argument-hint: "[--report [branch|commit|PR#|range] | --report --base <ref> | --base <ref>] [--output <path>]"
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code, codex]
---

# PR Walkthrough

Create a local, reviewer-facing visual explanation of an existing diff. Choose one style:

- **Guided walkthrough (default)** — Orient a reviewer to the current branch or open GitHub PR with a static D3 page and four interactive views.
- **Report (`--report`)** — Explain a branch, commit, PR, or range with a self-contained before/after report built from local visual templates.

This is an orientation artifact, not a review workflow. Do not invent authoritative findings, approve/request changes, or duplicate `kramme:pr:code-review` or `kramme:pr:ux-review`.

**Arguments:** "$ARGUMENTS"

If `--report` is present, remove it from the scope arguments and parse `--base <ref>` and `--output <path>`, requiring a value for each option that appears. Reject unknown flags and multiple positional scopes. If both a positional scope and `--base <ref>` are present, stop with: `Report mode accepts either one positional scope or --base, not both.` Otherwise follow only **Report Style (`--report`)**. Do not invoke the D3 render or validation scripts in report mode.

If `--report` is absent, accept only `--base <ref>` and `--output <path>`. If any positional token or unknown flag remains after parsing those options, stop with: `Positional branch, commit, PR, and range scopes require --report.` Otherwise follow only **Guided Walkthrough (Default)**.

## Guided Walkthrough (Default)

Create a single static HTML page with four interactive D3 views:

- **System overview** — stable architecture context for the subsystem touched by the PR. Keep this view PR-agnostic: no diff links, review comments, screenshots, changed-file callouts, or "this PR changes..." language.
- **Data flow** — how inputs, state, requests, files, assets, or rendered output move through the changed path.
- **Code dependency** — entry points, ownership boundaries, changed modules, leaf dependencies, and relevant tests.
- **User action** — the user surface, action, feedback, loading/error states, and implementation path.

### Workflow

1. **Parse arguments.**
   - `--base <ref>` overrides base-branch detection.
   - `--output <path>` overrides the default output path. Store the resolved value as `OUTPUT_PATH`.
   - Default `OUTPUT_PATH`: `.context/pr-walkthrough/index.html`.
   - Set `OUTPUT_DIR` to the parent directory of `OUTPUT_PATH`.
   - This skill only creates local artifacts. If the user asks for a public or hosted URL, stop after generating the local walkthrough and say publishing is out of scope for this skill.

2. **Resolve PR scope.**
   - Confirm the current directory is a git work tree.
   - Prefer the branch's open GitHub PR when `gh` is available:

     ```bash
     gh pr view --json number,url,title,body,baseRefName,headRefName,state,files,comments,reviews
     ```

   - Set `BASE_REF` from the PR's `baseRefName`. If no PR is available, resolve `BASE_REF` from `--base`, then `origin/HEAD`, then `origin/main`, then `origin/master`.
   - Collect:

     ```bash
     git --no-pager diff --stat "$BASE_REF"...HEAD
     git --no-pager diff --name-status "$BASE_REF"...HEAD
     git --no-pager log --oneline "$BASE_REF"..HEAD
     git --no-pager diff "$BASE_REF"...HEAD
     ```

3. **Read the codebase, not only the diff.**
   - Read the full current versions of important changed files.
   - Follow imports, call sites, type definitions, tests, state owners, renderers, commands, route handlers, and adjacent modules until the subsystem shape is clear.
   - Inspect unchanged files when they define the stable architecture touched by the PR.
   - Scale to PR size. Tiny PRs should produce compact views with 2-3 nodes/cards each; medium or large PRs can use more nodes only when each node teaches a distinct reviewer fact.

4. **Collect reviewer context.**
   - Include PR body, changed specs, existing review comments, linked issues, screenshots, demo videos, changed images/SVGs, and local artifacts when they clarify the review.
   - For changed specs, check paths under `specs/` and files named `PRODUCT.md`, `product.md`, `TECH.md`, `tech.md`, or close variants.
   - Download or export any visual assets into `OUTPUT_DIR/assets/` and reference them as `assets/<file>` or a safe image/video data URI. Do not hotlink remote images.
   - If review comments, specs, or visuals are unavailable, represent that absence as a terse note on a relevant PR-specific node.

5. **Build diff links when a PR URL is known.**
   - Link changed-file references to the PR's Files changed tab:

     ```text
     <pr_url>/files#diff-<sha256-lowercase-file-path>
     ```

   - Add `R<new_line>` or `L<old_line>` anchors when line-specific evidence is needed.
   - Generate anchors deterministically with a hash helper or shell command, not by hand.

6. **Create the view model.**
   - Write a JSON file with this shape:

     ```json
     {
       "meta": {
         "title": "PR title or branch name",
         "summary": "One-sentence reviewer orientation.",
         "prUrl": "https://github.com/org/repo/pull/123",
         "baseRef": "main",
         "headRef": "feature-branch"
       },
       "graphs": [
         {
           "id": "system-overview",
           "label": "System overview",
           "summary": "Stable subsystem architecture.",
           "nodes": [],
           "edges": [],
           "tour": []
         }
       ]
     }
     ```

   - Include exactly these graph IDs: `system-overview`, `data-flow`, `code-dependency`, `user-action`.
   - Each graph needs its own nodes and tour.
   - Non-overview graphs need directed edges with relationship labels.
   - System overview should normally have no edges and should use larger cards with visible paragraph summaries.
   - Every tour step must point to an existing node and explain why that node matters at that point.
   - Nodes should be concepts, subsystems, state owners, user surfaces, tests, specs, and review-discussion hotspots, not a dump of every changed file.

7. **Render the static walkthrough.**
   - Resolve `SKILL_DIR` to this skill directory.
   - Use the helper script:

     ```bash
     python3 "$SKILL_DIR/scripts/render_walkthrough.py" \
       --data .context/pr-walkthrough/graph.json \
       --output "$OUTPUT_PATH"
     ```

   - The generated page must load directly from `file://`, use inline data, avoid `fetch()` for local data, and inline D3 from the vendored asset at `$SKILL_DIR/assets/d3.v7.9.0.min.js`. Do not replace the vendored asset with a CDN or unversioned dependency.
   - Required UI: view toggles, zoom/pan, fit/reset zoom, search, detail panel, previous/next/restart tour controls, keyboard shortcuts, and stable `data-graph-id`, `data-node-id`, `data-edge-id`, and `data-tour-index` attributes.

8. **Validate before reporting ready.**
   - Run:

     ```bash
     python3 "$SKILL_DIR/scripts/validate_walkthrough.py" \
       --html "$OUTPUT_PATH"
     ```

   - Open the `file://` URL and manually verify graph switching, tour controls, search, node details, zoom/pan, and readable text. If browser automation is available, use it to capture at least one screenshot per view.
   - Do not report the walkthrough as ready if static validation fails. If browser validation cannot be performed, say that rendering is statically validated but visually unverified.

### Final Response

Report:

- Walkthrough path and `file://` URL.
- Base ref, head ref, and PR URL if found.
- Whether PR comments, changed specs, and visual artifacts were included or unavailable.
- Whether static validation passed and whether browser validation was performed.
- Any caveats about missing `gh`, missing comments, missing visuals, or requested publishing that was not performed.

## Report Style (`--report`)

Generate a comprehensive visual diff report as a self-contained HTML page. This is a visual before/after artifact, not an actionable code review: use `kramme:pr:code-review` for fix-oriented code findings and `kramme:pr:ux-review` for live UX, product, visual, and accessibility review.

### Prerequisites

Confirm the environment before gathering data:

- Run from inside a git work tree. If the working directory is not a git repository, report that and stop.
- For a PR-number argument, `gh` must be installed and authenticated. If it is missing, report the exact tool needed and stop, or ask for a branch or range instead.

Read the local `references/` and `assets/` files just in time, as step 2 below directs. Use a GitHub-diff-inspired aesthetic with red/green before/after panels, but vary fonts and palette from previous diagrams.

### Workflow

1. **Think.** Decide what changed, who needs the explanation, and which comparisons deserve the most visual weight. Choose diagram types that make before/after changes legible, not just pretty.

2. **Structure.** Use the local templates and references to choose the rendering approach:
   - `assets/architecture.html` for text-heavy architecture comparisons
   - `assets/mermaid-flowchart.html` for dependency graphs, pipelines, state changes, and behavioral flows
   - `assets/data-table.html` for KPI dashboards, file maps, and review tables
   - `references/css-patterns.md` for layout patterns, zoom controls, depth tiers, and collapsible sections
   - `references/responsive-nav.md` when the report spans 4+ sections and needs responsive navigation
   - `references/libraries.md` for Mermaid theming, Chart.js, anime.js, and CDN usage

3. **Style.** Use typography, palette, and depth to clearly distinguish before, after, neutral context, and risks. Avoid generic default styling. Respect `prefers-reduced-motion`.

4. **Generate and fact-check.** After composing the artifact, compare the rendered claims back to the fact sheet and source evidence before reporting it. Verify counts, file references, function/type names, Mermaid labels, before/after statements, and review notes. If polish introduced a new claim, add source evidence or remove the claim.

5. **Deliver.** Open the fact-checked artifact in the browser and report the file path to the user.

### Scope Detection

Determine what to diff from the remaining positional scope after removing `--report`, `--output <path>`, `--base <ref>`, and their values. Accept at most one positional scope. If `--base <ref>` is present and no positional scope remains, use `<ref>` as the branch/reference scope. The argument parser above rejects combining a positional scope with `--base` rather than silently ignoring either ref:

- Branch name (for example, `main` or `develop`): working tree vs. that branch
- Commit hash: that specific commit's diff (`git show <hash>`)
- `HEAD`: uncommitted changes only (`git diff` and `git diff --staged`)
- PR number (for example, `#42`): `gh pr diff 42`
- Range (for example, `abc123..def456`): diff between two commits
- No scope argument: detect the default branch from `origin/HEAD`; fall back to `main`, then `master`

### Data Gathering

Run these first to understand the full scope:

- `git diff --stat <ref>` for a file-level overview
- `git diff --name-status <ref> --` for new, modified, and deleted files; separate source from tests
- Compare line counts for key files between `<ref>` and the working tree
- Find new public API surface by checking added lines for exported symbols, public functions, classes, and interfaces
- Compare both sides for new actions, keybindings, config fields, and event types
- Read all changed files in full, including surrounding code paths needed to validate behavior
- Check whether `CHANGELOG.md` has an entry for the changes
- Check whether project documentation needs updates for new or changed features
- Reconstruct decision rationale from available conversation history, progress docs, commit messages, and PR descriptions

### Verification Checkpoint

Before generating HTML, produce a structured fact sheet of every claim to present:

- Record every quantitative figure: line counts, file counts, function counts, and test counts.
- Record every function, type, and module name to reference.
- Record every behavior description: what code does, what changed, and before vs. after.
- Cite each claim to command output or the file and line where it was read.
- Mark anything unverifiable as uncertain rather than stating it as fact.
- Do not embed secrets, credentials, tokens, or personal data surfaced in diffs, commit messages, or source. Summarize sensitive areas instead of quoting them because the output is written to disk and opened in a browser.
- Escape repo-derived text such as code snippets, names, paths, and commit messages before embedding it in HTML.
- Re-check the final HTML against the fact sheet before delivery. Every visible count, path, diagram label, and behavioral claim must trace to source evidence or be marked uncertain.

### Page Sections

1. **Executive summary** — Lead with the intuition: why do these changes exist, and what was the core insight? Then give factual scope such as files, lines, and new modules. Use hero depth with 20-24px type and an accent-tinted background.
2. **KPI dashboard** — Show lines added/removed, files changed, new modules, and test counts. Include housekeeping indicators for whether `CHANGELOG.md` was updated and whether docs need changes.
3. **Module architecture** — Show a Mermaid dependency graph of the current state inside `.mermaid-wrap` with zoom controls.
4. **Major feature comparisons** — Use side-by-side before/after panels for each significant change area.
5. **Flow diagrams** — Use Mermaid flowcharts, sequences, or state diagrams for new lifecycle, pipeline, or interaction patterns with the same zoom controls.
6. **File map** — Show a full tree with color-coded new, modified, and deleted indicators inside `<details>` collapsed by default.
7. **Test coverage** — Compare before/after test file counts and explain what is covered.
8. **Review notes** — Present explanatory Good/Bad/Ugly analysis for the visual artifact, not authoritative inline findings. Use `kramme:pr:code-review` for actionable review and `kramme:pr:ux-review` for live UX/product review.
   - **Good**: Solid choices, improvements, and clean patterns
   - **Bad**: Bugs, regressions, missing error handling, and logic errors
   - **Ugly**: Introduced tech debt and maintainability concerns
   - **Questions**: Anything unclear or needing author clarification
   - Style cards with green, red, amber, and blue left-border accents. Reference specific files and line ranges.
9. **Decision log** — For each significant design choice, include:
   - **Decision**: One-line summary
   - **Rationale**: Why this approach
   - **Alternatives considered**: What was rejected and why
   - **Confidence**: High for sourced, medium for inferred, and low for unrecoverable rationale, with green, blue, and amber borders respectively
10. **Re-entry context** — Add a present-you-to-future-you note inside `<details>` collapsed by default:
    - Key invariants the changed code relies on
    - Non-obvious coupling between files or behaviors
    - Gotchas that would surprise a future modifier
    - Follow-up work such as migrations, config updates, or docs

Make sections 1-3 dominate the viewport. Keep sections 6 onward compact and collapsible. Use red for removed/before, green for added/after, yellow for modified, and blue for neutral context.

### Output

If `--output <path>` is present, use it. Otherwise write the report to `~/.kramme-cc-workflow/diagrams/diff-review-{descriptive-name}.html`, creating the parent directory when needed and choosing a descriptive name for the current scope.

Open the report in a browser:

- macOS: `open <report-path>`
- Linux: `xdg-open <report-path>`

Report the file path to the user and include responsive section navigation.

## Source Tracking

This skill is adapted from the Warp `pr-walkthrough` concept and the nicobailon visual-explainer project, and it vendors D3 for offline single-file guided rendering. See `references/sources.yaml` for upstream source and license metadata used for maintenance audits.
