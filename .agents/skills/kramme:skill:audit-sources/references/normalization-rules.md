# Normalization Rules

Defines what `scripts/normalize.py` strips and keeps when turning a fetched source into a stable snapshot. Stability matters: a source that hasn't meaningfully changed must produce the same hash on re-fetch, otherwise every audit will trigger expensive LLM comparisons.

## Goals

1. **Stable hash for unchanged content.** Cosmetic noise (timestamps, build IDs, ad slots) must not flip the hash.
2. **Preserve substance.** Headings, body prose, code blocks, lists, and tables must survive intact so the LLM comparison is meaningful.
3. **Plain text output.** Snapshots are committed as readable markdown, not raw HTML.

## What to strip

### Always

- `<script>`, `<style>`, `<noscript>`, `<iframe>`, `<svg>` blocks (entire element including content).
- HTML comments (`<!-- ... -->`).
- Navigation: `<nav>`, `<header>`, `<footer>`, `<aside>`, and elements with class/id matching `nav|navigation|sidebar|topbar|header|footer|cookie|banner|breadcrumb|menu|toc-fixed`.
- Forms and inputs: `<form>`, `<input>`, `<button>`, `<select>`.
- Image binaries (keep `alt` text inline as `[image: <alt>]`).
- Inline event handlers and `data-*` attributes.

### Volatile noise (regex pass after HTML strip)

- Build/version stamps in footers: `Build [a-f0-9]{6,}`, `Generated on YYYY-MM-DD( HH:MM)?`, `v\d+\.\d+\.\d+(-\w+)?` *only when on a line with no other meaningful content*.
- Copyright years: collapse `Copyright YYYY` to `Copyright YEAR`.
- View counters, "last updated" timestamps that appear on every page render.
- Tracking query strings on links: strip `?utm_*`, `?ref=`, `?fbclid=`.

## What to keep

- All headings (`<h1>`–`<h6>`) → markdown `#`–`######`.
- Paragraphs and lists.
- Code blocks (`<pre><code>` and triple-backtick fences from markdown sources). Keep language hints when present.
- Tables → markdown tables.
- Inline links (text + URL). The URL is part of the substance — link target changes are real changes.
- Blockquotes.

## Markdown sources

If the input is already markdown (e.g. a GitHub raw README), skip HTML parsing and apply only the volatile-noise regex pass and normalization below.

## Final normalization (applied to both HTML and markdown inputs)

After strip, before hashing:

1. Collapse runs of 3+ blank lines to 2.
2. Trim trailing whitespace on every line.
3. Normalize Windows line endings to `\n`.
4. Strip a leading or trailing blank line from the whole document.
5. Lowercase the URL hosts in inline links (paths stay case-sensitive). E.g. `HTTPS://Example.com/Path` → `https://example.com/Path`.

## Hash input

The sha256 hash is computed over the **final normalized markdown** as UTF-8 bytes. The same string that gets written to `references/sources-snapshot/<id>.md` is the string that gets hashed. No hidden delta.

## Stability test

Re-running `normalize.py` on the same input must produce a byte-identical output. If the script ever produces non-deterministic output (e.g. ordering depends on a `dict`'s iteration order), that's a bug — fix it rather than accepting hash flap.
