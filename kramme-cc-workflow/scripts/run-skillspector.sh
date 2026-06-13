#!/usr/bin/env bash
#
# Run SkillSpector against repository skills with stable local defaults.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
PLUGIN_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
SKILLS_DIR="$PLUGIN_ROOT/skills"

MODE=""
BASE_REF="${BASE_REF:-origin/main}"
FORMAT="json"
OUTPUT_DIR=""
FAIL_ON="none"
SEMANTIC=0

usage() {
	cat >&2 <<'USAGE'
Usage: run-skillspector.sh (--all|--changed) [options]

Options:
  --all                         Scan every skill directory.
  --changed                     Scan skill directories changed against the base ref.
  --base <ref>                  Base ref for --changed (default: ${BASE_REF:-origin/main}).
  --format <format>             Primary report format: markdown, json, sarif, or terminal (default: json).
  --output-dir <dir>            Report directory (default: $RUNNER_TEMP/skillspector or .context/skillspector).
  --fail-on <threshold>         Finding threshold: high, critical, or none (default: none).
  --semantic                    Enable SkillSpector LLM analysis. Static-only mode is the default.
  -h, --help                    Show this help.

The wrapper always writes a JSON report for each scanned skill so threshold
checks have a stable machine-readable input. When --format is not json, it also
writes a companion report in the requested format.
USAGE
}

require_value() {
	local flag="$1"
	local value="${2-}"
	case "$value" in
	"" | --*)
		echo "$flag requires a value" >&2
		exit 2
		;;
	esac
}

set_mode() {
	local next_mode="$1"
	if [ -n "$MODE" ] && [ "$MODE" != "$next_mode" ]; then
		echo "Choose only one scan mode: --all or --changed" >&2
		exit 2
	fi
	MODE="$next_mode"
}

while [ $# -gt 0 ]; do
	case "$1" in
	--all)
		set_mode "all"
		shift
		;;
	--changed)
		set_mode "changed"
		shift
		;;
	--base)
		require_value "$1" "${2-}"
		BASE_REF="$2"
		shift 2
		;;
	--format)
		require_value "$1" "${2-}"
		FORMAT="$2"
		shift 2
		;;
	--output-dir)
		require_value "$1" "${2-}"
		OUTPUT_DIR="$2"
		shift 2
		;;
	--fail-on)
		require_value "$1" "${2-}"
		FAIL_ON="$2"
		shift 2
		;;
	--semantic)
		SEMANTIC=1
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		echo "Unknown argument: $1" >&2
		usage
		exit 2
		;;
	esac
done

case "$MODE" in
all | changed) ;;
"")
	echo "Missing scan mode: choose --all or --changed" >&2
	usage
	exit 2
	;;
esac

case "$FORMAT" in
markdown | json | sarif | terminal) ;;
*)
	echo "Unsupported --format '$FORMAT'; expected markdown, json, sarif, or terminal" >&2
	exit 2
	;;
esac

case "$FAIL_ON" in
high | critical | none) ;;
*)
	echo "Unsupported --fail-on '$FAIL_ON'; expected high, critical, or none" >&2
	exit 2
	;;
esac

if ! REPO_ROOT=$(git -C "$PLUGIN_ROOT" rev-parse --show-toplevel 2>/dev/null); then
	echo "run-skillspector.sh must run from inside a git repository" >&2
	exit 1
fi
REPO_ROOT=$(cd -- "$REPO_ROOT" && pwd -P)

if [ -z "$OUTPUT_DIR" ]; then
	if [ -n "${RUNNER_TEMP:-}" ]; then
		OUTPUT_DIR="$RUNNER_TEMP/skillspector"
	else
		OUTPUT_DIR="$REPO_ROOT/.context/skillspector"
	fi
fi
mkdir -p "$OUTPUT_DIR"

relative_plugin_path() {
	if [ "$PLUGIN_ROOT" = "$REPO_ROOT" ]; then
		printf '%s\n' ""
	else
		printf '%s\n' "${PLUGIN_ROOT#"$REPO_ROOT"/}"
	fi
}

append_unique_skill_dir() {
	local skill_dir="$1"
	local existing

	if [ ! -f "$skill_dir/SKILL.md" ]; then
		return
	fi
	for existing in "${SKILL_DIRS[@]:-}"; do
		if [ "$existing" = "$skill_dir" ]; then
			return
		fi
	done
	SKILL_DIRS+=("$skill_dir")
}

discover_all_skills() {
	local skill_md
	SKILL_DIRS=()
	while IFS= read -r skill_md; do
		append_unique_skill_dir "$(dirname -- "$skill_md")"
	done < <(find "$SKILLS_DIR" -mindepth 2 -maxdepth 2 -name SKILL.md -type f | sort)
}

