#!/usr/bin/env bats

setup() {
  TMP_ROOT="$(mktemp -d)"
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/lint-skill-contracts.py"
  VISUAL_GENERATOR="$BATS_TEST_DIRNAME/../scripts/generate-visual-shared-assets.py"
  COMPONENT_GENERATOR="$BATS_TEST_DIRNAME/../scripts/generate-component-reference.py"
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

@test "copy review rubric is synced as a skill-local resource" {
  local registry="$BATS_TEST_DIRNAME/../scripts/synced-contracts.yaml"
  local code_rubric="$BATS_TEST_DIRNAME/../skills/kramme:code:copy-review/references/copy-review-rubric.md"
  local pr_rubric="$BATS_TEST_DIRNAME/../skills/kramme:pr:copy-review/references/copy-review-rubric.md"

  test -f "$code_rubric"
  test -f "$pr_rubric"
  cmp -s "$code_rubric" "$pr_rubric"
  grep -qF '"name": "copy-review-rubric"' "$registry"
  ! grep -qF '"name": "copy-review-redundancy-scope"' "$registry"
  ! grep -qF '"name": "copy-review-ui-relevant-file-types"' "$registry"
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
  local resolver_text
  local emphasis_line
  local normalization_line

  skill_text="$(cat "$BATS_TEST_DIRNAME/../skills/kramme:pr:code-review/SKILL.md")"
  template_text="$(cat "$BATS_TEST_DIRNAME/../skills/kramme:pr:code-review/references/output-template.md")"
  discipline_text="$(cat "$BATS_TEST_DIRNAME/../skills/kramme:pr:code-review/references/review-discipline.md")"
  team_text="$(cat "$BATS_TEST_DIRNAME/../skills/kramme:pr:code-review/references/team-mode.md")"
  resolver_text="$(cat "$BATS_TEST_DIRNAME/../skills/kramme:pr:resolve-review/SKILL.md")"

  [[ "$skill_text" == *"After emphasis adjustments, run an **action-class normalization pass**."* ]]
  [[ "$skill_text" == *"default to \`gated_auto\` with owner \`resolver\`"* ]]
  [[ "$skill_text" == *"\`Manual blocker: <one of the blocker categories above>\`"* ]]
  [[ "$skill_text" == *"**Auto-resolution Readiness**"* ]]
  emphasis_line="$(grep -nF "Track the count of promoted findings for the report." <<<"$skill_text" | cut -d: -f1)"
  normalization_line="$(grep -nF "After emphasis adjustments, run an **action-class normalization pass**." <<<"$skill_text" | cut -d: -f1)"
  [ "$normalization_line" -gt "$emphasis_line" ]

  [[ "$template_text" == *"## Auto-resolution Readiness"* ]]
  [[ "$template_text" == *"Manual blockers: product/UX/architecture/maintainer decision X"* ]]
  [[ "$template_text" == *"Manual blocker: product/UX/architecture/maintainer decision"* ]]
  [[ "$template_text" == *"Next human decision: concrete decision"* ]]

  [[ "$discipline_text" == *"Critical or Important PR-caused findings default to \`gated_auto\`"* ]]
  [[ "$discipline_text" == *"Every manual Critical/Important finding includes \`Manual blocker\` and \`Next human decision\`"* ]]

  [[ "$team_text" == *"Treat teammate action classes as provisional."* ]]
  [[ "$team_text" == *"Include the \`## Auto-resolution Readiness\` section from the standard template"* ]]

  [[ "$resolver_text" == *"\`Manual blocker\`, and \`Next human decision\`"* ]]
  [[ "$resolver_text" == *"manual blocker, and next human decision when available"* ]]
  [[ "$resolver_text" == *"Findings outside the filter are not processed and keep their existing \`Resolution status\` and \`Action taken\` fields unchanged"* ]]
  [[ "$resolver_text" == *"A finding skipped only because it was outside a previous severity filter remains eligible"* ]]
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
