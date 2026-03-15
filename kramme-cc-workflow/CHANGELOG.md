# Changelog

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


[0.42.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.41.0...v0.42.0
[0.41.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.40.0...v0.41.0
[0.40.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.39.0...v0.40.0
[0.39.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.38.0...v0.39.0
[0.38.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.37.0...v0.38.0