#!/usr/bin/env bats

load 'test_helper/common'

setup() {
  TMP_ROOT="$(mktemp -d)"
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/lint-skill-contracts.py"
  SYNCED_FILES_GENERATOR="$BATS_TEST_DIRNAME/../scripts/generate-synced-files.py"
  VISUAL_GENERATOR="$BATS_TEST_DIRNAME/../scripts/generate-visual-shared-assets.py"
  COMPONENT_GENERATOR="$BATS_TEST_DIRNAME/../scripts/generate-component-reference.py"
  ISSUE_DEFINE_RESERVATION_HELPER="$BATS_TEST_DIRNAME/../skills/kramme:siw:issue-define/scripts/siw-issue-reservation.sh"
  GENERATE_PHASES_RESERVATION_HELPER="$BATS_TEST_DIRNAME/../skills/kramme:siw:generate-phases/scripts/siw-issue-reservation.sh"
}

teardown() {
  rm -rf "$TMP_ROOT"
}

file_mode() {
  python3 -c 'import os, stat, sys; print(f"{stat.S_IMODE(os.stat(sys.argv[1]).st_mode):04o}")' "$1"
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

write_text_contract_inventory_fixture() {
  write_file "$TMP_ROOT/contracts/a.md" <<'EOF'
Canonical inventory marker: alpha
EOF
  write_file "$TMP_ROOT/contracts/b.md" <<'EOF'
Canonical inventory marker: alpha
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "text_contracts": [
    {
      "name": "sample-inventoried-contract",
      "extract_regex": "Canonical inventory marker: ([A-Za-z]+)",
      "inventory": {
        "glob": "contracts/*.md",
        "marker": "Canonical inventory marker:"
      },
      "paths": [
        "contracts/a.md",
        "contracts/b.md"
      ]
    }
  ]
}
EOF
}

siw_spec_exclusion_expected_paths() {
  printf '%s\n' \
    "kramme-cc-workflow/skills/kramme:siw:close/SKILL.md" \
    "kramme-cc-workflow/skills/kramme:siw:continue/SKILL.md" \
    "kramme-cc-workflow/skills/kramme:siw:discovery/SKILL.md" \
    "kramme-cc-workflow/skills/kramme:siw:generate-phases/SKILL.md" \
    "kramme-cc-workflow/skills/kramme:siw:implementation-audit/SKILL.md" \
    "kramme-cc-workflow/skills/kramme:siw:implementation-audit/references/spec-resolution.md" \
    "kramme-cc-workflow/skills/kramme:siw:init/SKILL.md" \
    "kramme-cc-workflow/skills/kramme:siw:issue-define/SKILL.md" \
    "kramme-cc-workflow/skills/kramme:siw:issue-define/references/classification-and-prefix.md" \
    "kramme-cc-workflow/skills/kramme:siw:issue-implement/references/spec-sync.md" \
    "kramme-cc-workflow/skills/kramme:siw:issue-implement/references/team-mode.md" \
    "kramme-cc-workflow/skills/kramme:siw:issue-reindex/references/spec-capture-check.md" \
    "kramme-cc-workflow/skills/kramme:siw:product-audit/SKILL.md" \
    "kramme-cc-workflow/skills/kramme:siw:remove/SKILL.md" \
    "kramme-cc-workflow/skills/kramme:siw:reset/SKILL.md" \
    "kramme-cc-workflow/skills/kramme:siw:spec-audit/SKILL.md" \
    "kramme-cc-workflow/skills/kramme:siw:spec-audit/references/spec-resolution.md" \
    "kramme-cc-workflow/skills/kramme:siw:transfer-to-linear/references/artifact-extraction.md"
}

write_reference_skill() {
  local path="$1"
  local name="$2"
  local description="$3"
  local disable_model_invocation="$4"
  local user_invocable="$5"
  local argument_hint="${6:-}"

  if [ -n "$argument_hint" ]; then
    write_file "$path" <<EOF
---
name: $name
description: $description
argument-hint: $argument_hint
disable-model-invocation: $disable_model_invocation
user-invocable: $user_invocable
---
# $name
EOF
  else
    write_file "$path" <<EOF
---
name: $name
description: $description
disable-model-invocation: $disable_model_invocation
user-invocable: $user_invocable
---
# $name
EOF
  fi
}

write_readme_skill_sync_registry() {
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "readme_skill_sync": {
    "readme": "README.md",
    "skills_dir": "kramme-cc-workflow/skills",
    "start_marker": "<!-- BEGIN SOURCE-SYNCED SKILL ROWS -->",
    "end_marker": "<!-- END SOURCE-SYNCED SKILL ROWS -->"
  }
}
EOF
}

write_reference_agent() {
  local path="$1"
  local name="$2"
  local description="$3"

  write_file "$path" <<EOF
---
name: $name
description: $description
model: opus
color: green
---
# $name
EOF
}

write_hook_manifest() {
  local path="$1"
  local hook_name="$2"
  local event="${3:-PreToolUse}"
  local matcher="${4:-Bash}"

  if [ -n "$matcher" ]; then
    write_file "$path" <<EOF
{
  "hooks": {
    "$event": [
      {
        "matcher": "$matcher",
        "hooks": [
          {
            "type": "command",
            "command": "bash \${CLAUDE_PLUGIN_ROOT}/hooks/$hook_name.sh"
          }
        ]
      }
    ]
  }
}
EOF
  else
    write_file "$path" <<EOF
{
  "hooks": {
    "$event": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \${CLAUDE_PLUGIN_ROOT}/hooks/$hook_name.sh"
          }
        ]
      }
    ]
  }
}
EOF
  fi
}

make_body_lines() {
  local count="$1"
  local index
  for ((index = 1; index <= count; index++)); do
    printf '# body line %03d\n' "$index"
  done
}

@test "real synced contract registry passes current tree" {
  run python3 "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"skill contract lint passed."* ]]
}

@test "registry consumers reject every non-object JSON kind with path context" {
  local consumer
  local fixture

  for consumer in "$SCRIPT" "$COMPONENT_GENERATOR" "$VISUAL_GENERATOR"; do
    for fixture in "null" "[]" '"scalar"' "false" "42"; do
      printf '%s\n' "$fixture" >"$TMP_ROOT/registry.yaml"

      run python3 "$consumer" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

      [ "$status" -eq 1 ]
      [[ "$output" == *"$TMP_ROOT/registry.yaml"* ]]
      [[ "$output" == *"registry must be a JSON object"* ]]
    done
  done
}

@test "copy review rubric is owned by the code skill with automatic PR mode" {
  local registry="$BATS_TEST_DIRNAME/../scripts/synced-contracts.yaml"
  local code_skill="$BATS_TEST_DIRNAME/../skills/kramme:code:copy-review/SKILL.md"
  local code_rubric="$BATS_TEST_DIRNAME/../skills/kramme:code:copy-review/references/copy-review-rubric.md"
  local pr_skill="$BATS_TEST_DIRNAME/../skills/kramme:pr:copy-review/SKILL.md"

  test -f "$code_skill"
  test -f "$code_rubric"
  test ! -f "$pr_skill"
  grep -qF 'Canonical owner: `kramme:code:copy-review`.' "$code_rubric"
  grep -qF 'If `FORCE_PR_MODE=true`, set `SCAN_MODE=false`' "$code_skill"
  grep -qF 'equals `BASE_BRANCH`, set `SCAN_MODE=true`' "$code_skill"
  grep -qF 'differs from `BASE_BRANCH`, set `SCAN_MODE=false`.' "$code_skill"
  grep -qF 'the repo root for `--all` or automatic base-branch audit mode' "$code_skill"
  ! grep -qF '"name": "copy-review-rubric"' "$registry"
  ! grep -qF '"name": "copy-review-redundancy-scope"' "$registry"
  ! grep -qF '"name": "copy-review-ui-relevant-file-types"' "$registry"
}

@test "spec-audit fix-confidence rubric is synced as a skill-local resource" {
  local registry="$BATS_TEST_DIRNAME/../scripts/synced-contracts.yaml"
  local auto_fix_rubric="$BATS_TEST_DIRNAME/../skills/kramme:siw:apply-spec-audit-fixes/references/classification-rubric.md"
  local audit_rubric="$BATS_TEST_DIRNAME/../skills/kramme:siw:spec-audit/references/fix-confidence-rubric.md"

  test -f "$auto_fix_rubric"
  test -f "$audit_rubric"
  cmp -s "$auto_fix_rubric" "$audit_rubric"
  grep -qF '"name": "siw-spec-audit-fix-confidence-rubric"' "$registry"
}

@test "visual shared asset generator passes current tree" {
  run python3 "$VISUAL_GENERATOR" --check

  [ "$status" -eq 0 ]
  [[ "$output" == *"visual shared assets are in sync."* ]]
}

@test "readme skill sync accepts source-generated frontmatter rows" {
  write_reference_skill \
    "$TMP_ROOT/kramme-cc-workflow/skills/kramme:sample/SKILL.md" \
    "kramme:sample" \
    "Sample skill description" \
    "false" \
    "true" \
    "[target]"
  write_file "$TMP_ROOT/README.md" <<'EOF'
# Fixture

## Skills

<!-- BEGIN SOURCE-SYNCED SKILL ROWS -->

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:sample` | User, Auto | `[target]` | Sample skill description |

<!-- END SOURCE-SYNCED SKILL ROWS -->

## Agents
EOF
  write_readme_skill_sync_registry

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 0 ]
  [[ "$output" == *"skill contract lint passed."* ]]
}

@test "readme skill sync normalizes quoted boolean frontmatter rows" {
  write_reference_skill \
    "$TMP_ROOT/kramme-cc-workflow/skills/kramme:hidden/SKILL.md" \
    "kramme:hidden" \
    "Hidden quoted skill" \
    '"true"' \
    '"false"'
  write_reference_skill \
    "$TMP_ROOT/kramme-cc-workflow/skills/kramme:user-only/SKILL.md" \
    "kramme:user-only" \
    "User-only quoted skill" \
    '"true"' \
    '"true"' \
    "[target]"
  write_file "$TMP_ROOT/README.md" <<'EOF'
# Fixture

## Skills

<!-- BEGIN SOURCE-SYNCED SKILL ROWS -->

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `kramme:hidden` | Hidden | — | Hidden quoted skill |
| `/kramme:user-only` | User | `[target]` | User-only quoted skill |

<!-- END SOURCE-SYNCED SKILL ROWS -->

## Agents
EOF
  write_readme_skill_sync_registry

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 0 ]
  [[ "$output" == *"skill contract lint passed."* ]]
}

@test "readme skill sync catches invocation arguments and description drift" {
  write_reference_skill \
    "$TMP_ROOT/kramme-cc-workflow/skills/kramme:sample/SKILL.md" \
    "kramme:sample" \
    "Sample skill description" \
    "false" \
    "true" \
    "[target]"
  write_file "$TMP_ROOT/README.md" <<'EOF'
# Fixture

## Skills

<!-- BEGIN SOURCE-SYNCED SKILL ROWS -->

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:sample` | User | — | Stale copied description |

<!-- END SOURCE-SYNCED SKILL ROWS -->

## Agents
EOF
  write_readme_skill_sync_registry

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"readme skill sync"* ]]
  [[ "$output" == *"invocation differs from SKILL.md frontmatter"* ]]
  [[ "$output" == *"arguments differs from SKILL.md frontmatter"* ]]
  [[ "$output" == *"description differs from SKILL.md frontmatter"* ]]
}

