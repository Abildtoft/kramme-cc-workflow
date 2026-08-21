#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/.."
}

SKILL="skills/kramme:docs:sync-release/SKILL.md"

@test "current scope uses merge-base three-dot semantics before dirty changes" {
  grep -qF 'compute `merge-base(<default>, HEAD)`' "$SKILL"
  grep -qF 'use `<merge-base>...HEAD` for committed branch changes' "$SKILL"
  grep -qF 'Never use a two-endpoint `<default> HEAD` diff' "$SKILL"
  grep -qF 'then add staged, unstaged, and untracked changes' "$SKILL"
}

@test "named-ref apply requires the analyzed snapshot to match HEAD" {
  grep -qF 'A named base/ref scope is report-only unless its resolved `<ref>` commit exactly equals the current `HEAD` commit.' "$SKILL"
  grep -qF 'the analyzed snapshot is not the checkout that would be mutated' "$SKILL"
  grep -qF 'Do not checkout the named ref or apply its proposed documentation to the current worktree.' "$SKILL"
}

@test "apply revalidates every evidence and generator input by content and identity" {
  grep -qF 'Snapshot every input whose bytes or identity inform a planned mutation' "$SKILL"
  grep -qF 'change-evidence source files, candidate documents, generator source inputs, generator executables, configuration, manifests, and planned destinations' "$SKILL"
  grep -qF 'Record content hashes plus file identity and type metadata rather than Git status alone.' "$SKILL"
  grep -qF 'stop if any input or destination changed, even when `git status` did not' "$SKILL"
}

@test "candidate document paths cannot escape or alias repository files" {
  grep -qF 'Before reading a candidate document, resolve the repository root and validate the complete path.' "$SKILL"
  grep -qF 'resolve inside the repository, be a regular file, have no symlink path component, and have exactly one hard-link name' "$SKILL"
  grep -qF 'never read or mutate it through the apparent repository path' "$SKILL"
  grep -qF 'repeat the repository-containment, regular-file, non-symlink, single-link, destination-identity, and all-input snapshot checks' "$SKILL"
}

@test "generated ownership is independent from drift status" {
  grep -qF 'Track ownership independently from drift status as `AUTHORED`, `GENERATED`, or `UNVERIFIED`' "$SKILL"
  grep -qF 'classify it `CURRENT` when it matches, `GENERATED` only when confirmed generator-owned drift exists, or `UNVERIFIED`' "$SKILL"
  grep -qF 'Generated ownership by itself is not drift.' "$SKILL"
  grep -qF 'Ownership: <AUTHORED|GENERATED|UNVERIFIED>' "$SKILL"
}

@test "adoption review waits for a full 90-day evidence window" {
  grep -qF 'First adoption-review date: 2026-11-19.' "$SKILL"
  grep -qF 'inspect 30-day and 90-day usage' "$SKILL"
}
