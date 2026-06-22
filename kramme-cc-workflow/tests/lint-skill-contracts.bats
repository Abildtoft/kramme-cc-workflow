#!/usr/bin/env bats

setup() {
  TMP_ROOT="$(mktemp -d)"
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/lint-skill-contracts.py"
}

teardown() {
  rm -rf "$TMP_ROOT"
}

write_file() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat >"$path"
}

write_minimal_skill() {
  local path="$1"
  local body="$2"
  write_file "$path" <<EOF
---
name: test-skill
description: Test skill
disable-model-invocation: false
user-invocable: true
---
$body
EOF
}

@test "real synced contract registry passes current tree" {
  run python3 "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"skill contract lint passed."* ]]
}

@test "verify-understanding supports answer option prompts" {
  local skill_text
  skill_text="$(cat "$BATS_TEST_DIRNAME/../skills/kramme:learn:verify-understanding/SKILL.md")"

  [[ "$skill_text" == *'[--answer-options|--choices]'* ]]
  [[ "$skill_text" == *'`--answer-options` or `--choices`: Prefer verification prompts with explicit answer options.'* ]]
  [[ "$skill_text" == *'After removing invocation options, use the remaining non-option text as the topic.'* ]]
  [[ "$skill_text" == *'still require the human to explain their choice before counting it as demonstrated understanding'* ]]
}

@test "fix-ci auto mode consolidates pipeline fix commits" {
  local skill_text
  local consolidation_text
  skill_text="$(cat "$BATS_TEST_DIRNAME/../skills/kramme:pr:fix-ci/SKILL.md")"
  consolidation_text="$(cat "$BATS_TEST_DIRNAME/../skills/kramme:pr:fix-ci/references/consolidation-flow.md")"

  [[ "$skill_text" == *'`--auto` - Run the CI fix loop unattended'* ]]
  [[ "$skill_text" == *'If `AUTO_MODE=true`, choose **Automated** without prompting'* ]]
  [[ "$skill_text" == *'**Skip this step if:** `--fixup` mode was used, or `--no-consolidate` flag is set.'* ]]
  [[ "$skill_text" != *'Alias for `--no-consolidate`'* ]]
  [[ "$skill_text" != *'`--no-consolidate` / `--auto` flag'* ]]

  [[ "$consolidation_text" == *'If `AUTO_MODE=true`, do not offer "Keep separate".'* ]]
  [[ "$consolidation_text" == *'Before any automated rebase, confirm one of these is true:'* ]]
  [[ "$consolidation_text" == *'If `AUTO_MODE=true`, apply the pre-rebase safety gate above, then select **Automated**'* ]]
}

@test "text contract drift fails with precise contract name" {
  write_minimal_skill "$TMP_ROOT/kramme-cc-workflow/skills/a/SKILL.md" "Contract: alpha"
  write_minimal_skill "$TMP_ROOT/kramme-cc-workflow/skills/b/SKILL.md" "Contract: beta"
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "text_contracts": [
    {
      "name": "sample-text-contract",
      "extract_regex": "Contract: ([A-Za-z]+)",
      "paths": [
        "kramme-cc-workflow/skills/a/SKILL.md",
        "kramme-cc-workflow/skills/b/SKILL.md"
      ]
    }
  ]
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"sample-text-contract"* ]]
  [[ "$output" == *"differs"* ]]
}

@test "ordered heading drift fails" {
  write_minimal_skill "$TMP_ROOT/kramme-cc-workflow/skills/a/SKILL.md" $'## Current Progress\n\n### Last Completed\n\n### Project Status'
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "ordered_heading_contracts": [
    {
      "name": "sample-heading-contract",
      "headings": [
        "## Current Progress",
        "### Project Status",
        "### Last Completed"
      ],
      "paths": [
        "kramme-cc-workflow/skills/a/SKILL.md"
      ]
    }
  ]
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"sample-heading-contract"* ]]
  [[ "$output" == *"missing or out-of-order heading"* ]]
}

@test "file identity drift fails" {
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/a/references/shared.md" <<'EOF'
same
EOF
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/b/references/shared.md" <<'EOF'
different
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "file_identity_groups": [
    {
      "name": "sample-file-identity",
      "paths": [
        "kramme-cc-workflow/skills/a/references/shared.md",
        "kramme-cc-workflow/skills/b/references/shared.md"
      ]
    }
  ]
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"sample-file-identity"* ]]
  [[ "$output" == *"sync all registered copies"* ]]
}

