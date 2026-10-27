#!/usr/bin/env bats

load 'test_helper/common'

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TMP_DIR="$(mktemp -d)"
  SKILL_COPY="$TMP_DIR/skill"
  cp -R "$REPO_DIR/skills/kramme:verify:run" "$SKILL_COPY"
  HELPER="$SKILL_COPY/scripts/discovery-cache.sh"
  TREE_ID="$REPO_DIR/scripts/worktree-tree-id.sh"
  WORK="$TMP_DIR/work"
  init_test_git_repo "$WORK"
  cd "$WORK"
  printf '# Agents\n\nRun `npm run lint` and `npm test`.\n' > AGENTS.md
  printf '{"name":"fixture"}\n' > package.json
  mkdir -p src
  printf 'console.log(1);\n' > src/app.js
  git add --all
  git commit -m "Add discovery inputs" > /dev/null
}

teardown() {
  if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR"
  fi
}

ignore_cache_dir() {
  printf '.context/\n' >> .git/info/exclude
}

current_key() {
  "$HELPER" key | jq -r .key
}

# Usage: write_record <path> <key> [jq-filter]
write_record() {
  jq -n --arg key "$2" '{
    version: 1,
    key: $key,
    created: "2026-10-26T00:00:00Z",
    project_type: "node",
    tiers: {fast: {source: null}, full: {source: null}},
    base_branch: null,
    checks: [
      {category: "linting", command: "npm run lint", cwd: ".", tiers: ["fast", "full"],
       base_scoped: false, side_effecting: false, source: "AGENTS.md:3"},
      {category: "unit", command: "npm test", cwd: ".", tiers: ["fast", "full"],
       base_scoped: false, side_effecting: false, source: "AGENTS.md:3"}
    ],
    skipped: ["No E2E suite found"]
  } | '"${3:-.}" > "$1"
}

@test "key is stable and changes with each root discovery input class" {
  local first second
  first="$(current_key)"
  second="$(current_key)"
  [[ "$first" =~ ^[0-9a-f]{40}$ ]]
  [ "$first" = "$second" ]

  printf 'Also run `npm run typecheck`.\n' >> AGENTS.md
  second="$(current_key)"
  [ "$second" != "$first" ]

  first="$second"
  mkdir -p .github/workflows
  printf 'on: push\n' > .github/workflows/ci.yml
  second="$(current_key)"
  [ "$second" != "$first" ]

  first="$second"
  printf '{"name":"fixture","scripts":{"test":"jest"}}\n' > package.json
  second="$(current_key)"
  [ "$second" != "$first" ]

  first="$second"
  mkdir -p apps/web
  printf '{}\n' > apps/web/project.json
  second="$(current_key)"
  [ "$second" != "$first" ]

  first="$second"
  printf '\n<!-- edited -->\n' >> "$SKILL_COPY/SKILL.md"
  second="$(current_key)"
  [ "$second" != "$first" ]
}

@test "key ignores files discovery does not read" {
  local before
  before="$(current_key)"

  printf 'console.log(2);\n' > src/app.js
  printf 'notes\n' > docs.md
  printf '{"changed":true}\n' > apps-project.json

  [ "$(current_key)" = "$before" ]
}

@test "cache is disabled and write refused when the cache directory is not ignored" {
  local key
  run "$HELPER" key
  [ "$status" -eq 0 ]
  [ "$(jq -r .enabled <<< "$output")" = false ]
  [[ "$(jq -r .reason <<< "$output")" == *".context/verify-run/ is not Git-ignored"* ]]

  key="$(current_key)"
  write_record "$TMP_DIR/record.json" "$key"
  run "$HELPER" write "$key" "$TMP_DIR/record.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cache disabled"* ]]
  [ ! -e .context/verify-run ]

  run "$HELPER" read "$key"
  [ "$status" -eq 3 ]
}

@test "missing jq disables the cache without blocking discovery" {
  local no_jq_bin key
  no_jq_bin="$TMP_DIR/no-jq-bin"
  mkdir -p "$no_jq_bin"
  for command in bash dirname env git mktemp paste sed sort; do
    ln -s "$(command -v "$command")" "$no_jq_bin/$command"
  done

  run env PATH="$no_jq_bin" "$HELPER" key
  [ "$status" -eq 0 ]
  [[ "$output" == *'"enabled":false'* ]]
  [[ "$output" == *'"reason":"jq is not available"'* ]]
  key="$(sed -n 's/.*"key":"\([0-9a-f]*\)".*/\1/p' <<< "$output")"

  run env PATH="$no_jq_bin" "$HELPER" read "$key"
  [ "$status" -eq 3 ]
}