@test "readme skill sync uses frontmatter fields from shared schema" {
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/kramme:custom/SKILL.md" <<'EOF'
---
name: kramme:custom
description: Custom schema skill
prompt: "[topic]"
no-ai: true
manual: true
---
# kramme:custom
EOF
  write_file "$TMP_ROOT/schema.json" <<'EOF'
{
  "skill_frontmatter": {
    "fields": {
      "name": {"type": "string", "required": true},
      "description": {"type": "string", "required": true},
      "prompt": {
        "type": "string",
        "required": false,
        "loader_property": "argumentHint"
      },
      "no-ai": {
        "type": "boolean",
        "required": true,
        "loader_property": "disableModelInvocation"
      },
      "manual": {
        "type": "boolean",
        "required": true,
        "loader_property": "userInvocable"
      }
    }
  },
  "source_manifest": {
    "required_fields": [],
    "one_of_fields": []
  }
}
EOF
  write_file "$TMP_ROOT/README.md" <<'EOF'
# Fixture

## Skills

<!-- BEGIN SOURCE-SYNCED SKILL ROWS -->

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:custom` | User | `[topic]` | Custom schema skill |

<!-- END SOURCE-SYNCED SKILL ROWS -->

## Agents
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "contract_schema": "schema.json",
  "readme_skill_sync": {
    "readme": "README.md",
    "skills_dir": "kramme-cc-workflow/skills",
    "start_marker": "<!-- BEGIN SOURCE-SYNCED SKILL ROWS -->",
    "end_marker": "<!-- END SOURCE-SYNCED SKILL ROWS -->"
  }
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 0 ]
  [[ "$output" == *"skill contract lint passed."* ]]
}

@test "component reference generator check reports drift and write syncs rows" {
  write_reference_skill \
    "$TMP_ROOT/kramme-cc-workflow/skills/kramme:sample/SKILL.md" \
    "kramme:sample" \
    "Sample skill description" \
    "false" \
    "true" \
    "[target]"
  write_file "$TMP_ROOT/README.md" <<'EOF'
# Fixture

## Skills

<!-- BEGIN SOURCE-SYNCED SKILL ROWS -->

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:sample` | User | — | Stale copied description |

<!-- END SOURCE-SYNCED SKILL ROWS -->

## Agents
EOF
  write_readme_skill_sync_registry

  run python3 "$COMPONENT_GENERATOR" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml" --check

  [ "$status" -eq 1 ]
  [[ "$output" == *"component reference sync check failed:"* ]]

  run python3 "$COMPONENT_GENERATOR" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml" --write

  [ "$status" -eq 0 ]
  [[ "$output" == *"updated README.md component reference rows."* ]]
  [[ "$(cat "$TMP_ROOT/README.md")" == *"| \`/kramme:sample\` | User, Auto | \`[target]\` | Sample skill description |"* ]]
}

