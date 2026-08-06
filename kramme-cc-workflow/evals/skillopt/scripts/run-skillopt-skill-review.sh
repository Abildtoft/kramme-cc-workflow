#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: run-skillopt-skill-review.sh [--dry-run] [--run-id <id>] [--out-root <path>]

Builds and optionally runs the external SkillOpt command for the skill-review
pilot. A real run requires SKILLOPT_REPO to point at an external SkillOpt
checkout. Dry-run mode validates local splits and prints the command without
requiring SkillOpt or model credentials.
EOF
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
workflow_root="$(cd "$script_dir/../../.." && pwd -P)"
repo_root="$(cd "$workflow_root/.." && pwd -P)"
# shellcheck source=../../../scripts/lib/shell-helpers.sh
source "$workflow_root/scripts/lib/shell-helpers.sh"
skillopt_env_name="kramme_skill_review"

dry_run=false
run_id=""
out_root=""

while [ "$#" -gt 0 ]; do
  case "$1" in
  --dry-run)
    dry_run=true
    shift
    ;;
  --run-id)
    require_value "$1" "${2-}" 2 "run-skillopt: "
    run_id="$2"
    shift 2
    ;;
  --out-root)
    require_value "$1" "${2-}" 2 "run-skillopt: "
    out_root="$2"
    shift 2
    ;;
  --help | -h)
    usage
    exit 0
    ;;
  *)
    echo "run-skillopt: unknown argument: $1" >&2
    usage >&2
    exit 2
    ;;
  esac
done

if [ -z "$run_id" ]; then
  run_id="$(date -u +%Y%m%dT%H%M%SZ)"
fi

case "$run_id" in
*[!A-Za-z0-9._-]* | "")
  echo "run-skillopt: run id must contain only letters, numbers, dots, underscores, and dashes" >&2
  exit 2
  ;;
esac

config_path="$workflow_root/evals/skillopt/configs/skill-review.yaml"
split_dir="$workflow_root/evals/skill-review/items"
skill_init="$workflow_root/skills/kramme:skill:review/SKILL.md"

if [ -z "$out_root" ]; then
  out_root="$repo_root/.context/skillopt-runs/skill-review/$run_id/skillopt-output"
fi

case "$out_root" in
/* | ~*) ;;
*) out_root="$repo_root/$out_root" ;;
esac

out_root_real="$(require_scratch_boundary "$repo_root" ".context/skillopt-runs/skill-review" "$out_root" "run-skillopt: output root ")"

bash "$script_dir/prepare-splits.sh" --check-only --split-dir "$split_dir" >/dev/null

if [ ! -f "$config_path" ]; then
  echo "run-skillopt: missing config: $config_path" >&2
  exit 1
fi

if [ ! -f "$skill_init" ]; then
  echo "run-skillopt: missing seed skill: $skill_init" >&2
  exit 1
fi

skillopt_repo="${SKILLOPT_REPO:-$repo_root/.context/skillopt}"

export REPO_ROOT="$repo_root"
export SKILLOPT_CONFIG="$config_path"
export SKILLOPT_SPLIT_DIR="$split_dir"
export SKILLOPT_SKILL_INIT="$skill_init"
export SKILLOPT_OUT_ROOT="$out_root_real"

if [ -n "${SKILLOPT_CMD:-}" ]; then
  command_text="$SKILLOPT_CMD"
else
  # shellcheck disable=SC2016 # Expanded later inside the SkillOpt checkout with exported paths.
  command_text='python3 scripts/train.py --config "$SKILLOPT_CONFIG" --split_mode split_dir --split_dir "$SKILLOPT_SPLIT_DIR" --skill_init "$SKILLOPT_SKILL_INIT" --out_root "$SKILLOPT_OUT_ROOT"'
fi

if [ "$dry_run" = true ]; then
  echo "DRY RUN: SkillOpt command preview"
  if [ -z "${SKILLOPT_REPO:-}" ]; then
    echo "SKILLOPT_REPO is not set; dry-run used placeholder: $skillopt_repo"
  else
    echo "SKILLOPT_REPO=$skillopt_repo"
  fi
  echo "SKILLOPT_CONFIG=$SKILLOPT_CONFIG"
  echo "SKILLOPT_SPLIT_DIR=$SKILLOPT_SPLIT_DIR"
  echo "SKILLOPT_SKILL_INIT=$SKILLOPT_SKILL_INIT"
  echo "SKILLOPT_OUT_ROOT=$SKILLOPT_OUT_ROOT"
  echo "cd \"$skillopt_repo\" && $command_text"
  exit 0
fi

if [ -z "${SKILLOPT_REPO:-}" ]; then
  echo "run-skillopt: SKILLOPT_REPO is required for a real run" >&2
  echo "run-skillopt: set SKILLOPT_REPO to an external SkillOpt checkout or use --dry-run" >&2
  exit 1
fi

if [ ! -d "$skillopt_repo" ]; then
  echo "run-skillopt: SKILLOPT_REPO does not exist or is not a directory: $skillopt_repo" >&2
  exit 1
fi

if [ -z "${SKILLOPT_CMD:-}" ] && [ ! -f "$skillopt_repo/scripts/train.py" ]; then
  echo "run-skillopt: expected SkillOpt train script at $skillopt_repo/scripts/train.py" >&2
  exit 1
fi

if [ -z "${SKILLOPT_CMD:-}" ] && ! grep -R -q "$skillopt_env_name" "$skillopt_repo/scripts" "$skillopt_repo/skillopt" 2>/dev/null; then
  echo "run-skillopt: default command requires SkillOpt environment '$skillopt_env_name' to be registered in SKILLOPT_REPO" >&2
  echo "run-skillopt: use an external checkout/fork with that EnvAdapter, or set SKILLOPT_CMD for your custom runner" >&2
  exit 1
fi

mkdir -p "$out_root_real"
(
  cd "$skillopt_repo"
  bash -c "$command_text"
)
