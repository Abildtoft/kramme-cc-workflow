# Output template

Reply inline using this structure verbatim. Include every section even when empty (note `(none)` rather than omitting).

```markdown
# PR Split Plan

## Branch
- Base: <base-branch>
- Files changed: X (source: A, tests: B, config: C, generated/locks: D)
- Lines changed: X insertions / Y deletions (Z total)

## Recommendation: SPLIT into N PRs / KEEP AS ONE

<one-sentence rationale>

## Suggested Slices

### Slice 1: <short name describing user-visible capability or boundary>
- **Strategy:** Vertical / Stack / By file group / Horizontal
- **Files (X lines):**
  - `path/to/file.ts` (+12 / -3)
  - `path/to/other.ts` (+45 / -0)
- **Est. review time:** ~10 min (target: 10–15 min; sub-split if >20 min)
- **Depends on:** none / Slice N (must merge first)
- **Tests:** <one line on what verifies this slice in isolation>
- **Why this seam:** <one sentence — the specific reason this cut works>

### Slice 2: <name>
...

## Carried With Slices
<files that travel with their owner — lock files, snapshots, generated code, shared utilities — and which slice carries each>

- `pnpm-lock.yaml` → Slice 1 (only changes are deps for the import feature)
- `src/lib/parseCsv.ts` → Slice 1 (used by the import feature; export feature reuses unchanged)

## Coupling Notes
<cross-slice dependencies, shared types, schema ordering constraints, or anything that would surprise a reviewer>

- Slice 2 imports `UserSession` from Slice 1's new module. Slice 1 must merge first.
- No schema changes; no migration ordering required.

## Next Steps
1. Note your current branch state (`git status`, current commits) so you can return here if needed.
2. For each slice, create a new branch off `<base>` and bring in only that slice's files (cherry-pick, partial checkout, or re-author). See the recipes in `strategies.md`.
3. In each PR's body, document its position in the plan: `"depends on #N"` for stacked slices, or `"part 1 of 3, parallel with #M"` for parallel splits. Reviewers shouldn't have to reverse-engineer the structure.
4. Open one PR per slice in dependency order. Run `kramme:pr:code-review` on each before publishing.
```

## Section notes

- **Recommendation** — the load-bearing line. Either `SPLIT into N PRs` with N ≥ 2, or `KEEP AS ONE` with an explicit reason. Never hedge ("maybe split if you feel like it").
- **Est. review time** — the practical sizing test, not raw line count. Target 10–15 minutes per slice; sub-split anything over ~20 minutes. 400 mechanical-rename lines may read in 5 minutes; 80 lines of intricate logic may read in 25.
- **Why this seam** — one sentence per slice. *"Smaller"* is not a reason. The reason is what makes the slice independently meaningful: a feature boundary, a module seam, a deploy-ordering constraint.
- **Carried With Slices** — distinguish files that *define* a slice from files that *follow* a slice (lock updates, generated code, snapshots). Reviewers waste time when this isn't called out.
- **Coupling Notes** — name every cross-slice dependency. If there are none, say so.
- **Next Steps** — concrete user actions. The skill never executes these; the user does.