@test "component reference generator check rejects ghost skill rows" {
  write_reference_skill \
    "$TMP_ROOT/kramme-cc-workflow/skills/kramme:real/SKILL.md" \
    "kramme:real" \
    "Real skill description" \
    "false" \
    "true"
  write_file "$TMP_ROOT/README.md" <<'EOF'
# Fixture

## Skills

<!-- BEGIN SOURCE-SYNCED SKILL ROWS -->

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:real` | User, Auto | — | Real skill description |
| `/kramme:ghost` | User | — | Ghost skill description |

<!-- END SOURCE-SYNCED SKILL ROWS -->

## Agents
EOF
  write_readme_skill_sync_registry

  run python3 "$COMPONENT_GENERATOR" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml" --check

  [ "$status" -eq 1 ]
  [[ "$output" == *"component reference sync failed:"* ]]
  [[ "$output" == *"documents 'kramme:ghost'"* ]]
  [[ "$output" == *"does not exist"* ]]
}

@test "readme agent sync catches missing source agent rows" {
  write_reference_agent \
    "$TMP_ROOT/kramme-cc-workflow/agents/kramme:reviewer.md" \
    "kramme:reviewer" \
    "Reviews fixture code"
  write_file "$TMP_ROOT/README.md" <<'EOF'
# Fixture

## Agents

<!-- BEGIN SOURCE-SYNCED AGENT ROWS -->
| Agent | Description |
| --- | --- |
<!-- END SOURCE-SYNCED AGENT ROWS -->
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "readme_agent_sync": {
    "readme": "README.md",
    "agents_dir": "kramme-cc-workflow/agents",
    "start_marker": "<!-- BEGIN SOURCE-SYNCED AGENT ROWS -->",
    "end_marker": "<!-- END SOURCE-SYNCED AGENT ROWS -->"
  }
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"readme agent sync"* ]]
  [[ "$output" == *"missing agent 'kramme:reviewer'"* ]]
}

@test "readme hook sync catches missing hook rows" {
  write_hook_manifest "$TMP_ROOT/kramme-cc-workflow/hooks/hooks.json" "sample-hook"
  write_file "$TMP_ROOT/README.md" <<'EOF'
# Fixture

## Hooks

<!-- BEGIN SOURCE-SYNCED HOOK ROWS -->
| Hook | Event | Description |
| --- | --- | --- |
<!-- END SOURCE-SYNCED HOOK ROWS -->
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "readme_hook_sync": {
    "readme": "README.md",
    "hooks_json": "kramme-cc-workflow/hooks/hooks.json",
    "start_marker": "<!-- BEGIN SOURCE-SYNCED HOOK ROWS -->",
    "end_marker": "<!-- END SOURCE-SYNCED HOOK ROWS -->",
    "descriptions": {
      "sample-hook": "Runs a sample hook"
    }
  }
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"readme hook sync"* ]]
  [[ "$output" == *"missing hook 'sample-hook'"* ]]
}

@test "component reference generator writes agent and hook rows" {
  write_reference_agent \
    "$TMP_ROOT/kramme-cc-workflow/agents/kramme:reviewer.md" \
    "kramme:reviewer" \
    "Reviews fixture code"
  write_hook_manifest "$TMP_ROOT/kramme-cc-workflow/hooks/hooks.json" "sample-hook" "PostToolUse" "Write|Edit"
  write_file "$TMP_ROOT/README.md" <<'EOF'
# Fixture

## Agents

<!-- BEGIN SOURCE-SYNCED AGENT ROWS -->
| Agent | Description |
| --- | --- |
<!-- END SOURCE-SYNCED AGENT ROWS -->

## Hooks

<!-- BEGIN SOURCE-SYNCED HOOK ROWS -->
| Hook | Event | Description |
| --- | --- | --- |
<!-- END SOURCE-SYNCED HOOK ROWS -->
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "readme_agent_sync": {
    "readme": "README.md",
    "agents_dir": "kramme-cc-workflow/agents",
    "start_marker": "<!-- BEGIN SOURCE-SYNCED AGENT ROWS -->",
    "end_marker": "<!-- END SOURCE-SYNCED AGENT ROWS -->"
  },
  "readme_hook_sync": {
    "readme": "README.md",
    "hooks_json": "kramme-cc-workflow/hooks/hooks.json",
    "start_marker": "<!-- BEGIN SOURCE-SYNCED HOOK ROWS -->",
    "end_marker": "<!-- END SOURCE-SYNCED HOOK ROWS -->",
    "descriptions": {
      "sample-hook": "Runs a sample hook"
    }
  }
}
EOF

  run python3 "$COMPONENT_GENERATOR" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml" --write

  [ "$status" -eq 0 ]
  [[ "$output" == *"updated README.md component reference rows."* ]]
  [[ "$(cat "$TMP_ROOT/README.md")" == *"| \`kramme:reviewer\` | Reviews fixture code |"* ]]
  [[ "$(cat "$TMP_ROOT/README.md")" == *"| \`sample-hook\` | PostToolUse (Write\\|Edit) | Runs a sample hook |"* ]]
}

@test "pr code review exposes resolver readiness contract" {
  local skill_text
  local template_text
  local discipline_text
  local team_text
  local relevance_validator_text
  local resolver_text
  local resolver_team_text
  local resolver_output_text
  local emphasis_line
  local normalization_line

  skill_text="$(cat "$BATS_TEST_DIRNAME/../skills/kramme:pr:code-review/SKILL.md")"
  template_text="$(cat "$BATS_TEST_DIRNAME/../skills/kramme:pr:code-review/references/output-template.md")"
  discipline_text="$(cat "$BATS_TEST_DIRNAME/../skills/kramme:pr:code-review/references/review-discipline.md")"
  team_text="$(cat "$BATS_TEST_DIRNAME/../skills/kramme:pr:code-review/references/team-mode.md")"
  relevance_validator_text="$(cat "$BATS_TEST_DIRNAME/../agents/kramme:pr-relevance-validator.md")"
  resolver_text="$(cat "$BATS_TEST_DIRNAME/../skills/kramme:pr:resolve-review/SKILL.md")"
  resolver_team_text="$(cat "$BATS_TEST_DIRNAME/../skills/kramme:pr:resolve-review/references/team-mode.md")"
  resolver_output_text="$(cat "$BATS_TEST_DIRNAME/../skills/kramme:pr:resolve-review/references/resolution-output.md")"

  [[ "$skill_text" == *"After emphasis adjustments, run an **action-class normalization pass**."* ]]
  [[ "$skill_text" == *"default to \`gated_auto\` with owner \`resolver\`"* ]]
  [[ "$skill_text" == *"\`Manual blocker: <one of the blocker categories above>\`"* ]]
  [[ "$skill_text" == *"**Auto-resolution Readiness**"* ]]
  [[ "$skill_text" == *"Label every finding produced by this check with \`OVERENGINEERING\`"* ]]
  [[ "$skill_text" == *"Treat findings labeled \`OVERENGINEERING\` by any reviewer the same way."* ]]
  [[ "$skill_text" == *"Overengineering findings default to Suggestion with action class \`advisory\`."* ]]
  [[ "$skill_text" == *"Treat validator output as classifications over the original finding records, not replacement findings."* ]]
  [[ "$skill_text" == *"Treat meta-review output as annotations over the original finding records."* ]]
  [[ "$skill_text" == *"\`MISSING REQUIREMENT\`, \`OVERENGINEERING\`"* ]]
  emphasis_line="$(grep -nF "Track the count of promoted findings for the report." <<<"$skill_text" | cut -d: -f1)"
  normalization_line="$(grep -nF "After emphasis adjustments, run an **action-class normalization pass**." <<<"$skill_text" | cut -d: -f1)"
  [ "$normalization_line" -gt "$emphasis_line" ]

  [[ "$template_text" == *"## Auto-resolution Readiness"* ]]
  [[ "$template_text" == *"Manual blockers: product/UX/architecture/maintainer decision X"* ]]
  [[ "$template_text" == *"Manual blocker: product/UX/architecture/maintainer decision"* ]]
  [[ "$template_text" == *"Next human decision: concrete decision"* ]]

  [[ "$discipline_text" == *"Critical or Important PR-caused findings default to \`gated_auto\`"* ]]
  [[ "$discipline_text" == *"Every manual Critical/Important finding includes \`Manual blocker\` and \`Next human decision\`"* ]]
  [[ "$discipline_text" == *"**OVERENGINEERING** — the finding comes from the Overengineering Check"* ]]
  [[ "$discipline_text" == *"Every finding produced by the Overengineering Check is labeled \`OVERENGINEERING\`"* ]]

  [[ "$team_text" == *"Treat teammate action classes as provisional."* ]]
  [[ "$team_text" == *"Include the \`## Auto-resolution Readiness\` section from the standard template"* ]]
  [[ "$team_text" == *"Label every finding produced by this check with \`OVERENGINEERING\`"* ]]
  [[ "$team_text" == *"findings labeled \`OVERENGINEERING\` by any teammate the same way."* ]]
  [[ "$team_text" == *"Overengineering findings default to Suggestion with action class \`advisory\`."* ]]
  [[ "$team_text" == *"Treat meta-review output as annotations over the original finding records."* ]]
  [[ "$team_text" == *"Treat validator output as classifications over the original finding records, not replacement findings."* ]]

  [[ "$relevance_validator_text" == *"Return classifications over the original finding records, not abbreviated replacement findings."* ]]
  [[ "$relevance_validator_text" == *"Return every raw finding field and standalone marker unchanged"* ]]

  [[ "$resolver_text" == *"\`Manual blocker\`, and \`Next human decision\`"* ]]
  [[ "$resolver_text" == *"manual blocker, and next human decision when available"* ]]
  [[ "$resolver_text" == *"Findings outside the filter are not processed and keep their existing \`Resolution status\` and \`Action taken\` fields unchanged"* ]]
  [[ "$resolver_text" == *"A finding skipped only because it was outside a previous severity filter remains eligible"* ]]
  [[ "$resolver_text" == *"Deferred — manual follow-up required; proposed resolution below."* ]]
  [[ "$resolver_text" == *"Also parse these canonical lifecycle fields when present: \`Recommended resolution\`, \`Alternatives\`, \`To proceed\`, \`Process handoff\`, \`Waiting on\`, \`Selected resolution\`, and \`Decision outcome\`."* ]]
  [[ "$resolver_text" == *"legacy manual deferral eligible for proposal backfill only"* ]]
  [[ "$resolver_text" == *"confirms its recorded \`Process handoff\` completed"* ]]
  [[ "$resolver_text" == *"reports its recorded \`Process handoff\` failed"* ]]
  [[ "$resolver_text" == *"Route a completed process handoff directly to the completed-decision replacement in Step 2d"* ]]
  [[ "$resolver_text" == *"reports that its recorded **Process handoff** failed"* ]]
  [[ "$resolver_text" == *"replace the failed handoff with either a corrected **Process handoff** or **Waiting on**"* ]]
  [[ "$resolver_text" == *"counts as the explicit reopen in Step 1: on that run, treat the chosen option as an explicit implementation payload and implement it when it is an in-scope"* ]]
  [[ "$resolver_text" == *"supplying the dependency counts as the explicit reopen in Step 1"* ]]
  [[ "$resolver_text" == *"retain **Selected resolution**, keep **Resolution status: open**, and record the failed attempt in **Action taken**"* ]]
  [[ "$resolver_text" == *"retry-eligible without asking for the same decision again"* ]]
  [[ "$resolver_text" == *"replace **To proceed** with **Selected resolution** and a concrete **Process handoff**"* ]]
  [[ "$resolver_text" == *"Keep the finding deferred until the process action is completed; when the user confirms completion, mark it addressed. Do not route an accepted process decision back through code implementation."* ]]
  [[ "$resolver_text" == *"Waiting on"* ]]
  [[ "$resolver_text" == *"apply the completed-decision replacement in \`references/resolution-output.md\`"* ]]
  [[ "$resolver_text" == *"Read \`references/resolution-output.md\` before writing or updating manual findings."* ]]
  [[ "$resolver_text" == *"Before generating or updating review output, read \`references/resolution-output.md\`"* ]]
  [[ "$resolver_output_text" == *"**Recommended resolution:**"* ]]
  [[ "$resolver_output_text" == *"every finding routed through Step 2d's manual-proposal flow"* ]]
  [[ "$resolver_output_text" == *"process-level external or legacy findings without an action class"* ]]
  [[ "$resolver_output_text" == *"**Alternatives:** (omit when no genuinely distinct option exists)"* ]]
  [[ "$resolver_output_text" == *"preserving that entry's field marker and indentation"* ]]
  [[ "$resolver_output_text" == *"exactly one next-step field that matches who can act"* ]]
  [[ "$resolver_output_text" == *"For a user-selectable code or process decision"* ]]
  [[ "$resolver_output_text" == *"accepted process decisions transition to \`Selected resolution\` and \`Process handoff\`"* ]]
  [[ "$resolver_output_text" == *"For an accepted process decision: record \`Selected resolution\`"* ]]
  [[ "$resolver_output_text" == *"**Waiting on:**"* ]]
  [[ "$resolver_output_text" == *"**Selected resolution:**"* ]]
  [[ "$resolver_output_text" == *"**Decision outcome:**"* ]]
  [[ "$resolver_output_text" == *"A selected code resolution becomes retry-eligible implementation state, not another pending decision."* ]]
  [[ "$resolver_output_text" == *"retain **Selected resolution**, keep **Resolution status: open**, and record the failed attempt in **Action taken**"* ]]
  [[ "$resolver_output_text" == *"Do not leave proposal-only fields on an addressed or acknowledged finding."* ]]
  [[ "$resolver_output_text" == *"R open selected-resolution retries or blocked implementations, A manual findings awaiting a user decision, P accepted process handoffs awaiting completion, and X manual findings waiting on an external owner"* ]]
  [[ "$resolver_output_text" == *'If the source review was `UX_REVIEW_OVERVIEW.md`'* ]]
  [[ "$resolver_output_text" == *"Findings present in the source but not addressed in this run"*'stay verbatim'* ]]
  [[ "$resolver_output_text" == *"#### Comment #N: [Brief description]"* ]]
  [[ "$resolver_output_text" == *"#### Finding #N: [Brief description]"* ]]
  [[ "$resolver_output_text" == *"#### Deferred: [Brief description]"* ]]
  [[ "$resolver_team_text" == *"Manual findings that Step 2d keeps unresolved or deferred are never assigned to resolver agents"* ]]
  [[ "$resolver_team_text" == *"Any manual finding that Step 2d classifies as implementation payload remains resolver-eligible"* ]]
  [[ "$resolver_team_text" == *"Step 2d is the canonical eligibility contract"* ]]
  [[ "$resolver_team_text" == *"If no resolver-eligible implementation candidates remain after the action-class gate"* ]]
  [[ "$resolver_team_text" == *"Do not prompt for a parallel plan or spawn resolver agents for a manual-only review."* ]]
  [[ "$resolver_text" != *"Findings outside the filter are skipped with **Resolution status: skipped**"* ]]
}

@test "verify-understanding supports answer option prompts" {
  local skill_text
  skill_text="$(cat "$BATS_TEST_DIRNAME/../skills/kramme:learn:verify-understanding/SKILL.md")"

  [[ "$skill_text" == *'[--answer-options|--choices]'* ]]
  [[ "$skill_text" == *'`--answer-options` or `--choices`: Prefer verification prompts with explicit answer options.'* ]]
  [[ "$skill_text" == *'After removing invocation options, use the remaining non-option text as the topic.'* ]]
  [[ "$skill_text" == *'still require the human to explain their choice before counting it as demonstrated understanding'* ]]
}

@test "siw transfer-to-linear gates duplicate issue content before creation" {
  local skill_text
  local mapping_text
  local extraction_text
  local docs_text

  skill_text="$(cat "$BATS_TEST_DIRNAME/../skills/kramme:siw:transfer-to-linear/SKILL.md")"
  mapping_text="$(cat "$BATS_TEST_DIRNAME/../skills/kramme:siw:transfer-to-linear/references/linear-mapping.md")"
  extraction_text="$(cat "$BATS_TEST_DIRNAME/../skills/kramme:siw:transfer-to-linear/references/artifact-extraction.md")"
  docs_text="$(cat "$BATS_TEST_DIRNAME/../docs/siw.md")"

  [[ "$skill_text" == *'Duplicate-content preflight per `references/linear-mapping.md`'* ]]
  [[ "$skill_text" == *'Cross-reference rewrite plan per `references/linear-mapping.md`'* ]]
  [[ "$skill_text" == *'Run the final duplicate-content preflight immediately before issue creation'* ]]
  [[ "$skill_text" == *'If any unresolved duplicate-content group is found, stop before creating any issue'* ]]

  [[ "$mapping_text" == *'**Duplicate content preflight**'* ]]
  [[ "$mapping_text" == *'do not silently `skip-existing` on content alone'* ]]
  [[ "$mapping_text" == *'Before creating Linear issues, run the duplicate-content preflight above against the final rewritten issue descriptions.'* ]]
  [[ "$mapping_text" == *'**Issue-to-issue references:**'* ]]
  [[ "$mapping_text" == *'DEV-123 (P4-001)'* ]]
  [[ "$mapping_text" == *'Do not rewrite IDs embedded in filenames, paths, URLs, markdown link destinations, inline code, fenced code, or source provenance lines'* ]]
  [[ "$mapping_text" == *'Do not rewrite the issue'\''s own canonical `- SIW ID: {id}` metadata line'* ]]
  [[ "$mapping_text" == *'Before assembling the Linear description, remove the source issue'\''s inline metadata line'* ]]
  [[ "$mapping_text" == *'Preserve escaped table pipes (`\|`)'* ]]

  [[ "$extraction_text" == *'Raw substantive body content for duplicate-content preflight.'* ]]
  [[ "$extraction_text" == *'Reference inventory from the body and metadata'* ]]
  [[ "$docs_text" == *'checks for duplicate issue content before creating Linear issues'* ]]
}

@test "fix-ci auto mode consolidates pipeline fix commits" {
  local skill_text
  local consolidation_text
  local scoped_plan_text
  skill_text="$(cat "$BATS_TEST_DIRNAME/../skills/kramme:pr:fix-ci/SKILL.md")"
  consolidation_text="$(cat "$BATS_TEST_DIRNAME/../skills/kramme:pr:fix-ci/references/consolidation-flow.md")"
  scoped_plan_text="$(cat "$BATS_TEST_DIRNAME/../skills/kramme:pr:fix-ci/references/scoped-plan.md")"

  [[ "$skill_text" == *'`--auto` - Run the CI fix loop unattended'* ]]
  [[ "$skill_text" == *'If `AUTO_MODE=true`, choose **Automated** without prompting'* ]]
  [[ "$skill_text" == *'**Skip this step if:** `--fixup` mode was used, or `--no-consolidate` flag is set.'* ]]
  [[ "$skill_text" != *'Alias for `--no-consolidate`'* ]]
  [[ "$skill_text" != *'`--no-consolidate` / `--auto` flag'* ]]
  [[ "$skill_text" == *'`--scope-plan <archived-plan>` - Reconstruct and enforce a plan-to-PR mutation boundary'* ]]
  [[ "$skill_text" == *'read `references/scoped-plan.md` completely'* ]]

  [[ "$scoped_plan_text" == *'SCOPED_PLAN_LIFECYCLE=initial'* ]]
  [[ "$scoped_plan_text" == *'SCOPED_PLAN_LIFECYCLE=recovery'* ]]
  [[ "$scoped_plan_text" == *'Before each edit, validate every intended path.'* ]]
  [[ "$scoped_plan_text" == *'Before every push, revalidate all committed paths'* ]]
  [[ "$scoped_plan_text" == *'immediately after every proven push replace the archived checkpoint head/tree'* ]]
  [[ "$scoped_plan_text" == *'$kramme:pr:fix-ci --no-consolidate --scope-plan {validated-scope-plan}'* ]]

  [[ "$consolidation_text" == *'If `AUTO_MODE=true`, do not offer "Keep separate".'* ]]
  [[ "$consolidation_text" == *'Before any automated rebase, confirm one of these is true:'* ]]
  [[ "$consolidation_text" == *'If `AUTO_MODE=true`, apply the pre-rebase safety gate above, then select **Automated**'* ]]
}

@test "scoped fix-ci lifecycle preserves valid state transitions" {
  local scoped_plan_text
  local classification_line
  local initial_removal_line
  local recovery_removal_line
  scoped_plan_text="$(cat "$BATS_TEST_DIRNAME/../skills/kramme:pr:fix-ci/references/scoped-plan.md")"

  classification_line="$(grep -nF 'After this classification, reject unknown, duplicate, or misplaced lifecycle sections.' <<<"$scoped_plan_text" | cut -d: -f1)"
  initial_removal_line="$(grep -nF 'In initial lifecycle, remove exactly the one workflow-state section' <<<"$scoped_plan_text" | cut -d: -f1)"
  recovery_removal_line="$(grep -nF 'In recovery lifecycle, remove exactly one workflow-state and one execution-result section.' <<<"$scoped_plan_text" | cut -d: -f1)"

  [ -n "$classification_line" ]
  [ "$classification_line" -eq "$initial_removal_line" ]
  [ "$classification_line" -eq "$recovery_removal_line" ]
  [[ "$scoped_plan_text" == *'In initial lifecycle, require its repository, base ref, head branch, and head OID'* ]]
  [[ "$scoped_plan_text" == *'In recovery lifecycle, require the execution result to record the exact Pull Request number and URL, repository, base ref, head branch, and head OID'* ]]
  [[ "$scoped_plan_text" == *'require the execution-result completion commit to equal the recorded workflow checkpoint before any recovery action'* ]]
  [[ "$scoped_plan_text" == *'Continue directly when `{live-head}` equals the recorded checkpoint. Otherwise, reject initial lifecycle immediately.'* ]]
  [[ "$scoped_plan_text" == *'atomically refresh both the workflow checkpoint head/tree and execution-result completion commit and Pull Request head OID'* ]]
  [[ "$scoped_plan_text" == *'In initial lifecycle mode, immediately after every proven push replace only the archived workflow-state checkpoint head/tree'* ]]
  [[ "$scoped_plan_text" == *'never adding an execution result'* ]]
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

@test "text contract inventory accepts a fully synchronized tree" {
  write_text_contract_inventory_fixture

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 0 ]
}

@test "text contract inventory rejects an unregistered marked copy" {
  write_text_contract_inventory_fixture
  write_file "$TMP_ROOT/contracts/unregistered.md" <<'EOF'
Canonical inventory marker: alpha
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"discovered unregistered contract copy: contracts/unregistered.md"* ]]
  [[ "$output" == *"registered inventory count 2 does not equal discovered count 3"* ]]
}

@test "text contract inventory rejects a missing registered copy" {
  write_text_contract_inventory_fixture
  rm "$TMP_ROOT/contracts/b.md"

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"registered path is missing: contracts/b.md"* ]]
  [[ "$output" == *"registered contract copy is not discoverable: contracts/b.md"* ]]
  [[ "$output" == *"registered inventory count 2 does not equal discovered count 1"* ]]
}

@test "text contract inventory still rejects divergent marked values" {
  write_text_contract_inventory_fixture
  write_file "$TMP_ROOT/contracts/b.md" <<'EOF'
Canonical inventory marker: beta
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"sample-inventoried-contract"* ]]
  [[ "$output" == *"differs"* ]]
}

@test "text contract inventory rejects duplicate markers in one copy" {
  write_text_contract_inventory_fixture
  write_file "$TMP_ROOT/contracts/b.md" <<'EOF'
Canonical inventory marker: alpha
Canonical inventory marker: alpha
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"contracts/b.md contains 2 inventory markers; expected exactly 1"* ]]
}

@test "siw spec exclusion inventory detects marker removal from every runtime copy" {
  local repo_root="$BATS_TEST_DIRNAME/../.."
  local source_registry="$BATS_TEST_DIRNAME/../scripts/synced-contracts.yaml"
  local fixture_root="$TMP_ROOT/siw-inventory"
  local fixture_registry="$fixture_root/registry.yaml"
  local expected_paths_file="$fixture_root/expected-paths.txt"
  local path

  mkdir -p "$fixture_root"
  siw_spec_exclusion_expected_paths >"$expected_paths_file"

  python3 - \
    "$source_registry" \
    "$repo_root" \
    "$fixture_root" \
    "$fixture_registry" \
    "$expected_paths_file" <<'PY'
import json
import pathlib
import shutil
import sys

source_registry, repo_root, fixture_root, fixture_registry, expected_paths_file = map(
    pathlib.Path, sys.argv[1:]
)
registry = json.loads(source_registry.read_text())
contract = next(
    item
    for item in registry["text_contracts"]
    if item["name"] == "siw-spec-exclusion-list"
)
expected_paths = expected_paths_file.read_text().splitlines()
if contract["paths"] != expected_paths:
    raise SystemExit("siw spec exclusion registry does not match the independent test inventory")
for relative in expected_paths:
    destination = fixture_root / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(repo_root / relative, destination)
(fixture_root / "registry.yaml").write_text(
    json.dumps(
        {
            "text_contracts": [contract],
            "mechanical": {"max_skill_lines": 10000},
        }
    )
)
PY

  while IFS= read -r path; do
    python3 - "$source_registry" "$repo_root/$path" "$fixture_root/$path" <<'PY'
import json
import pathlib
import sys

registry_path, source_path, fixture_path = map(pathlib.Path, sys.argv[1:])
contract = next(
    item
    for item in json.loads(registry_path.read_text())["text_contracts"]
    if item["name"] == "siw-spec-exclusion-list"
)
marker = contract["inventory"]["marker"]
text = source_path.read_text()
if text.count(marker) != 1:
    raise SystemExit(f"expected one canonical marker in {source_path}")
fixture_path.write_text(text.replace(marker, "Unsynchronized SIW spec-exclusion contract:", 1))
PY

    run python3 "$SCRIPT" --repo-root "$fixture_root" --registry "$fixture_registry"

    [ "$status" -eq 1 ]
    [[ "$output" == *"$path"* ]]
    cp "$repo_root/$path" "$fixture_root/$path"
  done <"$expected_paths_file"
}

@test "siw main spec ambiguity contract drift fails with precise contract name" {
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/a/SKILL.md" <<'EOF'
Synced SIW main-spec ambiguity contract (keep aligned across SIW spec detectors): when multiple spec candidates remain after deterministic heading/filename matching, auto mode stops with MISSING REQUIREMENT and interactive mode asks the user which file is the main spec.
EOF
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/b/SKILL.md" <<'EOF'
Synced SIW main-spec ambiguity contract (keep aligned across SIW spec detectors): when multiple spec candidates remain after deterministic heading/filename matching, auto mode picks the first candidate and interactive mode asks the user which file is the main spec.
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "text_contracts": [
    {
      "name": "siw-main-spec-ambiguity-rule",
      "extract_regex": "Synced SIW main-spec ambiguity contract \\(keep aligned across SIW spec detectors\\):\\s*(when multiple spec candidates remain after deterministic heading/filename matching, auto mode .*? and interactive mode asks the user which file is the main spec\\.)",
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
  [[ "$output" == *"siw-main-spec-ambiguity-rule"* ]]
  [[ "$output" == *"differs"* ]]
}

@test "siw main spec ambiguity contract covers issue implement team mode" {
  local registry_text
  registry_text="$(cat "$BATS_TEST_DIRNAME/../scripts/synced-contracts.yaml")"

  [[ "$registry_text" == *'"name": "siw-main-spec-ambiguity-rule"'* ]]
  [[ "$registry_text" == *'"kramme-cc-workflow/skills/kramme:siw:issue-implement/references/team-mode.md"'* ]]
}

@test "siw issue implement spec sync retains its handoff and topic routes" {
  local skill_text spec_sync_text
  skill_text="$(cat "$BATS_TEST_DIRNAME/../skills/kramme:siw:issue-implement/SKILL.md")"
  spec_sync_text="$(cat "$BATS_TEST_DIRNAME/../skills/kramme:siw:issue-implement/references/spec-sync.md")"

  [[ "$skill_text" == *'Read `references/spec-sync.md` and follow it for the classification categories, the spec routing rules'* ]]
  [[ "$spec_sync_text" == *'- Data model decisions → `*-data-model*.md`'* ]]
  [[ "$spec_sync_text" == *'- API decisions → `*-api*.md`'* ]]
  [[ "$spec_sync_text" == *'- Contract/interface decisions → `siw/contracts/*.md`'* ]]
  [[ "$spec_sync_text" == *'- UI/frontend decisions → `*-ui*.md` or `*-frontend*.md`'* ]]
  [[ "$spec_sync_text" == *'- Architecture decisions → `*-architecture*.md`'* ]]
  [[ "$spec_sync_text" == *'- User story updates → `*-user-stories*.md`'* ]]
  [[ "$spec_sync_text" == *'- Default → main spec if no matching supporting or contract spec'* ]]
}

@test "siw issue implement team mode makes the lead the sole shared-state writer" {
  local team_text
  team_text="$(cat "$BATS_TEST_DIRNAME/../skills/kramme:siw:issue-implement/references/team-mode.md")"

  [[ "$team_text" == *'The issue file, `siw/OPEN_ISSUES_OVERVIEW.md`, and `siw/LOG.md` are tracking state owned exclusively by the lead; treat all three as read-only.'* ]]
  [[ "$team_text" == *'`Issue ID`: canonical SIW ID'* ]]
  [[ "$team_text" == *'`Final status`: recommended IN REVIEW or DONE'* ]]
  [[ "$team_text" == *'`Resolution`: complete Markdown content for the issue file'* ]]
  [[ "$team_text" == *'`Log event`: one-line meaningful completion event for `Last Completed`'* ]]
  [[ "$team_text" == *'`Decisions`: decisions requiring spec or log synchronization, or `None`'* ]]
  [[ "$team_text" == *'Immediately before assigning any issue to a teammate — whether spawning a new teammate or reusing an idle one — the lead must claim that issue by publishing its `IN PROGRESS` transition **serially, one issue at a time**'* ]]
  [[ "$team_text" == *'maintain an `**Issue States:**` field that lists every issue assigned in this team session and its tracker-visible status'* ]]
  [[ "$team_text" == *'Do not assign the issue to its teammate until the status agrees across all three files.'* ]]
  [[ "$team_text" == *"For each Batch 2 issue, run the Step 5 claim procedure, then assign it to an idle teammate or spawn a new one."* ]]
  [[ "$team_text" == *'Never reuse an idle teammate before that issue is `IN PROGRESS` across all three tracking files.'* ]]
  [[ "$team_text" == *"do not rerun the standard workflow's IN PROGRESS Status Update Procedure"* ]]
  [[ "$team_text" == *"Do not run the standard workflow's Sync Decisions to Spec step"* ]]
  [[ "$team_text" == *'If a field is absent, is invalid for the assigned issue, or contradicts the verification results, reject the handoff'* ]]
  [[ "$team_text" == *'Review the `Decisions` in every accepted handoff before publishing any final status.'* ]]
  [[ "$team_text" == *'Do not publish an affected issue as `DONE` until its required spec synchronization completes or the user explicitly chooses to skip that update.'* ]]
  [[ "$team_text" == *'publish accepted handoffs **serially, one at a time**'* ]]
  [[ "$team_text" == *'Immediately before writing, re-read the issue file, `siw/OPEN_ISSUES_OVERVIEW.md`, and `siw/LOG.md`'* ]]
  [[ "$team_text" == *'verify the issue status agrees across them and that the log retains every completion and decision published so far'* ]]
  [[ "$team_text" == *'Preserve the exact `Log event` and non-`None` `Decisions` entries from every accepted handoff'* ]]
  [[ "$team_text" != *'Update ALL THREE tracking files atomically'* ]]
}

@test "siw issue implement team mode preserves interleaved worker completions" {
  run python3 - "$BATS_TEST_DIRNAME/../skills/kramme:siw:issue-implement/references/team-mode.md" <<'PY'
import pathlib
import sys

team_text = pathlib.Path(sys.argv[1]).read_text()
required_protocol = (
    "tracking state owned exclusively by the lead",
    "whether spawning a new teammate or reusing an idle one",
    "publishing its `IN PROGRESS` transition **serially, one issue at a time**",
    "Do not assign the issue to its teammate until the status agrees across all three files",
    "For each Batch 2 issue, run the Step 5 claim procedure",
    "Never reuse an idle teammate before that issue is `IN PROGRESS`",
    "Do not run the standard workflow's Sync Decisions to Spec step",
    "Review the `Decisions` in every accepted handoff before publishing any final status",
    "Do not publish an affected issue as `DONE` until its required spec synchronization completes",
    "publish accepted handoffs **serially, one at a time**",
    "Immediately before writing, re-read",
    "maintain an `**Issue States:**` field",
    "update only that issue's `Issue States` entry",
    "without discarding entries published for earlier handoffs",
    "retains every completion and decision published so far",
    "Preserve the exact `Log event` and non-`None` `Decisions` entries",
)
missing = [marker for marker in required_protocol if marker not in team_text]
if missing:
    raise SystemExit("missing serialized-publication guidance: " + ", ".join(missing))

# The lead claims each issue serially before spawning it. Both workers then
# finish from revision 2 and return handoffs rather than writing tracking state;
# the lead re-reads and publishes all three tracking files serially.
shared = {
    "revision": 0,
    "issue_status": {},
    "overview": {},
    "log_status": {},
    "log_events": [],
    "decisions": [],
}
for issue_id in ("P1-001", "P1-002"):
    current = shared.copy()
    current["issue_status"] = shared["issue_status"].copy()
    current["overview"] = shared["overview"].copy()
    current["log_status"] = shared["log_status"].copy()
    current["log_events"] = shared["log_events"].copy()
    current["decisions"] = shared["decisions"].copy()
    current["issue_status"][issue_id] = "IN PROGRESS"
    current["overview"][issue_id] = "IN PROGRESS"
    current["log_status"][issue_id] = "IN PROGRESS"
    current["revision"] += 1
    shared = current

assert shared["overview"] == {
    "P1-001": "IN PROGRESS",
    "P1-002": "IN PROGRESS",
}
assert shared["issue_status"] == shared["overview"]
assert shared["issue_status"] == shared["log_status"]
assert shared["revision"] == 2

handoffs = [
    {
        "Issue ID": "P1-002",
        "Final status": "IN REVIEW",
        "Resolution": "Implemented beta",
        "Log event": "P1-002 implementation completed",
        "Decisions": "Use beta compatibility mode",
        "worker_revision": 2,
    },
    {
        "Issue ID": "P1-001",
        "Final status": "DONE",
        "Resolution": "Implemented alpha",
        "Log event": "P1-001 implementation completed",
        "Decisions": "None",
        "worker_revision": 2,
    },
]

for handoff in handoffs:
    current = shared.copy()
    current["issue_status"] = shared["issue_status"].copy()
    current["overview"] = shared["overview"].copy()
    current["log_status"] = shared["log_status"].copy()
    current["log_events"] = shared["log_events"].copy()
    current["decisions"] = shared["decisions"].copy()
    current["issue_status"][handoff["Issue ID"]] = handoff["Final status"]
    current["overview"][handoff["Issue ID"]] = handoff["Final status"]
    current["log_status"][handoff["Issue ID"]] = handoff["Final status"]
    current["log_events"].append(handoff["Log event"])
    if handoff["Decisions"] != "None":
        current["decisions"].append(handoff["Decisions"])
    current["revision"] += 1
    shared = current

assert shared["overview"] == {"P1-002": "IN REVIEW", "P1-001": "DONE"}
assert shared["issue_status"] == shared["overview"]
assert shared["issue_status"] == shared["log_status"]
assert shared["log_events"] == [
    "P1-002 implementation completed",
    "P1-001 implementation completed",
]
assert shared["decisions"] == ["Use beta compatibility mode"]
assert shared["revision"] == 4

# Final session summarization preserves the accepted handoff records instead
# of rebuilding them from generic issue titles or cross-cutting decisions only.
summary = shared.copy()
summary["log_events"] = shared["log_events"].copy()
summary["decisions"] = shared["decisions"].copy()
summary["quick_summary"] = "Parallel implementation of 2 issues"
summary["completed_this_session"] = ["P1-002", "P1-001"]
assert summary["log_events"] == shared["log_events"]
assert summary["decisions"] == shared["decisions"]
PY

  [ "$status" -eq 0 ]
}

@test "siw issue creators share the same final-boundary reservation protocol" {
  local issue_define_text generate_phases_text publication_recovery_text generate_phases_contract_text tracker_schema_text
  issue_define_text="$(cat "$BATS_TEST_DIRNAME/../skills/kramme:siw:issue-define/SKILL.md")"
  generate_phases_text="$(cat "$BATS_TEST_DIRNAME/../skills/kramme:siw:generate-phases/SKILL.md")"
  publication_recovery_text="$(cat "$BATS_TEST_DIRNAME/../skills/kramme:siw:generate-phases/references/publication-recovery.md")"
  generate_phases_contract_text="${generate_phases_text}"$'\n'"${publication_recovery_text}"
  tracker_schema_text="$(cat "$BATS_TEST_DIRNAME/../skills/kramme:siw:issue-define/references/tracker-schema.md")"

  cmp -s "$ISSUE_DEFINE_RESERVATION_HELPER" "$GENERATE_PHASES_RESERVATION_HELPER"
  [ -x "$ISSUE_DEFINE_RESERVATION_HELPER" ]
  [ -x "$GENERATE_PHASES_RESERVATION_HELPER" ]

  [[ "$generate_phases_text" == *'Before approving replacement, read `references/publication-recovery.md`'* ]]
  [[ "$generate_phases_text" == *'Before Phase 6 performs its first mutation, read `references/publication-recovery.md`'* ]]

  for skill_text in "$issue_define_text" "$generate_phases_contract_text"; do
    [[ "$skill_text" == *'scripts/siw-issue-reservation.sh'* ]]
    [[ "$skill_text" == *'serializes its own invocations'* ]]
    [[ "$skill_text" == *'operation claim is reclaimed only after its recorded process no longer exists'* ]]
    [[ "$skill_text" == *'Immediately before the first mutation'* ]]
    [[ "$skill_text" == *'owner-bound baseline manifest'* ]]
    [[ "$skill_text" == *'collision-resistant owner token'* ]]
    [[ "$skill_text" == *'sh <helper> new-owner'* ]]
    [[ "$skill_text" == *'publish-receipt siw <owner-token>'* ]]
    [[ "$skill_text" == *'verify-receipt siw <owner-token>'* ]]
    [[ "$skill_text" == *'legacy-only zero-ID recovery receipt'* ]]
    [[ "$skill_text" == *'legacy lock with an owned reservation'*'reject'* ]]
    [[ "$skill_text" == *'every ID whose issue file, overview row, or log entry changed since acquisition'* ]]
    [[ "$skill_text" == *'separate normal-path `verify-receipt`'*'unnecessary'* ]]
    [[ "$skill_text" == *"During normal contention, never copy or reuse a token"* ]]
    [[ "$skill_text" == *"A later recovery session may use the retained token only after the user explicitly confirms"* ]]
    [[ "$skill_text" == *'without exposing its token'* ]]
    [[ "$skill_text" == *'Never publish from the'*'snapshot'* ]]
    [[ "$skill_text" == *'retries collisions with exclusive atomic claims'* ]]
    [[ "$skill_text" == *'Never delete a reservation based on age or filename'* ]]
    [[ "$skill_text" == *"never clean up a different owner's token"* ]]
  done

  [[ "$issue_define_text" == *'Phase 6 may advance it if another creator publishes first'* ]]
  [[ "$issue_define_text" == *'reserve siw <issue-prefix> <owner-token> 100 issue-create'* ]]
  [[ "$issue_define_text" == *'In IMPROVE MODE no ID reservation exists'*'run only `release-publication`'* ]]
  [[ "$issue_define_text" == *'IMPROVE_BASE_HASH'* ]]
  [[ "$issue_define_text" == *'Compare both its path and hash with the stored interview base'* ]]
  [[ "$issue_define_text" == *'Conflicting edits always require approval'* ]]
  [[ "$publication_recovery_text" == *'Build the complete provisional-to-final map'* ]]
  [[ "$publication_recovery_text" == *'reserve-batch siw <prefix> <owner-token> 100 <provisional-id>...'* ]]
  [[ "$publication_recovery_text" == *'release-batch siw <owner-token> <final-issue-id>...'* ]]
  [[ "$publication_recovery_text" == *'update filenames, headings, dependencies, related IDs, overview rows, and log ranges before writing'* ]]
  [[ "$publication_recovery_text" == *'REPLACE_APPROVED_SNAPSHOT'*'git hash-object'* ]]
  [[ "$publication_recovery_text" == *'compare it with `REPLACE_APPROVED_SNAPSHOT`, regardless of `git status`'* ]]
  [[ "$publication_recovery_text" == *'replacement issue path must be a non-symlink regular file'* ]]
  [[ "$publication_recovery_text" == *'path_hash="$(git hash-object "$path")" || exit 1'* ]]
  [[ "$publication_recovery_text" == *'separate sort defined in the `Replacement approval snapshot` section above'* ]]
  [[ "$publication_recovery_text" == *'release-publication siw <owner-token>'*'because no replacement IDs have been reserved yet'* ]]
  [[ "$publication_recovery_text" == *'reacquire with the retained token'*'recompute the snapshot'* ]]
  [[ "$publication_recovery_text" == *'REMOVED_ISSUE_IDS'* ]]
  [[ "$publication_recovery_text" == *'append every `REMOVED_ISSUE_IDS` value after the final IDs'* ]]
  [[ "$publication_recovery_text" == *'release only the completed final-ID reservations'* ]]
  [[ "$publication_recovery_text" == *'failed multi-ID reservation attempt must unwind every exact reservation created by that attempt'* ]]
  [[ "$publication_recovery_text" == *'Once replacement deletion starts, never abandon any replacement reservation'* ]]
  [[ "$publication_recovery_text" == *'batches all issue-file digests within each immutable operation snapshot'* ]]
  [[ "$tracker_schema_text" == *'Phase 6 Step 3'* ]]
  [[ "$tracker_schema_text" != *'ask the user whether'* ]]
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

@test "synced file generator accepts explicit canonical metadata in any path position" {
  write_file "$TMP_ROOT/files/canonical.txt" <<'EOF'
same
EOF
  write_file "$TMP_ROOT/files/mirror.txt" <<'EOF'
same
EOF
  chmod 755 "$TMP_ROOT/files/canonical.txt" "$TMP_ROOT/files/mirror.txt"
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "file_identity_groups": [
    {
      "name": "sample-files",
      "canonical": "files/canonical.txt",
      "paths": [
        "files/mirror.txt",
        "files/canonical.txt"
      ]
    }
  ]
}
EOF

  run python3 "$SYNCED_FILES_GENERATOR" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 0 ]
  [[ "$output" == *"declared file mirrors are in sync."* ]]

  run python3 "$SYNCED_FILES_GENERATOR" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml" --check

  [ "$status" -eq 0 ]
  [[ "$output" == *"declared file mirrors are in sync."* ]]
}

@test "synced file generator check reports content mode and missing drift without writes" {
  write_file "$TMP_ROOT/files/canonical.txt" <<'EOF'
canonical
EOF
  write_file "$TMP_ROOT/files/content.txt" <<'EOF'
drifted
EOF
  write_file "$TMP_ROOT/files/mode.txt" <<'EOF'
canonical
EOF
  chmod 755 "$TMP_ROOT/files/canonical.txt" "$TMP_ROOT/files/content.txt"
  chmod 644 "$TMP_ROOT/files/mode.txt"
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "file_identity_groups": [
    {
      "name": "sample-files",
      "canonical": "files/canonical.txt",
      "paths": [
        "files/canonical.txt",
        "files/content.txt",
        "files/mode.txt",
        "files/missing/nested.txt"
      ]
    }
  ]
}
EOF

  run python3 "$SYNCED_FILES_GENERATOR" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"sample-files"* ]]
  [[ "$output" == *"files/content.txt content differs from canonical files/canonical.txt"* ]]
  [[ "$output" == *"files/mode.txt mode 0644 differs from canonical mode 0755"* ]]
  [[ "$output" == *"files/missing/nested.txt is missing"* ]]
  [ "$(cat "$TMP_ROOT/files/content.txt")" = "drifted" ]
  [ "$(file_mode "$TMP_ROOT/files/mode.txt")" = "0644" ]
  [ ! -e "$TMP_ROOT/files/missing/nested.txt" ]

  run python3 "$SYNCED_FILES_GENERATOR" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml" --check

  [ "$status" -eq 1 ]
  [ "$(cat "$TMP_ROOT/files/content.txt")" = "drifted" ]
  [ "$(file_mode "$TMP_ROOT/files/mode.txt")" = "0644" ]
  [ ! -e "$TMP_ROOT/files/missing/nested.txt" ]
}

@test "synced file generator write copies canonical bytes and mode to declared mirrors" {
  write_file "$TMP_ROOT/files/canonical.txt" <<'EOF'
canonical
EOF
  write_file "$TMP_ROOT/files/content.txt" <<'EOF'
drifted
EOF
  write_file "$TMP_ROOT/files/mode.txt" <<'EOF'
canonical
EOF
  chmod 755 "$TMP_ROOT/files/canonical.txt" "$TMP_ROOT/files/content.txt"
  chmod 644 "$TMP_ROOT/files/mode.txt"
  local canonical_hash
  canonical_hash="$(shasum -a 256 "$TMP_ROOT/files/canonical.txt")"
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "file_identity_groups": [
    {
      "name": "sample-files",
      "canonical": "files/canonical.txt",
      "paths": [
        "files/canonical.txt",
        "files/content.txt",
        "files/mode.txt",
        "files/missing/nested.txt"
      ]
    }
  ]
}
EOF

  run python3 "$SYNCED_FILES_GENERATOR" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml" --write

  [ "$status" -eq 0 ]
  [[ "$output" == *"synced 3 file mirror(s)."* ]]
  [ "$(shasum -a 256 "$TMP_ROOT/files/canonical.txt")" = "$canonical_hash" ]
  cmp -s "$TMP_ROOT/files/canonical.txt" "$TMP_ROOT/files/content.txt"
  cmp -s "$TMP_ROOT/files/canonical.txt" "$TMP_ROOT/files/mode.txt"
  cmp -s "$TMP_ROOT/files/canonical.txt" "$TMP_ROOT/files/missing/nested.txt"
  [ "$(file_mode "$TMP_ROOT/files/content.txt")" = "0755" ]
  [ "$(file_mode "$TMP_ROOT/files/mode.txt")" = "0755" ]
  [ "$(file_mode "$TMP_ROOT/files/missing/nested.txt")" = "0755" ]
}

@test "synced file generator write replaces a read-only mirror" {
  write_file "$TMP_ROOT/files/canonical.txt" <<'EOF'
canonical
EOF
  write_file "$TMP_ROOT/files/mirror.txt" <<'EOF'
canonical
EOF
  chmod 755 "$TMP_ROOT/files/canonical.txt"
  chmod 444 "$TMP_ROOT/files/mirror.txt"
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "file_identity_groups": [
    {
      "name": "sample-files",
      "canonical": "files/canonical.txt",
      "paths": [
        "files/canonical.txt",
        "files/mirror.txt"
      ]
    }
  ]
}
EOF

  run python3 "$SYNCED_FILES_GENERATOR" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml" --write

  [ "$status" -eq 0 ]
  [[ "$output" == *"synced 1 file mirror(s)."* ]]
  cmp -s "$TMP_ROOT/files/canonical.txt" "$TMP_ROOT/files/mirror.txt"
  [ "$(file_mode "$TMP_ROOT/files/mirror.txt")" = "0755" ]
}

@test "synced file generator rejects invalid canonical metadata before writes" {
  write_file "$TMP_ROOT/files/canonical.txt" <<'EOF'
canonical
EOF
  write_file "$TMP_ROOT/files/mirror.txt" <<'EOF'
drifted
EOF

  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "file_identity_groups": [
    {
      "name": "missing-canonical",
      "paths": ["files/canonical.txt", "files/mirror.txt"]
    }
  ]
}
EOF
  run python3 "$SYNCED_FILES_GENERATOR" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml" --write
  [ "$status" -eq 1 ]
  [[ "$output" == *"canonical must be a non-empty string"* ]]
  [ "$(cat "$TMP_ROOT/files/mirror.txt")" = "drifted" ]

  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "file_identity_groups": [
    {
      "name": "non-member-canonical",
      "canonical": "files/other.txt",
      "paths": ["files/canonical.txt", "files/mirror.txt"]
    }
  ]
}
EOF
  run python3 "$SYNCED_FILES_GENERATOR" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml" --write
  [ "$status" -eq 1 ]
  [[ "$output" == *"canonical path must appear exactly once in paths"* ]]
  [ "$(cat "$TMP_ROOT/files/mirror.txt")" = "drifted" ]

  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "file_identity_groups": [
    {
      "name": "duplicate-paths",
      "canonical": "files/canonical.txt",
      "paths": [
        "files/canonical.txt",
        "files/canonical.txt",
        "files/mirror.txt"
      ]
    }
  ]
}
EOF
  run python3 "$SYNCED_FILES_GENERATOR" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml" --write
  [ "$status" -eq 1 ]
  [[ "$output" == *"paths must not contain duplicates"* ]]
  [ "$(cat "$TMP_ROOT/files/mirror.txt")" = "drifted" ]
}

@test "synced file generator rejects paths shared across identity groups" {
  write_file "$TMP_ROOT/files/first.txt" <<'EOF'
first
EOF
  write_file "$TMP_ROOT/files/second.txt" <<'EOF'
second
EOF
  write_file "$TMP_ROOT/files/shared.txt" <<'EOF'
unchanged
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "file_identity_groups": [
    {
      "name": "first-group",
      "canonical": "files/first.txt",
      "paths": ["files/first.txt", "files/shared.txt"]
    },
    {
      "name": "second-group",
      "canonical": "files/second.txt",
      "paths": ["files/second.txt", "files/shared.txt"]
    }
  ]
}
EOF

  run python3 "$SYNCED_FILES_GENERATOR" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml" --write

  [ "$status" -eq 1 ]
  [[ "$output" == *"second-group: path files/shared.txt is already registered in group first-group"* ]]
  [ "$(cat "$TMP_ROOT/files/shared.txt")" = "unchanged" ]
}

@test "synced file generator rejects absolute and traversal paths before writes" {
  write_file "$TMP_ROOT/files/canonical.txt" <<'EOF'
canonical
EOF
  write_file "$TMP_ROOT/files/mirror.txt" <<'EOF'
drifted
EOF
  write_file "$TMP_ROOT/outside.txt" <<'EOF'
outside
EOF
  write_file "$TMP_ROOT/registry.yaml" <<EOF
{
  "file_identity_groups": [
    {
      "name": "valid-first",
      "canonical": "files/canonical.txt",
      "paths": ["files/canonical.txt", "files/mirror.txt"]
    },
    {
      "name": "absolute-path",
      "canonical": "$TMP_ROOT/outside.txt",
      "paths": ["$TMP_ROOT/outside.txt", "files/absolute-mirror.txt"]
    },
    {
      "name": "traversal-path",
      "canonical": "../outside.txt",
      "paths": ["../outside.txt", "files/traversal-mirror.txt"]
    }
  ]
}
EOF

  run python3 "$SYNCED_FILES_GENERATOR" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml" --write

  [ "$status" -eq 1 ]
  [[ "$output" == *"absolute paths are not allowed"* ]]
  [[ "$output" == *"parent traversal is not allowed"* ]]
  [ "$(cat "$TMP_ROOT/files/mirror.txt")" = "drifted" ]
  [ "$(cat "$TMP_ROOT/outside.txt")" = "outside" ]
  [ ! -e "$TMP_ROOT/files/absolute-mirror.txt" ]
  [ ! -e "$TMP_ROOT/files/traversal-mirror.txt" ]
}

@test "synced file generator rejects symlinks and non-regular files before writes" {
  write_file "$TMP_ROOT/files/canonical.txt" <<'EOF'
canonical
EOF
  write_file "$TMP_ROOT/files/mirror.txt" <<'EOF'
drifted
EOF
  write_file "$TMP_ROOT/files/symlink-ancestor-canonical.txt" <<'EOF'
canonical
EOF
  write_file "$TMP_ROOT/files/directory-canonical.txt" <<'EOF'
canonical
EOF
  write_file "$TMP_ROOT/files/fifo-canonical.txt" <<'EOF'
canonical
EOF
  write_file "$TMP_ROOT/outside/source.txt" <<'EOF'
outside
EOF
  write_file "$TMP_ROOT/outside/target.txt" <<'EOF'
outside target
EOF
  mkdir -p "$TMP_ROOT/links" "$TMP_ROOT/files/directory.txt"
  ln -s "$TMP_ROOT/outside/source.txt" "$TMP_ROOT/links/source.txt"
  ln -s "$TMP_ROOT/outside" "$TMP_ROOT/linked-parent"
  mkfifo "$TMP_ROOT/files/fifo.txt"
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "file_identity_groups": [
    {
      "name": "valid-first",
      "canonical": "files/canonical.txt",
      "paths": ["files/canonical.txt", "files/mirror.txt"]
    },
    {
      "name": "symlink-source",
      "canonical": "links/source.txt",
      "paths": ["links/source.txt", "files/symlink-mirror.txt"]
    },
    {
      "name": "symlink-ancestor",
      "canonical": "files/symlink-ancestor-canonical.txt",
      "paths": ["files/symlink-ancestor-canonical.txt", "linked-parent/target.txt"]
    },
    {
      "name": "directory-mirror",
      "canonical": "files/directory-canonical.txt",
      "paths": ["files/directory-canonical.txt", "files/directory.txt"]
    },
    {
      "name": "fifo-mirror",
      "canonical": "files/fifo-canonical.txt",
      "paths": ["files/fifo-canonical.txt", "files/fifo.txt"]
    }
  ]
}
EOF

  run python3 "$SYNCED_FILES_GENERATOR" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml" --write

  [ "$status" -eq 1 ]
  [[ "$output" == *"must not be a symlink"* ]]
  [[ "$output" == *"must be a regular file"* ]]
  [ "$(cat "$TMP_ROOT/files/mirror.txt")" = "drifted" ]
  [ "$(cat "$TMP_ROOT/outside/target.txt")" = "outside target" ]
  [ ! -e "$TMP_ROOT/files/symlink-mirror.txt" ]
}

@test "synced file generator current registry governs the SIW helper mirror" {
  local registry="$BATS_TEST_DIRNAME/../scripts/synced-contracts.yaml"
  local issue_define_rel="kramme-cc-workflow/skills/kramme:siw:issue-define/scripts/siw-issue-reservation.sh"
  local generate_phases_rel="kramme-cc-workflow/skills/kramme:siw:generate-phases/scripts/siw-issue-reservation.sh"

  run jq -e \
    --arg canonical "$issue_define_rel" \
    --arg mirror "$generate_phases_rel" \
    '.file_identity_groups[] | select(.name == "siw-issue-reservation-helper") | .canonical == $canonical and (.paths | index($canonical) != null) and (.paths | index($mirror) != null)' \
    "$registry"

  [ "$status" -eq 0 ]
  [ "$output" = "true" ]

  run python3 "$SYNCED_FILES_GENERATOR" --check

  [ "$status" -eq 0 ]
  [[ "$output" == *"declared file mirrors are in sync."* ]]
}

@test "visual shared asset generator check succeeds for matching copies" {
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/kramme:visual:a/references/shared.md" <<'EOF'
same
EOF
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/kramme:visual:b/references/shared.md" <<'EOF'
same
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "file_identity_groups": [
    {
      "name": "visual-fixture-shared",
      "canonical": "kramme-cc-workflow/skills/kramme:visual:a/references/shared.md",
      "paths": [
        "kramme-cc-workflow/skills/kramme:visual:a/references/shared.md",
        "kramme-cc-workflow/skills/kramme:visual:b/references/shared.md"
      ]
    }
  ]
}
EOF

  run python3 "$VISUAL_GENERATOR" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml" --check

  [ "$status" -eq 0 ]
  [[ "$output" == *"visual shared assets are in sync."* ]]
}

@test "visual shared asset generator check reports drift" {
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/kramme:visual:a/references/shared.md" <<'EOF'
canonical
EOF
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/kramme:visual:b/references/shared.md" <<'EOF'
drifted
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "file_identity_groups": [
    {
      "name": "visual-fixture-shared",
      "canonical": "kramme-cc-workflow/skills/kramme:visual:a/references/shared.md",
      "paths": [
        "kramme-cc-workflow/skills/kramme:visual:a/references/shared.md",
        "kramme-cc-workflow/skills/kramme:visual:b/references/shared.md"
      ]
    }
  ]
}
EOF

  run python3 "$VISUAL_GENERATOR" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml" --check

  [ "$status" -eq 1 ]
  [[ "$output" == *"visual shared asset sync check failed:"* ]]
  [[ "$output" == *"visual-fixture-shared"* ]]
  [[ "$output" == *"differs from canonical"* ]]
  [[ "$output" == *"generate-visual-shared-assets.py --write"* ]]
}

@test "visual shared asset generator write syncs from canonical copy" {
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/kramme:visual:a/references/shared.md" <<'EOF'
canonical
EOF
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/kramme:visual:b/references/shared.md" <<'EOF'
drifted
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "file_identity_groups": [
    {
      "name": "visual-fixture-shared",
      "canonical": "kramme-cc-workflow/skills/kramme:visual:a/references/shared.md",
      "paths": [
        "kramme-cc-workflow/skills/kramme:visual:a/references/shared.md",
        "kramme-cc-workflow/skills/kramme:visual:b/references/shared.md"
      ]
    }
  ]
}
EOF

  run python3 "$VISUAL_GENERATOR" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml" --write

  [ "$status" -eq 0 ]
  [[ "$output" == *"synced 1 visual shared asset file(s)."* ]]
  [ "$(cat "$TMP_ROOT/kramme-cc-workflow/skills/kramme:visual:b/references/shared.md")" = "canonical" ]
}

@test "visual shared asset generator ignores non-visual identity groups" {
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/kramme:visual:a/references/shared.md" <<'EOF'
visual
EOF
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/kramme:visual:b/references/shared.md" <<'EOF'
visual
EOF
  write_file "$TMP_ROOT/policy/canonical.md" <<'EOF'
policy
EOF
  write_file "$TMP_ROOT/policy/mirror.md" <<'EOF'
drifted
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "file_identity_groups": [
    {
      "name": "policy-files",
      "canonical": "policy/canonical.md",
      "paths": ["policy/canonical.md", "policy/mirror.md"]
    },
    {
      "name": "visual-fixture-shared",
      "canonical": "kramme-cc-workflow/skills/kramme:visual:a/references/shared.md",
      "paths": [
        "kramme-cc-workflow/skills/kramme:visual:a/references/shared.md",
        "kramme-cc-workflow/skills/kramme:visual:b/references/shared.md"
      ]
    }
  ]
}
EOF

  run python3 "$VISUAL_GENERATOR" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml" --write

  [ "$status" -eq 0 ]
  [[ "$output" == *"visual shared assets are in sync."* ]]
  [ "$(cat "$TMP_ROOT/policy/mirror.md")" = "drifted" ]
}

@test "required file contract accepts frontmatter and required text" {
  write_minimal_skill "$TMP_ROOT/kramme-cc-workflow/skills/a/SKILL.md" $'PLAN ROUTE: direct\nMISSING REQUIREMENT'
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "required_file_contracts": [
    {
      "name": "sample-required-file-contract",
      "path": "kramme-cc-workflow/skills/a/SKILL.md",
      "frontmatter": {
        "name": "test-skill",
        "user-invocable": "true"
      },
      "contains": [
        "PLAN ROUTE:",
        "MISSING REQUIREMENT"
      ]
    }
  ]
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 0 ]
  [[ "$output" == *"skill contract lint passed."* ]]
}

@test "required file contract frontmatter drift fails with precise field" {
  write_minimal_skill "$TMP_ROOT/kramme-cc-workflow/skills/a/SKILL.md" "PLAN ROUTE: direct"
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "required_file_contracts": [
    {
      "name": "sample-required-file-contract",
      "path": "kramme-cc-workflow/skills/a/SKILL.md",
      "frontmatter": {
        "name": "expected-skill"
      },
      "contains": [
        "PLAN ROUTE:"
      ]
    }
  ]
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"sample-required-file-contract"* ]]
  [[ "$output" == *"frontmatter field 'name' expected 'expected-skill'"* ]]
}

@test "required file contract missing marker fails" {
  write_minimal_skill "$TMP_ROOT/kramme-cc-workflow/skills/a/SKILL.md" "PLAN ROUTE: direct"
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "required_file_contracts": [
    {
      "name": "sample-required-file-contract",
      "path": "kramme-cc-workflow/skills/a/SKILL.md",
      "contains": [
        "MISSING REQUIREMENT"
      ]
    }
  ]
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"sample-required-file-contract"* ]]
  [[ "$output" == *"is missing required text 'MISSING REQUIREMENT'"* ]]
}

@test "migrated guidance contracts stay registered" {
  run python3 - "$BATS_TEST_DIRNAME/../scripts/synced-contracts.yaml" <<'PY'
import json
import pathlib
import sys

registry = json.loads(pathlib.Path(sys.argv[1]).read_text())
registered = {contract["name"] for contract in registry.get("required_file_contracts", [])}
required = {
    "pr-create-gh-prevalidation",
    "pr-create-description-generation-contract",
    "pr-create-linear-id-normalization",
    "pr-create-branch-linear-state",
    "pr-create-body-file-contract",
    "pr-create-edit-loop-linear-normalization",
    "pr-create-state-restoration-contract",
    "pr-generate-description-subskill-contract",
    "pr-generate-description-main-guidance",
    "pr-generate-description-template-discovery",
    "pr-generate-description-template-and-test-plan-rules",
    "pr-generate-description-section-template-rules",
    "pr-generate-description-output-cleanliness",
    "pr-generate-description-antipattern-examples",
    "pr-generate-description-red-flag-examples",
    "pr-generate-description-visual-capture-safety",
    "pr-generate-description-direct-update-safety",
    "pr-plan-reconcile-safety",
    "pr-plan-reconcile-migration-guidance",
    "pr-plan-split-reconcile-scope",
    "linear-issue-implement-reference-mapping",
    "linear-issue-implement-display-template",
    "linear-issue-implement-plan-template",
    "linear-issue-implement-readme-note",
    "visual-demo-reel-guidance",
    "visual-demo-reel-capture-tiers",
    "visual-demo-reel-source-manifest",
    "code-optimize-shell-permission",
    "code-optimize-source-manifest",
    "workflow-artifact-cleanup-names",
}
missing = sorted(required - registered)
if missing:
    raise SystemExit("missing migrated contracts: " + ", ".join(missing))

reconcile_path = (
    "kramme-cc-workflow/skills/kramme:code:breakdown-findings/"
    "references/reconcile-workflow.md"
)
base_diff_paths = set(registry.get("base_diff_scope", {}).get("paths", []))
if reconcile_path not in base_diff_paths:
    raise SystemExit("reconcile workflow is missing from base_diff_scope paths")
PY

  [ "$status" -eq 0 ]
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
COLLECT_ARGS=(--strict --format json)
[ -n "${BASE_BRANCH_OVERRIDE:-}" ] && COLLECT_ARGS+=(--base "$BASE_BRANCH_OVERRIDE")

RESOLVED=$(${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh "${COLLECT_ARGS[@]}") || {
  echo "Base/diff collection failed; see the message above and stop." >&2
  exit 1
}

parse_review_diff_json() {
  local field="$1"
  REVIEW_DIFF_JSON="$RESOLVED" REVIEW_DIFF_FIELD="$field" python3 - <<'PY'
import json
PY
}

BASE_REF=$(parse_review_diff_json base_ref) || exit 1
BASE_BRANCH=$(parse_review_diff_json base_branch) || exit 1
MERGE_BASE=$(parse_review_diff_json merge_base) || exit 1
CHANGED_FILES=$(parse_review_diff_json changed_files) || exit 1
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
COLLECT_ARGS=(--strict --format json)
[ -n "${BASE_BRANCH_OVERRIDE:-}" ] && COLLECT_ARGS+=(--base "$BASE_BRANCH_OVERRIDE")

RESOLVED=$(${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh "${COLLECT_ARGS[@]}") || {
  echo "Base/diff collection failed; see the message above and stop." >&2
  exit 2
}

parse_review_diff_json() {
  local field="$1"
  REVIEW_DIFF_JSON="$RESOLVED" REVIEW_DIFF_FIELD="$field" python3 - <<'PY'
import json
PY
}

BASE_REF=$(parse_review_diff_json base_ref) || exit 1
BASE_BRANCH=$(parse_review_diff_json base_branch) || exit 1
MERGE_BASE=$(parse_review_diff_json merge_base) || exit 1
CHANGED_FILES=$(parse_review_diff_json changed_files) || exit 1
```
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "text_contracts": [
    {
      "name": "sample-multiline-text-contract",
      "extract_regex": "(?s)(COLLECT_ARGS=\\(--strict --format json\\).*?CHANGED_FILES=\\$\\(parse_review_diff_json changed_files\\) \\|\\| exit 1)",
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
COLLECT_ARGS=(--strict --format json)
[ -n "${BASE_BRANCH_OVERRIDE:-}" ] && COLLECT_ARGS+=(--base "$BASE_BRANCH_OVERRIDE")

RESOLVED=$(${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh "${COLLECT_ARGS[@]}") || {
  echo "Base/diff collection failed; see the message above and stop." >&2
  exit 1
}

parse_review_diff_json() {
  local field="$1"
  REVIEW_DIFF_JSON="$RESOLVED" REVIEW_DIFF_FIELD="$field" python3 - <<'PY'
import json
PY
}

BASE_REF=$(parse_review_diff_json base_ref) || exit 1
BASE_BRANCH=$(parse_review_diff_json base_branch) || exit 1
MERGE_BASE=$(parse_review_diff_json merge_base) || exit 1
CHANGED_FILES=$(parse_review_diff_json changed_files) || exit 1
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
COLLECT_ARGS=(--strict --format json)
[ -n "${BASE_BRANCH_OVERRIDE:-}" ] && COLLECT_ARGS+=(--base "$BASE_BRANCH_OVERRIDE")

RESOLVED=$(${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh "${COLLECT_ARGS[@]}") || {
  echo "Base/diff collection failed; see the message above and stop." >&2
  exit 1
}

parse_review_diff_json() {
  local field="$1"
  REVIEW_DIFF_JSON="$RESOLVED" REVIEW_DIFF_FIELD="$field" python3 - <<'PY'
import json
PY
}

BASE_REF=$(parse_review_diff_json base_ref) || exit 1
BASE_BRANCH=$(parse_review_diff_json base_branch) || exit 1
MERGE_BASE=$(parse_review_diff_json merge_base) || exit 1 CHANGED_FILES=$(parse_review_diff_json changed_files) || exit 1
```
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "text_contracts": [
    {
      "name": "sample-linewise-multiline-text-contract",
      "extract_regex": "(?s)(COLLECT_ARGS=\\(--strict --format json\\).*?CHANGED_FILES=\\$\\(parse_review_diff_json changed_files\\) \\|\\| exit 1)",
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
  write_reference_skill \
    "$TMP_ROOT/kramme-cc-workflow/skills/kramme:sample/SKILL.md" \
    "kramme:sample" \
    "Sample skill description" \
    "false" \
    "true"
  write_file "$TMP_ROOT/README.md" <<'EOF'
# Test README

## Skills

<!-- BEGIN SOURCE-SYNCED SKILL ROWS -->

<!-- END SOURCE-SYNCED SKILL ROWS -->

## Agents
EOF
  write_readme_skill_sync_registry

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"readme skill sync"* ]]
  [[ "$output" == *"missing skill 'kramme:sample'"* ]]
}

@test "readme sync requires exact documented skill rows" {
  write_reference_skill \
    "$TMP_ROOT/kramme-cc-workflow/skills/kramme:qa/SKILL.md" \
    "kramme:qa" \
    "QA skill description" \
    "false" \
    "true"
  write_reference_skill \
    "$TMP_ROOT/kramme-cc-workflow/skills/kramme:qa:intake/SKILL.md" \
    "kramme:qa:intake" \
    "QA intake skill description" \
    "true" \
    "true"
  write_file "$TMP_ROOT/README.md" <<'EOF'
# Test README

Try /kramme:qa for live checks.

## Skills

<!-- BEGIN SOURCE-SYNCED SKILL ROWS -->

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:qa:intake` | User | — | QA intake skill description |

<!-- END SOURCE-SYNCED SKILL ROWS -->

## Agents
EOF
  write_readme_skill_sync_registry

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"readme skill sync"* ]]
  [[ "$output" == *"missing skill 'kramme:qa'"* ]]
}

@test "readme sync accepts background skill rows but ignores agent rows" {
  write_reference_skill \
    "$TMP_ROOT/kramme-cc-workflow/skills/kramme:background/SKILL.md" \
    "kramme:background" \
    "Background skill description" \
    "false" \
    "false"
  write_file "$TMP_ROOT/README.md" <<'EOF'
# Test README

## Skills

<!-- BEGIN SOURCE-SYNCED SKILL ROWS -->

### Background Skills

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `kramme:background` | Background | — | Background skill description |

<!-- END SOURCE-SYNCED SKILL ROWS -->

## Agents

| Agent | Description |
| --- | --- |
| `kramme:missing-agent` | Agent, not a skill. |
EOF
  write_readme_skill_sync_registry

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 0 ]
  [[ "$output" == *"skill contract lint passed."* ]]
}

@test "readme ghost skill fails" {
  write_reference_skill \
    "$TMP_ROOT/kramme-cc-workflow/skills/kramme:real/SKILL.md" \
    "kramme:real" \
    "Real skill description" \
    "false" \
    "true"
  write_file "$TMP_ROOT/README.md" <<'EOF'
# Test README

## Skills

<!-- BEGIN SOURCE-SYNCED SKILL ROWS -->

| Skill | Invocation | Arguments | Description |
| --- | --- | --- | --- |
| `/kramme:real` | User, Auto | — | Real skill description |
| `/kramme:ghost` | User | — | Ghost skill description |

<!-- END SOURCE-SYNCED SKILL ROWS -->

## Agents
EOF
  write_readme_skill_sync_registry

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

@test "marker manifest rejects stale empty-field allowance" {
  write_minimal_skill "$TMP_ROOT/kramme-cc-workflow/skills/a/SKILL.md" "SIMPLICITY CHECK: minimum viable change"
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/a/references/sources.yaml" <<'EOF'
sources:
  - id: source-a
    url: https://example.com/source-a
    title: Source A
    rationale: Used for test fixture.
    last_reviewed_at: 2026-06-10
    baseline_hash: sha256:abc123
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

  [ "$status" -eq 1 ]
  [[ "$output" == *"marker manifest"* ]]
  [[ "$output" == *"allow_empty_fields entry"* ]]
  [[ "$output" == *"does not match an empty required field"* ]]
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

@test "marker manifest required fields come from shared schema" {
  write_minimal_skill "$TMP_ROOT/kramme-cc-workflow/skills/a/SKILL.md" "SIMPLICITY CHECK: minimum viable change"
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/a/references/sources.yaml" <<'EOF'
sources:
  - id: source-a
    url: https://example.com/source-a
    title: Source A
EOF
  write_file "$TMP_ROOT/schema.json" <<'EOF'
{
  "skill_frontmatter": {
    "fields": {
      "name": {"type": "string", "required": true}
    }
  },
  "source_manifest": {
    "required_fields": [
      "id",
      "title",
      "audit_token"
    ],
    "one_of_fields": [
      "url"
    ]
  }
}
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "contract_schema": "schema.json",
  "marker_implies_manifest": {
    "skill_glob": "kramme-cc-workflow/skills/*/SKILL.md",
    "manifest": "references/sources.yaml",
    "markers": [
      "SIMPLICITY CHECK"
    ],
    "allow_empty_fields": []
  }
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"marker manifest"* ]]
  [[ "$output" == *"missing 'audit_token'"* ]]
}

