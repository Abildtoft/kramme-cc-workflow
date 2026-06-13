---
name: kramme:visual:onboarding
description: "Generate an interactive HTML onboarding guide for newcomers to a codebase — architecture overview, domain model, key flows, conventions, and getting-started walkthrough."
argument-hint: "[focus-area or audience]"
disable-model-invocation: false
user-invocable: true
kramme-platforms: [claude-code, codex]
---

# Visual Onboarding Guide

Generate a comprehensive onboarding guide for newcomers to a codebase as a single HTML file (diagram and chart libraries load from CDN, so rendering needs network access).

Use this for a full newcomer guide to a codebase or subsystem. For a single diagram of one system or flow, use `kramme:visual:diagram` instead.

**Arguments:** "$ARGUMENTS"

## Prerequisites

Read `references/css-patterns.md` before generating — it holds the always-needed layout, depth-tier, zoom, and collapsible patterns. Load the other references (`libraries.md`, `responsive-nav.md`) and the asset templates only when the workflow step below calls for them.

**Aesthetic:** a warm, inviting editorial style — friendly textbook, not cold reference. Expressive typography, a clear palette, atmospheric backgrounds, obvious hierarchy, and motion only where it aids orientation. Vary fonts and palette. Respect `prefers-reduced-motion` and `prefers-color-scheme`.

## Workflow

1. **Think.** Decide who the onboarding page is for, what they need to understand first, and which diagrams best lower the initial cognitive load.

2. **Structure.** Choose the rendering approach. Read each resource below only when its condition applies:
   - `assets/mermaid-flowchart.html` for architecture, entity relationships, and key flows
   - `assets/architecture.html` for text-heavy module overviews
   - `assets/data-table.html` for setup commands, conventions, and quick-reference tables
   - `references/responsive-nav.md` when the guide spans 4+ sections and needs responsive navigation
   - `references/libraries.md` when using Mermaid theming, Chart.js, or anime.js (CDN usage)

3. **Style.** Apply the aesthetic from Prerequisites, keeping hierarchy and orientation cues obvious.

4. **Deliver.** Run the Verification Checkpoint, then produce and open the page per the **Output** section below.

## Arguments

- If `$ARGUMENTS` specifies a **focus area** ("frontend", "API", "auth"): scope exploration to that subsystem.
- If `$ARGUMENTS` specifies an **audience** ("backend dev", "designer"): adjust technical depth.
- If empty: full codebase for a generic developer audience.

## Data Gathering

Read the exploration dimensions guide from `references/exploration-dimensions.md`. Read the agent prompt template from `references/explore-agent.md`.

Launch **2-3 Explore agents** in parallel (Task tool, `subagent_type: Explore`), splitting six dimensions:

| Dimension | What to find |
| --- | --- |
| **Project Identity** | Project docs, package manifests, AGENTS.md / CLAUDE.md — purpose, users, tech stack |
| **Architecture** | Directory structure, module boundaries, dependency graph, entry points, build system |
| **Domain Model** | Key entities, relationships, schemas, state management, data flow |
| **Key Flows** | 3-5 most important user/system flows traced end-to-end |
| **Conventions** | Code style, naming, file organization, testing, common patterns |
| **Dev Setup** | Install, build, run, test, environment requirements |

Populate agent prompts with relevant dimension details from the exploration-dimensions reference.

If an agent returns nothing or fails, proceed with the dimensions you have and mark the gap in the fact sheet rather than blocking. If the codebase lacks project docs or a package manifest, still emit a best-effort guide and flag the thin sections explicitly.

## Verification Checkpoint

Before generating HTML, produce a structured fact sheet:

- Every module, function, type, and entity referenced — cite `source: file:line`
- Every architecture description and behavior claim
- Mark uncertain items explicitly
- Verify Mermaid diagram data against actual file structure
- Escape repo-derived text (code snippets, names, paths) before embedding it in HTML

## Page Sections

1. **Welcome & Project Identity** — Hero: name, one-sentence description, who it's for, key stats (languages, deps, test count). _Hero depth: large type, dominant._

2. **Architecture Overview** — Mermaid diagram of modules/relationships in `.mermaid-wrap` with zoom controls. Brief explanation per module. _Elevated depth._

3. **Domain Model** — Mermaid ER/class diagram of key entities. Glossary of domain terms. Collapsible `<details>` per entity.

4. **Data Flows** — Mermaid sequence/flowchart for 3-5 important flows. Each flow gets subsection with walkthrough.

5. **Getting Started** — Setup guide from README/docs. Common commands in styled table. "Your first change" walkthrough.

6. **Conventions Quick Reference** — Styled table of coding conventions, naming patterns, do's/don'ts.

7. **Key Files Map** — Interactive directory tree with `<details>`. Color-coded by module. Important files annotated.

8. **Where to Go Next** — Links to docs, common next steps, contacts (from CODEOWNERS if available).

**Visual hierarchy:** Sections 1-2 dominate viewport. Sections 5-8 are reference (compact, collapsible). Sticky sidebar nav.

## Output

Write to `~/.kramme-cc-workflow/diagrams/onboarding-{project-name}.html`, deriving `{project-name}` from the package manifest's `name`, falling back to the repository directory name. Create the directory if needed. Re-running for the same project overwrites the existing file.

Open in the default browser:

- macOS: `open <path>`
- Linux: `xdg-open <path>`
- Windows: `start <path>`

If no browser opens (e.g., a headless environment), skip it. Always report the final file path to the user.

Ultrathink.
