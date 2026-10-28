# The root README is the entry point; deep usage reference lives in docs guides

- Status: ACCEPTED
- Date: 2026-10-28
- Deciders: repository maintainer (explicit implementation request)

## Context

The settled rule kept install, usage, component listings, and testing documentation in the root `README.md`. Under that rule the README grew from about 61 KB in June 2026 to 134 KB in October, and 160 commits touched it between August and October. Every behavior change added a clause to the README as well as to the owning `SKILL.md`, and Bats tests and synced contracts pinned the README wording, so the README became a second specification.

The result was hard to read. Getting Started held 23 KB of reference material, and the four-command review flow first appeared on line 315. One paragraph describing `kramme:linear:issue-to-pr` ran to 5,245 characters, and another ran migration notes for 16 renamed commands together into 4,830 characters. Thirteen migration notes about removed or moved commands sat between the tables of live skills. The skill and agent tables showed full routing descriptions, written for model routing rather than for people, of up to 879 characters per cell. `docs/siw.md` and `docs/hooks.md` already showed the alternative: the README summarizes a workflow and links a guide.

## Decision

- The root `README.md` stays the canonical entry point. It holds what the plugin is, a quick start, requirements, install and update, short workflow guides, a configuration table, the skill, agent, and hook reference, renamed and removed commands, and contributor entry points.
- Deep usage reference lives in linked guides under `kramme-cc-workflow/docs/`: `review.md` for review workflows, `shipping.md` for implementing and publishing, plus the existing `siw.md`, `hooks.md`, `agent-portability.md`, and `development.md`. The owning `SKILL.md` remains the contract.
- Skill and agent table rows show a one-line summary of at most 160 characters from `summaries` in `readme_skill_sync` and `readme_agent_sync` in `scripts/synced-contracts.yaml`. The full description stays in the component source. The README sync check fails when a component lacks a summary, a summary names an unknown component, or a summary exceeds the limit.
- `lint-skill-contracts.py` warns on README paragraphs and list items of 500 characters or more. The warning is a burndown queue, like the long-skill and long-description warnings.
- Tests pin behavior wording in the owning `SKILL.md` or the docs guide that documents it. They pin the README only for component existence, generated rows, migration entries, and links.

## Alternatives and consequences

- **Keep everything in the README behind collapsible `<details>` sections.** This would have kept the old rule and the pinned phrases in place, but the README would have stayed a second specification, kept growing, and hidden content from search.
- **A summary field in each component's frontmatter.** Summaries would sit next to their descriptions, but the change would touch 105 shipped files and need schema and converter changes. A central map follows the precedent of hook descriptions, which already live in the registry. Adding a skill or agent now also means adding its summary there; the README sync check enforces that.
- **Derive summaries from the first sentence of each description.** Many descriptions open with a requirement or a trigger list, such as "Requires Linear MCP.", so a derived summary would often say nothing useful.

The README shrank from about 134 KB to about 78 KB, and its paragraphs over 500 characters fell from 26 to none. Readers who need full behavior follow one more link than before. The docs guides now carry the detailed wording that tests pin, so they can grow the way the README did; their owners should keep them structured with headings, lists, and tables.
