#!/usr/bin/env bats

setup() {
  TMP_ROOT="$(mktemp -d)"
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/release.py"
  PLUGIN_ROOT="$TMP_ROOT/kramme-cc-workflow"
  mkdir -p "$PLUGIN_ROOT/.claude-plugin" "$PLUGIN_ROOT/scripts"
  cat >"$PLUGIN_ROOT/.claude-plugin/plugin.json" <<'EOF'
{
  "name": "kramme-cc-workflow",
  "version": "0.64.0"
}
EOF
  cat >"$PLUGIN_ROOT/package.json" <<'EOF'
{
  "name": "kramme-cc-workflow",
  "version": "0.64.0"
}
EOF
  cat >"$PLUGIN_ROOT/CHANGELOG.md" <<'EOF'
# Changelog
EOF
  cp "$BATS_TEST_DIRNAME/../scripts/release.py" "$PLUGIN_ROOT/scripts/release.py"
  cp "$BATS_TEST_DIRNAME/../scripts/changelog.py" "$PLUGIN_ROOT/scripts/changelog.py"
  git -C "$TMP_ROOT" init >/dev/null
  git -C "$TMP_ROOT" config user.email "test@example.com"
  git -C "$TMP_ROOT" config user.name "Test User"
  git -C "$TMP_ROOT" add .
  git -C "$TMP_ROOT" commit -m "initial" >/dev/null
}

teardown() {
  rm -rf "$TMP_ROOT"
}

@test "release dry run accepts explicit semantic version" {
  run python3 "$PLUGIN_ROOT/scripts/release.py" 1.2.3 --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *"Release: 0.64.0 -> 1.2.3"* ]]
  [[ "$output" == *"Would update"* ]]
}

@test "release rejects unknown version selector without traceback" {
  run python3 "$PLUGIN_ROOT/scripts/release.py" banana --dry-run

  [ "$status" -eq 2 ]
  [[ "$output" == *"Invalid bump type: banana"* ]]
  [[ "$output" != *"Traceback"* ]]
}

@test "release checks dependencies before mutating files" {
  MOCK_BIN="$TMP_ROOT/bin"
  mkdir -p "$MOCK_BIN"
  cat >"$MOCK_BIN/make" <<'SH'
#!/bin/sh
if [ "$*" = "check-deps" ]; then
  echo "missing release dependency" >&2
  exit 42
fi

echo "unexpected make args: $*" >&2
exit 2
SH
  chmod +x "$MOCK_BIN/make"

  run env PATH="$MOCK_BIN:$PATH" python3 "$PLUGIN_ROOT/scripts/release.py" patch

  [ "$status" -eq 1 ]
  [[ "$output" == *"Release verification dependencies are missing. Aborting before changing files."* ]]
  grep -q '"version": "0.64.0"' "$PLUGIN_ROOT/.claude-plugin/plugin.json"
  grep -q '"version": "0.64.0"' "$PLUGIN_ROOT/package.json"
  ! grep -q '## \[0.64.1\]' "$PLUGIN_ROOT/CHANGELOG.md"
}