@test "schema-backed marker manifest rejects duplicate registry field lists" {
  write_minimal_skill "$TMP_ROOT/kramme-cc-workflow/skills/a/SKILL.md" "SIMPLICITY CHECK: minimum viable change"
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/a/references/sources.yaml" <<'EOF'
sources:
  - id: source-a
    url: https://example.com/source-a
    title: Source A
EOF
  write_file "$TMP_ROOT/schema.json" <<'EOF'
{
  "skill_frontmatter": {
    "fields": {
      "name": {"type": "string", "required": true}
    }
  },
  "source_manifest": {
    "required_fields": ["id", "title"],
    "one_of_fields": ["url"]
  }
}
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "contract_schema": "schema.json",
  "marker_implies_manifest": {
    "skill_glob": "kramme-cc-workflow/skills/*/SKILL.md",
    "manifest": "references/sources.yaml",
    "markers": [
      "SIMPLICITY CHECK"
    ],
    "required_fields": [
      "id"
    ],
    "allow_empty_fields": []
  }
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"marker manifest"* ]]
  [[ "$output" == *"required_fields must come from contract_schema"* ]]
}

@test "source provenance rejects committed source snapshots" {
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/a/references/sources-snapshot/upstream.md" <<'EOF'
copied upstream body
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "source_provenance": {
    "manifest_glob": "kramme-cc-workflow/skills/*/references/sources.yaml",
    "forbidden_snapshot_globs": [
      "kramme-cc-workflow/skills/*/references/sources-snapshot"
    ]
  }
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"committed upstream source bodies are forbidden"* ]]
  [[ "$output" == *"sources-snapshot"* ]]
}