@test "multiline text contract drift fails" {
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/a/SKILL.md" <<'EOF'
---
name: test-skill-a
description: Test skill A
disable-model-invocation: false
user-invocable: true
---
```bash
COLLECT_ARGS=(--strict)
[ -n "${BASE_BRANCH_OVERRIDE:-}" ] && COLLECT_ARGS+=(--base "$BASE_BRANCH_OVERRIDE")

RESOLVED=$(${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh "${COLLECT_ARGS[@]}") || {
  echo "Base/diff collection failed; see the message above and stop." >&2
  exit 1
}
eval "$RESOLVED"
```
EOF
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/b/SKILL.md" <<'EOF'
---
name: test-skill-b
description: Test skill B
disable-model-invocation: false
user-invocable: true
---
```bash
COLLECT_ARGS=(--strict)
[ -n "${BASE_BRANCH_OVERRIDE:-}" ] && COLLECT_ARGS+=(--base "$BASE_BRANCH_OVERRIDE")

RESOLVED=$(${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh "${COLLECT_ARGS[@]}") || {
  echo "Base/diff collection failed; see the message above and stop." >&2
  exit 2
}
eval "$RESOLVED"
```
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "text_contracts": [
    {
      "name": "sample-multiline-text-contract",
      "extract_regex": "(?s)(COLLECT_ARGS=\\(--strict\\).*?eval \"\\$RESOLVED\")",
      "paths": [
        "kramme-cc-workflow/skills/a/SKILL.md",
        "kramme-cc-workflow/skills/b/SKILL.md"
      ]
    }
  ]
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"sample-multiline-text-contract"* ]]
  [[ "$output" == *"differs"* ]]
}

@test "linewise multiline text contract catches line-boundary drift" {
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/a/SKILL.md" <<'EOF'
---
name: test-skill-a
description: Test skill A
disable-model-invocation: false
user-invocable: true
---
```bash
COLLECT_ARGS=(--strict)
[ -n "${BASE_BRANCH_OVERRIDE:-}" ] && COLLECT_ARGS+=(--base "$BASE_BRANCH_OVERRIDE")

RESOLVED=$(${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh "${COLLECT_ARGS[@]}") || {
  echo "Base/diff collection failed; see the message above and stop." >&2
  exit 1
}
eval "$RESOLVED"
```
EOF
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/b/SKILL.md" <<'EOF'
---
name: test-skill-b
description: Test skill B
disable-model-invocation: false
user-invocable: true
---
```bash
COLLECT_ARGS=(--strict)
[ -n "${BASE_BRANCH_OVERRIDE:-}" ] && COLLECT_ARGS+=(--base "$BASE_BRANCH_OVERRIDE")

RESOLVED=$(${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh "${COLLECT_ARGS[@]}") || {
  echo "Base/diff collection failed; see the message above and stop." >&2
  exit 1
} eval "$RESOLVED"
```
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "text_contracts": [
    {
      "name": "sample-linewise-multiline-text-contract",
      "extract_regex": "(?s)(COLLECT_ARGS=\\(--strict\\).*?eval \"\\$RESOLVED\")",
      "normalizer": "linewise",
      "paths": [
        "kramme-cc-workflow/skills/a/SKILL.md",
        "kramme-cc-workflow/skills/b/SKILL.md"
      ]
    }
  ]
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"sample-linewise-multiline-text-contract"* ]]
  [[ "$output" == *"differs"* ]]
}

@test "malformed hooks json fails" {
  write_file "$TMP_ROOT/kramme-cc-workflow/hooks/hooks.json" <<'EOF'
{"hooks":
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "hooks_json": {
    "path": "kramme-cc-workflow/hooks/hooks.json"
  }
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"hooks json"* ]]
  [[ "$output" == *"invalid JSON"* ]]
}

