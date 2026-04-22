---
name: kramme:code:source-driven
description: "(experimental) Ground framework and library decisions in official documentation with explicit citation. Use when touching any external framework, library, CLI tool, or cloud service — especially recent versions where training data may be stale. Fetches via Context7 MCP or direct URLs, implements against documented patterns, and cites deep links with quoted passages when decisions are non-obvious."
disable-model-invocation: false
user-invocable: true
---

# Source-Driven Development

Ground framework and library decisions in official documentation. Training data goes stale silently — a pattern that was idiomatic two versions ago is often deprecated, renamed, or actively harmful today. This skill turns "I think I remember how this works" into an explicit workflow: detect the stack, fetch the current docs, implement against them, and cite what you used so a reviewer can check your work.

## When to use

- Touching any external framework, library, CLI tool, or cloud service.
- Especially when the project uses a recent version (released in the last 12 months) where training data is likely stale.
- Version migrations — pair with `kramme:code:migrate`.
- API design decisions that depend on web standards (REST conventions, HTTP semantics, browser capabilities).
- Any time the right answer depends on what the docs say *today*, not what you remember.

Skip for: generic programming concepts, internal project code, and well-established language-level features that haven't changed in years.

## The DETECT / FETCH / IMPLEMENT / CITE workflow

### 1. DETECT — identify the stack and versions

Read whichever of these exist:

- `package.json` (Node/JS/TS)
- `composer.json` (PHP)
- `requirements.txt` / `pyproject.toml` / `Pipfile` (Python)
- `go.mod` (Go)
- `Cargo.toml` (Rust)
- `Gemfile` (Ruby)
- `pom.xml` / `build.gradle` (Java/Kotlin)

Extract the libraries in play and their pinned versions. Then emit:

```
STACK DETECTED: <framework> <version>, <library> <version>, ...
```

Version matters. "React" is not enough — React 18 and React 19 have materially different APIs.

### 2. FETCH — pull the current docs

Try Context7 MCP first (`mcp__context7__resolve-library-id` → `mcp__context7__query-docs`). It returns version-matched documentation directly.

If Context7 doesn't cover the library, fall back to direct URLs from the Source Hierarchy in `references/source-hierarchy.md`. Be precise — fetch the exact page you need, not the homepage.

If two authoritative sources disagree, emit:

```
CONFLICT DETECTED: <source A> says X; <source B> says Y
Resolution: <which you followed and why>
```

### 3. IMPLEMENT — build against documented patterns only

Use the patterns the docs describe. If you cannot find documentation for a claim you need to make, stop and emit:

```
UNVERIFIED: <the claim that has no source>
```

Do not proceed silently with unverified claims and do not paper over them with a disclaimer. Either find a source, or surface the gap and ask.

**Disclaimers don't help; flag or verify.** Saying "this might be outdated" does not make the code correct — it just shifts the bug forward. Flag it with `UNVERIFIED` so a reviewer can see it, or go find the source.

### 4. CITE — record what you used

For any non-obvious decision, include in the commit message, PR description, or inline comment:

- The full deep URL (not shortened, not the homepage).
- A short quoted passage when the decision turns on specific wording.
- Browser or runtime compatibility data when relevant (caniuse, node.green).

Citations let a reviewer re-derive your decision. If they can't, the citation isn't doing its job.

## Precision rule (BAD / GOOD)

Fetch the exact page, not the neighborhood.

- BAD: "Fetch React homepage"
- GOOD: "Fetch react.dev/reference/react/useActionState"
- BAD: "django authentication best practices"
- GOOD: "docs.djangoproject.com/en/6.0/topics/auth/"

Imprecise fetches return pages of navigation and marketing; precise fetches return the answer.

## Citation rules

1. Full URLs — not shortened, not relative.
2. Deep links with anchors where the doc supports them.
3. Quoted passages for non-obvious decisions. A link alone is weak evidence when the page is long.
4. Include browser/runtime support data when relevant (caniuse for web APIs, node.green for Node features).
5. When docs are unavailable, state it explicitly with `UNVERIFIED` — never paper over the gap with a hedge.

## Markers

- `STACK DETECTED` — emitted after the DETECT step; anchors every subsequent decision to a specific version.
- `CONFLICT DETECTED` — emitted when two authoritative sources disagree. Name both sources and the resolution.
- `UNVERIFIED` — emitted when a claim cannot be source-backed. Blocks silent passage of guesswork.

## Integration with other skills

- **Canonical docs-grounding entry point**: when another skill depends on current third-party framework/library behavior, it should point here rather than restating its own ad hoc doc-fetch rules. This skill owns the DETECT / FETCH / CITE discipline.
- **Upstream/paired**: `kramme:code:migrate` — version migrations are the highest-value use case for this skill. The migration target version is the stack you need current docs for.
- **Sibling authoring**: `kramme:code:frontend-authoring` — when UI work depends on framework-specific hooks, router behavior, server/client boundaries, or third-party component-library APIs, ground those decisions here and build the component there.
- **Pairs well with**: any implementation skill touching external libraries. This skill owns *how to cite*; implementation skills own *what to build*.

---

## Common Rationalizations

These are the lies you will tell yourself to skip the source step. Each one has a correct response:

- *"I've used this library a hundred times, I don't need to check."* → Your last ten times may have been on an older version. Emit `STACK DETECTED` and at minimum skim the changelog.
- *"The docs probably say the same thing my training data does."* → Often they don't. That's the bug you're about to ship.
- *"I'll mention it might be outdated."* → Disclaimers don't help; flag with `UNVERIFIED` or verify.
- *"Stack Overflow had a clear answer."* → Stack Overflow is not in the Source Hierarchy. Use it to find the official page, not as the citation.
- *"The homepage is good enough for the link."* → No. Deep link or don't cite.
- *"I'll add citations later."* → You won't. Cite in the commit that introduces the decision.
- *"Two docs disagree, I'll just pick one."* → Emit `CONFLICT DETECTED` and name your resolution. Silent picks are unreviewable.

## Red Flags

If you notice any of these, stop and re-ground:

- Writing framework code without having opened the framework's docs for the version in use.
- A decision you can't explain with a URL.
- Citing the homepage or a top-level landing page.
- "This used to work like X" without checking whether it still does.
- Relying on Stack Overflow, a third-party blog, or an AI-generated docs site for an authoritative claim.
- Multiple `UNVERIFIED` markers accumulating without being resolved before the PR opens.
- Silent resolution of conflicting docs with no `CONFLICT DETECTED` marker.

## Verification

Before declaring the work done, self-check:

- Does every non-obvious framework/library decision have a deep-link citation?
- Are all citations to Tier 1–4 sources in the Source Hierarchy (no Stack Overflow, no third-party blogs)?
- Does every `UNVERIFIED` marker have either a source now or an explicit unresolved note?
- Did every `CONFLICT DETECTED` record name its resolution?
- Would a reviewer who follows each citation arrive at the same code you wrote?

If any answer is no, fix the gap before declaring done.
