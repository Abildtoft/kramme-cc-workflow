# Source Hierarchy

The ranked list of sources to ground framework and library decisions in, highest authority first.

## The 4 tiers

| Tier | Source | Example |
|---|---|---|
| 1 | Official project docs | react.dev, docs.djangoproject.com, symfony.com/doc |
| 2 | Official blog / changelog | react.dev/blog, nextjs.org/blog |
| 3 | Web standards | MDN, web.dev, html.spec.whatwg.org |
| 4 | Browser / runtime compat | caniuse.com, node.green |

Prefer higher tiers. Drop to a lower tier only when the higher tier is silent on your question.

## Explicitly NOT authoritative

These may help you find the right page, but they are never the citation:

- Stack Overflow and similar Q&A sites.
- Third-party blog posts and tutorials.
- AI-generated documentation mirrors.
- Your training data or memory of past projects.

If Stack Overflow points you at an API, follow through to the official docs page for that API and cite *that*.

## Examples of good source selection

- **Question: "How do I use React 19's `useActionState`?"** → Tier 1: `react.dev/reference/react/useActionState`.
- **Question: "What changed between Django 5.2 and 6.0?"** → Tier 2: `docs.djangoproject.com/en/6.0/releases/6.0/` or the official release blog post.
- **Question: "Is `URLPattern` safe to use in the browser?"** → Tier 3: `developer.mozilla.org/en-US/docs/Web/API/URLPattern_API` for semantics, plus Tier 4: `caniuse.com/urlpattern` for support.
- **Question: "Which Node version supports top-level `await`?"** → Tier 4: `node.green` entry for top-level await.

## How to link

- Full URLs, never shortened.
- Deep links with anchors where the page supports them (e.g., `#section-slug`).
- Quote a passage when the decision turns on specific wording — a URL alone can point at a page that disagrees with your claim if the reviewer doesn't read closely.

## When docs are unavailable

If a library has no Tier 1 docs for the question you need to answer — or the docs are silent on the specific edge case — do not fall through to Stack Overflow as the citation. Emit `UNVERIFIED` in the SKILL.md workflow, surface the gap, and let the user decide whether to accept a lower-authority source, read the library source directly, or change approach.
