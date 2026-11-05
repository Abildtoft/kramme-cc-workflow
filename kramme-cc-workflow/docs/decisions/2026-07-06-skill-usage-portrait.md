# Skill Usage Portrait - 2026-07-06

## Source

Commands run from the repository root:

```bash
node kramme-cc-workflow/scripts/skill-usage.js report --since 90d --json
node kramme-cc-workflow/scripts/skill-usage.js report --since 30d --json
git log --name-only
```

The local hook data source was `/Users/kramme/.local/state/kramme-cc-workflow/skill-usage.jsonl`. I found one local JSONL file, so there was no local multi-machine merge step to perform. The file contained 684 records from 2026-05-28T12:46:33.887Z through 2026-07-06T19:31:56.999Z. The report included two invocations of `trackbed:pr`, which is not one of the 108 skill directories, so the 108-skill library table below excludes it.

## Summary

The current usage pattern is concentrated in a small core, not broad across the library. Of 108 shipped skills, 31 had any 90-day usage and 30 had any 30-day usage. The 108-skill table accounts for 682 invocations in 90 days and 225 in 30 days. The top 15 skills account for 641 of 682 90-day invocations (94%) and 194 of 225 30-day invocations (86.2%).

## Full Usage Table

| Skill name | Invocations 90d | Invocations 30d | Last used |
| --- | --- | --- | --- |
| trackbed:pr:resolve-review | 204 | 35 | 2026-07-02T12:56:42.909Z |
| trackbed:skill:review | 195 | 3 | 2026-07-02T08:56:33.312Z |
| trackbed:pr:code-review | 44 | 26 | 2026-07-03T19:45:58.929Z |
| trackbed:pr:rebase | 34 | 6 | 2026-06-22T14:22:11.261Z |
| trackbed:code:agent-readiness | 31 | 18 | 2026-07-05T16:13:14.045Z |
| trackbed:linear:issue-implement | 26 | 26 | 2026-06-25T08:22:26.273Z |
| trackbed:code:refactor-opportunities | 25 | 14 | 2026-07-06T07:25:53.916Z |
| trackbed:code:breakdown-findings | 18 | 13 | 2026-07-06T08:04:24.042Z |
| kramme:siw:discovery | 17 | 10 | 2026-06-22T08:12:30.896Z |
| trackbed:pr:generate-description | 12 | 8 | 2026-07-01T09:48:47.901Z |
| kramme:code:weakness-audit | 9 | 9 | 2026-07-05T16:12:04.161Z |
| trackbed:discovery:strategic-inquiry | 9 | 9 | 2026-07-06T19:31:56.999Z |
| trackbed:pr:github-review | 6 | 6 | 2026-06-26T10:12:36.649Z |
| kramme:siw:issue-implement | 6 | 6 | 2026-06-22T09:51:37.374Z |
| trackbed:linear:issue-define | 5 | 5 | 2026-06-22T11:32:03.730Z |
| trackbed:pr:create | 5 | 3 | 2026-06-29T11:40:24.022Z |
| trackbed:git:recreate-commits | 5 | 2 | 2026-06-08T14:39:33.207Z |
| trackbed:pr:github-review-reply | 4 | 4 | 2026-06-20T11:13:30.488Z |
| kramme:siw:issue-reindex | 4 | 4 | 2026-06-22T11:12:17.656Z |
| trackbed:siw:resolve-audit | 3 | 3 | 2026-06-22T09:01:45.182Z |
| trackbed:siw:init | 3 | 2 | 2026-06-07T13:29:11.479Z |
| trackbed:discovery:interview | 3 | 0 | 2026-06-05T11:41:40.309Z |
| trackbed:learn:verify-understanding | 2 | 2 | 2026-06-18T12:48:51.439Z |
| kramme:pr:copy-review | 2 | 2 | 2026-06-19T09:44:56.570Z |
| trackbed:siw:transfer-to-linear | 2 | 2 | 2026-06-24T12:23:15.311Z |
| kramme:workflow-artifacts:cleanup | 2 | 2 | 2026-07-02T12:57:02.832Z |
| trackbed:pr:fix-ci | 2 | 1 | 2026-06-29T10:09:57.809Z |
| trackbed:code:copy-review | 1 | 1 | 2026-06-19T10:08:33.914Z |
| trackbed:docs:adr | 1 | 1 | 2026-06-08T05:55:24.740Z |
| kramme:pr:ux-review | 1 | 1 | 2026-07-02T12:56:42.909Z |
| trackbed:siw:generate-phases | 1 | 1 | 2026-06-11T14:35:47.863Z |
| trackbed:browse | 0 | 0 | not recorded |
| kramme:changelog:generate | 0 | 0 | not recorded |
| kramme:ci:design-pipeline | 0 | 0 | not recorded |
| trackbed:code:api-design | 0 | 0 | not recorded |
| kramme:code:cleanup-ai | 0 | 0 | not recorded |
| trackbed:code:deprecate | 0 | 0 | not recorded |
| trackbed:code:harden-security | 0 | 0 | not recorded |
| kramme:code:incremental | 0 | 0 | not recorded |
| trackbed:code:migrate | 0 | 0 | not recorded |
| trackbed:code:optimize | 0 | 0 | not recorded |
| kramme:code:performance | 0 | 0 | not recorded |
| trackbed:code:refactor-pass | 0 | 0 | not recorded |
| kramme:code:rewrite-clean | 0 | 0 | not recorded |
| kramme:code:source-driven | 0 | 0 | not recorded |
| trackbed:code:work-from-plan | 0 | 0 | not recorded |
| trackbed:debug:investigate | 0 | 0 | not recorded |
| trackbed:debug:triage-to-issue | 0 | 0 | not recorded |
| trackbed:deps:audit | 0 | 0 | not recorded |
| kramme:docs:add-greenfield-policy | 0 | 0 | not recorded |
| trackbed:docs:feature-spec | 0 | 0 | not recorded |
| kramme:docs:out-of-scope | 0 | 0 | not recorded |
| trackbed:docs:review | 0 | 0 | not recorded |
| trackbed:docs:solution-note | 0 | 0 | not recorded |
| kramme:docs:solution-refresh | 0 | 0 | not recorded |
| trackbed:docs:to-markdown | 0 | 0 | not recorded |
| trackbed:docs:ubiquitous-language | 0 | 0 | not recorded |
| trackbed:docs:update-agents-md | 0 | 0 | not recorded |
| kramme:git:clean-gone-branches | 0 | 0 | not recorded |
| trackbed:git:commit-message | 0 | 0 | not recorded |
| trackbed:git:fixup | 0 | 0 | not recorded |
| kramme:git:worktree | 0 | 0 | not recorded |
| kramme:hooks:configure-links | 0 | 0 | not recorded |
| trackbed:hooks:toggle | 0 | 0 | not recorded |
| kramme:launch:announce | 0 | 0 | not recorded |
| kramme:launch:rollout | 0 | 0 | not recorded |
| kramme:linear:select-next | 0 | 0 | not recorded |
| kramme:nx:setup-portless | 0 | 0 | not recorded |
| kramme:pr:autoreview | 0 | 0 | not recorded |
| kramme:pr:finalize | 0 | 0 | not recorded |
| kramme:pr:plan-split | 0 | 0 | not recorded |
| trackbed:pr:product-review | 0 | 0 | not recorded |
| kramme:pr:update-split-plans | 0 | 0 | not recorded |
| kramme:pr:verify-description | 0 | 0 | not recorded |
| trackbed:pr:walkthrough | 0 | 0 | not recorded |
| trackbed:product:design-critic | 0 | 0 | not recorded |
| kramme:product:pulse | 0 | 0 | not recorded |
| trackbed:product:review | 0 | 0 | not recorded |
| trackbed:product:strategy | 0 | 0 | not recorded |
| trackbed:qa | 0 | 0 | not recorded |
| trackbed:qa:intake | 0 | 0 | not recorded |
| trackbed:session:automate-repeats | 0 | 0 | not recorded |
| kramme:session:context-setup | 0 | 0 | not recorded |
| kramme:session:search | 0 | 0 | not recorded |
| trackbed:setup | 0 | 0 | not recorded |
| kramme:siw:breakdown-findings | 0 | 0 | not recorded |
| kramme:siw:close | 0 | 0 | not recorded |
| kramme:siw:continue | 0 | 0 | not recorded |
| kramme:siw:implementation-audit | 0 | 0 | not recorded |
| kramme:siw:issue-define | 0 | 0 | not recorded |
| kramme:siw:product-audit | 0 | 0 | not recorded |
| kramme:siw:remove | 0 | 0 | not recorded |
| kramme:siw:reset | 0 | 0 | not recorded |
| trackbed:siw:spec-audit | 0 | 0 | not recorded |
| kramme:siw:spec-audit:auto-fix | 0 | 0 | not recorded |
| trackbed:skill:create | 0 | 0 | not recorded |
| kramme:test:generate | 0 | 0 | not recorded |
| kramme:test:tdd | 0 | 0 | not recorded |
| kramme:text:humanize | 0 | 0 | not recorded |
| kramme:verify:before-completion | 0 | 0 | not recorded |
| trackbed:verify:run | 0 | 0 | not recorded |
| kramme:visual:demo-reel | 0 | 0 | not recorded |
| kramme:visual:diagram | 0 | 0 | not recorded |
| kramme:visual:diff-review | 0 | 0 | not recorded |
| kramme:visual:generate-image | 0 | 0 | not recorded |
| kramme:visual:onboarding | 0 | 0 | not recorded |
| kramme:visual:plan-review | 0 | 0 | not recorded |
| kramme:visual:project-recap | 0 | 0 | not recorded |