discover_changed_skills() {
	local changed_path
	local merge_base
	local plugin_rel
	local skills_prefix
	local rest
	local skill_name

	SKILL_DIRS=()
	merge_base=$(git -C "$REPO_ROOT" merge-base "$BASE_REF" HEAD)
	plugin_rel=$(relative_plugin_path)
	if [ -n "$plugin_rel" ]; then
		skills_prefix="$plugin_rel/skills/"
	else
		skills_prefix="skills/"
	fi

	while IFS= read -r changed_path; do
		case "$changed_path" in
		"$skills_prefix"*/*)
			rest=${changed_path#"$skills_prefix"}
			skill_name=${rest%%/*}
			append_unique_skill_dir "$SKILLS_DIR/$skill_name"
			;;
		esac
	done < <(
		{
			git -C "$REPO_ROOT" diff --name-only "$merge_base"
			git -C "$REPO_ROOT" ls-files --others --exclude-standard
		} | sort -u
	)
}

report_stem_for_skill() {
	local skill_dir="$1"
	local skill_name
	skill_name=$(basename -- "$skill_dir")
	printf '%s' "$skill_name" | tr -c 'A-Za-z0-9._-' '_'
}

extension_for_format() {
	case "$1" in
	json) printf '%s\n' "json" ;;
	markdown) printf '%s\n' "md" ;;
	sarif) printf '%s\n' "sarif" ;;
	terminal) printf '%s\n' "txt" ;;
	esac
}

run_scan_format() {
	local skill_dir="$1"
	local format="$2"
	local output_file="$3"
	local log_file="$4"
	local status
	local args

	args=(scan "$skill_dir" --format "$format" --output "$output_file")
	if [ "$SEMANTIC" -eq 0 ]; then
		args+=(--no-llm)
	fi

	set +e
	skillspector "${args[@]}" >"$log_file" 2>&1
	status=$?
	set -e

	if [ "$status" -eq 0 ]; then
		return 0
	fi

	if [ "$status" -eq 1 ] && [ -s "$output_file" ]; then
		return 0
	fi

	echo "SkillSpector scan failed for $skill_dir with exit code $status" >&2
	if [ -s "$log_file" ]; then
		cat "$log_file" >&2
	fi
	return "$status"
}

severity_count() {
	local json_file="$1"
	local severity="$2"

	jq --arg severity "$severity" \
		'[.issues[]? | select(((.severity // "") | ascii_upcase) == $severity)] | length' \
		"$json_file"
}

threshold_failed_for_report() {
	local json_file="$1"
	local threshold="$2"
	local high_count=0
	local critical_count=0

	if [ "$threshold" = "none" ]; then
		return 1
	fi

	critical_count=$(severity_count "$json_file" "CRITICAL")
	if [ "$threshold" = "critical" ]; then
		[ "$critical_count" -gt 0 ]
		return
	fi

	high_count=$(severity_count "$json_file" "HIGH")
	[ "$critical_count" -gt 0 ] || [ "$high_count" -gt 0 ]
}

if [ "$MODE" = "all" ]; then
	discover_all_skills
else
	discover_changed_skills
fi

if [ "${#SKILL_DIRS[@]}" -eq 0 ]; then
	if [ "$MODE" = "changed" ]; then
		echo "No changed skill directories found against $BASE_REF."
	else
		echo "No skill directories found under $SKILLS_DIR."
	fi
	exit 0
fi

if ! command -v skillspector >/dev/null 2>&1; then
	cat >&2 <<'ERROR'
SkillSpector scanner not found on PATH.
Install SkillSpector in an active Python 3.12+ environment, then retry.
See: https://github.com/NVIDIA/SkillSpector
ERROR
	exit 127
fi

if [ "$FAIL_ON" != "none" ] && ! command -v jq >/dev/null 2>&1; then
	echo "--fail-on $FAIL_ON requires jq to parse SkillSpector JSON reports" >&2
	exit 1
fi

echo "SkillSpector scan mode: $MODE"
if [ "$MODE" = "changed" ]; then
	echo "Base ref: $BASE_REF"
fi
echo "Output directory: $OUTPUT_DIR"
echo "Static only: $([ "$SEMANTIC" -eq 0 ] && printf 'yes' || printf 'no')"
echo "Fail threshold: $FAIL_ON"
echo "Skills: ${#SKILL_DIRS[@]}"

SCAN_FAILED=0
THRESHOLD_FAILED=0
for skill_dir in "${SKILL_DIRS[@]}"; do
	stem=$(report_stem_for_skill "$skill_dir")
	json_report="$OUTPUT_DIR/$stem.json"
	log_file="$OUTPUT_DIR/$stem.log"
	primary_ext=$(extension_for_format "$FORMAT")
	primary_report="$OUTPUT_DIR/$stem.$primary_ext"

	echo "Scanning $skill_dir"
	if ! run_scan_format "$skill_dir" "json" "$json_report" "$log_file"; then
		SCAN_FAILED=1
		continue
	fi
	echo "  JSON report: $json_report"

	if [ "$FORMAT" != "json" ]; then
		if ! run_scan_format "$skill_dir" "$FORMAT" "$primary_report" "$log_file"; then
			SCAN_FAILED=1
			continue
		fi
		echo "  $FORMAT report: $primary_report"
	fi

	if threshold_failed_for_report "$json_report" "$FAIL_ON"; then
		echo "  Findings meet --fail-on $FAIL_ON threshold"
		THRESHOLD_FAILED=1
	fi
done

if [ "$SCAN_FAILED" -ne 0 ]; then
	exit 1
fi
if [ "$THRESHOLD_FAILED" -ne 0 ]; then
	echo "SkillSpector findings met the configured fail threshold." >&2
	exit 1
fi