@test "source provenance requires copied-source rights and immutable origin" {
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/a/references/sources.yaml" <<'EOF'
sources:
  - id: copied-source
    url: https://example.com/copied
    title: Copied source
    rationale: "Copied into scripts/copied.sh."
    usage: copied
    last_reviewed_at: 2026-07-29
    baseline_hash: "sha256:abc123"
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "source_provenance": {
    "manifest_glob": "kramme-cc-workflow/skills/*/references/sources.yaml"
  }
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"copied entry 'copied-source' is missing non-empty 'license'"* ]]
  [[ "$output" == *"copied entry 'copied-source' is missing non-empty 'notice'"* ]]
  [[ "$output" == *"copied entry 'copied-source' is missing non-empty 'upstream_path'"* ]]
  [[ "$output" == *"copied entry 'copied-source' is missing an immutable upstream revision"* ]]
}

@test "source provenance accepts copied source with skill-local notice" {
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/a/references/sources.yaml" <<'EOF'
sources:
  - id: copied-source
    url: https://example.com/copied
    title: Copied source
    rationale: "Copied into scripts/copied.sh."
    usage: copied
    license: MIT
    notice: references/UPSTREAM-LICENSE
    upstream_path: scripts/copied.sh
    upstream_commit: 0123456789abcdef0123456789abcdef01234567
    last_reviewed_at: 2026-07-29
    baseline_hash: "sha256:abc123"
EOF
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/a/references/UPSTREAM-LICENSE" <<'EOF'
Upstream license notice
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "source_provenance": {
    "manifest_glob": "kramme-cc-workflow/skills/*/references/sources.yaml"
  }
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 0 ]
  [[ "$output" == *"skill contract lint passed."* ]]
}

