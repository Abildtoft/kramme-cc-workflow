# PR Review Summary

## Relevance Filter
- 12 findings validated as PR-caused
- 0 findings filtered (pre-existing or out-of-scope)
- 0 findings filtered (previously addressed in REVIEW_OVERVIEW.md)

## Critical Issues (0 found)

## Important Issues (4 found)
- code-reviewer + comment-analyzer: Disambiguation predicate "matches a top-level project directory name" is evaluated by Step 1 before Step 2 examines the project structure or Step 6's Full branch enumerates source dirs — and "matches" is itself ambiguous (substring vs exact). The skill's argument router cannot run as written until the project layout has been read [kramme-cc-workflow/skills/kramme:code:refactor-opportunities/SKILL.md:22, :41]
- comment-analyzer: Three statements describe the same edge case (bare path-shaped argument that does not resolve) in three different framings — line 20 says "resolves to … routes to path", line 22 says "does not resolve triggers a clarification ask", line 57 says "If a value does not match, ask for clarification instead of treating it as a feature." An LLM following the skill may infer feature-fallback even though line 22 forbids it. Collapse to one rule [kramme-cc-workflow/skills/kramme:code:refactor-opportunities/SKILL.md:20, :22, :57]
- comment-analyzer: The "more than one scope selector → pause and ask" rule has no corresponding branch in Step 6, which assumes a single resolved `SCOPE_MODE`. A user passing `--scope pr` plus a bare path (both reserved selectors) falls through to whichever the parser sees first [kramme-cc-workflow/skills/kramme:code:refactor-opportunities/SKILL.md:23]
- code-reviewer: `SCOPE_VALUE` is declared in Step 1 and described as resolved-later for `pr`/`feature`, but Step 6 only builds `SCOPE_DESCRIPTION` and nothing downstream references `SCOPE_VALUE`. Either drop it from Step 1 or have Step 6 assign to it so the variable contract holds [kramme-cc-workflow/skills/kramme:code:refactor-opportunities/SKILL.md:41]

## Suggestions (7 found)
- **Consider:** code-reviewer: A real feature literally named `pr`, `diff`, `changes`, `all`, `everything`, `full`, or `repo` is unreachable through the bare-argument path — the keyword bullets at lines 18-19 swallow it. One sentence pointing users to the explicit `feature <name>` escape hatch closes this gap [kramme-cc-workflow/skills/kramme:code:refactor-opportunities/SKILL.md:18-22]
- **Nit:** code-reviewer: `gh pr view --json baseRefName,baseRefOid` requests `baseRefOid` but only `baseRefName` is consumed downstream. Drop the unused field [kramme-cc-workflow/skills/kramme:code:refactor-opportunities/SKILL.md:52]
- **Nit:** deslop-reviewer: The trailing parenthetical "`SCOPE_VALUE` is the repo root for `full`, the matched path set for `path`, and resolved in *Resolve the effective scan scope* below for `pr` and `feature`." restates Step 6 inline three lines before Step 6 itself. Cut and let Step 6 own the resolution [kramme-cc-workflow/skills/kramme:code:refactor-opportunities/SKILL.md:41]
- **Nit:** comment-analyzer: Step 7 example `Feature "billing exports" (22 files across API, UI, and tests)` omits `docs`, even though Step 6 promises to "include … docs that directly define the feature." Add docs to the example breakdown [kramme-cc-workflow/skills/kramme:code:refactor-opportunities/SKILL.md:58, :59]
- **Nit:** comment-analyzer: PR-mode aliases `diff` and `changes` are common English words that may show up in user phrasing meant for path mode (e.g., "scan the changes in src/api"). Worth at least noting in the Inputs bullet [kramme-cc-workflow/skills/kramme:code:refactor-opportunities/SKILL.md:19]
- **Consider:** comment-analyzer: The default-branch fallback chain `origin/main`, `origin/master`, `main`, `master` will not match repos using `trunk` or `develop`. The `--base` ask-on-miss already covers this, but a one-liner acknowledging non-standard defaults could pre-empt the ask [kramme-cc-workflow/skills/kramme:code:refactor-opportunities/SKILL.md:54]
- **Nit:** deslop-reviewer: The second sentence "Do not silently broaden the scan." reads as defensive reassurance, and the "broaden" framing doesn't match the rule (multiple selectors might narrow, not broaden) [kramme-cc-workflow/skills/kramme:code:refactor-opportunities/SKILL.md:23]

## Slop Warnings (4 found)
- comment-analyzer: Step 7 feature example omits `docs` — fix branch [kramme-cc-workflow/skills/kramme:code:refactor-opportunities/SKILL.md:59]
  Warning: The "note that categories are illustrative" alternative would add a defensive hedge with no behavior change. Prefer the "add docs to the example" branch.
- comment-analyzer: PR-mode aliases `diff`/`changes` are loose — fix [kramme-cc-workflow/skills/kramme:code:refactor-opportunities/SKILL.md:19]
  Warning: Adding a "bare token, not embedded in a phrase" caveat is parser-pedantry slop the LLM doesn't need; trust the model's intent matching or drop the aliases entirely.
- comment-analyzer: Default-branch fallback may rot — fix [kramme-cc-workflow/skills/kramme:code:refactor-opportunities/SKILL.md:54]
  Warning: A "non-standard branches exist" one-liner is verbose-alternative slop given the chain already lists `main`/`master` and the explicit `--base` escape covers the gap. Prefer no change.
- deslop-reviewer: Drop the second sentence "Do not silently broaden the scan." — fix [kramme-cc-workflow/skills/kramme:code:refactor-opportunities/SKILL.md:23]
  Warning: The slop meta-review disagrees with this suggestion — that sentence names the failure mode the rule prevents, and removing it weakens model adherence. The "broaden" framing is the only weak part; consider rewording instead of deleting.

## Filtered (Pre-existing/Out-of-scope)
<collapsed>
(0 found)
</collapsed>

## Filtered (Previously Addressed)
<collapsed>
(0 found)
</collapsed>

## Strengths
- **FYI** Step 6 PR base-resolution order is well-sequenced — explicit `--base` first, then `gh pr view`, then a guarded upstream check, then a default-branch fallback — and explicitly handles the fork-PR edge case rather than guessing [kramme-cc-workflow/skills/kramme:code:refactor-opportunities/SKILL.md:50-55]
- **FYI** The "If no base can be resolved, report the attempted refs and ask for `--base <ref>` — do not fall back to `full`" guardrail is the kind of explicit anti-pattern note that ages well [kramme-cc-workflow/skills/kramme:code:refactor-opportunities/SKILL.md:55]
- **FYI** The four `SCOPE_DESCRIPTION` examples in Step 7 each demonstrate a distinct shape (directory count, resolved base ref, literal path, quoted multi-word feature with cross-area split) — none is a copy of another's structure [kramme-cc-workflow/skills/kramme:code:refactor-opportunities/SKILL.md:59]
- **FYI** README description condenses the multi-step base-resolution chain into a one-line summary without losing the operative escape hatch (`--base <ref>`) [kramme-cc-workflow/README.md:267]

## Approval Standard

Approve if the change definitely improves overall code health.

## Recommended Action
1. Fix critical issues first
2. Address important issues
3. Consider suggestions
4. Re-run review after fixes

**To automatically resolve code-backed findings, run:** `/kramme:pr:resolve-review`
