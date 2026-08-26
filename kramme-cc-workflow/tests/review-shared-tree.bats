#!/usr/bin/env bats

load 'test_helper/common'

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  FINGERPRINT="$REPO_DIR/scripts/review-tree-fingerprint.sh"
  SKILL="$REPO_DIR/skills/kramme:pr:code-review/SKILL.md"
  DISCIPLINE="$REPO_DIR/skills/kramme:pr:code-review/references/review-discipline.md"
  TEAM_MODE="$REPO_DIR/skills/kramme:pr:code-review/references/team-mode.md"
  TEMPLATE="$REPO_DIR/skills/kramme:pr:code-review/references/output-template.md"
  UX_SKILL="$REPO_DIR/skills/kramme:pr:ux-review/SKILL.md"
  UX_DISCIPLINE="$REPO_DIR/skills/kramme:pr:ux-review/references/shared-working-tree.md"
  UX_TEAM_MODE="$REPO_DIR/skills/kramme:pr:ux-review/references/team-mode.md"
  UX_TEMPLATE="$REPO_DIR/skills/kramme:pr:ux-review/assets/ux-review-report-format.md"
  TMP_DIR="$(mktemp -d)"
  WORK="$TMP_DIR/work"
  init_test_git_repo "$WORK"
  cd "$WORK"
}

teardown() {
  if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR"
  fi
}

@test "fingerprint reports a clean tree as an empty manifest" {
  run "$FINGERPRINT"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "fingerprint detects a mutated tracked file" {
  local before
  before="$("$FINGERPRINT")"
  printf 'mutated by a reviewer\n' >> tracked.txt

  run "$FINGERPRINT"

  [ "$status" -eq 0 ]
  [ "$output" != "$before" ]
  [[ "$output" == *"tracked.txt"* ]]
}

@test "fingerprint detects a file created during the review" {
  printf 'new\n' > added.txt

  run "$FINGERPRINT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"added.txt"* ]]
}

@test "fingerprint marks a deleted tracked file as absent" {
  rm tracked.txt

  run "$FINGERPRINT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"absent"$'\t'"tracked.txt"* ]]
}

@test "fingerprint ignores build output and other ignored paths" {
  printf 'dist/\n' > .gitignore
  git add .gitignore
  git commit -m "ignore dist" > /dev/null
  mkdir dist
  printf 'bundle\n' > dist/app.js

  run "$FINGERPRINT"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "fingerprint output is stable across invocation directories" {
  printf 'staged\n' > added.txt
  mkdir -p nested
  local from_root from_nested
  from_root="$("$FINGERPRINT")"
  from_nested="$(cd nested && "$FINGERPRINT")"

  [ "$from_root" = "$from_nested" ]
  [[ "$from_root" == *"added.txt"* ]]
}

@test "fingerprint rejects unknown arguments and non-repository directories" {
  run "$FINGERPRINT" --digest
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown argument"* ]]

  cd "$TMP_DIR"
  mkdir -p outside
  cd outside
  run "$FINGERPRINT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not inside a git working tree"* ]]
}

@test "review discipline documents the shared working tree constraint" {
  grep -qF "## Shared working tree" "$DISCIPLINE"
  grep -qF "**Every spawned reviewer is read-only.**" "$DISCIPLINE"
  grep -qF "scripts/review-tree-fingerprint.sh" "$DISCIPLINE"
  grep -qF "Drop any finding whose cited code does not reproduce." "$DISCIPLINE"
  grep -qF "Never revert or clean them automatically" "$DISCIPLINE"
  grep -qF "The post-review working-tree manifest matches the pre-launch capture" "$DISCIPLINE"
}

@test "code review skill loads authoritative safety guidance and checks tree integrity" {
  grep -qF 'Immediately before launching any standard reviewer, read `references/review-discipline.md`' "$SKILL"
  grep -qF 'read `references/review-discipline.md` and then `references/team-mode.md`' "$SKILL"
  grep -qF 'Treat that reference as authoritative; do not reconstruct or abbreviate those contracts' "$SKILL"
  grep -qF '"${CLAUDE_PLUGIN_ROOT}/scripts/review-tree-fingerprint.sh" > "$TREE_MANIFEST_BEFORE"' "$SKILL"
  grep -qF '**Working-tree integrity check.**' "$SKILL"
  grep -qF 'diff "$TREE_MANIFEST_BEFORE" "$TREE_MANIFEST_AFTER"' "$SKILL"
  grep -qF 'apply the mutation handling in the `Shared working tree` section of `references/review-discipline.md`' "$SKILL"
  grep -qF "stop without writing \`REVIEW_OVERVIEW.md\` and report the mutation instead" "$SKILL"
  ! grep -qF 'No reviewer may create, edit, delete, move, or rename files' "$SKILL"
  ! grep -qF 'never revert or clean them' "$SKILL"
}