## Zero-Usage Skills

These 77 skills had zero recorded 90-day usage:

- `trackbed:browse`
- `kramme:changelog:generate`
- `kramme:ci:design-pipeline`
- `trackbed:code:api-design`
- `kramme:code:cleanup-ai`
- `trackbed:code:deprecate`
- `trackbed:code:harden-security`
- `kramme:code:incremental`
- `trackbed:code:migrate`
- `trackbed:code:optimize`
- `kramme:code:performance`
- `trackbed:code:refactor-pass`
- `kramme:code:rewrite-clean`
- `kramme:code:source-driven`
- `trackbed:code:work-from-plan`
- `trackbed:debug:investigate`
- `trackbed:debug:triage-to-issue`
- `trackbed:deps:audit`
- `kramme:docs:add-greenfield-policy`
- `trackbed:docs:feature-spec`
- `kramme:docs:out-of-scope`
- `trackbed:docs:review`
- `trackbed:docs:solution-note`
- `kramme:docs:solution-refresh`
- `trackbed:docs:to-markdown`
- `trackbed:docs:ubiquitous-language`
- `trackbed:docs:update-agents-md`
- `kramme:git:clean-gone-branches`
- `trackbed:git:commit-message`
- `trackbed:git:fixup`
- `kramme:git:worktree`
- `kramme:hooks:configure-links`
- `trackbed:hooks:toggle`
- `kramme:launch:announce`
- `kramme:launch:rollout`
- `kramme:linear:select-next`
- `kramme:nx:setup-portless`
- `kramme:pr:autoreview`
- `kramme:pr:finalize`
- `kramme:pr:plan-split`
- `trackbed:pr:product-review`
- `kramme:pr:update-split-plans`
- `kramme:pr:verify-description`
- `trackbed:pr:walkthrough`
- `trackbed:product:design-critic`
- `kramme:product:pulse`
- `trackbed:product:review`
- `trackbed:product:strategy`
- `trackbed:qa`
- `trackbed:qa:intake`
- `trackbed:session:automate-repeats`
- `kramme:session:context-setup`
- `kramme:session:search`
- `trackbed:setup`
- `kramme:siw:breakdown-findings`
- `kramme:siw:close`
- `kramme:siw:continue`
- `kramme:siw:implementation-audit`
- `kramme:siw:issue-define`
- `kramme:siw:product-audit`
- `kramme:siw:remove`
- `kramme:siw:reset`
- `trackbed:siw:spec-audit`
- `kramme:siw:spec-audit:auto-fix`
- `trackbed:skill:create`
- `kramme:test:generate`
- `kramme:test:tdd`
- `kramme:text:humanize`
- `kramme:verify:before-completion`
- `trackbed:verify:run`
- `kramme:visual:demo-reel`
- `kramme:visual:diagram`
- `kramme:visual:diff-review`
- `kramme:visual:generate-image`
- `kramme:visual:onboarding`
- `kramme:visual:plan-review`
- `kramme:visual:project-recap`

