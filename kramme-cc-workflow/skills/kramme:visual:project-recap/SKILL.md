---
name: kramme:visual:project-recap
description: Generate a visual HTML project recap to rebuild mental model when returning to a project — architecture snapshot, recent activity timeline, decision log, and cognitive debt hotspots
argument-hint: "[time-window: 2w|30d|3m]"
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code, codex]
---

# Visual Project Recap

Generate a comprehensive visual project recap as a self-contained HTML page to rebuild mental model when returning to a project.

Use this when returning to a project you already know and need to reload context. For first-time orientation in an unfamiliar codebase, use `kramme:visual:onboarding` instead — an onboarding walkthrough fits better than a recap.

**Arguments:** "$ARGUMENTS"

## Visual resources

Load these on demand as Workflow step 2 directs — don't read them all up front:

- `references/css-patterns.md`, `references/libraries.md`, `references/responsive-nav.md`
- `assets/architecture.html`, `assets/data-table.html`, `assets/mermaid-flowchart.html` — copy the one template matching the element you're rendering

Use a warm editorial or paper/ink aesthetic with muted blues and greens. Vary fonts and palette so the page doesn't feel generic.

## Workflow

1. **Think.** Decide who the page is for, which diagram types best explain the project, and which visual direction fits this recap. Do not default to a generic dark dashboard.

2. **Structure.** Use the local templates and references to choose the right rendering approach:
   - `assets/architecture.html` for text-heavy architecture snapshots
   - `assets/mermaid-flowchart.html` for Mermaid-based flows, state, and dependency views
   - `assets/data-table.html` for KPI tables, audits, and structured comparisons
   - `references/css-patterns.md` for layout, depth tiers, zoom controls, and collapsible sections
   - `references/responsive-nav.md` when the page has 4+ sections and needs sticky desktop nav plus mobile horizontal nav
   - `references/libraries.md` for Mermaid theming, Chart.js, anime.js, and CDN usage

3. **Style.** Make typography, palette, depth, and motion feel intentional. Use distinctive Google Fonts, CSS custom properties for the full palette, atmospheric backgrounds instead of flat fills, meaningful hierarchy, and motion that respects `prefers-reduced-motion`.

4. **Generate and fact-check.** After composing the artifact, compare the rendered claims back to the fact sheet and source evidence before reporting it. Verify counts, file references, module names, Mermaid labels, timeline summaries, decision log entries, and cognitive debt labels. If polish introduced a new claim, add source evidence or remove the claim.

5. **Deliver.** Open the fact-checked artifact. See the Output section for the path, overwrite behavior, and how to open it.

## Time Window

Determine the recency window from the argument:

- Shorthand like `2w`, `30d`, `3m`: parse to git's `--since` format
- If argument doesn't match a time pattern, treat as free-form context and use default
- No argument: default to `2w` (2 weeks)
- If the window contains no commits, widen it (e.g., `2w` → `3m`) until there is activity, or state "no activity in {window}" explicitly rather than rendering empty Recent activity, Decision log, and Cognitive debt sections

## Data Gathering

If the directory is not a git repository, skip the git-based steps (2–4) and build the recap from docs, file structure, and source only — state plainly in the page that no git history was available. Otherwise:

1. **Project identity.** Read available project docs, `CHANGELOG.md`, `package.json` / `Cargo.toml` / `pyproject.toml` / `go.mod` for name, description, version, dependencies. Read the top-level file structure. If no manifest declares a name, fall back to the working-directory name.

2. **Recent activity.** `git log --oneline --since=<window>` for commit history. `git log --stat --since=<window>` for file-level change scope. `git shortlog -sn --since=<window>` for contributor activity. Identify most active codebase areas.

3. **Current state.** Check for uncommitted changes (`git status`). Check for stale branches (`git branch --no-merged`). Look for TODO/FIXME in recently changed files. Read progress docs if they exist.