@test "team mode carries the same read-only mandate and integrity check" {
  grep -qF 'Every teammate is **read-only**' "$TEAM_MODE"
  grep -qF 'Pass the `Shared working tree`, `Reviewer calibration`, `Output markers`, and `Finding schema` sections' "$TEAM_MODE"
  grep -qF '"${CLAUDE_PLUGIN_ROOT}/scripts/review-tree-fingerprint.sh" > "$TREE_MANIFEST_BEFORE"' "$TEAM_MODE"
  grep -qF "**working-tree integrity check**" "$TEAM_MODE"
  grep -qF "TREE_MANIFEST_AFTER" "$TEAM_MODE"
  ! grep -qF 'no creating, editing, deleting, moving, or renaming files' "$TEAM_MODE"
}

@test "output template can report a mutated working tree" {
  grep -qF "Working tree mutated during review:" "$TEMPLATE"
  grep -qF "or the working tree changed during the review" "$TEMPLATE"
}

@test "ux review documents the shared working tree constraint" {
  grep -qF "# Shared working tree" "$UX_DISCIPLINE"
  grep -qF "**Every spawned reviewer is read-only.**" "$UX_DISCIPLINE"
  grep -qF '${CLAUDE_PLUGIN_ROOT}/scripts/review-tree-fingerprint.sh' "$UX_DISCIPLINE"
  grep -qF "a screenshot, recording, or trace must not be saved into the repository working tree" "$UX_DISCIPLINE"
  grep -qF "Drop any finding whose cited code does not reproduce." "$UX_DISCIPLINE"
  grep -qF "Never revert or clean them automatically" "$UX_DISCIPLINE"
}

@test "ux review skill mandates read-only reviewers and checks tree integrity" {
  grep -qF 'Read `references/shared-working-tree.md` and instruct every reviewer that it is **read-only**' "$UX_SKILL"
  grep -qF '"${CLAUDE_PLUGIN_ROOT}/scripts/review-tree-fingerprint.sh" > "$TREE_MANIFEST_BEFORE"' "$UX_SKILL"
  grep -qF '**Working-tree integrity check.**' "$UX_SKILL"
  grep -qF 'diff "$TREE_MANIFEST_BEFORE" "$TREE_MANIFEST_AFTER"' "$UX_SKILL"
  grep -qF "never save a screenshot, recording, or trace into the repository working tree" "$UX_SKILL"
  grep -qF "Parallel reviewers share one working tree" "$UX_SKILL"
  grep -qF "stop without writing \`UX_REVIEW_OVERVIEW.md\` and report the mutation instead" "$UX_SKILL"
}

@test "ux team mode carries the same read-only mandate and integrity check" {
  grep -qF 'Every teammate is **read-only**' "$UX_TEAM_MODE"
  grep -qF '"${CLAUDE_PLUGIN_ROOT}/scripts/review-tree-fingerprint.sh" > "$TREE_MANIFEST_BEFORE"' "$UX_TEAM_MODE"
  grep -qF "**working-tree integrity check**" "$UX_TEAM_MODE"
  grep -qF "TREE_MANIFEST_AFTER" "$UX_TEAM_MODE"
}

@test "ux report formats can report a mutated working tree" {
  grep -qF "Working tree mutated during audit:" "$UX_TEMPLATE"
  grep -qF "Working tree mutated during audit:" "$UX_TEAM_MODE"
}

@test "every reviewer agent launched by ux review is read-only" {
  local agents=(
    ux-reviewer
    product-reviewer
    visual-reviewer
    a11y-auditor
    pr-relevance-validator
  )
  local agent path

  for agent in "${agents[@]}"; do
    path="$REPO_DIR/agents/kramme:$agent.md"
    test -f "$path"
    if ! grep -qEi "read-only agent|do not edit files|never edit files" "$path"; then
      printf 'missing read-only mandate: %s\n' "$path" >&2
      return 1
    fi
  done
}

@test "every reviewer agent launched by code review is read-only" {
  local agents=(
    code-reviewer
    code-simplifier
    silent-failure-hunter
    deslop-reviewer
    pr-test-analyzer
    comment-analyzer
    type-design-analyzer
    removal-planner
    performance-oracle
    injection-reviewer
    auth-reviewer
    data-reviewer
    logic-reviewer
    lean-reviewer
    pr-relevance-validator
  )
  local agent path

  for agent in "${agents[@]}"; do
    path="$REPO_DIR/agents/kramme:$agent.md"
    test -f "$path"
    if ! grep -qEi "read-only agent|do not edit files|never edit files" "$path"; then
      printf 'missing read-only mandate: %s\n' "$path" >&2
      return 1
    fi
  done
}
