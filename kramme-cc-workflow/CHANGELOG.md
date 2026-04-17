# Changelog

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

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


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