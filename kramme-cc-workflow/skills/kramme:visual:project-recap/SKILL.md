---
name: kramme:visual:project-recap
description: Generate a visual HTML project recap to rebuild mental model when returning to a project — architecture snapshot, recent activity timeline, decision log, and cognitive debt hotspots
argument-hint: "[time-window: 2w|30d|3m]"
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code]
---

# Visual Project Recap

Generate a comprehensive visual project recap as a self-contained HTML page to rebuild mental model when returning to a project.

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

Follow the visual-explainer workflow from `${CLAUDE_PLUGIN_ROOT}/skills/kramme:visual:diagram/SKILL.md` (Think, Structure, Style, Deliver). Use a warm editorial or paper/ink aesthetic with muted blues and greens, but vary fonts and palette from previous diagrams.

## Time Window

Determine the recency window from the argument:
- Shorthand like `2w`, `30d`, `3m`: parse to git's `--since` format
- If argument doesn't match a time pattern, treat as free-form context and use default
- No argument: default to `2w` (2 weeks)

## Data Gathering

1. **Project identity.** Read `README.md`, `CHANGELOG.md`, `package.json` / `Cargo.toml` / `pyproject.toml` / `go.mod` for name, description, version, dependencies. Read the top-level file structure.

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

## Page Sections

1. **Project identity** — a *current-state* summary: what this project does, who uses it, what stage it's at. Include version, key dependencies, and the elevator pitch for someone who forgot what they were building.

2. **Architecture snapshot** — Mermaid diagram of the system as it exists today. Focus on conceptual modules and their relationships, not every file. Label nodes with what they do. Wrap in `.mermaid-wrap` with zoom controls. *Hero depth: elevated container, larger padding, accent-tinted background.*

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

Write to `~/.kramme-cc-workflow/diagrams/project-recap-{project-name}.html`. Create the directory if needed.
Open in browser: `open ~/.kramme-cc-workflow/diagrams/{filename}.html`
Report the file path to the user.

Include responsive section navigation.

Ultrathink.
