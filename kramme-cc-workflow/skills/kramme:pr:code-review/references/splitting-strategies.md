# Splitting strategies for oversized PRs

Use when a PR exceeds ~1,000 changed lines and the reviewer recommends splitting. Pair the recommendation with a named strategy so the author has a concrete next step instead of a vague "make it smaller."

| Strategy | When |
|---|---|
| Stack | Sequential, each builds on previous |
| By file group | Clean seams by directory / module |
| Horizontal | By layer (DB → API → UI) — but prefer vertical |
| Vertical | By feature slice — preferred |

**Prefer vertical.** A vertical slice (one user-visible capability, end to end) ships value independently and exercises every layer at once. Horizontal splits (DB PR, then API PR, then UI PR) often leave each layer un-exercised until the next PR lands, making regressions harder to catch and reviews shallower.

## How to word the recommendation

When surfacing the splitting recommendation in review output, name the strategy and explain the seam:

> **Critical:** PR is 1,400 lines. Split before merge.
> Recommended strategy: **Vertical** — split by the two features bundled here (user import + CSV export). Each becomes an independently mergeable PR with its own tests.

Avoid vague framings ("this is too big", "consider splitting") — the author already knows it's big. The value is naming the specific seam.
