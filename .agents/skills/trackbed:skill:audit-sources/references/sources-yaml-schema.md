# `sources.yaml` Schema

Per-skill manifest of inspiration sources. Lives at `<skill>/references/sources.yaml`. Read by `trackbed:skill:audit-sources` to detect upstream changes without retaining source bodies: GitHub-hosted sources through their commit history, other sources by fetching transiently and comparing normalized hashes.

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
| `last_reviewed_at` | yes | ISO date (`YYYY-MM-DD`) when the baseline was last refreshed. Updated by Phase 5 of the audit skill. It is not a compared-on date: a GitHub change window derived from it may include upstream changes the skill already adopted. |
| `baseline_hash` | yes after first audit | `sha256:<hex>` of the transiently normalized source content. Empty string on a freshly bootstrapped entry; populated on the first successful fetch. The hash decides change only for web pages that are not GitHub-hosted. For a GitHub-hosted `url`, commit history decides, and an immutable post gets an availability check instead; the audit fills an empty hash for them once but never compares it. A vendored runtime library is never fetched, so its hash stays as recorded. |
| `baseline_commit` | no | For a GitHub-hosted `url`, the full 40-character SHA of the upstream commit through which the audit last checked the source. The change window starts here, and Phase 5 writes the checked upstream HEAD. On a `copied` entry with no other immutable revision field, it records the copy origin instead, and the audit never rewrites it. |
| `fetch_mode` | no | How the audit produced `baseline_hash`: `curl-markdown` or `curl-html` for a local `curl` fetch normalized as Markdown or HTML, `graphql-helper` for `graphql_definitions` extraction, or `docs-mcp` for docs MCP output. `availability` marks an immutable post that is never re-hashed. Absent means an older hash of unknown mode, which cannot prove a source unchanged. Phase 5 writes it on the line before `baseline_hash`; see `references/normalization-rules.md`. |
| `graphql_definitions` | no | Ordered list of named GraphQL type-system definitions to extract before normalization. Supported kinds are `enum`, `input`, `interface`, `scalar`, `type`, and `union`, including extensions of a requested name. Use only with an HTTPS `url` when a bounded part of a large schema informs the skill. The local helper fetches the URL without exposing the full schema to model context; missing or malformed definitions fail the source audit instead of falling back to the full schema. |

Exactly one of `url` and `context7_library` must be set.

## GitHub-hosted sources

The audit decides change for a GitHub-hosted `url` from upstream commit history, not from a hash. Supported forms:

- `https://raw.githubusercontent.com/<owner>/<repo>/<ref>/<path>`, where `<ref>` may also be `refs/heads/<branch>` or `refs/tags/<tag>`
- `https://github.com/<owner>/<repo>/tree/<ref>/<path>` and `https://github.com/<owner>/<repo>/blob/<ref>/<path>`
- `https://github.com/<owner>/<repo>`

A `<ref>` that is a full commit SHA or a version tag pins the URL. Keep the pin as frozen evidence of what the skill adopted: the audit still checks the default branch for later commits to the same path, because the pinned content never changes. Entries with `graphql_definitions` keep the hash route, because only their named definitions matter.

The change window starts at `baseline_commit` when it is set, otherwise at the pinned commit, otherwise at the last commit on the tracked branch at or before `last_reviewed_at`, which the report marks as derived. `scripts/github_changes.py` reads only GitHub metadata through `gh api` and never fetches file bodies. Phase 5 records the checked upstream HEAD in `baseline_commit`, so manifests gain the field as sources are audited rather than through a bulk backfill.

## Source kinds and fetch modes

The audit recognizes vendored runtime libraries and immutable posts first, even when their `url` is on GitHub, and treats every remaining entry that is not GitHub-hosted as a web page:

- **Vendored runtime libraries** — `usage: copied` entries with a `version` that pins a published package or distribution file — stay in the manifest for their license and notice. The audit does not fetch, hash, or compare them; review their versions and advisories as dependencies.
- **Immutable posts**, such as a social post or a dated article, do not change after publication. The audit checks that they are still available and never compares their hash. Social post URLs (`x.com/<user>/status/<id>`, `twitter.com/<user>/status/<id>`) and URLs with a dated `/<YYYY>/<MM>/` path are recognized automatically unless the entry records another `fetch_mode`; set `fetch_mode: availability` by hand for any other post.
- **Web pages** are fetched in the local process with `curl` and normalized before hashing, never through the runtime's web-fetch tool, whose output can be summarized or converted. `fetch_mode` records how the hash was produced, because a hash is comparable only with one produced the same way (see `references/normalization-rules.md`). Prefer a Markdown endpoint, such as a `code.claude.com/docs/...` page with a `.md` suffix or a docs repository's raw file, over rendered HTML. The audit suggests such a switch but never makes it; after you switch a `url`, the next audit reports the entry as changed and Phase 5 records the new mode.

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
    fetch_mode: curl-html
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

### GitHub-hosted source

```yaml
sources:
  - id: example-review-skill
    url: https://raw.githubusercontent.com/example/skills/main/skills/review/SKILL.md
    title: Example skills — review skill
    rationale: "Review checklist adapted in references/checklist.md"
    usage: inspiration
    last_reviewed_at: 2026-10-31
    baseline_commit: "0123456789abcdef0123456789abcdef01234567"
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

### Immutable post

```yaml
sources:
  - id: example-launch-post
    url: https://x.com/example/status/1234567890123456789
    title: Example — launch announcement
    rationale: "The release checklist idea in references/checklist.md comes from this post"
    usage: inspiration
    last_reviewed_at: 2026-10-31
    fetch_mode: availability
    baseline_hash: "sha256:..."
```

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
- **Code dependencies.** Use `trackbed:deps:audit` for npm/pip/cargo packages. A vendored runtime library whose code ships with a skill stays here as a `usage: copied` entry for its license and notice, and the source audit skips it.
- **Tools the skill calls but doesn't derive content from** (e.g. `gh`, `git`, `markitdown`).
- **Fetched source bodies.** Never create or commit a `references/sources-snapshot/` directory. Store only URLs, original notes, review dates, license metadata where applicable, and hashes.
