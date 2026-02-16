# Changelog

## [Unreleased]

### Added
## [0.24.0] - 2026-02-16

### Added
- Add specialized security agents and refine agent quality (#156)

- Add 4 specialized security review agents: injection, auth, data, logic (#156)

### Removed
- Remove monolithic find-bugs and find-bugs:team skills (replaced by security agents in pr:review)

### Changed
## [0.23.0] - 2026-02-15

### Added
- Add discovery workflow and spec-scan exclusions (#153)

### Changed
- Rename to hierarchical naming convention kramme:<domain>:<action> (#154)

## [0.22.0] - 2026-02-15

### Added
- Add spec audit workflow and split audit reports (#150)

### Changed
- Extract Connect-specific skills to separate plugin (#151)

- Extract Connect-specific skills to separate `kramme-connect-workflow` plugin

## [0.21.0] - 2026-02-12

### Added
- Preserve colon-based skill names and remove prompt duplication (#146)

### Fixed
- Strengthen siw audit workflow guidance (#148)

## [0.20.0] - 2026-02-12

### Added
- Simplify Codex conversion by removing redundant prompt generation (#144)

## [0.19.0] - 2026-02-11

### Added
- Add org-configurable context link settings (#141)
- Configure commit guard for review artifacts (#137)
- Support non-interactive cleanup flow (#135)

### Fixed
- Harden command execution and cache loading (#140)
- Harden parser and close bypasses (#139)
- Clean stale codex artifacts in non-interactive installs (#138)

## [0.18.0] - 2026-02-11

### Added
- Add audit and resolve workflow commands (#133)
- Rename elegant-refactor to redo-elegantly and add refactor-pass skill (#132)

### Fixed
- Disambiguate deleted issue references in LOG.md during restart (#131)

## [0.17.0] - 2026-02-06

### Added
- Add Agent Teams support skills (#129)

### Fixed
- Quote YAML argument-hint values containing brackets (#127)

## [0.16.0] - 2026-02-06

### Added
- Install agents to ~/.agents/skills (#125)

## [0.15.0] - 2026-02-06

### Changed
- Enforce explicit skill frontmatter for all fields (#123)
- Unify review artifacts as REVIEW_OVERVIEW (#122)

## [0.14.0] - 2026-02-06

### Added
- Migrate all commands to unified skills system (#120)
- Add removal planner agent (#119)
- Add wrap-up session workflow (#118)
- Add persistent SQLite database for cross-session learning storage (#117)
- Add kramme:connect:rive Rive documentation skill (#116)

## [0.13.1] - 2026-02-04

### Added
- Prompt before deleting kramme agents and skills (#114)

## [0.13.0] - 2026-02-04

### Added
- Automatically update LOG.md when renumbering issues (#112)
- Add /kramme:siw:generate-phases command (#110)

## [0.12.1] - 2026-02-04

### Added
- Add support for linking external specs and discover mode (#108)

## [0.12.0] - 2026-02-03

### Added
- Overhaul of the Structured Implementation Workflow (SIW) (#106)
- Add kramme:elegant-refactor command (#104)
- Add automatic conflict resolution to rebase-pr command (#101)

### Changed
- Add Magic Patterns MCP to recommended servers (#105)
- Add Other Claude Code Plugins section (#103)
- Fix command patterns from colon to space syntax (#100)

### Fixed
- PreToolUse hooks now use exit 2 to communicate with Claude (#102)

## [0.11.0] - 2026-01-29

### Changed
- Implement progressive disclosure (#98)
- Add kramme: prefix to agents-md skill and granola-meeting-notes command (#97)
- Note opencode/codex updates (#96)
- Add sub-headers to table of contents (#95)
- Clarify base branch update steps (#94)

### Fixed
- Tighten merge command detection (#93)

## [0.10.0] - 2026-01-28

### Added
- Add agents-md skill (#90)
- Add commit message skill (#91)
- Add opencode/codex converter (#84)
- Add performance-oracle agent (#85)
- Update changelog-generator skill for engaging internal changelogs (#88)
- Add design-iterator agent for iterative UI/UX refinement (#87)
- Add architecture-strategist agent (#86)

### Changed
- Add extract-learnings command (#89)

## [0.9.0] - 2026-01-25

### Added
- Add conventional commit title generation (#82)

## [0.8.0] - 2026-01-24

### Added
- Add connect-extract-to-nx-libraries skill (#78)
- Add reset command and improve hook toggle system (#76)
- Add consolidation rebase mode prompt to iterate-pr (#75)

### Changed
- Add git show-branch to core permissions (#77)
- Update README intro (#74)
- Update markdown converter stdin guidance (#72)
- Add Recommended CLIs section to README (#70)

### Fixed
- Ensure define-linear-issue creates Linear issues and stops after completion (#80)
- Add explicit prohibition of AI attribution in PR descriptions (#79)

## [0.7.0] - 2026-01-22

### Added
- Add clean-up-artifacts command (#67)
- Add simple bug template to define-linear-issue skill (#65)
- Add Granola Meeting Notes skill and command (#64)

### Changed
- Reorganize permissions into Core and Extended sections (#66)
- Add table of contents and consolidate installation/updating section (#63)

### Fixed
- Use remote branch for PR diff comparisons to avoid stale local branches (#68)

## [0.6.0] - 2026-01-21

### Added
- Add kramme:rebase-pr command (#60)
- Add noninteractive-git hook to block editor-opening git commands (#61)
- Add confirmation hook for REVIEW_RESPONSES.md commits (#58)

### Changed
- Fix component frontmatter examples and typo (#59)
- Add recommended MCP servers with installation instructions (#57)
- Add Linear MCP permissions to suggested permissions section (#55)

### Fixed
- Move branch creation to immediately after issue fetch (#56)

## [0.5.0] - 2026-01-20

### Added
- Add PostToolUse auto-format hook (#52)

### Changed
- Add suggested permissions section to README (#53)

### Fixed
- Prevent create-pr workflow from stopping after commits (#51)

## [0.4.0] - 2026-01-20

### Added
- Add humanize-text skill and command (#48)
- Detect vacuous tests in test-analyzer agent (#49)
- Check REVIEW_RESPONSES.md to avoid re-reporting addressed findings (#47)
- Retain original Dev Ask content in Linear issues (#43)
- Enforce conventional commits for PR titles (#42)

### Changed
- Remove greeting from README (#46)
- Add greeting to README (#45)
- Clarify recreate-commits works in-place, not on clean branch (#41)

## [0.3.1] - 2026-01-19

### Added
- Add recreate-commits command (#27)
- Add release automation: GitHub Actions, Python script, and documentation (#26)
- Rename review response file and add commit tracking to fixup workflow (#24)
- Add fixup mode base-branch guidance (#19)
- Add plugin update instructions to README (#21)
- Add marketplace support and update rename (#14)
- Add comprehensive tests for hooks using BATS (#15)
- Add Linear issue branch naming to create-pr (#12)
- Add hook to block destructive rm -rf commands (#13)
- Add context-links Stop hook for displaying PR/MR and Linear issue links (#11)
- Add kramme:define-linear-issue command (initial version) (#9)
- Add kramme:implement-linear-issue command (#8)
- Add deslop-reviewer agent to PR review workflow (v1) (#7)
- Add PR relevance validator agent (#6)
- Add personal skills I've been using locally (#4)
- Add kramme: user-scoped commands to plugin (#3)
- Add CLAUDE.md with plugin architecture documentation (#2)
- Add Claude Code plugin foundation structure (#1)
- Initial commit

### Changed
- Update PR creation instructions (#35)
- Auto-generate CHANGELOG from git commits (#34)
- Modify recreate-commits skill to default to current branch (#31)
- Rename fixup-review-changes to fixup-changes (#29)
- Bump plugin version to 0.2.0 (#22)
- Update kramme:review-pr to suggest resolve-review-findings (#18)
- Expand define-linear-issue to support improving existing issues (#17)
- Unify PR terminology across plugin (#10)
- Copy pr-review-toolkit from official Claude Code plugin (#5)

### Fixed
- Configure git identity in release-tag workflow (#37)
- Fix release workflow branch conflict by cleaning up existing branches (#32)
- Fix release workflow to use PR-based releases for protected branches (#30)
- Fix GitHub Actions release workflow git configuration (#28)
- Fix GitLab MR URL extraction and update output format (#25)
- Fix marketplace update command in README (#23)
- Fix GitLab MR link detection in context-links hook (#20)
- Fix marketplace source schema validation (#16)

## [0.3.0] - 2026-01-19

### Added
- Add recreate-commits command (#27)
- Add release automation: GitHub Actions, Python script, and documentation (#26)
- Rename review response file and add commit tracking to fixup workflow (#24)
- Add fixup mode base-branch guidance (#19)
- Add plugin update instructions to README (#21)
- Add marketplace support and update rename (#14)
- Add comprehensive tests for hooks using BATS (#15)
- Add Linear issue branch naming to create-pr (#12)
- Add hook to block destructive rm -rf commands (#13)
- Add context-links Stop hook for displaying PR/MR and Linear issue links (#11)
- Add kramme:define-linear-issue command (initial version) (#9)
- Add kramme:implement-linear-issue command (#8)
- Add deslop-reviewer agent to PR review workflow (v1) (#7)
- Add PR relevance validator agent (#6)
- Add personal skills I've been using locally (#4)
- Add kramme: user-scoped commands to plugin (#3)
- Add CLAUDE.md with plugin architecture documentation (#2)
- Add Claude Code plugin foundation structure (#1)
- Initial commit

### Changed
- Update PR creation instructions (#35)
- Auto-generate CHANGELOG from git commits (#34)
- Modify recreate-commits skill to default to current branch (#31)
- Rename fixup-review-changes to fixup-changes (#29)
- Bump plugin version to 0.2.0 (#22)
- Update kramme:review-pr to suggest resolve-review-findings (#18)
- Expand define-linear-issue to support improving existing issues (#17)
- Unify PR terminology across plugin (#10)
- Copy pr-review-toolkit from official Claude Code plugin (#5)

### Fixed
- Fix release workflow branch conflict by cleaning up existing branches (#32)
- Fix release workflow to use PR-based releases for protected branches (#30)
- Fix GitHub Actions release workflow git configuration (#28)
- Fix GitLab MR URL extraction and update output format (#25)
- Fix marketplace update command in README (#23)
- Fix GitLab MR link detection in context-links hook (#20)
- Fix marketplace source schema validation (#16)

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2025-01-17

### Added
- Initial marketplace release
- 10+ slash commands for PR workflows, Linear integration, and code review
- 8 specialized review agents
- 10 auto-triggered skills
- `block-rm-rf` hook for safer file deletion
- `context-links` hook for PR/Linear link display
- BATS test suite for hooks

[0.24.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.23.0...v0.24.0
[0.23.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.22.0...v0.23.0
[0.22.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.21.0...v0.22.0
[0.21.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.20.0...v0.21.0
[0.20.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.19.0...v0.20.0
[0.19.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.18.0...v0.19.0
[0.18.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.17.0...v0.18.0
[0.17.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.16.0...v0.17.0
[0.16.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.15.0...v0.16.0
[0.15.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.14.0...v0.15.0
[0.14.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.13.1...v0.14.0
[0.13.1]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.13.0...v0.13.1
[0.13.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.12.1...v0.13.0
[0.12.1]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.12.0...v0.12.1
[0.12.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.11.0...v0.12.0
[0.11.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.10.0...v0.11.0
[0.10.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.9.0...v0.10.0
[0.9.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/Abildtoft/kramme-cc-workflow/releases/tag/v0.3.1
[0.3.0]: https://github.com/Abildtoft/kramme-cc-workflow/releases/tag/v0.3.0
[0.2.0]: https://github.com/Abildtoft/kramme-cc-workflow/releases/tag/v0.2.0