## Top 15 By Usage

| Rank | Skill name | Invocations 90d | Invocations 30d | Last used |
| --- | --- | --- | --- | --- |
| 1 | trackbed:pr:resolve-review | 204 | 35 | 2026-07-02T12:56:42.909Z |
| 2 | trackbed:skill:review | 195 | 3 | 2026-07-02T08:56:33.312Z |
| 3 | trackbed:pr:code-review | 44 | 26 | 2026-07-03T19:45:58.929Z |
| 4 | trackbed:pr:rebase | 34 | 6 | 2026-06-22T14:22:11.261Z |
| 5 | trackbed:code:agent-readiness | 31 | 18 | 2026-07-05T16:13:14.045Z |
| 6 | trackbed:linear:issue-implement | 26 | 26 | 2026-06-25T08:22:26.273Z |
| 7 | trackbed:code:refactor-opportunities | 25 | 14 | 2026-07-06T07:25:53.916Z |
| 8 | trackbed:code:breakdown-findings | 18 | 13 | 2026-07-06T08:04:24.042Z |
| 9 | kramme:siw:discovery | 17 | 10 | 2026-06-22T08:12:30.896Z |
| 10 | trackbed:pr:generate-description | 12 | 8 | 2026-07-01T09:48:47.901Z |
| 11 | kramme:code:weakness-audit | 9 | 9 | 2026-07-05T16:12:04.161Z |
| 12 | trackbed:discovery:strategic-inquiry | 9 | 9 | 2026-07-06T19:31:56.999Z |
| 13 | trackbed:pr:github-review | 6 | 6 | 2026-06-26T10:12:36.649Z |
| 14 | kramme:siw:issue-implement | 6 | 6 | 2026-06-22T09:51:37.374Z |
| 15 | trackbed:linear:issue-define | 5 | 5 | 2026-06-22T11:32:03.730Z |