@test "missing jq still prints valid JSON for a repository path with quotes" {
  local no_jq_bin quoted_work
  no_jq_bin="$TMP_DIR/no-jq-bin"
  mkdir -p "$no_jq_bin"
  for command in bash dirname env git mktemp paste sed sort; do
    ln -s "$(command -v "$command")" "$no_jq_bin/$command"
  done
  quoted_work="$TMP_DIR/say \"hi\""
  mv "$WORK" "$quoted_work"
  cd "$quoted_work"

  run env PATH="$no_jq_bin" "$HELPER" key
  [ "$status" -eq 0 ]
  [ "$(jq -r .path <<< "$output")" = "$(pwd -P)/.context/verify-run/discovery-$(jq -r .key <<< "$output").json" ]
}

@test "write then read returns the saved record" {
  local key
  ignore_cache_dir
  run "$HELPER" key
  [ "$(jq -r .enabled <<< "$output")" = true ]
  key="$(jq -r .key <<< "$output")"

  run "$HELPER" read "$key"
  [ "$status" -eq 3 ]

  write_record "$TMP_DIR/record.json" "$key"
  run "$HELPER" write "$key" "$TMP_DIR/record.json"
  [ "$status" -eq 0 ]
  [ -f ".context/verify-run/discovery-$key.json" ]

  run "$HELPER" read "$key"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.checks[1].command' <<< "$output")" = "npm test" ]
  [ "$(jq -r '.skipped[0]' <<< "$output")" = "No E2E suite found" ]
}

@test "cache records preserve source paths containing spaces" {
  local key
  ignore_cache_dir
  mkdir -p .claude
  printf 'Run `npm test`.\n' > '.claude/project instructions.md'
  key="$(current_key)"
  write_record "$TMP_DIR/record.json" "$key" '.checks[0].source = ".claude/project instructions.md:1"'

  run "$HELPER" write "$key" "$TMP_DIR/record.json"
  [ "$status" -eq 0 ]
  run "$HELPER" read "$key"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.checks[0].source' <<< "$output")" = ".claude/project instructions.md:1" ]
}

@test "a changed input turns an earlier key into a miss" {
  local key
  ignore_cache_dir
  key="$(current_key)"
  write_record "$TMP_DIR/record.json" "$key"
  "$HELPER" write "$key" "$TMP_DIR/record.json" > /dev/null

  printf 'Use `pnpm test` instead.\n' >> AGENTS.md

  run "$HELPER" read "$key"
  [ "$status" -eq 3 ]
  run "$HELPER" read "$(current_key)"
  [ "$status" -eq 3 ]
}

@test "read rejects tampered records with exit 4" {
  local key record
  ignore_cache_dir
  key="$(current_key)"
  record=".context/verify-run/discovery-$key.json"
  mkdir -p .context/verify-run

  printf '{not json' > "$record"
  run "$HELPER" read "$key"
  [ "$status" -eq 4 ]
  [[ "$output" == *"not valid JSON"* ]]

  write_record "$record" "$key" '.key = "0000000000000000000000000000000000000000"'
  run "$HELPER" read "$key"
  [ "$status" -eq 4 ]
  [[ "$output" == *"key does not match"* ]]

  write_record "$record" "$key" '.checks[0].source = "src/app.js:1"'
  run "$HELPER" read "$key"
  [ "$status" -eq 4 ]
  [[ "$output" == *"not a hashed discovery input"* ]]

  write_record "$record" "$key" '.checks[0].cwd = "../elsewhere"'
  run "$HELPER" read "$key"
  [ "$status" -eq 4 ]

  write_record "$record" "$key" '.tiers.full.source = "README.md:1"'
  run "$HELPER" read "$key"
  [ "$status" -eq 4 ]

  write_record "$record" "$key" 'del(.base_branch)'
  run "$HELPER" read "$key"
  [ "$status" -eq 4 ]

  write_record "$record" "$key" '.base_branch = {name: "develop", source: "package.json:1"}'
  run "$HELPER" read "$key"
  [ "$status" -eq 0 ]
}

@test "write refuses records whose commands cite unhashed sources" {
  local key
  ignore_cache_dir
  key="$(current_key)"
  write_record "$TMP_DIR/record.json" "$key" '.checks[1].source = "CONTRIBUTING.md:4"'

  run "$HELPER" write "$key" "$TMP_DIR/record.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not a hashed discovery input"* ]]
  [ ! -e ".context/verify-run/discovery-$key.json" ]
}

@test "read rejects a record tracked by Git" {
  local key record
  ignore_cache_dir
  key="$(current_key)"
  record=".context/verify-run/discovery-$key.json"
  mkdir -p .context/verify-run
  write_record "$record" "$key"
  git add --force "$record"

  run "$HELPER" read "$key"
  [ "$status" -eq 4 ]
  [[ "$output" == *"tracked by Git"* ]]
}

@test "writing a record leaves the working-tree ID unchanged" {
  local key before
  ignore_cache_dir
  before="$("$TREE_ID")"
  key="$(current_key)"
  write_record "$TMP_DIR/record.json" "$key"
  "$HELPER" write "$key" "$TMP_DIR/record.json" > /dev/null

  [ -f ".context/verify-run/discovery-$key.json" ]
  [ "$("$TREE_ID")" = "$before" ]
}
