#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/.."
}

SKILL="skills/kramme:code:audit-practice/SKILL.md"
RUBRIC="skills/kramme:code:audit-practice/references/mistakes.md"
SOURCES="skills/kramme:code:audit-practice/references/sources.yaml"

@test "audit is user-invoked, read-only, and bounded in what it reads" {
  test -f "$SKILL"
  grep -qF 'argument-hint: "[--recent N] [--no-sessions]"' "$SKILL"
  grep -qF "disable-model-invocation: true" "$SKILL"
  grep -qF "user-invocable: true" "$SKILL"
  grep -qF "Never edit, create, or delete files, settings, memory, or Git state, and never run the project's tests, builds, or installs." "$SKILL"
  grep -qF "applying a fix is a separate request" "$SKILL"
  grep -qF "Read nothing else outside the repository." "$SKILL"
  grep -qF "Run in one pass in this session without subagents." "$SKILL"
}

@test "session and settings evidence never exposes private content" {
  grep -qF "Never open a transcript directly." "$SKILL"
  grep -qF 'never print `env` values, tokens, credentials, or MCP server commands and arguments' "$SKILL"
  grep -qF "Use only the JSON it prints." "$SKILL"
  grep -qF "It never holds prompt text, command lines, tool output, or" "skills/kramme:code:audit-practice/scripts/session-signals.py"
}

@test "arguments select the session window and reject conflicts" {
  grep -qF 'No arguments: sessions from the last 30 days, at most 30 (`--days 30 --limit 30`).' "$SKILL"
  grep -qF '`--recent N`: the N most recent sessions from the last year (`--days 365 --limit N`), where N is an integer from 1 to 100.' "$SKILL"
  grep -qF '`--recent` combined with `--no-sessions`' "$SKILL"
  grep -qF 'Usage: /kramme:code:audit-practice [--recent N] [--no-sessions]' "$SKILL"
}

@test "sessions are found through every worktree and archived Conductor workspaces" {
  grep -qF 'every `worktree` path from `git worktree list --porcelain`' "$SKILL"
  grep -qF 'When the root matches `*/conductor/workspaces/<repo>/<workspace>`, use `*/conductor/workspaces/<repo>` instead' "$SKILL"
  grep -qF 'python3 "${CLAUDE_PLUGIN_ROOT}/skills/kramme:code:audit-practice/scripts/session-signals.py"' "$SKILL"
  grep -qF "If the script fails or analyzes zero sessions, record an audit gap and continue" "$SKILL"
}

@test "verdicts come from the rubric and missing evidence is never a pass" {
  grep -qF 'Read the rubric from `references/mistakes.md` now. If it cannot be read, stop and report the missing path; never judge from memory.' "$SKILL"
  grep -qF "A mistake with no evidence source is UNOBSERVABLE, never CLEAR." "$SKILL"
  grep -qF "Record a missing file as absent, never as proof of a healthy practice." "$SKILL"
  grep -qF "session-only evidence comes from fewer than five sessions" "$SKILL"
  grep -qF "With fewer than five analyzed sessions, session-only evidence supports POSSIBLE at most." "$RUBRIC"
}

@test "rubric covers all eighteen mistakes with signals, a self-check, and a change" {
  for number in $(seq 1 18); do
    grep -qE "^### ${number}\. " "$RUBRIC"
  done
  [ "$(grep -c '^- \*\*LIKELY:\*\*' "$RUBRIC")" -eq 18 ]
  [ "$(grep -c '^- \*\*Self-check:\*\*' "$RUBRIC")" -eq 18 ]
  [ "$(grep -c '^- \*\*Change:\*\*' "$RUBRIC")" -eq 18 ]
  grep -qF "## Pairing Rules" "$RUBRIC"
  grep -qF "Recommend calibrating by task size, not more or less alignment overall." "$RUBRIC"
}

@test "every routed skill exists and accepts user invocation" {
  routes=$(grep -oE '/kramme:[a-z0-9:-]+' "$RUBRIC" | sort -u)
  [ -n "$routes" ]
  for route in $routes; do
    skill="skills/${route#/}/SKILL.md"
    test -f "$skill" || { echo "missing route target: $route"; return 1; }
    grep -qF "user-invocable: true" "$skill" || { echo "route is not user-invocable: $route"; return 1; }
  done
}

@test "report ranks the fixes to make first and lists every check" {
  grep -qF "Reply inline; do not write a report file." "$SKILL"
  grep -qF "## Fix First" "$SKILL"
  grep -qF "## All Checks" "$SKILL"
  grep -qF "## Self-Check" "$SKILL"
  grep -qF "No files were changed." "$SKILL"
  grep -qF "Fill \`Fix First\` with up to three LIKELY mistakes" "$SKILL"
  grep -qF "**Reach:**" "$SKILL"
  grep -qF "**Leverage:**" "$SKILL"
  grep -qF "**Cost to fix:**" "$SKILL"
  grep -qF "List all eighteen mistakes in numeric order" "$SKILL"
}

@test "sources credit the post and its glossary as inspiration" {
  grep -qF "url: https://x.com/mattpocockuk/status/2109973273924579720" "$SOURCES"
  grep -qF "url: https://www.aicodingdictionary.com/" "$SOURCES"
  [ "$(grep -c 'usage: inspiration' "$SOURCES")" -eq 2 ]
}
