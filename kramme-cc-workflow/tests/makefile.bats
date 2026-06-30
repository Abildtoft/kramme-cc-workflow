#!/usr/bin/env bats

create_fake_tool() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat >"$path" <<'SH'
#!/bin/sh
exit 0
SH
  chmod +x "$path"
}

setup_check_deps_repo() {
  CHECK_DEPS_REPO="$BATS_TEST_TMPDIR/repo"
  CHECK_DEPS_BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p \
    "$CHECK_DEPS_REPO/kramme-cc-workflow/skills/kramme:test" \
    "$CHECK_DEPS_REPO/node_modules/.bin" \
    "$CHECK_DEPS_BIN"
  cp "$BATS_TEST_DIRNAME/../Makefile" "$CHECK_DEPS_REPO/kramme-cc-workflow/Makefile"

  for tool in python3 shellcheck ruff bats jq node npm; do
    create_fake_tool "$CHECK_DEPS_BIN/$tool"
  done
  create_fake_tool "$CHECK_DEPS_REPO/node_modules/.bin/prettier"

  cat >"$CHECK_DEPS_REPO/kramme-cc-workflow/skills/kramme:test/SKILL.md" <<'MD'
---
name: kramme:test
description: Test skill
---
MD

  git -C "$CHECK_DEPS_REPO" init >/dev/null
  git -C "$CHECK_DEPS_REPO" config user.email "test@example.com"
  git -C "$CHECK_DEPS_REPO" config user.name "Test User"
  git -C "$CHECK_DEPS_REPO" add .
  git -C "$CHECK_DEPS_REPO" commit -m "initial" >/dev/null
  git -C "$CHECK_DEPS_REPO" branch -M main
  git -C "$CHECK_DEPS_REPO" switch -c feature >/dev/null
}

@test "format dependency check accepts PRETTIER command from PATH" {
  BIN_DIR="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$BIN_DIR"
  create_fake_tool "$BIN_DIR/prettier"

  run env PATH="$BIN_DIR:$PATH" make -C "$BATS_TEST_DIRNAME/.." --no-print-directory check-format-deps PRETTIER=prettier

  [ "$status" -eq 0 ]
}

@test "check-deps does not require skillspector without changed skill directories" {
  setup_check_deps_repo

  run env PATH="$CHECK_DEPS_BIN:/usr/bin:/bin" make -C "$CHECK_DEPS_REPO/kramme-cc-workflow" --no-print-directory check-deps SKILLSPECTOR_BASE=main

  [ "$status" -eq 0 ]
  [[ "$output" == *"All verification dependencies installed."* ]]
}

@test "check-deps requires skillspector when a skill directory changed" {
  setup_check_deps_repo
  printf '\nChanged.\n' >>"$CHECK_DEPS_REPO/kramme-cc-workflow/skills/kramme:test/SKILL.md"

  run env PATH="$CHECK_DEPS_BIN:/usr/bin:/bin" make -C "$CHECK_DEPS_REPO/kramme-cc-workflow" --no-print-directory check-deps SKILLSPECTOR_BASE=main

  [ "$status" -eq 2 ]
  [[ "$output" == *"skillspector not found. Install SkillSpector before running skill-security or verify."* ]]
}
