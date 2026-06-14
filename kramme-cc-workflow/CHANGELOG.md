# Changelog

## Unreleased

### Changed
## [0.63.0] - 2026-06-14

### Added
- Add accepted findings policy (#517)
- Add GitHub PR reviewer skill (#508)
- Add next issue selector skill (#507)

### Changed
- Add Codex support metadata (#516)
- Document SkillSpector scanning (#513)
- Remove wrap-up skill docs (#511)
- Move review posting to reply skill (#510)
- Clarify handoff planning flow (#509)
- Require discovery evidence coverage (#506)
- Default Linear links to Closes (#505)
- Document Linear transfer safeguards (#504)

## [0.62.0] - 2026-06-12

### Added
- Add autoreview skill (#498)
- Add demo reel evidence capture (#477)
- Add work-from-plan adapter (#476)
- Add spec-audit apply mode (#474)
- Add document review skill (#475)
- Add release communication workflows (#473)
- Add measured optimization workflow (#469)
- Add setup and git maintenance helpers (#468)
- Add shared auto URL detection (#467)
- Add safe prior-session search (#466)
- Add product strategy feedback loops (#465)

### Changed
- Clarify Linear transfer retry rules (#502)
- Clarify workflow skill guidance (#501)
- Extract shared base and diff helpers (#493)
- Trim oversized skills into references (#492)
- Centralize direct-update logic in auto-fix (#490)
- Clarify platform-aware instructions (#489)
- Trim oversized PR and QA workflows (#488)
- Normalize ported code skill epilogues (#487)
- Add source reference snapshots (#486)
- Clarify skill namespaces and diff-review scope (#485)
- Harden invocation safety (#483)
- Harden review contracts (#482)
- Make audit retries idempotent (#480)
- Harden PR creation flow (#481)
- Sync shared workflow contracts (#479)
- Tighten deletion safety (#478)
- Add solution note workflows (#472)
- Tighten phase generation gates (#471)
- Add structured review handoffs (#470)
- Codify external adaptation guardrails (#464)

### Fixed
- Harden hook error handling (#499)
- Harden helper script fallbacks (#500)
- Harden destructive workflow safeguards (#484)

- Rename `/kramme:pr:design-pipeline` to `/kramme:ci:design-pipeline` so CI/CD pipeline design no longer appears in PR review namespaces.
- Rename `/kramme:verify-understanding` to `/kramme:learn:verify-understanding` to separate human comprehension checks from code verification skills.
- Clarify that `/kramme:visual:diff-review` produces a visual diff artifact, not an actionable PR/code review workflow.

## [0.61.0] - 2026-06-06

### Added
- Add verify-understanding workflow (#462)
- Add GitHub review reply workflow (#461)
- Add Linear transfer skill (#460)
- Add quick issue creation mode (#459)

### Changed
- Add auto modes to workflow skills (#458)

## [0.60.0] - 2026-06-05

### Added
- Default issue Mode to AUTO and add Mode column to schema (#454)

### Changed
- Tighten PR body guidance (#456)
- Add prompt footprint rubric (#455)
- Delegate plan-split artifacts to breakdown-findings (#453)

- pr:plan-split now delegates `PR_PLAN_*.md` artifact generation to code:breakdown-findings, handing over its slices as pre-clustered themes plus a worktree-based implementation setup that extracts each slice's changes from the branch the skill is run in
- code:breakdown-findings now accepts a pre-clustered handoff (themes mapped one-to-one to plans, no re-clustering) and an optional shared implementation-setup block rendered verbatim into every plan

### Removed

## [0.59.0] - 2026-05-28

### Added
- Add pr:verify-description for body/diff drift checks (#371)

### Changed
- Resolve review findings on kramme:visual:diff-review (#451)
- Resolve review findings on kramme:visual:diagram (#447)
- Resolve review findings on kramme:visual:generate-image (#450)
- Resolve review findings on kramme:visual:project-recap (#449)
- Resolve review findings on kramme:visual:plan-review (#448)
- Resolve review findings on kramme:visual:onboarding (#446)
- Resolve review findings on kramme:product:review (#445)
- Resolve review findings on kramme:browse (#441)
- Resolve review findings on kramme:product:design-critic (#443)
- Resolve review findings on kramme:nx:setup-portless (#442)
- Resolve review findings on kramme:linear:issue-implement (#444)
- Resolve review findings on kramme:linear:issue-define (#440)
- Guard workflow-artifacts:cleanup deletions (#439)
- Resolve review findings on kramme:hooks:toggle (#437)
- Resolve review findings on kramme:docs:adr (#426)
- Resolve review findings on kramme:git:recreate-commits (#436)
- Resolve review findings on kramme:hooks:configure-links (#433)
- Resolve review findings on kramme:launch:rollout (#435)
- Resolve review findings on kramme:changelog:generate (#434)
- Resolve review findings on kramme:git:commit-message (#432)
- Resolve review findings on kramme:git:fixup (#431)
- Resolve review findings on kramme:session:automate-repeats (#430)
- Resolve review findings on kramme:session:context-setup (#429)
- Resolve review findings on kramme:session:wrap-up (#428)
- Resolve review findings on kramme:docs:ubiquitous-language (#427)
- Resolve review findings on kramme:discovery:interview (#425)
- Resolve review findings on kramme:docs:feature-spec (#424)
- Resolve review findings on kramme:docs:update-agents-md (#423)
- Resolve review findings on kramme:text:humanize (#422)
- Resolve review findings on kramme:docs:out-of-scope (#421)
- Resolve review findings on kramme:docs:add-greenfield-policy (#419)
- Resolve review findings on kramme:qa:intake (#418)
- Resolve review findings on kramme:qa (#416)
- Resolve review findings on kramme:verify:before-completion (#415)
- Resolve review findings on kramme:verify:run (#414)
- Resolve review findings on kramme:test:tdd (#417)
- Resolve review findings on kramme:test:generate (#413)
- Resolve review findings on kramme:debug:triage-to-issue (#412)
- Resolve review findings on kramme:debug:investigate (#411)
- Resolve review findings on kramme:code:api-design (#409)
- Resolve review findings on kramme:code:performance (#410)
- Resolve review findings on kramme:code:harden-security (#408)
- Resolve review findings on kramme:code:migrate (#404)
- Resolve review findings on kramme:deps:audit (#405)
- Resolve review findings on kramme:code:agent-readiness (#406)
- Resolve review findings on kramme:code:deprecate (#407)
- Resolve review findings on kramme:code:source-driven (#403)
- Remove kramme:code:frontend-authoring (#402)
- Resolve review findings on kramme:code:cleanup-ai (#401)
- Resolve review findings on kramme:code:refactor-opportunities (#400)
- Resolve review findings on kramme:code:breakdown-findings (#398)
- Resolve review findings on kramme:code:refactor-pass (#399)
- Resolve review findings on kramme:code:rewrite-clean (#397)
- Resolve review findings on kramme:code:incremental (#396)
- Resolve review findings on kramme:pr:resolve-review (#394)
- Resolve review findings on kramme:pr:generate-description (#388)
- Resolve review findings on kramme:pr:design-pipeline (#392)
- Resolve review findings on kramme:pr:code-review (#393)
- Resolve review findings on kramme:pr:ux-review (#389)
- Resolve review findings on kramme:pr:copy-review (#391)
- Resolve review findings on kramme:pr:product-review (#390)
- Resolve review findings on kramme:pr:fix-ci (#385)
- Resolve review findings on kramme:pr:create (#386)
- Resolve review findings on kramme:pr:finalize (#387)
- Resolve review findings on kramme:pr:rebase (#384)
- Resolve review findings on kramme:pr:plan-split (#383)
- Resolve review findings on kramme:siw:implementation-audit (#379)
- Resolve review findings on kramme:siw:product-audit (#381)
- Resolve review findings on siw:spec-audit:auto-fix (#380)
- Resolve review findings on kramme:siw:spec-audit (#382)
- Resolve review findings on kramme:siw:issue-define (#375)
- Resolve review findings on siw:issue-implement (#374)
- Harden siw:generate-phases against review findings (#376)
- Resolve review findings on kramme:siw:breakdown-findings (#373)
- Resolve review findings on kramme:siw:discovery (#372)
- Tighten siw:close and add verify-before-delete gate (#370)
- Harden siw:remove with safety checks and consistent cleanup (#367)
- Resolve review findings on kramme:siw:reset (#365)
- Tighten skill:create interview and add error handling (#364)
- Tighten skill:review resolution and N/A rubric handling (#363)

### Fixed
- Resolve review findings on kramme:docs:to-markdown (#420)
- Resolve review findings on kramme:siw:resolve-audit (#377)
- Harden kramme:siw:init destructive paths (#369)
- Repair siw:continue template paths and clarify role (#368)
- Correct rename order and harden delete in issue-reindex (#366)

- Remove kramme:code:zoom-out orientation skill
- Breaking: Removed `/kramme:code:frontend-authoring` skill.

## [0.58.0] - 2026-05-27

### Fixed
- Restore skill review workflow (#361)

## [0.57.0] - 2026-05-27

### Added
- Add skill usage stats (#355)
- Install converted hook plugin bundle (#353)
- Add repeat automation skill (#352)
- Add skill review workflow (#351)

### Changed
- Make root README canonical (#359)
- Support implementation audit breakdowns (#358)
- Require manual test plans in descriptions (#357)
- Discourage implementation-restating tests (#356)
- Remove OpenCode support (#354)

## [0.56.0] - 2026-05-19

### Added
- Calibrate codebase findings (#349)

### Changed
- Fold team modes into base skills (#344)
- Extract workflow detail references (#340)
- Document data URI option (#341)
- Add argument hints (#339)
- Add context pointer guidance (#338)
- Trim progressive-disclosure docs (#336)
- Avoid GitHub UI duplication (#337)

### Fixed
- Rewrite agent markdown references (#343)

- Breaking: Removed separate team-mode skills (`kramme:pr:code-review:team`, `kramme:pr:resolve-review:team`, `kramme:pr:ux-review:team`, `kramme:siw:issue-implement:team`, `kramme:siw:spec-audit:team`, and `kramme:siw:implementation-audit:team`). Use the base skill with `--team` instead.

## [0.55.0] - 2026-05-15

### Added

- Audit Pocock arch sources, absorb 4-category taxonomy (#332)
- Add research pre-pass (#333)

### Changed

- Gate PR-scoped findings (#334)

## [0.54.0] - 2026-05-02

### Added

- Add auto mode to rebase skill (#330)
- Include PR description as review context and target (#327)
- Add wave/lane labels to breakdown-findings plans (#326)

### Changed

- Scope refactor opportunity scans (#328)
- Reduce file inventory guidance (#325)

## [0.53.0] - 2026-04-28

### Added

- Add plan-split skill, drop reviewer size gate (#315)
- Add source manifests and harden HITL gate (#316)
- Add kramme:docs:out-of-scope rejection KB (#314)
- Add --decision-tree mode for coupled decisions (#313)
- Add conversational QA intake skill (#312)
- Add Design It Twice, Refactor mode, ADR-aware scans (#311)
- Uplift workflow skills with HITL/AUTO + Pocock patterns (#307)
- Add inline-offer pattern and multiline question support (#310)
- Add kramme:debug:triage-to-issue skill (#309)
- Add kramme:code:zoom-out orientation map (#308)
- Add kramme:docs:ubiquitous-language for DDD glossaries (#306)
- Add source audit workflow (#305)
- Adapt Claude tool idioms in Codex skill output (#303)

### Changed

- Extract document creation reference (#321)
- Split implementation audit output steps (#322)
- Split reverse-engineer spec skill references (#323)
- Regularize command names (#319)
- Split issues-reindex skill references (#320)
- Split issue-implement SKILL.md into references (#317)

- Drop GitLab support; plugin is GitHub-only. Removes the GitLab MR detection branch from the `context-links` hook, the `glab` CLI permissions, the `mcp__gitlab__*` MCP permissions, and the `CONTEXT_LINKS_GITLAB_REMOTE_REGEX` config var. Skills, agents, and references now assume GitHub. Downstream users on GitLab installs should clean up their `settings.json` and any local `hooks/context-links.config` entries that referenced these.

## [0.52.0] - 2026-04-23

### Added

- Add deprecate and ADR authoring workflows (#300)
- Add rollout workflow and harden git hooks (#299)
- Add kramme:code:deprecate skill, harden kramme:code:migrate (#298)
- Port Addy rigor into debug:investigate and harden git hook parsing (#297)
- Add kramme:docs:adr skill for authoring ADRs (#296)
- Add design-pipeline skill and harden fix-ci quality gates (#295)
- Add kramme:code:performance skill (#294)
- Port Addy Osmani git/PR rigor into kramme git and pr skills (#293)
- Port Addy rigor into refactor and rewrite skills (#292)
- Add task sizing and parallelization to phase planning (#291)
- Port Addy Osmani code-review conventions into PR skills (#290)
- Add kramme:code:harden-security skill (#289)
- Add kramme:session:context-setup skill (#288)
- Port browse and qa to Addy conventions (#287)
- Add kramme:code:frontend-authoring skill (#286)
- Add kramme:code:api-design skill (#284)
- Add kramme:code:source-driven skill (#285)
- Add kramme:code:incremental skill (#283)
- Add kramme:docs:feature-spec skill (#282)
- Port idea-refine divergent pre-stage to interview skill (#281)
- Add kramme:test:tdd skill (#280)

## [0.51.0] - 2026-04-19

### Added

- Broaden breakdown-findings sources and harden opencode hooks (#277)

### Changed

- Generalize instruction-file guidance (#276)
- Inline shared refs so each skill is self-contained (#274)

### Fixed

- Harden hooks and dedupe skill keyword docs (#275)

## [0.50.0] - 2026-04-18

### Added

- Make draft PRs opt-in via --draft flag (#272)
- Add breakdown-findings skill for decision-ready spec triage (#271)

## [0.49.0] - 2026-04-17

### Added

- Add --after flag to recreate-commits and harden hook parsing (#268)
- Add code:breakdown-findings skill with guarded plan artifacts (#269)
- Add --emphasize flag and fix env unset/clear in hooks (#265)

### Changed

- Add missing flags to skill documentation (#267)
- Constrain code-simplifier to behavior-preserving changes (#264)

### Fixed

- Handle env unset and clear in command parsing (#266)
- Support compound commands and shell wrappers in git commit parsing (#261)

## [0.48.0] - 2026-04-09

### Added

- Harden recreate-commits base branch resolution (#262)

## [0.47.0] - 2026-03-31

### Added

- Add discovery-first workflow handoff (#258)
- Add spec-audit auto-fix skill for mechanical findings (#259)
- Add copy review skills for UI text redundancy analysis (#253)

### Changed

- Strengthen product framing guidance (#255)

### Fixed

- Allow model invocation for skills called from other skills (#256)

## [0.46.0] - 2026-03-22

### Added

- Add --fix, --granular, and --severity flags to PR review skills (#251)

## [0.45.0] - 2026-03-22

### Fixed

- Fetch remote base branch before diff comparison (#249)

## [0.44.0] - 2026-03-19

### Added

- Add --granular flag for atomic decomposition (#244)

### Changed

- Add inline report output options (#246)
- Rename product skills to clarify audit vs review (#245)

### Fixed

- Harden PR base branch resolution (#247)

## [0.43.0] - 2026-03-17

### Added

- Add product design critic skill (#242)
- Add auto-mode workflow support (#241)

## [0.42.0] - 2026-03-15

### Added

- Add kramme:pr:product-review skill — deep product review of branch and local changes
- Add kramme:siw:product-review skill — product critique of SIW specs/plans before implementation
- Add kramme:browse skill — browser operator for live product inspection via MCP
- Add kramme:qa skill — structured QA testing with evidence capture and reports
- Add kramme:product:audit skill — whole-product review across flows and surfaces
- Add kramme:pr:finalize skill — final PR readiness orchestration with ready/not-ready verdict
- Expand kramme:product-reviewer agent with PR/spec modes, 6 new review dimensions, and threshold philosophy

### Changed

- Improve kramme:browse with explicit MCP detection probes and before/after state comparison pattern
- Improve kramme:qa with health score rubric, framework-specific hints, regression baseline mode
- Improve kramme:product:audit with previous-audit deduplication
- Enrich QA report template with metadata, health score breakdown, and category tracking
- Update kramme:workflow-artifacts:cleanup to include new review artifacts
- Update kramme:pr:resolve-review to recognize PRODUCT_REVIEW_OVERVIEW.md
- Update kramme:siw:continue with product-review entry point
- Add new artifact names to confirm-review-artifacts hook

## [0.41.0] - 2026-03-08

### Added

- Add kramme:docs:add-greenfield-policy skill (#233)

## [0.40.0] - 2026-03-05

### Changed

- Make README alert more welcoming (#231)

## [0.39.0] - 2026-03-05

### Added

- Improve `migrate-store-ngrx` skill with patterns from UFA `certificationStore` migration (#224)

### Changed

- Correct installation instructions for plugins (#220)
- Align supporting file dirs with Agent Skills spec (#229)
- Simplify argument names (#228)
- Add skills-best-practices inspiration (#226)
- Clarify personal workflow scope (#225)

### Fixed

- Align review scope with PR target branch (#227)

## [0.38.0] - 2026-03-04

### Added

- Support review-source and reply flags (#219)

### Changed

- Clarify skill policy and release docs (#221)
- Add Getting Started guide and fix skill count (#218)

### Fixed

- Preserve skill resources in conversion (#222)

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

[0.63.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.62.0...v0.63.0
[0.62.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.61.0...v0.62.0
[0.61.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.60.0...v0.61.0
[0.60.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.59.0...v0.60.0
[0.59.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.58.0...v0.59.0
[0.58.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.57.0...v0.58.0
[0.57.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.56.0...v0.57.0
[0.56.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.55.0...v0.56.0
[0.55.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.54.0...v0.55.0
[0.54.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.53.0...v0.54.0
[0.53.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.52.0...v0.53.0
[0.52.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.51.0...v0.52.0
[0.51.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.50.0...v0.51.0
[0.50.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.49.0...v0.50.0
[0.49.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.48.0...v0.49.0
[0.48.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.47.0...v0.48.0
[0.47.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.46.0...v0.47.0
[0.46.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.45.0...v0.46.0
[0.45.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.44.0...v0.45.0
[0.44.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.43.0...v0.44.0
[0.43.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.42.0...v0.43.0
[0.42.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.41.0...v0.42.0
[0.41.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.40.0...v0.41.0
[0.40.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.39.0...v0.40.0
[0.39.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.38.0...v0.39.0
[0.38.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.37.0...v0.38.0