4. **Decision context.** Read recent commit messages for rationale. If running in the same session as recent work, mine conversation history. Read any plan docs, RFCs, or ADRs.

5. **Architecture scan.** Read key source files to understand module structure and dependencies. Focus on entry points, public API surface, and files most frequently changed in the time window.

## Verification Checkpoint

Before generating HTML, produce a structured fact sheet of every claim you will present:

- Every quantitative figure: commit counts, file counts, line counts, branch counts
- Every module, function, and type name you will reference
- Every behavior and architecture description
- For each, cite the source: the git command output or the file:line where you read it
- If something cannot be verified, mark it as uncertain
- Do not embed secrets, credentials, tokens, or personal data surfaced in diffs, commit messages, or source. Summarize sensitive areas instead of quoting them — the output is written to disk and opened in a browser
- Re-check the final HTML against this fact sheet before delivery; every visible count, path, diagram label, timeline statement, and architecture claim must trace back to source evidence or be marked uncertain

## Page Sections

1. **Project identity** — a _current-state_ summary: what this project does, who uses it, what stage it's at. Include version, key dependencies, and the elevator pitch for someone who forgot what they were building.

2. **Architecture snapshot** — Mermaid diagram of the system as it exists today. Focus on conceptual modules and their relationships, not every file. Label nodes with what they do. Wrap in `.mermaid-wrap` with zoom controls. _Hero depth: elevated container, larger padding, accent-tinted background._

3. **Recent activity** — human-readable narrative grouped by theme: feature work, bug fixes, refactors, infrastructure. Timeline visualization with significant changes called out. For each theme, a one-sentence summary of what happened and why it mattered.

4. **Decision log** — key design decisions from the time window. Extracted from commit messages, conversation history, plan docs. Each entry: what was decided, why, what was considered. This is the highest-value section for fighting cognitive debt.

5. **State of things** — KPI card pattern with large hero numbers for working/broken/blocked/in-progress counts, with color-coded indicators:
   - What's working (stable, shipped, tested)
   - What's in progress (uncommitted work, open branches, active TODOs)
   - What's broken or degraded (known bugs, failing tests, tech debt)
   - What's blocked (waiting on external input, dependencies, decisions)

6. **Mental model essentials** — the 5-10 things you need to hold in your head to work on this project:
   - Key invariants and contracts
   - Non-obvious coupling
   - Gotchas (common mistakes, easy-to-forget requirements)
   - Naming conventions or patterns the codebase follows

7. **Cognitive debt hotspots** — amber-tinted cards with severity indicators (colored left border: red for high, amber for medium, blue for low):
   - Code that changed recently but has no documented rationale
   - Complex modules with no tests
   - Areas where multiple people made overlapping changes
   - Files frequently modified but poorly understood
   - Each with a concrete suggestion (e.g., "add a doc comment explaining the coordination levels")

8. **Next steps** — inferred from recent activity, open TODOs, project trajectory. Not prescriptive — just "here's where the momentum was pointing when you left." Include explicit next-step notes from progress docs if found.

**Visual hierarchy**: Sections 1-2 dominate the viewport (hero depth). Sections 6+ are reference material (compact, collapsible).

**Visual language**: Warm muted blues and greens for architecture, amber for cognitive debt hotspots, green/blue/amber/red for state-of-things status.

## Output

Write to `~/.kramme-cc-workflow/diagrams/project-recap-{project-name}.html`, where `{project-name}` is the manifest name or, failing that, the working-directory name. Create the directory if needed. Re-running overwrites the existing recap for this project.

Open in the browser, then report the file path to the user:

- macOS: `open <path>`
- Linux: `xdg-open <path>`
- Windows: `start "" "%USERPROFILE%\.kramme-cc-workflow\diagrams\project-recap-{project-name}.html"` (`~` does not expand under cmd.exe)

If no opener is available (headless, CI, or the command fails), just report the path — the file is the deliverable.

Include responsive section navigation.

Ultrathink.
