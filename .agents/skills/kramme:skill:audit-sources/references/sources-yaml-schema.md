# `sources.yaml` Schema

Per-skill manifest of inspiration sources. Lives at `<skill>/references/sources.yaml`. Read by `kramme:skill:audit-sources` to fetch, snapshot, and compare upstream content.

## Top-level shape

```yaml
sources:
  - <source entry>
  - <source entry>
```

A skill with no sources to audit may omit the file entirely. An empty file (`sources: []`) means "no audit needed" and is treated the same as missing for bootstrap purposes.

## Source entry fields

| Field | Required | Notes |
|---|---|---|
| `id` | yes | Stable, kebab-case slug. Used as the snapshot filename: `references/sources-snapshot/<id>.md`. Do not rename after first snapshot — rename means orphaned baseline. |
| `url` | one of | Fully qualified `https://` URL. Use this for arbitrary docs, blog posts, GitHub READMEs, papers. |
| `context7_library` | one of | Library identifier resolvable by a docs MCP (e.g. Context7's `resolve-library-id`), in `<owner>/<name>` form (`facebook/react`, `vercel/next.js`). The audit will use the MCP when present and fall back to fetching the library's canonical docs URL otherwise. |
| `title` | yes | Human-readable title. Shown in the audit report. |
| `rationale` | yes | One sentence: *what in this skill is derived from this source*. Forces curation discipline; if you can't write it, the source isn't an inspiration source. |
| `last_reviewed_at` | yes | ISO date (`YYYY-MM-DD`) when the baseline was last refreshed. Updated by Phase 5 of the audit skill. |
| `baseline_hash` | yes after first audit | `sha256:<hex>` of the normalized snapshot content. Empty string on a freshly bootstrapped entry; populated on the first successful fetch. |

Exactly one of `url` and `context7_library` must be set.

## Examples

### URL source

```yaml
sources:
  - id: owasp-top-10
    url: https://owasp.org/www-project-top-ten/
    title: OWASP Top 10 (2021)
    rationale: "Threat categories enumerated in references/owasp-top-10.md"
    last_reviewed_at: 2026-04-25
    baseline_hash: "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
```

### Context7 library source

```yaml
sources:
  - id: react-hooks-rules
    context7_library: facebook/react
    title: React — Rules of Hooks
    rationale: "Hook ordering and call-site rules captured in references/hook-rules.md"
    last_reviewed_at: 2026-04-25
    baseline_hash: "sha256:a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3"
```

### Mixed: skill with multiple sources

```yaml
sources:
  - id: addy-osmani-agent-skills
    url: https://github.com/addyosmani/agent-skills
    title: Addy Osmani — agent-skills
    rationale: "Output marker and epilogue conventions adopted from this repo"
    last_reviewed_at: 2026-04-25
    baseline_hash: "sha256:..."
  - id: anthropic-skills-docs
    url: https://code.claude.com/docs/en/skills
    title: Anthropic — Agent Skills documentation
    rationale: "Frontmatter rules and progressive-disclosure guidance"
    last_reviewed_at: 2026-04-25
    baseline_hash: "sha256:..."
```

### Freshly bootstrapped (before first fetch)

```yaml
sources:
  - id: nielsen-heuristics
    url: https://www.nngroup.com/articles/ten-usability-heuristics/
    title: Nielsen Norman — 10 Usability Heuristics
    rationale: "Heuristic list used in the UX review prompt"
    last_reviewed_at: 2026-04-25
    baseline_hash: ""
```

`baseline_hash: ""` signals to the audit phase: fetch, snapshot, populate hash, but skip LLM compare (there is nothing to compare against yet).

## What does NOT belong in `sources.yaml`

- **Illustrative URLs.** A link to "an example PR" or "a related blog post" mentioned in passing is not an inspiration source.
- **Internal cross-references.** Links to other skills in this plugin (`kramme:code:source-driven` etc.) are not external sources.
- **Code dependencies.** Use `kramme:deps:audit` for npm/pip/cargo packages.
- **Tools the skill calls but doesn't derive content from** (e.g. `gh`, `git`, `markitdown`).