## Top 15 Usage Compared With Recent PR Effort

I treated the last 100 commits with GitHub PR numbers in their subject as the last approximately 100 PRs. Those 100 PRs touched 658 files by `git log --name-only`. Skill files were the largest single area by touch count, but tests and scripts were touched across more PRs.

| Skill name | 90d usage rank | Invocations 90d | 30d | Last-100 PR skill file touches | PRs touching skill dir |
| --- | --- | --- | --- | --- | --- |
| trackbed:pr:resolve-review | 1 | 204 | 35 | 2 | 2 |
| trackbed:skill:review | 2 | 195 | 3 | 0 | 0 |
| trackbed:pr:code-review | 3 | 44 | 26 | 19 | 7 |
| trackbed:pr:rebase | 4 | 34 | 6 | 2 | 2 |
| trackbed:code:agent-readiness | 5 | 31 | 18 | 0 | 0 |
| trackbed:linear:issue-implement | 6 | 26 | 26 | 7 | 3 |
| trackbed:code:refactor-opportunities | 7 | 25 | 14 | 5 | 2 |
| trackbed:code:breakdown-findings | 8 | 18 | 13 | 12 | 3 |
| kramme:siw:discovery | 9 | 17 | 10 | 12 | 5 |
| trackbed:pr:generate-description | 10 | 12 | 8 | 8 | 3 |
| kramme:code:weakness-audit | 11 | 9 | 9 | 6 | 2 |
| trackbed:discovery:strategic-inquiry | 12 | 9 | 9 | 4 | 1 |
| trackbed:pr:github-review | 13 | 6 | 6 | 5 | 4 |
| kramme:siw:issue-implement | 14 | 6 | 6 | 8 | 4 |
| trackbed:linear:issue-define | 15 | 5 | 5 | 4 | 2 |

