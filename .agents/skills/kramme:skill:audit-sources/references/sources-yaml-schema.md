# `sources.yaml` Schema

Per-skill manifest of inspiration sources. Lives at `<skill>/references/sources.yaml`. Read by `kramme:skill:audit-sources` to fetch upstream content transiently and compare normalized hashes without retaining source bodies.

## Top-level shape

```yaml
sources:
  - <source entry>
  - <source entry>
```

A skill with no sources to audit may omit the file entirely. An empty file (`sources: []`) means "no audit needed" and is treated the same as missing for bootstrap purposes.

## Source entry fields

| Field | Required | Notes |
| --- | --- | --- |
| `id` | yes | Stable, kebab-case slug used in reports and hash-baseline updates. |
| `url` | one of | Fully qualified `https://` URL. Use this for arbitrary docs, blog posts, GitHub READMEs, papers. |
| `context7_library` | one of | Library identifier resolvable by a docs MCP (e.g. Context7's `resolve-library-id`), in `<owner>/<name>` form (`facebook/react`, `vercel/next.js`). The audit will use the MCP when present and fall back to fetching the library's canonical docs URL otherwise. |
| `title` | yes | Human-readable title. Shown in the audit report. |
| `rationale` | yes | One sentence: _what in this skill is derived from this source_. Forces curation discipline; if you can't write it, the source isn't an inspiration source. |
| `usage` | yes | `inspiration` when the local skill retains ideas, facts, methods, or rewritten workflow influence only; `copied` when source expression remains. |
| `license` | for `copied` | Verified upstream license that permits the retained copy. A public URL or repository is not a license. |
| `notice` | for `copied` | Skill-relative path to the complete required license/attribution notice. The file must ship with the skill. |
| `upstream_path` | for `copied` | Exact path, page title, or artifact name from which the retained expression came. |
| `upstream_commit`, `baseline_commit`, `upstream_revision`, `upstream_release`, or `version` | one for `copied` | Immutable upstream identifier for the retained expression. Moving branch names are insufficient. |
| `last_reviewed_at` | yes | ISO date (`YYYY-MM-DD`) when the baseline was last refreshed. Updated by Phase 5 of the audit skill. |
| `baseline_hash` | yes after first audit | `sha256:<hex>` of the transiently normalized source content. Empty string on a freshly bootstrapped entry; populated on the first successful fetch. |
| `graphql_definitions` | no | Ordered list of named GraphQL type-system definitions to extract before normalization. Supported kinds are `enum`, `input`, `interface`, `scalar`, `type`, and `union`, including extensions of a requested name. Use only with an HTTPS `url` when a bounded part of a large schema informs the skill. The local helper fetches the URL without exposing the full schema to model context; missing or malformed definitions fail the source audit instead of falling back to the full schema. |

Exactly one of `url` and `context7_library` must be set.

## Examples

### URL source

```yaml
sources:
  - id: owasp-top-10
    url: https://owasp.org/www-project-top-ten/
    title: OWASP Top 10 (2021)
    rationale: "Threat categories enumerated in references/owasp-top-10.md"
    usage: inspiration
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
    usage: inspiration
    last_reviewed_at: 2026-04-25
    baseline_hash: "sha256:a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3"
```

### Bounded GraphQL source

```yaml
sources:
  - id: linear-project-contract
    url: https://raw.githubusercontent.com/linear/linear/master/packages/sdk/src/schema.graphql
    graphql_definitions: [ProjectCreateInput, WorkflowState]
    title: Linear project creation and workflow state contract
    rationale: "Project creation fields and workflow state values used by the integration."
    usage: inspiration
    last_reviewed_at: 2026-07-29
    baseline_hash: "sha256:..."
```

### Mixed: skill with multiple sources

```yaml
sources:
  - id: addy-osmani-agent-skills
    url: https://github.com/addyosmani/agent-skills
    title: Addy Osmani — agent-skills
    rationale: "Output marker and epilogue conventions adopted from this repo"
    usage: inspiration
    last_reviewed_at: 2026-04-25
    baseline_hash: "sha256:..."
  - id: anthropic-skills-docs
    url: https://code.claude.com/docs/en/skills
    title: Anthropic — Agent Skills documentation
    rationale: "Frontmatter rules and progressive-disclosure guidance"
    usage: inspiration
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
    usage: inspiration
    last_reviewed_at: 2026-04-25
    baseline_hash: ""
```

`baseline_hash: ""` signals to the audit phase: fetch transiently, populate the hash, but skip model comparison on that first successful review.

### Copied source

```yaml
sources:
  - id: upstream-helper
    url: https://github.com/example/project/blob/main/scripts/helper.sh
    title: Example project helper
    rationale: "scripts/helper.sh is adapted from the upstream helper."
    usage: copied
    license: MIT
    notice: references/UPSTREAM-LICENSE
    upstream_path: scripts/helper.sh
    upstream_commit: 0123456789abcdef0123456789abcdef01234567
    last_reviewed_at: 2026-07-29
    baseline_hash: "sha256:..."
```

The copied local file must also identify the exact upstream path and immutable commit, revision, release, or version. If the license is absent, unclear, incompatible, or forbids this form of redistribution, change the use to conceptual inspiration and rewrite the local material.

## What does NOT belong in `sources.yaml`

- **Illustrative URLs.** A link to "an example PR" or "a related blog post" mentioned in passing is not an inspiration source.
- **Internal cross-references.** Links to other skills in this plugin (`kramme:code:source-driven` etc.) are not external sources.
- **Code dependencies.** Use `kramme:deps:audit` for npm/pip/cargo packages.
- **Tools the skill calls but doesn't derive content from** (e.g. `gh`, `git`, `markitdown`).
- **Fetched source bodies.** Never create or commit a `references/sources-snapshot/` directory. Store only URLs, original notes, review dates, license metadata where applicable, and hashes.
