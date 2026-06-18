#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: prepare-splits.sh [--check-only] [--split-dir <path>]

Validates the skill-review split directory used by the external SkillOpt pilot.
The script does not copy data by default because evals/skill-review/items
already has the train/val/test directory shape expected by SkillOpt split_dir.
EOF
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
workflow_root="$(cd "$script_dir/../../.." && pwd -P)"
split_dir="$workflow_root/evals/skill-review/items"
check_only=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check-only)
      check_only=true
      shift
      ;;
    --split-dir)
      if [ "$#" -lt 2 ]; then
        echo "prepare-splits: --split-dir requires a path" >&2
        exit 2
      fi
      split_dir="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "prepare-splits: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! command -v python3 >/dev/null 2>&1; then
  echo "prepare-splits: python3 is required to validate JSON split files" >&2
  exit 1
fi

python3 - "$split_dir" <<'PY'
import json
import sys
from pathlib import Path

split_dir = Path(sys.argv[1]).expanduser().resolve()
required = ("train", "val", "test")

for split in required:
    path = split_dir / split / "items.json"
    if not path.is_file():
        raise SystemExit(f"prepare-splits: missing split file: {path}")
    try:
        items = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise SystemExit(f"prepare-splits: invalid JSON in {path}: {error}") from error
    if not isinstance(items, list):
        raise SystemExit(f"prepare-splits: {path} must contain a JSON array")
    if not items:
        raise SystemExit(f"prepare-splits: {path} must contain at least one item")

print(split_dir)
PY

if [ "$check_only" = true ]; then
  exit 0
fi

echo "prepare-splits: no copy needed; use the printed split_dir with SkillOpt"