Recent effort by top-level area:

| Area         | File touches | PRs touched |
| ------------ | ------------ | ----------- |
| skills       | 302          | 47          |
| scripts      | 111          | 45          |
| tests        | 111          | 65          |
| hooks        | 35           | 20          |
| README.md    | 21           | 21          |
| docs         | 15           | 10          |
| .github      | 13           | 5           |
| package.json | 10           | 7           |
| evals        | 7            | 5           |
| Makefile     | 7            | 7           |

Skill directories with the most direct PR effort:

| Skill directory | File touches | PRs touched | 90d usage | 30d usage |
| --- | --- | --- | --- | --- |
| trackbed:pr:code-review | 19 | 7 | 44 | 26 |
| trackbed:siw:generate-phases | 14 | 7 | 1 | 1 |
| trackbed:code:breakdown-findings | 12 | 3 | 18 | 13 |
| kramme:siw:discovery | 12 | 5 | 17 | 10 |
| trackbed:qa | 11 | 4 | 0 | 0 |
| trackbed:siw:init | 11 | 3 | 3 | 2 |
| trackbed:siw:transfer-to-linear | 11 | 5 | 2 | 2 |
| kramme:siw:close | 10 | 3 | 0 | 0 |
| trackbed:pr:generate-description | 8 | 3 | 12 | 8 |
| kramme:siw:continue | 8 | 2 | 0 | 0 |
| kramme:siw:issue-implement | 8 | 4 | 6 | 6 |
| trackbed:code:api-design | 7 | 2 | 0 | 0 |
| trackbed:linear:issue-implement | 7 | 3 | 26 | 26 |
| kramme:siw:issue-define | 7 | 4 | 0 | 0 |
| kramme:siw:product-audit | 7 | 4 | 0 | 0 |

The comparison shows three useful patterns. First, the heavily used review skills are mostly stable: `trackbed:pr:resolve-review`, `trackbed:skill:review`, and `trackbed:code:agent-readiness` have high usage but little or no direct skill-directory churn in the last 100 PRs. Second, some active development is going into low-use or zero-use skill families, especially SIW, QA, and product/live-review work. Third, `trackbed:pr:code-review`, `trackbed:code:breakdown-findings`, `kramme:siw:discovery`, and `trackbed:linear:issue-implement` line up well: they have both recorded usage and recent maintenance investment.

## Recommendation

Adopt a quarterly usage-informed pruning review, not immediate deletion from a single report. This hook history starts on 2026-05-28, so the requested 90-day report is really the first 40 days of captured data. That is enough to identify concentration, but not enough to prove that every zero-use skill is dead. Classify skills each quarter into four buckets: core, emerging, observe, and sunset. Core skills should have meaningful 30-day or 90-day usage, or clear workflow-critical status. Emerging skills are recently added or actively developed, such as `trackbed:discovery:strategic-inquiry`, and should get one full quarter before judgment. Observe skills have no usage but recent PR investment or strategic roadmap dependency. Sunset candidates have zero 90-day usage, no recent direct PR effort, no roadmap dependency, and overlap with a used skill.

The pruning cadence should be conservative but real: run the 30-day and 90-day report monthly for trend visibility, then make pruning decisions quarterly. In each quarterly pass, require an owner to either provide a current use case, merge the behavior into a stronger adjacent skill, or mark the skill deprecated. After one additional quarter with zero usage and no owner case, remove or unship the skill. This avoids deleting planned work too early while creating pressure against indefinite library growth.

"Usage report consulted" should gate new-skill PRs, but as a lightweight policy gate rather than an absolute numeric threshold. Every new-skill PR should include a short section with the latest 30-day and 90-day usage report date, the nearest existing skills, why those existing skills are insufficient, the expected invocation path, and the review date for the first adoption check. For changes to existing zero-use skills, require the same section or a clear statement that the PR is cleanup/deprecation. The gate should block new skills that duplicate unused or lightly used skills without a migration or adoption argument. It should not block bug fixes, source corrections, or planned roadmap work that explicitly accepts the adoption risk.
