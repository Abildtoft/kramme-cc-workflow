---
name: kramme:visual:plan-review
description: Generate a visual HTML plan review comparing current codebase state vs. a proposed implementation plan, with architecture diagrams, blast radius analysis, and risk assessment
argument-hint: "[plan-file-path]"
disable-model-invocation: true
user-invocable: true
kramme-platforms: [claude-code]
---

# Visual Plan Review

Generate a comprehensive visual plan review as a self-contained HTML page, comparing the current codebase against a proposed implementation plan.

**Arguments:** "$ARGUMENTS"

## Prerequisites

Read the local visual references before generating:
- `references/css-patterns.md`
- `references/libraries.md`
- `references/responsive-nav.md`

Select the appropriate template to absorb patterns:
- `assets/architecture.html`
- `assets/data-table.html`
- `assets/mermaid-flowchart.html`

Follow the workflow below. Use a blueprint/editorial aesthetic with current-state vs. planned-state panels, but vary fonts and palette from previous diagrams.

## Workflow

1. **Think.** Decide who is reviewing the plan, which current-vs-planned comparisons need the strongest emphasis, and which diagram types will clarify blast radius and risk.

2. **Structure.** Use the local templates and references to choose the rendering approach:
   - `assets/architecture.html` for text-heavy subsystem snapshots
   - `assets/mermaid-flowchart.html` for current/planned architecture, dependency graphs, and flows
   - `assets/data-table.html` for impact dashboards, ripple analysis, and review tables
   - `references/css-patterns.md` for layout patterns, zoom controls, depth tiers, and collapsible sections
   - `references/responsive-nav.md` when the review spans 4+ sections and needs responsive navigation
   - `references/libraries.md` for Mermaid theming, Chart.js, anime.js, and CDN usage

3. **Style.** Use typography, palette, and depth to separate current state, planned state, and risk. Avoid default app styling. Use CSS custom properties, atmospheric backgrounds, and motion only where it helps comprehension.

4. **Deliver.** Write a single self-contained HTML file to `~/.kramme-cc-workflow/diagrams/`, open it in the browser, and report the file path to the user.

## Inputs

- Plan file: `$1` (path to a markdown plan, spec, or RFC document)
- Codebase: `$2` if provided, otherwise the current working directory

## Data Gathering

1. **Read the plan file in full.** Extract: problem statement, each proposed change (files to modify/create/delete), rejected alternatives, scope boundaries or non-goals.

2. **Read every file the plan references.** Also read files that import or depend on those files — the plan may not mention all ripple effects.

3. **Map the blast radius.** From the codebase, identify: what imports the files being changed, what tests exist for affected files, config files/types/schemas that might need updates, public API surface callers depend on.

4. **Cross-reference plan vs. code.** For each change the plan proposes, verify: does the referenced file/function/type exist? Does the plan's description of current behavior match the actual code? Are there implicit assumptions that don't hold?

## Verification Checkpoint

Before generating HTML, produce a structured fact sheet of every claim you will present:
- Every quantitative figure: file counts, estimated lines, function counts, test counts
- Every function, type, and module name from both the plan and the codebase
- Every behavior description: what the code currently does vs. what the plan proposes
- For each, cite the source: the plan section or the file:line where you read it
- If something cannot be verified, mark it as uncertain

## Page Sections

1. **Plan summary** — lead with the *intuition*: what problem does this plan solve, and what's the core insight behind the approach? Then scope: files touched, estimated scale, new modules planned. *Hero depth: larger type 20-24px, accent-tinted background.*

2. **Impact dashboard** — files to modify/create/delete, estimated lines added/removed, new test files, dependencies affected. Include completeness indicator: tests (green/red), docs updates (green/yellow/red), migration/rollback (green/grey).

3. **Current architecture** — Mermaid diagram of how the affected subsystem works *today*. Focus only on parts the plan touches. Wrap in `.mermaid-wrap` with zoom controls. *Use matching layout direction and node names as section 4.*

4. **Planned architecture** — Mermaid diagram of how the subsystem will work *after* implementation. Same node names and layout direction as current architecture. Highlight new nodes with accent border, removed nodes with reduced opacity, changed edges with different stroke color.

5. **Change-by-change breakdown** — for each change in the plan, a side-by-side panel:
   - **Left (current):** what the code does now, with relevant snippets
   - **Right (planned):** what the plan proposes, with code examples if provided
   - **Rationale:** why the plan chose this approach, from the plan's reasoning
   - Flag discrepancies where the plan's description doesn't match actual code

6. **Dependency & ripple analysis** — what other code depends on files being changed. Table or Mermaid graph showing callers, importers, downstream effects. Color-code: covered by plan (green), not mentioned but likely affected (amber), definitely missed (red). Use `<details>` collapsed by default.

7. **Risk assessment** — styled cards for:
   - Edge cases the plan doesn't address
   - Assumptions the plan makes that should be verified
   - Ordering risks if changes need specific sequence
   - Rollback complexity if things go wrong
   - Cognitive complexity — non-obvious coupling, action-at-a-distance, implicit contracts
   - Each risk gets a severity indicator (low/medium/high)

8. **Plan review** — structured Good/Bad/Ugly analysis:
   - **Good**: Solid design decisions, well-reasoned tradeoffs
   - **Bad**: Gaps — missing files, unaddressed edge cases, incorrect assumptions
   - **Ugly**: Complexity introduced, maintenance burden, long-term concerns
   - **Questions**: Ambiguities needing clarification before implementation
   - Styled cards with green/red/amber/blue left-border accents.

9. **Understanding gaps** — closing dashboard rolling up decision-rationale gaps and cognitive complexity flags:
   - Count of changes with clear rationale vs. missing rationale
   - List of cognitive complexity flags with severity
   - Recommendations: "Before implementing, document the rationale for changes X and Y"

**Visual hierarchy**: Sections 1-4 dominate the viewport (hero depth for summary, elevated for architecture). Sections 6+ are reference material (flat/recessed, compact, collapsible).

**Visual language**: Blue/neutral for current state, green/purple for planned additions, amber for concerns, red for gaps/risks.

## Output

Write to `~/.kramme-cc-workflow/diagrams/plan-review-{descriptive-name}.html`. Create the directory if needed.
Open in browser:
- macOS: `open ~/.kramme-cc-workflow/diagrams/{filename}.html`
- Linux: `xdg-open ~/.kramme-cc-workflow/diagrams/{filename}.html`
Report the file path to the user.

Include responsive section navigation.

Ultrathink.
