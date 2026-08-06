#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: export-candidate.sh --run-dir <path> [--dest-dir <path>]

Copies SkillOpt candidate artifacts into a candidate-review directory under
this repository's .context/skillopt-runs/ scratch boundary. When --dest-dir is
omitted, the sibling candidate-review directory must remain inside that boundary.
EOF
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
workflow_root="$(cd "$script_dir/../../.." && pwd -P)"
repo_root="$(cd "$workflow_root/.." && pwd -P)"
# shellcheck source=../../../scripts/lib/shell-helpers.sh
source "$workflow_root/scripts/lib/shell-helpers.sh"

run_dir=""
dest_dir=""

while [ "$#" -gt 0 ]; do
  case "$1" in
  --run-dir)
    require_value "$1" "${2-}" 2 "export-candidate: "
    run_dir="$2"
    shift 2
    ;;
  --dest-dir)
    require_value "$1" "${2-}" 2 "export-candidate: "
    dest_dir="$2"
    shift 2
    ;;
  --help | -h)
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

dest_dir_real="$(require_scratch_boundary "$repo_root" ".context/skillopt-runs" "$dest_dir" "export-candidate: destination ")"

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
  best_skill.md | history.json | config.json | runtime_state.json) continue ;;
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
