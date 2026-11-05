#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  AGENT="agents/cold-reader.md"
  CONTRACT="shared/agents/references/cold-reader.md"
  CONTRACT_PATH='${CLAUDE_PLUGIN_ROOT}/shared/agents/references/cold-reader.md'
}

@test "cold reader agent starts without project instructions and stays read-only" {
  local frontmatter
  frontmatter="$(awk 'NR == 1 { next } /^---$/ { exit } { print }' "$AGENT")"

  grep -qxF 'name: cold-reader' <<<"$frontmatter"
  grep -qxF 'omitClaudeMd: true' <<<"$frontmatter"
  grep -qxF 'disallowedTools: Write, Edit, NotebookEdit' <<<"$frontmatter"
  grep -qF '**Read-only agent.**' "$AGENT"
}

@test "cold reader reports unreadable material instead of answering" {
  grep -qF 'Reply with `UNREADABLE: <path>` on its own line and stop.' "$AGENT"
  grep -qF 'A missing read is a failed read, not a clean result.' "$AGENT"
  grep -qF 'Count the read as failed, not clean, and record the path.' "$CONTRACT"
}

@test "cold reader launch contract covers each host and never simulates a reader" {
  grep -qF 'launch the plugin agent `trackbed:cold-reader`' "$CONTRACT"
  grep -qF 'The field needs Claude Code 2.1.271 or later' "$CONTRACT"
  grep -qF 'never fork the conversation or resume an earlier reader' "$CONTRACT"
  grep -qF 'spawn a new agent with `fork_turns="none"`, or with `fork_context: false` when the spawn tool exposes that field instead' "$CONTRACT"
  grep -qF 'Record that as reduced isolation wherever the adopting skill reports isolation.' "$CONTRACT"
  grep -qF 'Never simulate a cold reader in your own context.' "$CONTRACT"
  grep -qF 'no conversation history, no notes about what the author meant, no prior reports, and no expected findings' "$CONTRACT"
  grep -qF 'Apart from that Codex skill reference' "$CONTRACT"
}

@test "skills that want an outsider name the launch contract in SKILL.md" {
  local skill
  for skill in \
    "skills/code:outside-view/SKILL.md" \
    "skills/pr:generate-description/SKILL.md" \
    "skills/docs:review/SKILL.md" \
    "skills/siw:spec-audit/SKILL.md"; do
    grep -qF "$CONTRACT_PATH" "$skill" || {
      echo "missing launch contract: $skill"
      return 1
    }
  done
}

@test "outside-view raters launch as cold readers and report reduced isolation" {
  local skill="skills/code:outside-view/SKILL.md"
  local template="skills/code:outside-view/assets/report-template.md"

  grep -qF 'Launch each in-repo rater as a cold reader' "$skill"
  grep -qF 'record `project instructions loaded` as reduced isolation in the report' "$skill"
  grep -qF 'raters with project instructions loaded' "$skill"
  grep -qF 'otherwise launch them one at a time, each as a new agent' "$skill"
  grep -qF '**Rater isolation:**' "$template"
}

@test "the PR description cold read uses the agent and both Codex spawn fields" {
  local pass="skills/pr:generate-description/references/readability-pass.md"

  grep -qF 'On Claude Code that is the `trackbed:cold-reader` agent' "$pass"
  grep -qF 'On Codex, spawn it with `fork_turns="none"`, or `fork_context: false` when the spawn tool exposes that field instead' "$pass"
}

@test "github-review clarity readers keep project instructions" {
  local check="skills/pr:github-review/references/clarity-check.md"

  grep -qF 'launch them as ordinary agents that keep the project'"'"'s instructions, not as the `trackbed:cold-reader` agent' "$check"
  grep -qF 'or `fork_context: false` when the spawn tool exposes that field instead' "$check"
}

@test "reviewers that check project rules do not drop project instructions" {
  local path

  for path in agents/*.md; do
    [ "$path" = "$AGENT" ] && continue
    if grep -qF 'omitClaudeMd' "$path"; then
      echo "only the cold reader may drop project instructions: $path"
      return 1
    fi
  done
}