@test "release verifies generated files after mutation before branch commit" {
  MOCK_BIN="$TMP_ROOT/bin"
  RELEASE_MAKE_LOG="$TMP_ROOT/make.log"
  mkdir -p "$MOCK_BIN"
  cat >"$MOCK_BIN/make" <<'SH'
#!/bin/sh
set -e

current_branch="$(git rev-parse --abbrev-ref HEAD)"

if [ "$*" = "check-deps" ]; then
  printf 'check-deps branch=%s\n' "$current_branch" >>"$RELEASE_MAKE_LOG"
  exit 0
fi

if [ "$*" != "verify" ]; then
  echo "unexpected make args: $*" >&2
  exit 2
fi

printf 'verify branch=%s\n' "$current_branch" >>"$RELEASE_MAKE_LOG"

if [ "$current_branch" = "release/v0.64.1" ]; then
  echo "verification ran after release branch creation" >&2
  exit 3
fi
grep -q '"version": "0.64.1"' .claude-plugin/plugin.json
grep -q '"version": "0.64.1"' package.json
grep -q '## \[0.64.1\]' CHANGELOG.md
SH
  chmod +x "$MOCK_BIN/make"

  run env PATH="$MOCK_BIN:$PATH" RELEASE_MAKE_LOG="$RELEASE_MAKE_LOG" bash -c 'printf "y\n" | python3 "$1" patch' _ "$PLUGIN_ROOT/scripts/release.py"

  [ "$status" -eq 0 ]
  [[ "$output" == *"2. Generating changelog..."*"3. Running release verification..."*"4. Creating release branch..."* ]]
  grep -q '^check-deps branch=' "$RELEASE_MAKE_LOG"
  grep -q '^verify branch=' "$RELEASE_MAKE_LOG"
  ! grep -q '^verify branch=release/v0.64.1$' "$RELEASE_MAKE_LOG"
  [ "$(git -C "$TMP_ROOT" rev-parse --abbrev-ref HEAD)" = "release/v0.64.1" ]
  [ "$(git -C "$TMP_ROOT" log -1 --pretty=%s)" = "Release v0.64.1" ]
}

@test "release restores generated files when verification fails" {
  MOCK_BIN="$TMP_ROOT/bin"
  mkdir -p "$MOCK_BIN"
  cat >"$MOCK_BIN/make" <<'SH'
#!/bin/sh
set -e

if [ "$*" = "check-deps" ]; then
  exit 0
fi

if [ "$*" != "verify" ]; then
  echo "unexpected make args: $*" >&2
  exit 2
fi

grep -q '"version": "0.64.1"' .claude-plugin/plugin.json
grep -q '"version": "0.64.1"' package.json
grep -q '## \[0.64.1\]' CHANGELOG.md
exit 9
SH
  chmod +x "$MOCK_BIN/make"

  run env PATH="$MOCK_BIN:$PATH" bash -c 'printf "y\n" | python3 "$1" patch' _ "$PLUGIN_ROOT/scripts/release.py"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Restored release files to their pre-release state."* ]]
  grep -q '"version": "0.64.0"' "$PLUGIN_ROOT/.claude-plugin/plugin.json"
  grep -q '"version": "0.64.0"' "$PLUGIN_ROOT/package.json"
  ! grep -q '## \[0.64.1\]' "$PLUGIN_ROOT/CHANGELOG.md"
  [ -z "$(git -C "$TMP_ROOT" branch --list release/v0.64.1)" ]
  git -C "$TMP_ROOT" diff --quiet
}

@test "release aborts and restores files when changelog history cannot be read" {
  rm -rf "$TMP_ROOT/.git"
  git -C "$TMP_ROOT" init >/dev/null
  git -C "$TMP_ROOT" config user.email "test@example.com"
  git -C "$TMP_ROOT" config user.name "Test User"
  MOCK_BIN="$TMP_ROOT/bin"
  mkdir -p "$MOCK_BIN"
  cat >"$MOCK_BIN/make" <<'SH'
#!/bin/sh
set -e

if [ "$*" = "check-deps" ]; then
  exit 0
fi

if [ "$*" != "verify" ]; then
  echo "unexpected make args: $*" >&2
  exit 2
fi

exit 0
SH
  chmod +x "$MOCK_BIN/make"

  run env PATH="$MOCK_BIN:$PATH" python3 "$PLUGIN_ROOT/scripts/release.py" patch --ci

  [ "$status" -eq 1 ]
  [[ "$output" == *"No commits found in repository history"* ]]
  [[ "$output" == *"Release changelog generation failed:"* ]]
  [[ "$output" == *"Aborting after restoring release files."* ]]
  grep -q '"version": "0.64.0"' "$PLUGIN_ROOT/.claude-plugin/plugin.json"
  grep -q '"version": "0.64.0"' "$PLUGIN_ROOT/package.json"
  ! grep -q '## \[0.64.1\]' "$PLUGIN_ROOT/CHANGELOG.md"
}

