#!/usr/bin/env bats

setup() {
  export RELEASE_REAL_GIT="$(command -v git)"
  export RELEASE_PRETTIER="$BATS_TEST_DIRNAME/../../node_modules/.bin/prettier"
  export RELEASE_TEST_PATH="$PATH"
  TMP_ROOT="$(cd "$(mktemp -d)" && pwd -P)"
  # Fixtures must behave the same under a contributor's inherited signing settings, so
  # every Git command here reads an isolated global config that demands a signer that
  # does not exist. Only the fixture repository's own config keeps signing off.
  export GIT_CONFIG_GLOBAL="$TMP_ROOT/gitconfig-global"
  export GIT_CONFIG_SYSTEM="$TMP_ROOT/gitconfig-system"
  cat >"$GIT_CONFIG_GLOBAL" <<EOF
[commit]
	gpgsign = true
[tag]
	gpgsign = true
[gpg]
	program = $TMP_ROOT/missing-signer
EOF
  : >"$GIT_CONFIG_SYSTEM"
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
  init_release_fixture_repo
  git -C "$TMP_ROOT" add .
  git -C "$TMP_ROOT" commit -m "initial" >/dev/null
}

teardown() {
  rm -rf "$TMP_ROOT"
}

# Mirrors init_test_git_repo in tests/test_helper/common.bash: repository-local identity
# with commit and tag signing off, so fixtures never depend on the contributor's global
# Git configuration. Kept local because that helper commits its own tracked.txt as the
# initial commit and renames the branch, while these fixtures init in place over files
# already written and commit that set themselves.
init_release_fixture_repo() {
  git -C "$TMP_ROOT" init >/dev/null
  git -C "$TMP_ROOT" config user.email "test@example.com"
  git -C "$TMP_ROOT" config user.name "Test User"
  git -C "$TMP_ROOT" config commit.gpgsign false
  git -C "$TMP_ROOT" config tag.gpgsign false
}

# Create a disposable bare remote holding the fixture's initial commit on main.
init_release_fixture_origin() {
  ORIGIN="$TMP_ROOT/origin.git"
  git init --bare "$ORIGIN" >/dev/null
  git -C "$TMP_ROOT" remote add origin "$ORIGIN"
  git -C "$TMP_ROOT" push -q origin HEAD:refs/heads/main
}

# Record every push the release attempts, optionally rejecting it, so tests can assert
# which remote writes were even tried rather than only their final effect.
install_release_push_logging_git() {
  MOCK_BIN="$TMP_ROOT/bin"
  mkdir -p "$MOCK_BIN"
  # Exported like RELEASE_REAL_GIT: the mock reads it from its own environment, so a
  # caller that forgot to thread it through would log nowhere and still assert clean.
  export RELEASE_PUSH_LOG="$TMP_ROOT/push.log"
  : >"$RELEASE_PUSH_LOG"
  cat >"$MOCK_BIN/git" <<'SH'
#!/bin/sh
if [ "$1" = "push" ]; then
  printf '%s\n' "$*" >>"$RELEASE_PUSH_LOG"
  if [ -n "$RELEASE_PUSH_FAILS" ]; then
    echo "simulated push rejection" >&2
    exit 77
  fi
fi
exec "$RELEASE_REAL_GIT" "$@"
SH
  chmod +x "$MOCK_BIN/git"
}

