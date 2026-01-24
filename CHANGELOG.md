# Changelog

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

[0.8.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/Abildtoft/kramme-cc-workflow/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/Abildtoft/kramme-cc-workflow/releases/tag/v0.3.1
[0.3.0]: https://github.com/Abildtoft/kramme-cc-workflow/releases/tag/v0.3.0
[0.2.0]: https://github.com/Abildtoft/kramme-cc-workflow/releases/tag/v0.2.0