@test "base diff scope rejects hand-rolled remote base snippets" {
  write_minimal_skill "$TMP_ROOT/kramme-cc-workflow/skills/a/SKILL.md" $'```bash\nBASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2> /dev/null)\ngit fetch origin refs/heads/${BASE_BRANCH}:refs/remotes/origin/${BASE_BRANCH}\ngit merge-base "origin/${BASE_BRANCH}" HEAD\ngit diff --name-only "origin/$BASE_BRANCH"...HEAD\n```'
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "base_diff_scope": {
    "paths": [
      "kramme-cc-workflow/skills/a/SKILL.md"
    ],
    "forbidden_patterns": [
      {
        "name": "manual-origin-head-base-detection",
        "regex": "git\\s+symbolic-ref(?:\\s+--(?:quiet|short))*\\s+refs/remotes/origin/HEAD"
      },
      {
        "name": "manual-base-fetch",
        "regex": "git\\s+fetch\\s+origin\\s+[\"']?refs/heads/(?:\\$BASE_BRANCH|\\$\\{BASE_BRANCH\\})(?::refs/remotes/origin/(?:\\$BASE_BRANCH|\\$\\{BASE_BRANCH\\}))?[\"']?"
      },
      {
        "name": "manual-origin-base-merge-base",
        "regex": "git\\s+merge-base\\s+[\"']?origin/(?:\\$BASE_BRANCH|\\$\\{BASE_BRANCH\\})[\"']?\\s+HEAD"
      },
      {
        "name": "manual-origin-base-diff",
        "regex": "git\\s+diff\\s+(?:--name-only\\s+)?[\"']?origin/(?:\\$BASE_BRANCH|\\$\\{BASE_BRANCH\\})[\"']?\\.\\.\\.HEAD"
      }
    ]
  }
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"base-diff-scope"* ]]
  [[ "$output" == *"manual-origin-head-base-detection"* ]]
  [[ "$output" == *"manual-base-fetch"* ]]
  [[ "$output" == *"manual-origin-base-merge-base"* ]]
  [[ "$output" == *"manual-origin-base-diff"* ]]
}

