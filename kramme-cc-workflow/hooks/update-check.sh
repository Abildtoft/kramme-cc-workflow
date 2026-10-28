#!/bin/bash
set -uo pipefail
# Policy: -u/-pipefail only. No -e: every failure must end in a silent `{}`, never a hook error.
# Hook: Tell the user when a newer plugin version is available, and name the new
# version once after an update.
#
# Runs on SessionStart (startup only, through the hooks.json matcher). Its only
# output is a JSON systemMessage, which the host shows to the user; plain stdout
# or additionalContext would go into the model's context instead.
#
# At most once a day it fetches the plugin manifest from the default branch,
# where only release Pull Requests bump the version. The fetch is synchronous and
# bounded because a background hook's systemMessage is never shown to the user.

source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/check-enabled.sh"
exit_if_hook_disabled "update-check" "json"

PLUGIN_NAME="kramme-cc-workflow"
LATEST_MANIFEST_URL="https://raw.githubusercontent.com/Abildtoft/kramme-cc-workflow/main/kramme-cc-workflow/.claude-plugin/plugin.json"
CHANGELOG_URL="https://github.com/Abildtoft/kramme-cc-workflow/blob/main/kramme-cc-workflow/CHANGELOG.md"
CHECK_INTERVAL_SECONDS=86400
FETCH_TIMEOUT_SECONDS=2
NEWLINE=$'\n'

[ -t 0 ] || cat > /dev/null

is_release_version() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

# Succeeds when release version $1 is newer than release version $2.
version_newer() {
  local -a left right
  local i
  IFS=. read -r -a left <<< "$1"
  IFS=. read -r -a right <<< "$2"
  for i in 0 1 2; do
    if ((10#${left[i]} != 10#${right[i]})); then
      ((10#${left[i]} > 10#${right[i]}))
      return
    fi
  done
  return 1
}

# Prints how many entries in changelog $1 are marked breaking in the releases
# after version $2, up to and including version $3.
count_breaking_changes() {
  awk -v from="$2" -v to="$3" '
    function compare(a, b,    x, y, i) {
      split(a, x, ".")
      split(b, y, ".")
      for (i = 1; i <= 3; i++) {
        if (x[i] + 0 != y[i] + 0) return (x[i] + 0 > y[i] + 0) ? 1 : -1
      }
      return 0
    }
    /^## \[/ {
      version = $2
      sub(/^\[/, "", version)
      sub(/\].*$/, "", version)
      counting = (version ~ /^[0-9]+\.[0-9]+\.[0-9]+$/) && (compare(version, from) > 0) && (compare(version, to) <= 0)
      next
    }
    counting && tolower($0) ~ /^- (\*\*)?breaking/ { count++ }
    END { print count + 0 }
  ' "$1" 2> /dev/null
}

message=""
add_message() {
  message="${message:+${message}${NEWLINE}}$1"
}

if ! command -v jq > /dev/null 2>&1; then
  echo '{}'
  exit 0
fi

host="claude-code"
manifest="${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json"
if [ ! -f "$manifest" ]; then
  host="codex"
  manifest="${CLAUDE_PLUGIN_ROOT}/.codex-plugin/plugin.json"
fi
installed="$(jq -r '.version // empty' "$manifest" 2> /dev/null)"
if ! is_release_version "$installed"; then
  echo '{}'
  exit 0
fi

state_file="$(resolve_kramme_path "KRAMME_UPDATE_CHECK_FILE" "XDG_STATE_HOME" ".local/state" "update-check.json")"
# Hold a kernel lock across the entire read/check/write operation. Re-exec with
# the descriptor inherited by Bash; the OS releases it even if the hook is killed.
# Competing startups skip this run instead of delaying the session. Python is
# used because macOS does not ship the flock command.
if [ "${1:-}" != "--state-lock-held" ]; then
  if ! command -v python3 > /dev/null 2>&1; then
    echo '{}'
    exit 0
  fi
  python3 - "$state_file" "${BASH_SOURCE[0]}" 2> /dev/null << 'PY'
import os
import sys

try:
    import fcntl

    state_file, script = sys.argv[1:]
    os.makedirs(os.path.dirname(state_file) or ".", exist_ok=True)
    descriptor = os.open(state_file + ".lock", os.O_CREAT | os.O_RDWR, 0o600)
    fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
    os.set_inheritable(descriptor, True)
    os.execvp("bash", ["bash", script, "--state-lock-held"])
except (ImportError, OSError):
    print("{}")
PY
  exit 0
fi

checked_at=0
latest=""
seen=""
if [ -f "$state_file" ]; then
  {
    IFS= read -r checked_at
    IFS= read -r latest
    IFS= read -r seen
  } < <(jq -r '(.checkedAt // 0), (.latestVersion // ""), (.seenVersion // "")' "$state_file" 2> /dev/null)
fi
[[ "$checked_at" =~ ^[0-9]+$ ]] || checked_at=0
is_release_version "$latest" || latest=""

# seenVersion is the newest version a session has started with. It only moves
# forward, so an older copy in another scope or project never triggers a notice.
if ! is_release_version "$seen"; then
  seen="$installed"
elif version_newer "$installed" "$seen"; then
  breaking=0
  if [ -f "${CLAUDE_PLUGIN_ROOT}/CHANGELOG.md" ]; then
    breaking="$(count_breaking_changes "${CLAUDE_PLUGIN_ROOT}/CHANGELOG.md" "$seen" "$installed")"
  fi
  case "$breaking" in
    0 | '' | *[!0-9]*) breaking_note="" ;;
    1) breaking_note=" (1 breaking change)" ;;
    *) breaking_note=" (${breaking} breaking changes)" ;;
  esac
  add_message "${PLUGIN_NAME} updated from ${seen} to ${installed}${breaking_note}. Changelog: ${CHANGELOG_URL}"
  seen="$installed"
