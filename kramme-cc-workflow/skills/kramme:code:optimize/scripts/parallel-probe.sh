#!/usr/bin/env bash
# Parallelism probe for kramme:code:optimize.
#
# Adapted from EveryInc/compound-engineering-plugin:
# https://github.com/EveryInc/compound-engineering-plugin/tree/6f9ab03a031c054a8046659926251fb6c149269f/plugins/compound-engineering/skills/ce-optimize/scripts/parallel-probe.sh
# Reviewed upstream commit: 6f9ab03a031c054a8046659926251fb6c149269f
#
# Usage: parallel-probe.sh <project_directory> [measurement_command] [measurement_workdir] [shared_file ...]
#
# Outputs advisory JSON with mode, blockers, and blocker_count.

set -euo pipefail

project_dir="${1:?Error: project_directory argument required}"
measurement_cmd="${2:-}"
measurement_workdir="${3:-.}"

if [ $# -ge 3 ]; then
  shift 3
else
  shift $#
fi

shared_files=("$@")

cd "$project_dir" || {
  echo '{"mode":"serial","blockers":[{"type":"error","description":"Cannot access project directory","suggestion":"Check path"}],"blocker_count":1}'
  exit 0
}

if ! command -v python3 > /dev/null 2>&1; then
  echo '{"mode":"serial","blockers":[{"type":"missing_dependency","description":"python3 is required for structured probe output","suggestion":"Install python3 or review parallel readiness manually"}],"blocker_count":1}'
  exit 0
fi

blockers="[]"
scan_paths=()

json_append_blocker() {
  local type="$1"
  local description="$2"
  local suggestion="$3"

  blockers=$(
    python3 - "$blockers" "$type" "$description" "$suggestion" << 'PY'
import json
import sys

items = json.loads(sys.argv[1])
items.append({
    "type": sys.argv[2],
    "description": sys.argv[3],
    "suggestion": sys.argv[4],
})
print(json.dumps(items))
PY
  )
}

add_scan_path() {
  local candidate="$1"
  if [ -n "$candidate" ] && [ -e "$candidate" ]; then
    scan_paths+=("$candidate")
  fi
}

add_scan_path "$measurement_workdir"
for shared_file in "${shared_files[@]}"; do
  add_scan_path "$shared_file"
done

if [ "${#scan_paths[@]}" -eq 0 ]; then
  scan_paths=(".")
fi

if [ -n "$measurement_cmd" ] && echo "$measurement_cmd" | grep -qE '(--port([[:space:]]+|=)[0-9]+|localhost:[0-9]+|PORT=[0-9]+)'; then
  json_append_blocker "port" "Measurement command contains a hardcoded port reference" "Parameterize the port through an environment variable such as EVAL_PORT"
fi

sqlite_files=$(find "${scan_paths[@]}" -maxdepth 4 -type f \( -name '*.db' -o -name '*.sqlite' -o -name '*.sqlite3' \) ! -path '*/.git/*' ! -path '*/node_modules/*' ! -path '*/.claude/*' ! -path '*/.context/*' ! -path '*/.worktrees/*' 2> /dev/null | head -10 || true)
if [ -n "$sqlite_files" ]; then
  file_count=$(printf '%s\n' "$sqlite_files" | wc -l | tr -d ' ')
  json_append_blocker "shared_file" "Found $file_count SQLite database file(s)" "Copy database files into each experiment worktree or use serial mode"
fi

lock_files=$(find "${scan_paths[@]}" -maxdepth 4 -type f \( -name '*.lock' -o -name '*.pid' \) ! -path '*/.git/*' ! -path '*/node_modules/*' ! -path '*/.claude/*' ! -path '*/.context/*' ! -path '*/.worktrees/*' ! -name 'package-lock.json' ! -name 'yarn.lock' ! -name 'bun.lock' ! -name 'bun.lockb' ! -name 'Gemfile.lock' ! -name 'poetry.lock' ! -name 'Cargo.lock' 2> /dev/null | head -10 || true)
if [ -n "$lock_files" ]; then
  file_count=$(printf '%s\n' "$lock_files" | wc -l | tr -d ' ')
  json_append_blocker "lock_file" "Found $file_count lock or PID file(s) that may cause contention" "Ensure the measurement command cleans up locks, or run in serial mode"
fi

if [ -n "$measurement_cmd" ] && echo "$measurement_cmd" | grep -qiE '(cuda|gpu|tensorflow|torch|nvidia-smi|CUDA_VISIBLE_DEVICES)'; then
  json_append_blocker "exclusive_resource" "Measurement command appears to use GPU or another exclusive accelerator" "Use serial mode or explicit device parameterization"
fi

blocker_count=$(
  python3 - "$blockers" << 'PY'
import json
import sys

print(len(json.loads(sys.argv[1])))
PY
)

mode="parallel"
if [ "$blocker_count" -gt 0 ]; then
  if python3 - "$blockers" << 'PY'; then
import json
import sys

blockers = json.loads(sys.argv[1])
raise SystemExit(0 if any(item["type"] == "exclusive_resource" for item in blockers) else 1)
PY
    mode="serial"
  else
    mode="user-decision"
  fi
fi

python3 - "$mode" "$blockers" "$blocker_count" << 'PY'
import json
import sys

print(json.dumps({
    "mode": sys.argv[1],
    "blockers": json.loads(sys.argv[2]),
    "blocker_count": int(sys.argv[3]),
}, indent=2))
PY
