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

Read the shared visual references before generating:
- `${CLAUDE_PLUGIN_ROOT}/skills/kramme:visual:diagram/resources/references/css-patterns.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/kramme:visual:diagram/resources/references/libraries.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/kramme:visual:diagram/resources/references/responsive-nav.md`

Select the appropriate template to absorb patterns:
- `${CLAUDE_PLUGIN_ROOT}/skills/kramme:visual:diagram/resources/templates/architecture.html`
- `${CLAUDE_PLUGIN_ROOT}/skills/kramme:visual:diagram/resources/templates/data-table.html`
- `${CLAUDE_PLUGIN_ROOT}/skills/kramme:visual:diagram/resources/templates/mermaid-flowchart.html`

Follow the visual-explainer workflow from `${CLAUDE_PLUGIN_ROOT}/skills/kramme:visual:diagram/SKILL.md` (Think, Structure, Style, Deliver). Use a warm, inviting editorial aesthetic — "friendly textbook" not "cold reference." Vary fonts and palette.

## Arguments

- If `$ARGUMENTS` specifies a **focus area** ("frontend", "API", "auth"): scope exploration to that subsystem.
- If `$ARGUMENTS` specifies an **audience** ("backend dev", "designer"): adjust technical depth.
- If empty: full codebase for a generic developer audience.

## Data Gathering

Read the exploration dimensions guide from `resources/references/exploration-dimensions.md`.
Read the agent prompt template from `resources/prompts/explore-agent.md`.

Launch **2-3 Explore agents** in parallel (Task tool, `subagent_type: Explore`), splitting six dimensions:

| Dimension | What to find |
|---|---|
| **Project Identity** | README, package manifests, CLAUDE.md — purpose, users, tech stack |
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