fi

if [ "$host" = "codex" ]; then
  update_hint="Run codex plugin marketplace upgrade ${PLUGIN_NAME}, then codex plugin add ${PLUGIN_NAME}@${PLUGIN_NAME}, and restart Codex."
else
  update_hint="Run /plugin marketplace update ${PLUGIN_NAME}, then /reload-plugins. Turning on auto-update in /plugin → Marketplaces keeps it current."
fi

now="$(date +%s)"
[[ "$now" =~ ^[0-9]+$ ]] || now=0
if [ -z "${CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC:-}" ] \
  && [ $((now - checked_at)) -ge "$CHECK_INTERVAL_SECONDS" ] \
  && command -v curl > /dev/null 2>&1; then
  checked_at="$now"
  fetched="$(curl -fsSL --max-time "$FETCH_TIMEOUT_SECONDS" "$LATEST_MANIFEST_URL" 2> /dev/null | jq -r '.version // empty' 2> /dev/null)"
  if is_release_version "$fetched"; then
    latest="$fetched"
    if version_newer "$latest" "$installed"; then
      add_message "${PLUGIN_NAME} ${latest} is available (you have ${installed}). ${update_hint} Changelog: ${CHANGELOG_URL}"
    fi
  fi
fi

tmp_file="${state_file}.$$"
if mkdir -p -- "$(dirname -- "$state_file")" 2> /dev/null \
  && jq -n \
    --argjson checkedAt "$checked_at" \
    --arg latestVersion "$latest" \
    --arg seenVersion "$seen" \
    '{checkedAt: $checkedAt, latestVersion: $latestVersion, seenVersion: $seenVersion}' > "$tmp_file" 2> /dev/null; then
  mv -f -- "$tmp_file" "$state_file" 2> /dev/null || rm -f -- "$tmp_file"
else
  rm -f -- "$tmp_file" 2> /dev/null
fi

if [ -n "$message" ]; then
  jq -cn --arg message "$message" '{systemMessage: $message}'
else
  echo '{}'
fi
exit 0