@test "base diff scope accepts canonical shared script snippets" {
  write_minimal_skill "$TMP_ROOT/kramme-cc-workflow/skills/a/SKILL.md" $'```bash\nRESOLVED=$("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-base.sh" --strict)\nRESOLVED=$("${CLAUDE_PLUGIN_ROOT}/scripts/collect-review-diff.sh" --strict)\n```'
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "base_diff_scope": {
    "paths": [
      "kramme-cc-workflow/skills/a/SKILL.md"
    ],
    "forbidden_patterns": [
      {
        "name": "manual-origin-head-base-detection",
        "regex": "git\\s+symbolic-ref(?:\\s+--(?:quiet|short))*\\s+refs/remotes/origin/HEAD"
      },
      {
        "name": "manual-origin-base-diff",
        "regex": "git\\s+diff\\s+(?:--name-only\\s+)?[\"']?origin/(?:\\$BASE_BRANCH|\\$\\{BASE_BRANCH\\})[\"']?\\.\\.\\.HEAD"
      }
    ]
  }
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 0 ]
  [[ "$output" == *"skill contract lint passed."* ]]
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

@test "mechanical frontmatter accepts every schema-declared primitive type" {
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/a/SKILL.md" <<'EOF'
---
name: test-skill
description: Test skill
argument-hint: "[target]"
disable-model-invocation: "false"
user-invocable: true
kramme-platforms: [claude-code, "codex"]
---
# Test
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "mechanical": {
    "skill_glob": "kramme-cc-workflow/skills/*/SKILL.md"
  }
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 0 ]
  [[ "$output" == *"skill contract lint passed."* ]]
}

