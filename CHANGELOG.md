# Changelog

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

[0.3.1]: https://github.com/Abildtoft/kramme-cc-workflow/releases/tag/v0.3.1
[0.3.0]: https://github.com/Abildtoft/kramme-cc-workflow/releases/tag/v0.3.0
[0.2.0]: https://github.com/Abildtoft/kramme-cc-workflow/releases/tag/v0.2.0
