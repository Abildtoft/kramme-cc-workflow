#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: export-candidate.sh --run-dir <path> [--dest-dir <path>]

Copies SkillOpt candidate artifacts into a candidate-review directory under a
.context/skillopt-runs/ path. The helper refuses destinations outside that
scratch boundary.
EOF
}

run_dir=""
dest_dir=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --run-dir)
      if [ "$#" -lt 2 ]; then
        echo "export-candidate: --run-dir requires a path" >&2
        exit 2
      fi
      run_dir="$2"
      shift 2
      ;;
    --dest-dir)
      if [ "$#" -lt 2 ]; then
        echo "export-candidate: --dest-dir requires a path" >&2
        exit 2
      fi
      dest_dir="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "export-candidate: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$run_dir" ]; then
  echo "export-candidate: --run-dir is required" >&2
  usage >&2
  exit 2
fi

if [ ! -d "$run_dir" ]; then
  echo "export-candidate: run directory does not exist: $run_dir" >&2
  exit 1
fi

run_dir_real="$(cd "$run_dir" && pwd -P)"

if [ -z "$dest_dir" ]; then
  dest_dir="$(dirname "$run_dir_real")/candidate-review"
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "export-candidate: python3 is required to validate destination paths" >&2
  exit 1
fi

dest_dir_real="$(python3 - "$dest_dir" <<'PY'
import sys
from pathlib import Path

print(Path(sys.argv[1]).expanduser().resolve())
PY
)"

case "$dest_dir_real/" in
  */.context/skillopt-runs/*) ;;
  *)
    echo "export-candidate: destination must stay under a .context/skillopt-runs path: $dest_dir_real" >&2
    exit 1
    ;;
esac

mkdir -p "$dest_dir_real"

best_skill="$run_dir_real/best_skill.md"
if [ ! -f "$best_skill" ]; then
  echo "export-candidate: missing best_skill.md in run directory: $run_dir_real" >&2
  exit 1
fi

copy_if_present() {
  local source="$1"
  local target="$2"
  if [ -f "$source" ]; then
    mkdir -p "$(dirname "$target")"
    cp "$source" "$target"
  fi
}

copy_if_present "$run_dir_real/best_skill.md" "$dest_dir_real/best_skill.md"
copy_if_present "$run_dir_real/history.json" "$dest_dir_real/history.json"
copy_if_present "$run_dir_real/config.json" "$dest_dir_real/config.json"
copy_if_present "$run_dir_real/runtime_state.json" "$dest_dir_real/runtime_state.json"

artifacts_dir="$dest_dir_real/artifacts"
while IFS= read -r -d '' artifact; do
  relative="${artifact#"$run_dir_real"/}"
  case "$relative" in
    best_skill.md|history.json|config.json|runtime_state.json) continue ;;
  esac
  copy_if_present "$artifact" "$artifacts_dir/$relative"
done < <(
  find "$run_dir_real" -maxdepth 4 -type f \( \
    -name '*score*.json' -o \
    -name '*scores*.json' -o \
    -name '*eval*.json' -o \
    -name '*metric*.json' -o \
    -name '*result*.json' -o \
    -name '*results*.json' \
  \) -print0
)

echo "$dest_dir_real"