@test "release restores generated files when commit fails" {
  INITIAL_BRANCH="$(git -C "$TMP_ROOT" rev-parse --abbrev-ref HEAD)"
  MOCK_BIN="$TMP_ROOT/bin"
  mkdir -p "$MOCK_BIN"
  cat >"$MOCK_BIN/make" <<'SH'
#!/bin/sh
set -e

if [ "$*" = "check-deps" ]; then
  exit 0
fi

if [ "$*" != "verify" ]; then
  echo "unexpected make args: $*" >&2
  exit 2
fi

grep -q '"version": "0.64.1"' .claude-plugin/plugin.json
grep -q '"version": "0.64.1"' package.json
grep -q '## \[0.64.1\]' CHANGELOG.md
SH
  chmod +x "$MOCK_BIN/make"
  cat >"$TMP_ROOT/.git/hooks/pre-commit" <<'SH'
#!/bin/sh
echo "forced commit failure" >&2
exit 7
SH
  chmod +x "$TMP_ROOT/.git/hooks/pre-commit"

  run env PATH="$MOCK_BIN:$PATH" bash -c 'printf "y\n" | python3 "$1" patch' _ "$PLUGIN_ROOT/scripts/release.py"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Restored release files to their pre-release state."* ]]
  [[ "$output" == *"Release git step failed: git commit -m Release v0.64.1"* ]]
  grep -q '"version": "0.64.0"' "$PLUGIN_ROOT/.claude-plugin/plugin.json"
  grep -q '"version": "0.64.0"' "$PLUGIN_ROOT/package.json"
  ! grep -q '## \[0.64.1\]' "$PLUGIN_ROOT/CHANGELOG.md"
  [ "$(git -C "$TMP_ROOT" rev-parse --abbrev-ref HEAD)" = "$INITIAL_BRANCH" ]
  git -C "$TMP_ROOT" diff --quiet
  git -C "$TMP_ROOT" diff --cached --quiet
}

@test "release restores generated files when push fails" {
  INITIAL_BRANCH="$(git -C "$TMP_ROOT" rev-parse --abbrev-ref HEAD)"
  MOCK_BIN="$TMP_ROOT/bin"
  mkdir -p "$MOCK_BIN"
  cat >"$MOCK_BIN/make" <<'SH'
#!/bin/sh
set -e

if [ "$*" = "check-deps" ]; then
  exit 0
fi

if [ "$*" != "verify" ]; then
  echo "unexpected make args: $*" >&2
  exit 2
fi

grep -q '"version": "0.64.1"' .claude-plugin/plugin.json
grep -q '"version": "0.64.1"' package.json
grep -q '## \[0.64.1\]' CHANGELOG.md
SH
  chmod +x "$MOCK_BIN/make"

  run env PATH="$MOCK_BIN:$PATH" python3 "$PLUGIN_ROOT/scripts/release.py" patch --ci

  [ "$status" -eq 1 ]
  [[ "$output" == *"Restored release files to their pre-release state."* ]]
  [[ "$output" == *"Release git step failed: git push origin release/v0.64.1"* ]]
  grep -q '"version": "0.64.0"' "$PLUGIN_ROOT/.claude-plugin/plugin.json"
  grep -q '"version": "0.64.0"' "$PLUGIN_ROOT/package.json"
  ! grep -q '## \[0.64.1\]' "$PLUGIN_ROOT/CHANGELOG.md"
  [ "$(git -C "$TMP_ROOT" rev-parse --abbrev-ref HEAD)" = "$INITIAL_BRANCH" ]
  git -C "$TMP_ROOT" diff --quiet
  git -C "$TMP_ROOT" diff --cached --quiet
}
