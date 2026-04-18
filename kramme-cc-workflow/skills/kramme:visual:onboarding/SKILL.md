---
name: kramme:visual:onboarding
description: "(experimental) Generate an interactive HTML onboarding guide for newcomers to a codebase — architecture overview, domain model, key flows, conventions, and getting-started walkthrough."
argument-hint: "[focus-area or audience]"
disable-model-invocation: false
user-invocable: true
kramme-platforms: [claude-code]
---

# Visual Onboarding Guide

Generate a comprehensive, self-contained HTML onboarding guide for newcomers to a codebase.

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

Follow the workflow below. Use a warm, inviting editorial aesthetic: friendly textbook, not cold reference. Vary fonts and palette.

## Workflow

1. **Think.** Decide who the onboarding page is for, what they need to understand first, and which diagrams best lower the initial cognitive load.

2. **Structure.** Use the local templates and references to choose the rendering approach:
   - `assets/architecture.html` for text-heavy module overviews
   - `assets/mermaid-flowchart.html` for architecture, entity relationships, and key flows
   - `assets/data-table.html` for setup commands, conventions, and quick-reference tables
   - `references/css-patterns.md` for layout patterns, zoom controls, depth tiers, and collapsible sections
   - `references/responsive-nav.md` when the guide spans 4+ sections and needs responsive navigation
   - `references/libraries.md` for Mermaid theming, Chart.js, anime.js, and CDN usage

3. **Style.** Make the page inviting and readable: expressive typography, a clear palette, atmospheric backgrounds, obvious hierarchy, and motion only where it helps orientation. Respect `prefers-reduced-motion`.

4. **Deliver.** Write a single self-contained HTML file to `~/.kramme-cc-workflow/diagrams/`, open it in the browser, and report the file path to the user.

## Arguments

- If `$ARGUMENTS` specifies a **focus area** ("frontend", "API", "auth"): scope exploration to that subsystem.
- If `$ARGUMENTS` specifies an **audience** ("backend dev", "designer"): adjust technical depth.
- If empty: full codebase for a generic developer audience.

## Data Gathering

Read the exploration dimensions guide from `references/exploration-dimensions.md`.
Read the agent prompt template from `references/explore-agent.md`.

Launch **2-3 Explore agents** in parallel (Task tool, `subagent_type: Explore`), splitting six dimensions:

| Dimension | What to find |
|---|---|
| **Project Identity** | Project docs, package manifests, AGENTS.md / CLAUDE.md — purpose, users, tech stack |
| **Architecture** | Directory structure, module boundaries, dependency graph, entry points, build system |
| **Domain Model** | Key entities, relationships, schemas, state management, data flow |
| **Key Flows** | 3-5 most important user/system flows traced end-to-end |
| **Conventions** | Code style, naming, file organization, testing, common patterns |
| **Dev Setup** | Install, build, run, test, environment requirements |

Populate agent prompts with relevant dimension details from the exploration-dimensions reference.

## Verification Checkpoint

Before generating HTML, produce a structured fact sheet:
- Every module, function, type, and entity referenced — cite `source: file:line`
- Every architecture description and behavior claim
- Mark uncertain items explicitly
- Verify Mermaid diagram data against actual file structure

## Page Sections

1. **Welcome & Project Identity** — Hero: name, one-sentence description, who it's for, key stats (languages, deps, test count). *Hero depth: large type, dominant.*

2. **Architecture Overview** — Mermaid diagram of modules/relationships in `.mermaid-wrap` with zoom controls. Brief explanation per module. *Elevated depth.*

3. **Domain Model** — Mermaid ER/class diagram of key entities. Glossary of domain terms. Collapsible `<details>` per entity.

4. **Data Flows** — Mermaid sequence/flowchart for 3-5 important flows. Each flow gets subsection with walkthrough.

5. **Getting Started** — Setup guide from README/docs. Common commands in styled table. "Your first change" walkthrough.

6. **Conventions Quick Reference** — Styled table of coding conventions, naming patterns, do's/don'ts.

7. **Key Files Map** — Interactive directory tree with `<details>`. Color-coded by module. Important files annotated.

8. **Where to Go Next** — Links to docs, common next steps, contacts (from CODEOWNERS if available).

**Visual hierarchy:** Sections 1-2 dominate viewport. Sections 5-8 are reference (compact, collapsible). Sticky sidebar nav. Support `prefers-color-scheme`.

## Output

Write to `~/.kramme-cc-workflow/diagrams/onboarding-{project-name}.html`. Create directory if needed.
Open in browser:
- macOS: `open ~/.kramme-cc-workflow/diagrams/{filename}.html`
- Linux: `xdg-open ~/.kramme-cc-workflow/diagrams/{filename}.html`
Report the file path to the user.

Include responsive section navigation.

Ultrathink.
