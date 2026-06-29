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