@test "unknown hooks json event fails" {
  write_file "$TMP_ROOT/kramme-cc-workflow/hooks/hooks.json" <<'EOF'
{
  "hooks": {
    "BadEvent": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "echo ok"
          }
        ]
      }
    ]
  }
}
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "hooks_json": {
    "path": "kramme-cc-workflow/hooks/hooks.json"
  }
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown event 'BadEvent'"* ]]
}

@test "hook entry missing command fails" {
  write_file "$TMP_ROOT/kramme-cc-workflow/hooks/hooks.json" <<'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command"
          }
        ]
      }
    ]
  }
}
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "hooks_json": {
    "path": "kramme-cc-workflow/hooks/hooks.json"
  }
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"must define a non-empty command"* ]]
}

@test "hook command missing local plugin path fails" {
  write_file "$TMP_ROOT/kramme-cc-workflow/hooks/hooks.json" <<'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/missing.sh"
          }
        ]
      }
    ]
  }
}
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "hooks_json": {
    "path": "kramme-cc-workflow/hooks/hooks.json",
    "plugin_root": "kramme-cc-workflow"
  }
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"command references missing path kramme-cc-workflow/hooks/missing.sh"* ]]
}

@test "skill directory missing from readme fails" {
  write_minimal_skill "$TMP_ROOT/kramme-cc-workflow/skills/kramme:sample/SKILL.md" "# Sample"
  write_file "$TMP_ROOT/README.md" <<'EOF'
# Test README
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "readme_skill_sync": {
    "readme": "README.md",
    "skills_dir": "kramme-cc-workflow/skills"
  }
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"readme skill sync"* ]]
  [[ "$output" == *"missing skill 'kramme:sample'"* ]]
}

@test "readme sync requires exact documented skill rows" {
  write_minimal_skill "$TMP_ROOT/kramme-cc-workflow/skills/kramme:qa/SKILL.md" "# QA"
  write_minimal_skill "$TMP_ROOT/kramme-cc-workflow/skills/kramme:qa:intake/SKILL.md" "# QA intake"
  write_file "$TMP_ROOT/README.md" <<'EOF'
# Test README

Try /kramme:qa for live checks.

| Skill | Description |
| --- | --- |
| `/kramme:qa:intake` | QA intake. |
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "readme_skill_sync": {
    "readme": "README.md",
    "skills_dir": "kramme-cc-workflow/skills"
  }
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"readme skill sync"* ]]
  [[ "$output" == *"missing skill 'kramme:qa'"* ]]
}

@test "readme sync accepts background skill rows but ignores agent rows" {
  write_minimal_skill "$TMP_ROOT/kramme-cc-workflow/skills/kramme:background/SKILL.md" "# Background"
  write_file "$TMP_ROOT/README.md" <<'EOF'
# Test README

### Background Skills

| Skill | Trigger Condition |
| --- | --- |
| `kramme:background` | Runs in the background. |

## Agents

| Agent | Description |
| --- | --- |
| `kramme:missing-agent` | Agent, not a skill. |
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "readme_skill_sync": {
    "readme": "README.md",
    "skills_dir": "kramme-cc-workflow/skills"
  }
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 0 ]
  [[ "$output" == *"skill contract lint passed."* ]]
}

@test "readme ghost skill fails" {
  write_minimal_skill "$TMP_ROOT/kramme-cc-workflow/skills/kramme:real/SKILL.md" "# Real"
  write_file "$TMP_ROOT/README.md" <<'EOF'
# Test README

| Skill | Description |
| --- | --- |
| `/kramme:real` | Real skill. |
| `/kramme:ghost` | Ghost skill. |
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "readme_skill_sync": {
    "readme": "README.md",
    "skills_dir": "kramme-cc-workflow/skills"
  }
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"documents 'kramme:ghost'"* ]]
  [[ "$output" == *"does not exist"* ]]
}

@test "marker manifest empty field fails unless allowlisted" {
  write_minimal_skill "$TMP_ROOT/kramme-cc-workflow/skills/a/SKILL.md" "SIMPLICITY CHECK: minimum viable change"
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/a/references/sources.yaml" <<'EOF'
sources:
  - id: source-a
    url: https://example.com/source-a
    title: Source A
    rationale: Used for test fixture.
    last_reviewed_at: 2026-06-10
    baseline_hash: ""
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "marker_implies_manifest": {
    "skill_glob": "kramme-cc-workflow/skills/*/SKILL.md",
    "manifest": "references/sources.yaml",
    "markers": [
      "SIMPLICITY CHECK"
    ],
    "required_fields": [
      "id",
      "title",
      "rationale",
      "last_reviewed_at",
      "baseline_hash"
    ],
    "one_of_fields": [
      "url",
      "context7_library"
    ],
    "allow_empty_fields": []
  }
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"marker manifest"* ]]
  [[ "$output" == *"empty 'baseline_hash'"* ]]
}

