# Bootstrap Prompt

Use this prompt to propose a `sources.yaml` for a skill that has none yet. Phase 3 of `kramme:skill:audit-sources` invokes it.

## Inputs to gather before prompting

- The full text of the target skill's `SKILL.md`.
- The full text of every file under the target skill's `references/` directory.
- The skill's name (e.g. `kramme:code:harden-security`).

## Prompt

> You are proposing a `sources.yaml` manifest of inspiration sources for the plugin skill `<SKILL_NAME>`.
>
> **Inspiration sources** are external resources whose content the skill is *derived from* — official docs, library READMEs, blog posts, papers, standards, GitHub repos, conference talks. The skill encodes ideas, terminology, examples, or procedures from these sources.
>
> **Not inspiration sources** (do not include):
> - Illustrative links mentioned in passing ("see this example PR")
> - Links to other skills in this plugin
> - Tool documentation for tools the skill *calls* but doesn't derive content from (e.g. `gh`, `git`, `npm`)
> - Internal cross-references
> - Code package registries
>
> Read the SKILL.md and reference files below. For each candidate inspiration source you find, output a YAML entry with:
>
> - `id`: stable kebab-case slug
> - `url` *or* `context7_library` (exactly one)
> - `title`: human-readable
> - `rationale`: one sentence saying *what in this skill is derived from this source*. If you cannot write this confidently, drop the candidate — it is probably illustrative, not inspirational.
> - `last_reviewed_at: <today>`
> - `baseline_hash: ""` (empty — will be populated on first fetch)
>
> Prefer `context7_library` when the source is a well-known library that a docs MCP (e.g. Context7) can resolve directly (React, Next.js, Django, Tailwind, etc.) — the audit will use the MCP if available and fall back to a web fetch otherwise. Use `url` for everything else, including blog posts, GitHub repos, and standards bodies.
>
> Look for sources in these places, in order:
> 1. Inline links in `SKILL.md` (`[text](url)`)
> 2. Inline links in `references/*.md`
> 3. Named-but-unlinked references ("OWASP Top 10", "Hyrum's Law", "Nielsen heuristics", "Addy Osmani") — propose a URL if obvious, else flag for the user
> 4. Mentions of named libraries or frameworks where the skill encodes specific behaviors of that library
>
> Output only the YAML, fenced as ` ```yaml ... ``` `. Then below the fence, list any **flagged candidates** that need a human URL decision, with one line each: `- <name>: <reason>`.
>
> If no inspiration sources are found, output `sources: []` and a one-paragraph explanation. The user will decide whether to skip this skill or accept the empty manifest.

## After the model responds

1. Parse the YAML.
2. Show it to the user with the flagged candidates.
3. Ask the user to confirm: accept as-is, edit, or skip.
4. If accepted, write the file. If edited, apply edits then write. If skipped, do not write — record "skipped" in the audit report.