@test "mechanical frontmatter accepts block arrays after comments and blank lines" {
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/a/SKILL.md" <<'EOF'
---
name: test-skill
description: Test skill
disable-model-invocation: false
user-invocable: true
kramme-platforms:
  # Supported targets

  - claude-code
  - codex
---
# Test
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "mechanical": {
    "skill_glob": "kramme-cc-workflow/skills/*/SKILL.md"
  }
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 0 ]
  [[ "$output" == *"skill contract lint passed."* ]]
}

@test "mechanical frontmatter accepts an indented continued string" {
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/a/SKILL.md" <<'EOF'
---
name: test-skill
description:
  Test skill continued on the next line
disable-model-invocation: false
user-invocable: true
---
# Test
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "mechanical": {
    "skill_glob": "kramme-cc-workflow/skills/*/SKILL.md"
  }
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 0 ]
  [[ "$output" == *"skill contract lint passed."* ]]
}

@test "mechanical frontmatter rejects empty block scalar strings" {
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/a/SKILL.md" <<'EOF'
---
name: test-skill
description: |
disable-model-invocation: false
user-invocable: true
---
# Test
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "mechanical": {
    "skill_glob": "kramme-cc-workflow/skills/*/SKILL.md"
  }
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"frontmatter field 'description' must be a non-empty string"* ]]
}

@test "mechanical frontmatter reports every invalid schema-declared primitive type" {
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/a/SKILL.md" <<'EOF'
---
name: false
description:
argument-hint: false
disable-model-invocation: maybe
user-invocable: 0
kramme-platforms: codex
---
# Test
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "mechanical": {
    "skill_glob": "kramme-cc-workflow/skills/*/SKILL.md"
  }
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"skills/a/SKILL.md frontmatter field 'name' must be a non-empty string"* ]]
  [[ "$output" == *"skills/a/SKILL.md frontmatter field 'description' must be a non-empty string"* ]]
  [[ "$output" == *"skills/a/SKILL.md frontmatter field 'argument-hint' must be a non-empty string"* ]]
  [[ "$output" == *"skills/a/SKILL.md frontmatter field 'disable-model-invocation' must be a boolean"* ]]
  [[ "$output" == *"skills/a/SKILL.md frontmatter field 'user-invocable' must be a boolean"* ]]
  [[ "$output" == *"skills/a/SKILL.md frontmatter field 'kramme-platforms' must be a non-empty array of non-empty strings"* ]]
}

@test "mechanical frontmatter rejects non-string nodes in arrays" {
  write_file "$TMP_ROOT/kramme-cc-workflow/skills/a/SKILL.md" <<'EOF'
---
name: test-skill
description: Test skill
disable-model-invocation: false
user-invocable: true
kramme-platforms: [codex, [nested]]
---
# Test
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "mechanical": {
    "skill_glob": "kramme-cc-workflow/skills/*/SKILL.md"
  }
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"frontmatter field 'kramme-platforms' must be a non-empty array of non-empty strings"* ]]

  write_file "$TMP_ROOT/kramme-cc-workflow/skills/a/SKILL.md" <<'EOF'
---
name: test-skill
description: Test skill
disable-model-invocation: false
user-invocable: true
kramme-platforms: [codex, .5]
---
# Test
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"frontmatter field 'kramme-platforms' must be a non-empty array of non-empty strings"* ]]

  write_file "$TMP_ROOT/kramme-cc-workflow/skills/a/SKILL.md" <<'EOF'
---
name: test-skill
description: Test skill
disable-model-invocation: false
user-invocable: true
kramme-platforms: [codex, 0x10]
---
# Test
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"frontmatter field 'kramme-platforms' must be a non-empty array of non-empty strings"* ]]

  write_file "$TMP_ROOT/kramme-cc-workflow/skills/a/SKILL.md" <<'EOF'
---
name: test-skill
description: Test skill
disable-model-invocation: false
user-invocable: true
kramme-platforms:
  - codex
  - [nested]
---
# Test
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"frontmatter field 'kramme-platforms' must be a non-empty array of non-empty strings"* ]]
}

@test "mechanical agent frontmatter name must match filename" {
  write_file "$TMP_ROOT/kramme-cc-workflow/agents/kramme:sample-agent.md" <<'EOF'
---
name: sample-agent
description: Test agent
model: inherit
color: blue
---
# Test
EOF
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "mechanical": {
    "agent_glob": "kramme-cc-workflow/agents/*.md"
  }
}
EOF

  run python3 "$SCRIPT" --repo-root "$TMP_ROOT" --registry "$TMP_ROOT/registry.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"frontmatter name 'sample-agent' does not match agent filename 'kramme:sample-agent'"* ]]
}

@test "mechanical long-skill warning reports near-threshold candidates" {
  write_minimal_skill "$TMP_ROOT/kramme-cc-workflow/skills/below/SKILL.md" "$(make_body_lines 4)"
  write_minimal_skill "$TMP_ROOT/kramme-cc-workflow/skills/near/SKILL.md" "$(make_body_lines 6)"
  write_minimal_skill "$TMP_ROOT/kramme-cc-workflow/skills/high/SKILL.md" "$(make_body_lines 8)"
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "mechanical": {
    "skill_glob": "kramme-cc-workflow/skills/*/SKILL.md",
    "max_skill_lines": 20,
    "warn_skill_lines": 12,
    "skill_line_report_limit": 2,
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

  [ "$status" -eq 0 ]
  [[ "$output" == *"skill contract lint warnings:"* ]]
  [[ "$output" == *"::warning::mechanical: long-skill burndown: kramme-cc-workflow/skills/high/SKILL.md has 14 lines"* ]]
  [[ "$output" == *"::warning::mechanical: long-skill burndown: kramme-cc-workflow/skills/near/SKILL.md has 12 lines"* ]]
  [[ "$output" != *"kramme-cc-workflow/skills/below/SKILL.md"* ]]
  [[ "$output" == *"skill contract lint passed."* ]]
}

@test "mechanical hard line budget still fails above max" {
  write_minimal_skill "$TMP_ROOT/kramme-cc-workflow/skills/over/SKILL.md" "$(make_body_lines 15)"
  write_file "$TMP_ROOT/registry.yaml" <<'EOF'
{
  "mechanical": {
    "skill_glob": "kramme-cc-workflow/skills/*/SKILL.md",
    "max_skill_lines": 20,
    "warn_skill_lines": 12,
    "skill_line_report_limit": 2,
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
  [[ "$output" == *"::warning::mechanical: long-skill burndown: kramme-cc-workflow/skills/over/SKILL.md has 21 lines"* ]]
  [[ "$output" == *"::error::mechanical: kramme-cc-workflow/skills/over/SKILL.md has 21 lines, exceeds 20"* ]]
}