install_release_make_mock() {
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
"$RELEASE_PRETTIER" --check CHANGELOG.md >/dev/null
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
  init_release_fixture_repo
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

@test "release restores detached checkout when push fails" {
  INITIAL_HEAD="$(git -C "$TMP_ROOT" rev-parse HEAD)"
  git -C "$TMP_ROOT" checkout --detach "$INITIAL_HEAD" >/dev/null 2>&1
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
  [ "$(git -C "$TMP_ROOT" rev-parse --abbrev-ref HEAD)" = "HEAD" ]
  [ "$(git -C "$TMP_ROOT" rev-parse HEAD)" = "$INITIAL_HEAD" ]
  git -C "$TMP_ROOT" diff --quiet
  git -C "$TMP_ROOT" diff --cached --quiet
}

@test "release rollback preserves pre-existing staged and working file states" {
  install_release_make_mock
  printf 'tracked\n' >"$TMP_ROOT/unrelated.txt"
  git -C "$TMP_ROOT" add unrelated.txt
  git -C "$TMP_ROOT" commit -m "add unrelated file" >/dev/null
  git -C "$TMP_ROOT" update-index --skip-worktree unrelated.txt
  printf 'intent to add\n' >"$TMP_ROOT/intent.txt"
  git -C "$TMP_ROOT" add -N intent.txt
  printf '# Changelog\nstaged state\n' >"$PLUGIN_ROOT/CHANGELOG.md"
  git -C "$TMP_ROOT" add kramme-cc-workflow/CHANGELOG.md
  printf '# Changelog\nworking state\n' >"$PLUGIN_ROOT/CHANGELOG.md"
  chmod 664 "$TMP_ROOT/.git/index"
  cp "$TMP_ROOT/.git/index" "$TMP_ROOT/index.before"
  INDEX_MODE_BEFORE="$(python3 -c 'import os, sys; print(os.stat(sys.argv[1]).st_mode & 0o777)' "$TMP_ROOT/.git/index")"

  run env PATH="$MOCK_BIN:$RELEASE_TEST_PATH" python3 "$PLUGIN_ROOT/scripts/release.py" patch --ci

  [ "$status" -eq 1 ]
  [[ "$output" == *"Restored release files to their pre-release state."* ]]
  [ "$(git hash-object "$TMP_ROOT/index.before")" = "$(git hash-object "$TMP_ROOT/.git/index")" ]
  [ "$(python3 -c 'import os, sys; print(os.stat(sys.argv[1]).st_mode & 0o777)' "$TMP_ROOT/.git/index")" = "$INDEX_MODE_BEFORE" ]
  grep -q '^working state$' "$PLUGIN_ROOT/CHANGELOG.md"
  git -C "$TMP_ROOT" show :kramme-cc-workflow/CHANGELOG.md | grep -q '^staged state$'
}

@test "release rollback retries transient reset and branch checkout failures" {
  INITIAL_BRANCH="$(git -C "$TMP_ROOT" rev-parse --abbrev-ref HEAD)"
  install_release_make_mock
  RELEASE_GIT_LOG="$TMP_ROOT/git.log"
  cat >"$MOCK_BIN/git" <<'SH'
#!/bin/sh
set -e

if [ "$1" = "reset" ] && [ "$2" = "--mixed" ]; then
  echo reset >>"$RELEASE_GIT_LOG"
  if [ ! -e "$RELEASE_RESET_FAILED" ]; then
    : >"$RELEASE_RESET_FAILED"
    exit 71
  fi
fi
if [ "$1" = "checkout" ] && [ "$2" = "$RELEASE_START_BRANCH" ]; then
  echo checkout >>"$RELEASE_GIT_LOG"
  if [ ! -e "$RELEASE_CHECKOUT_FAILED" ]; then
    : >"$RELEASE_CHECKOUT_FAILED"
    exit 72
  fi
fi
exec "$RELEASE_REAL_GIT" "$@"
SH
  chmod +x "$MOCK_BIN/git"

  run env PATH="$MOCK_BIN:$RELEASE_TEST_PATH" \
    RELEASE_GIT_LOG="$RELEASE_GIT_LOG" \
    RELEASE_RESET_FAILED="$TMP_ROOT/reset-failed" \
    RELEASE_CHECKOUT_FAILED="$TMP_ROOT/checkout-failed" \
    RELEASE_START_BRANCH="$INITIAL_BRANCH" \
    python3 "$PLUGIN_ROOT/scripts/release.py" patch --ci

  [ "$status" -eq 1 ]
  [[ "$output" == *"Restored release files to their pre-release state."* ]]
  [ "$(grep -c '^reset$' "$RELEASE_GIT_LOG")" -eq 2 ]
  [ "$(grep -c '^checkout$' "$RELEASE_GIT_LOG")" -eq 2 ]
  [ "$(git -C "$TMP_ROOT" rev-parse --abbrev-ref HEAD)" = "$INITIAL_BRANCH" ]
}

@test "release reports incomplete rollback when branch checkout retries fail" {
  INITIAL_BRANCH="$(git -C "$TMP_ROOT" rev-parse --abbrev-ref HEAD)"
  install_release_make_mock
  cat >"$MOCK_BIN/git" <<'SH'
#!/bin/sh
if [ "$1" = "checkout" ] && [ "$2" = "$RELEASE_START_BRANCH" ]; then
  exit 73
fi
exec "$RELEASE_REAL_GIT" "$@"
SH
  chmod +x "$MOCK_BIN/git"

  run env PATH="$MOCK_BIN:$RELEASE_TEST_PATH" \
    RELEASE_START_BRANCH="$INITIAL_BRANCH" \
    python3 "$PLUGIN_ROOT/scripts/release.py" patch --ci

  [ "$status" -eq 2 ]
  [[ "$output" == *"Automatic rollback was incomplete."* ]]
  [[ "$output" == *"git -C $TMP_ROOT checkout $INITIAL_BRANCH"* ]]
  [[ "$output" == *"Aborting with incomplete rollback."* ]]
  [[ "$output" != *"Restored release files to their pre-release state."* ]]
}

@test "release reports incomplete rollback when reset retries fail" {
  install_release_make_mock
  cat >"$MOCK_BIN/git" <<'SH'
#!/bin/sh
if [ "$1" = "reset" ] && [ "$2" = "--mixed" ]; then
  exit 75
fi
exec "$RELEASE_REAL_GIT" "$@"
SH
  chmod +x "$MOCK_BIN/git"

  run env PATH="$MOCK_BIN:$RELEASE_TEST_PATH" python3 "$PLUGIN_ROOT/scripts/release.py" patch --ci

  [ "$status" -eq 2 ]
  [[ "$output" == *"Automatic rollback was incomplete."* ]]
  [[ "$output" == *"git -C $TMP_ROOT reset --mixed"* ]]
  [[ "$output" != *"Restored release files to their pre-release state."* ]]
}

@test "release reports incomplete rollback when detached checkout retries fail" {
  INITIAL_HEAD="$(git -C "$TMP_ROOT" rev-parse HEAD)"
  git -C "$TMP_ROOT" checkout --detach "$INITIAL_HEAD" >/dev/null 2>&1
  install_release_make_mock
  cat >"$MOCK_BIN/git" <<'SH'
#!/bin/sh
if [ "$1" = "checkout" ] && [ "$2" = "--detach" ]; then
  exit 74
fi
exec "$RELEASE_REAL_GIT" "$@"
SH
  chmod +x "$MOCK_BIN/git"

  run env PATH="$MOCK_BIN:$RELEASE_TEST_PATH" python3 "$PLUGIN_ROOT/scripts/release.py" patch --ci

  [ "$status" -eq 2 ]
  [[ "$output" == *"git -C $TMP_ROOT checkout --detach $INITIAL_HEAD"* ]]
  [[ "$output" != *"Restored release files to their pre-release state."* ]]
}

@test "release reports incomplete rollback when the index cannot be restored" {
  install_release_make_mock
  PHYSICAL_TMPDIR="$TMP_ROOT/recovery-temp"
  SYMLINKED_TMPDIR="$TMP_ROOT/recovery-temp-link"
  mkdir -p "$PHYSICAL_TMPDIR"
  ln -s "$PHYSICAL_TMPDIR" "$SYMLINKED_TMPDIR"
  cp "$TMP_ROOT/.git/index" "$TMP_ROOT/index.before"
  cat >"$MOCK_BIN/git" <<'SH'
#!/bin/sh
if [ "$1" = "push" ] && [ "$3" = "release/v0.64.1" ]; then
  rm -f "$RELEASE_GIT_DIR/index"
  mkdir "$RELEASE_GIT_DIR/index"
  exit 76
fi
exec "$RELEASE_REAL_GIT" "$@"
SH
  chmod +x "$MOCK_BIN/git"

  run env PATH="$MOCK_BIN:$RELEASE_TEST_PATH" \
    RELEASE_GIT_DIR="$TMP_ROOT/.git" \
    TMPDIR="$SYMLINKED_TMPDIR" \
    python3 "$PLUGIN_ROOT/scripts/release.py" patch --ci

  [ "$status" -eq 2 ]
  [[ "$output" == *"Automatic rollback was incomplete."* ]]
  [[ "$output" == *"$TMP_ROOT/.git/index"* ]]
  [[ "$output" == *"cp -- $PHYSICAL_TMPDIR/release-recovery-"* ]]
  [[ "$output" != *"$SYMLINKED_TMPDIR/release-recovery-"* ]]
  [[ "$output" != *"Restored release files to their pre-release state."* ]]

  recovery_commands="$(printf '%s\n' "$output" | sed -n '/^    /s/^    //p')"
  while IFS= read -r recovery_command; do
    eval "$recovery_command"
  done <<<"$recovery_commands"

  [ -f "$TMP_ROOT/.git/index" ]
  [ "$(git hash-object "$TMP_ROOT/index.before")" = "$(git hash-object "$TMP_ROOT/.git/index")" ]
}

@test "release refuses to replace an existing local release branch" {
  INITIAL_BRANCH="$(git -C "$TMP_ROOT" rev-parse --abbrev-ref HEAD)"
  git -C "$TMP_ROOT" branch release/v0.64.1
  BRANCH_OID_BEFORE="$(git -C "$TMP_ROOT" rev-parse release/v0.64.1)"
  cp "$TMP_ROOT/.git/index" "$TMP_ROOT/index.before"

  # No make mock is installed, so reaching the dependency check would fail differently.
  run python3 "$PLUGIN_ROOT/scripts/release.py" patch --ci

  [ "$status" -eq 1 ]
  [[ "$output" == *"local branch release/v0.64.1 already exists"* ]]
  [[ "$output" == *"No file, branch, or remote ref was changed."* ]]
  [ "$(git -C "$TMP_ROOT" rev-parse release/v0.64.1)" = "$BRANCH_OID_BEFORE" ]
  [ "$(git -C "$TMP_ROOT" rev-parse --abbrev-ref HEAD)" = "$INITIAL_BRANCH" ]
  [ "$(git hash-object "$TMP_ROOT/index.before")" = "$(git hash-object "$TMP_ROOT/.git/index")" ]
  grep -q '"version": "0.64.0"' "$PLUGIN_ROOT/.claude-plugin/plugin.json"
  grep -q '"version": "0.64.0"' "$PLUGIN_ROOT/package.json"
  ! grep -q '## \[0.64.1\]' "$PLUGIN_ROOT/CHANGELOG.md"
}

@test "release refuses to replace an existing remote release branch" {
  init_release_fixture_origin
  git -C "$TMP_ROOT" push -q origin HEAD:refs/heads/release/v0.64.1
  REMOTE_OID_BEFORE="$(git -C "$ORIGIN" rev-parse refs/heads/release/v0.64.1)"

  run python3 "$PLUGIN_ROOT/scripts/release.py" patch --ci

  [ "$status" -eq 1 ]
  [[ "$output" == *"remote branch origin/release/v0.64.1 already exists"* ]]
  [[ "$output" == *"No file, branch, or remote ref was changed."* ]]
  [ "$(git -C "$ORIGIN" rev-parse refs/heads/release/v0.64.1)" = "$REMOTE_OID_BEFORE" ]
  [ -z "$(git -C "$TMP_ROOT" branch --list release/v0.64.1)" ]
  grep -q '"version": "0.64.0"' "$PLUGIN_ROOT/.claude-plugin/plugin.json"
  ! grep -q '## \[0.64.1\]' "$PLUGIN_ROOT/CHANGELOG.md"
}

@test "release refuses unrelated staged content and leaves the index untouched" {
  printf 'unrelated staged\n' >"$TMP_ROOT/unrelated.txt"
  git -C "$TMP_ROOT" add unrelated.txt
  STAGED_BLOB_BEFORE="$(git -C "$TMP_ROOT" rev-parse :unrelated.txt)"
  cp "$TMP_ROOT/.git/index" "$TMP_ROOT/index.before"

  run python3 "$PLUGIN_ROOT/scripts/release.py" patch --ci

  [ "$status" -eq 1 ]
  [[ "$output" == *"unrelated staged changes would enter the release commit: unrelated.txt"* ]]
  [[ "$output" == *"No file, branch, or remote ref was changed."* ]]
  [ "$(git hash-object "$TMP_ROOT/index.before")" = "$(git hash-object "$TMP_ROOT/.git/index")" ]
  [ "$(git -C "$TMP_ROOT" rev-parse :unrelated.txt)" = "$STAGED_BLOB_BEFORE" ]
  [ -z "$(git -C "$TMP_ROOT" branch --list release/v0.64.1)" ]
  grep -q '"version": "0.64.0"' "$PLUGIN_ROOT/.claude-plugin/plugin.json"
  ! grep -q '## \[0.64.1\]' "$PLUGIN_ROOT/CHANGELOG.md"
}

@test "local release preparation writes no remote refs and leaves the installer version alone" {
  install_release_make_mock
  init_release_fixture_origin
  install_release_push_logging_git
  printf '{\n  "name": "installer",\n  "version": "9.9.9"\n}\n' >"$TMP_ROOT/package.json"
  git -C "$ORIGIN" show-ref >"$TMP_ROOT/origin-refs.before"

  run env PATH="$MOCK_BIN:$RELEASE_TEST_PATH" \
    bash -c 'printf "y\n" | python3 "$1" patch' _ "$PLUGIN_ROOT/scripts/release.py"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Created branch release/v0.64.1"* ]]
  [[ "$output" == *"Run: git push origin release/v0.64.1"* ]]
  [ ! -s "$RELEASE_PUSH_LOG" ]
  git -C "$ORIGIN" show-ref >"$TMP_ROOT/origin-refs.after"
  diff "$TMP_ROOT/origin-refs.before" "$TMP_ROOT/origin-refs.after"
  [ "$(git -C "$TMP_ROOT" rev-parse --abbrev-ref HEAD)" = "release/v0.64.1" ]
  [ "$(git -C "$TMP_ROOT" log -1 --pretty=%s)" = "Release v0.64.1" ]
  grep -q '"version": "0.64.1"' "$PLUGIN_ROOT/.claude-plugin/plugin.json"
  grep -q '"version": "9.9.9"' "$TMP_ROOT/package.json"
}

@test "failed CI push leaves every existing remote ref at its original OID" {
  install_release_make_mock
  init_release_fixture_origin
  install_release_push_logging_git
  git -C "$ORIGIN" show-ref >"$TMP_ROOT/origin-refs.before"

  run env PATH="$MOCK_BIN:$RELEASE_TEST_PATH" RELEASE_PUSH_FAILS=1 \
    python3 "$PLUGIN_ROOT/scripts/release.py" patch --ci

  [ "$status" -eq 1 ]
  [[ "$output" == *"Release git step failed: git push origin release/v0.64.1"* ]]
  [[ "$output" == *"Restored release files to their pre-release state."* ]]
  [ "$(cat "$RELEASE_PUSH_LOG")" = "push origin release/v0.64.1" ]
  git -C "$ORIGIN" show-ref >"$TMP_ROOT/origin-refs.after"
  diff "$TMP_ROOT/origin-refs.before" "$TMP_ROOT/origin-refs.after"
  grep -q '"version": "0.64.0"' "$PLUGIN_ROOT/.claude-plugin/plugin.json"
  ! grep -q '## \[0.64.1\]' "$PLUGIN_ROOT/CHANGELOG.md"

  # The attempt created a branch it must not delete, so it has to name it.
  [ -n "$(git -C "$TMP_ROOT" branch --list release/v0.64.1)" ]
  [[ "$output" == *"Left local branch release/v0.64.1 in place"* ]]
  [[ "$output" == *"git branch -D release/v0.64.1"* ]]

  # Retrying without that cleanup refuses on the leftover instead of replacing it.
  LEFTOVER_OID="$(git -C "$TMP_ROOT" rev-parse release/v0.64.1)"
  run env PATH="$MOCK_BIN:$RELEASE_TEST_PATH" RELEASE_PUSH_FAILS=1 \
    python3 "$PLUGIN_ROOT/scripts/release.py" patch --ci

  [ "$status" -eq 1 ]
  [[ "$output" == *"local branch release/v0.64.1 already exists"* ]]
  [ "$(git -C "$TMP_ROOT" rev-parse release/v0.64.1)" = "$LEFTOVER_OID" ]
  [ "$(cat "$RELEASE_PUSH_LOG")" = "push origin release/v0.64.1" ]
}

@test "release fixtures keep signing local when the inherited signer is unavailable" {
  [ "$(git config --global --get commit.gpgsign)" = "true" ]
  [ "$(git config --global --get tag.gpgsign)" = "true" ]
  [ ! -e "$(git config --global --get gpg.program)" ]
  [ "$(git -C "$TMP_ROOT" config --get commit.gpgsign)" = "false" ]
  [ "$(git -C "$TMP_ROOT" config --get tag.gpgsign)" = "false" ]
  install_release_make_mock

  run env PATH="$MOCK_BIN:$RELEASE_TEST_PATH" bash -c 'printf "y\n" | python3 "$1" patch' _ "$PLUGIN_ROOT/scripts/release.py"

  [ "$status" -eq 0 ]
  [ "$(git -C "$TMP_ROOT" log -1 --pretty=%s)" = "Release v0.64.1" ]
  [ "$(git -C "$TMP_ROOT" log -1 --pretty='%G?')" = "N" ]
}

@test "release refuses when origin cannot be inspected" {
  git -C "$TMP_ROOT" remote add origin "$TMP_ROOT/nonexistent.git"
  cp "$TMP_ROOT/.git/index" "$TMP_ROOT/index.before"

  run python3 "$PLUGIN_ROOT/scripts/release.py" patch --ci

  [ "$status" -eq 1 ]
  [[ "$output" == *"could not inspect origin/release/v0.64.1"* ]]
  [[ "$output" == *"No file, branch, or remote ref was changed."* ]]
  [ "$(git hash-object "$TMP_ROOT/index.before")" = "$(git hash-object "$TMP_ROOT/.git/index")" ]
  [ -z "$(git -C "$TMP_ROOT" branch --list release/v0.64.1)" ]
  grep -q '"version": "0.64.0"' "$PLUGIN_ROOT/.claude-plugin/plugin.json"
  ! grep -q '## \[0.64.1\]' "$PLUGIN_ROOT/CHANGELOG.md"
}

@test "release refuses work staged during verification and keeps it staged" {
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
# Stand in for a contributor staging unrelated work while verification runs.
printf 'staged during verify\n' >"$RELEASE_RACE_ROOT/unrelated.txt"
git -C "$RELEASE_RACE_ROOT" add unrelated.txt
SH
  chmod +x "$MOCK_BIN/make"

  run env PATH="$MOCK_BIN:$RELEASE_TEST_PATH" RELEASE_RACE_ROOT="$TMP_ROOT" \
    python3 "$PLUGIN_ROOT/scripts/release.py" patch --ci

  [ "$status" -eq 1 ]
  [[ "$output" == *"unrelated staged changes would enter the release commit: unrelated.txt"* ]]
  [[ "$output" == *"Aborting after restoring release files."* ]]
  # The refusal must not discard the staging it refused for.
  [ "$(git -C "$TMP_ROOT" rev-parse :unrelated.txt)" = "$(git hash-object "$TMP_ROOT/unrelated.txt")" ]
  [ -z "$(git -C "$TMP_ROOT" branch --list release/v0.64.1)" ]
  grep -q '"version": "0.64.0"' "$PLUGIN_ROOT/.claude-plugin/plugin.json"
  ! grep -q '## \[0.64.1\]' "$PLUGIN_ROOT/CHANGELOG.md"
}

@test "release ignores a rename Git detects in the working tree" {
  install_release_make_mock
  printf 'aaaa\nbbbb\ncccc\ndddd\neeee\n' >"$TMP_ROOT/rename-source.txt"
  git -C "$TMP_ROOT" add rename-source.txt
  git -C "$TMP_ROOT" commit -m "add rename source" >/dev/null
  mv "$TMP_ROOT/rename-source.txt" "$TMP_ROOT/rename-target.txt"
  git -C "$TMP_ROOT" add -N rename-target.txt
  # Git reports this in the worktree column, which stages nothing.
  [[ "$(git -C "$TMP_ROOT" status --porcelain -- rename-source.txt rename-target.txt)" == " R "* ]]

  run env PATH="$MOCK_BIN:$RELEASE_TEST_PATH" bash -c 'printf "y\n" | python3 "$1" patch' _ "$PLUGIN_ROOT/scripts/release.py"

  [ "$status" -eq 0 ]
  [[ "$output" != *"Release preflight refused"* ]]
  [ "$(git -C "$TMP_ROOT" rev-parse --abbrev-ref HEAD)" = "release/v0.64.1" ]
  [ "$(git -C "$TMP_ROOT" log -1 --pretty=%s)" = "Release v0.64.1" ]
}

@test "the branch re-check does not re-inspect the remote" {
  init_release_fixture_origin
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
# Break the remote after the first preflight has already inspected it.
git -C "$RELEASE_RACE_ROOT" remote set-url origin "$RELEASE_RACE_ROOT/nonexistent.git"
SH
  chmod +x "$MOCK_BIN/make"

  run env PATH="$MOCK_BIN:$RELEASE_TEST_PATH" RELEASE_RACE_ROOT="$TMP_ROOT" \
    bash -c 'printf "y\n" | python3 "$1" patch' _ "$PLUGIN_ROOT/scripts/release.py"

  [ "$status" -eq 0 ]
  [[ "$output" != *"could not inspect origin"* ]]
  [ "$(git -C "$TMP_ROOT" rev-parse --abbrev-ref HEAD)" = "release/v0.64.1" ]
  [ "$(git -C "$TMP_ROOT" log -1 --pretty=%s)" = "Release v0.64.1" ]
}

@test "release commits content staged in its own files" {
  install_release_make_mock
  printf '# Changelog\nstaged release note\n' >"$PLUGIN_ROOT/CHANGELOG.md"
  git -C "$TMP_ROOT" add kramme-cc-workflow/CHANGELOG.md

  run env PATH="$MOCK_BIN:$RELEASE_TEST_PATH" bash -c 'printf "y\n" | python3 "$1" patch' _ "$PLUGIN_ROOT/scripts/release.py"

  [ "$status" -eq 0 ]
  [[ "$output" != *"Release preflight refused"* ]]
  # Documented in RELEASE.md: release-owned files are rewritten from disk and committed,
  # so staging them is not the "unrelated staged content" the preflight refuses.
  git -C "$TMP_ROOT" show HEAD:kramme-cc-workflow/CHANGELOG.md | grep -q 'staged release note'
  [ "$(git -C "$TMP_ROOT" show --name-only --pretty=format: HEAD | sed '/^$/d' | sort | tr '\n' ' ')" \
    = "kramme-cc-workflow/.claude-plugin/plugin.json kramme-cc-workflow/CHANGELOG.md kramme-cc-workflow/package.json " ]
}

@test "an incomplete refusal rollback names the files it could not restore" {
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
# Trigger the re-check, then make one release file impossible to restore.
printf 'staged during verify\n' >"$RELEASE_RACE_ROOT/unrelated.txt"
git -C "$RELEASE_RACE_ROOT" add unrelated.txt
chmod 444 CHANGELOG.md
SH
  chmod +x "$MOCK_BIN/make"

  run env PATH="$MOCK_BIN:$RELEASE_TEST_PATH" RELEASE_RACE_ROOT="$TMP_ROOT" \
    python3 "$PLUGIN_ROOT/scripts/release.py" patch --ci

  [ "$status" -eq 2 ]
  [[ "$output" == *"Still holding this release's content: $PLUGIN_ROOT/CHANGELOG.md"* ]]
  [[ "$output" == *"Restore those files yourself; your index was not touched."* ]]
  [[ "$output" == *"Aborting with incomplete rollback."* ]]
  # No manual-recovery block: it would tell the operator to overwrite the index.
  [[ "$output" != *"Automatic rollback was incomplete."* ]]
  # The staged work that caused the refusal is still staged.
  [ "$(git -C "$TMP_ROOT" rev-parse :unrelated.txt)" = "$(git hash-object "$TMP_ROOT/unrelated.txt")" ]
  [ -z "$(git -C "$TMP_ROOT" branch --list release/v0.64.1)" ]
  chmod 644 "$PLUGIN_ROOT/CHANGELOG.md"
}

@test "release workflow isolates SkillSpector from verification dependencies" {
  WORKFLOW="$BATS_TEST_DIRNAME/../../.github/workflows/release.yml"
  workflow_step() {
    local name="$1"
    sed -n "/^      - name: $name\$/,/^      - name: /p" "$WORKFLOW" | sed '$d'
  }

  verification_install="$(workflow_step "Install release verification dependencies")"
  scanner_install="$(workflow_step "Install isolated SkillSpector")"
  dependency_check="$(workflow_step "Check release verification dependencies")"
  dry_run_verification="$(workflow_step "Run dry-run release verification")"
  scanner_run="$(workflow_step "Run SkillSpector release scan")"

  [ -n "$verification_install" ]
  [ -n "$scanner_install" ]
  [ -n "$dependency_check" ]
  [ -n "$dry_run_verification" ]
  [ -n "$scanner_run" ]
  [[ "$verification_install" != *"SkillSpector.git"* ]]
  [[ "$scanner_install" == *'python3 -m venv "$RUNNER_TEMP/skillspector-venv"'* ]]
  [[ "$scanner_install" == *'"$RUNNER_TEMP/skillspector-venv/bin/python" -m pip install'* ]]
  [[ "$scanner_install" == *'ln -s "$RUNNER_TEMP/skillspector-venv/bin/skillspector" "$RUNNER_TEMP/skillspector-bin/skillspector"'* ]]
  [[ "$scanner_install" != *"GITHUB_PATH"* ]]
  [[ "$dependency_check" == *'PATH="$RUNNER_TEMP/skillspector-bin:$PATH"'* ]]
  [[ "$dry_run_verification" == *'PATH="$RUNNER_TEMP/skillspector-bin:$PATH"'* ]]
  [[ "$scanner_run" == *'PATH="$RUNNER_TEMP/skillspector-bin:$PATH"'* ]]
}