@test "marker manifest accepts exact allowlisted empty field with reason" {
  write_minimal_skill "$TMP_ROOT/kramme-cc-workflow/skills/a/SKILL.md" "SIMPLICITY CHECK: minimum viable change"
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/a/references/sources.yaml" <<'EOF'
sources:
  - id: source-a
    url: https://example.com/source-a
    title: Source A
    rationale: Used for test fixture.
    last_reviewed_at: 2026-06-10
    baseline_hash: ""
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "marker_implies_manifest": {
    "skill_glob": "kramme-cc-workflow/skills/*/SKILL.md",
    "manifest": "references/sources.yaml",
    "markers": [
      "SIMPLICITY CHECK"
    ],
    "required_fields": [
      "id",
      "title",
      "rationale",
      "last_reviewed_at",
      "baseline_hash"
    ],
    "one_of_fields": [
      "url",
      "context7_library"
    ],
    "allow_empty_fields": [
      {
        "path": "kramme-cc-workflow/skills/a/references/sources.yaml",
        "entry_id": "source-a",
        "field": "baseline_hash",
        "reason": "Historical baseline hash debt in this fixture."
      }
    ]
  }
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 0 ]
  [[ "$output" == *"skill contract lint passed."* ]]
}

@test "marker manifest allowlisted empty field requires reason" {
  write_minimal_skill "$TMP_ROOT/kramme-cc-workflow/skills/a/SKILL.md" "SIMPLICITY CHECK: minimum viable change"
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/a/references/sources.yaml" <<'EOF'
sources:
  - id: source-a
    url: https://example.com/source-a
    title: Source A
    rationale: Used for test fixture.
    last_reviewed_at: 2026-06-10
    baseline_hash: ""
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "marker_implies_manifest": {
    "skill_glob": "kramme-cc-workflow/skills/*/SKILL.md",
    "manifest": "references/sources.yaml",
    "markers": [
      "SIMPLICITY CHECK"
    ],
    "required_fields": [
      "id",
      "title",
      "rationale",
      "last_reviewed_at",
      "baseline_hash"
    ],
    "one_of_fields": [
      "url",
      "context7_library"
    ],
    "allow_empty_fields": [
      {
        "path": "kramme-cc-workflow/skills/a/references/sources.yaml",
        "entry_id": "source-a",
        "field": "baseline_hash",
        "reason": ""
      }
    ]
  }
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"marker manifest"* ]]
  [[ "$output" == *"allow_empty_fields[1]"* ]]
  [[ "$output" == *"non-empty 'reason'"* ]]
}

@test "epilogue order drift fails" {
  write_minimal_skill "$TMP_ROOT/kramme-cc-workflow/skills/a/SKILL.md" $'## Common Rationalizations\n\n## Verification'
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "epilogue_order": {
    "skill_glob": "kramme-cc-workflow/skills/*/SKILL.md",
    "trigger_heading_regex": "^#{2,3}\\s+Common Rationalizations\\b",
    "required_headings": [
      "Common Rationalizations",
      "Red Flags",
      "Verification"
    ],
    "allowlist": []
  }
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"epilogue order"* ]]
  [[ "$output" == *"Red Flags"* ]]
}

@test "mechanical frontmatter regression fails" {
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/a/SKILL.md" <<'EOF'
---
name: test-skill
description: Test skill
disable-model-invocation: false
---
# Test
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "mechanical": {
    "skill_glob": "kramme-cc-workflow/skills/*/SKILL.md",
    "max_skill_lines": 500,
    "max_description_chars": 1024,
    "required_frontmatter": [
      "name",
      "description",
      "disable-model-invocation",
      "user-invocable"
    ],
    "allow_line_count_over": []
  }
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"missing frontmatter field 'user-invocable'"* ]]
}
