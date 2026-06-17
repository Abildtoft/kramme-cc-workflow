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
ACCEPTED_FINDINGS_FILE=""
ACCEPTED_FINDINGS_EXPLICIT=0
TODAY="${TODAY:-$(date +%F)}"

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
  --accepted-findings <path>    JSON registry for accepted findings (default: config/skillspector-accepted-findings.json when present).
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
	--accepted-findings)
		require_value "$1" "${2-}"
		ACCEPTED_FINDINGS_FILE="$2"
		ACCEPTED_FINDINGS_EXPLICIT=1
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

if [ -z "$ACCEPTED_FINDINGS_FILE" ] && [ -f "$PLUGIN_ROOT/config/skillspector-accepted-findings.json" ]; then
	ACCEPTED_FINDINGS_FILE="$PLUGIN_ROOT/config/skillspector-accepted-findings.json"
fi

if [ -n "$ACCEPTED_FINDINGS_FILE" ]; then
	case "$ACCEPTED_FINDINGS_FILE" in
	/*) ;;
	*) ACCEPTED_FINDINGS_FILE="$(pwd -P)/$ACCEPTED_FINDINGS_FILE" ;;
	esac
	if [ ! -f "$ACCEPTED_FINDINGS_FILE" ]; then
		if [ "$ACCEPTED_FINDINGS_EXPLICIT" -eq 1 ]; then
			echo "Accepted-findings file not found: $ACCEPTED_FINDINGS_FILE" >&2
			exit 2
		fi
		ACCEPTED_FINDINGS_FILE=""
	fi
fi

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

SCAN_TEMP_DIRS=()

cleanup_scan_temp_dirs() {
	local temp_dir

	for temp_dir in "${SCAN_TEMP_DIRS[@]:-}"; do
		rm -rf -- "$temp_dir"
	done
}
trap cleanup_scan_temp_dirs EXIT

prepare_scan_input() {
	local skill_dir="$1"
	local temp_root
	local temp_parent
	local scan_dir

	if [ ! -d "$skill_dir/references/sources-snapshot" ]; then
		printf '%s\n' "$skill_dir"
		return
	fi

	temp_root="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
	temp_parent=$(mktemp -d "$temp_root/skillspector-scan.XXXXXX")
	SCAN_TEMP_DIRS+=("$temp_parent")
	scan_dir="$temp_parent/$(basename -- "$skill_dir")"

	cp -R "$skill_dir" "$scan_dir"
	rm -rf -- "$scan_dir/references/sources-snapshot"
	printf '%s\n' "$scan_dir"
}

severity_count() {
	local json_file="$1"
	local severity="$2"

	jq --arg severity "$severity" \
		'[.issues[]? | select(((.severity // "") | ascii_upcase) == $severity)] | length' \
		"$json_file"
}

policy_jq_filter() {
	cat <<'JQ'
def normalize_path($repo_root):
	if type != "string" then empty
	elif startswith($repo_root + "/") then .[($repo_root | length + 1):]
	elif startswith("./") then .[2:]
	else .
	end;

def finding_rule_id:
	(.rule_id // .ruleId // .id // .rule // "");

def finding_path_candidates($repo_root; $skill_repo_rel):
	normalize_path($repo_root) as $path
	| if ($path | length) == 0 then
		empty
	elif ($path == $skill_repo_rel) or ($path | startswith($skill_repo_rel + "/")) then
		[$path]
	else
		[$path, ($skill_repo_rel + "/" + $path)]
	end;

def finding_paths($repo_root; $skill_repo_rel):
	[
		.path?,
		.file_path?,
		.file?,
		.filename?,
		.artifactLocation?.uri?,
		.location?.path?,
		.location?.file?,
		.location?.file_path?,
		.location?.physicalLocation?.artifactLocation?.uri?,
		.locations[]?.path?,
		.locations[]?.physicalLocation?.artifactLocation?.uri?,
		.source?.path?
	]
	| map(finding_path_candidates($repo_root; $skill_repo_rel))
	| flatten
	| map(select(length > 0))
	| unique;

def accepted_entry_cutoff:
	[.expires_at?, .review_after?]
	| map(select(type == "string" and length > 0))
	| if length == 0 then "9999-12-31" else min end;

def active_accepted_entries($policy; $today):
	($policy[0].accepted_findings // [])
	| map(select((. | accepted_entry_cutoff) >= $today));

def is_accepted($policy; $repo_root; $skill_repo_rel; $today):
	finding_rule_id as $rule
	| finding_paths($repo_root; $skill_repo_rel) as $paths
	| any(active_accepted_entries($policy; $today)[];
		. as $entry
		| ($entry.rule_id == $rule)
		and (($paths | index(($entry.path | normalize_path($repo_root)))) != null)
	);
JQ
}

finding_count() {
	local json_file="$1"

	jq '[.issues[]?] | length' "$json_file"
}

accepted_finding_count() {
	local json_file="$1"
	local skill_repo_rel="$2"

	if [ -z "$ACCEPTED_FINDINGS_FILE" ]; then
		printf '0\n'
		return
	fi

	jq \
		--arg repo_root "$REPO_ROOT" \
		--arg skill_repo_rel "$skill_repo_rel" \
		--arg today "$TODAY" \
		--slurpfile policy "$ACCEPTED_FINDINGS_FILE" \
		"$(policy_jq_filter)"'
		[.issues[]? | select(is_accepted($policy; $repo_root; $skill_repo_rel; $today))] | length
		' "$json_file"
}

enforceable_severity_count() {
	local json_file="$1"
	local severity="$2"
	local skill_repo_rel="$3"

	if [ -z "$ACCEPTED_FINDINGS_FILE" ]; then
		severity_count "$json_file" "$severity"
		return
	fi

	jq \
		--arg repo_root "$REPO_ROOT" \
		--arg skill_repo_rel "$skill_repo_rel" \
		--arg today "$TODAY" \
		--arg severity "$severity" \
		--slurpfile policy "$ACCEPTED_FINDINGS_FILE" \
		"$(policy_jq_filter)"'
		[
			.issues[]?
			| select(((.severity // "") | ascii_upcase) == $severity)
			| select(is_accepted($policy; $repo_root; $skill_repo_rel; $today) | not)
		] | length
		' "$json_file"
}

threshold_failed_for_report() {
	local json_file="$1"
	local threshold="$2"
	local skill_repo_rel="$3"
	local high_count=0
	local critical_count=0

	if [ "$threshold" = "none" ]; then
		return 1
	fi

	critical_count=$(enforceable_severity_count "$json_file" "CRITICAL" "$skill_repo_rel")
	if [ "$threshold" = "critical" ]; then
		[ "$critical_count" -gt 0 ]
		return
	fi

	high_count=$(enforceable_severity_count "$json_file" "HIGH" "$skill_repo_rel")
	[ "$critical_count" -gt 0 ] || [ "$high_count" -gt 0 ]
}

validate_accepted_findings_policy() {
	local validation_errors
	local expired_entries

	if [ -z "$ACCEPTED_FINDINGS_FILE" ]; then
		return 0
	fi

	if ! validation_errors=$(jq -r '
		def nonempty_string($entry; $field):
			(($entry[$field]? | type) == "string") and (($entry[$field] | length) > 0);
		def missing($index; $field):
			"accepted_findings[" + ($index | tostring) + "]." + $field + " is required";
		def invalid_date($index; $field):
			"accepted_findings[" + ($index | tostring) + "]." + $field + " must use YYYY-MM-DD";

		(
			if (.accepted_findings | type) != "array" then
				"accepted_findings must be an array"
			else
				empty
			end
		),
		(
			if (.accepted_findings | type) == "array" then
				.accepted_findings
				| to_entries[]
				| .key as $index
				| .value as $entry
				| (
					["path", "rule_id", "reason", "owner", "accepted_at"][]
					| select(nonempty_string($entry; .) | not)
					| missing($index; .)
				),
				(
					if ((nonempty_string($entry; "expires_at") or nonempty_string($entry; "review_after")) | not) then
						"accepted_findings[" + ($index | tostring) + "] requires expires_at or review_after"
					else
						empty
					end
				),
				(
					if nonempty_string($entry; "accepted_at") and (($entry.accepted_at | test("^\\d{4}-\\d{2}-\\d{2}$")) | not) then
						invalid_date($index; "accepted_at")
					else
						empty
					end
				),
				(
					if nonempty_string($entry; "expires_at") and (($entry.expires_at | test("^\\d{4}-\\d{2}-\\d{2}$")) | not) then
						invalid_date($index; "expires_at")
					else
						empty
					end
				),
				(
					if nonempty_string($entry; "review_after") and (($entry.review_after | test("^\\d{4}-\\d{2}-\\d{2}$")) | not) then
						invalid_date($index; "review_after")
					else
						empty
					end
				)
			else
				empty
			end
		)
	' "$ACCEPTED_FINDINGS_FILE"); then
		echo "Accepted-findings policy is not valid JSON: $ACCEPTED_FINDINGS_FILE" >&2
		exit 1
	fi

	if [ -n "$validation_errors" ]; then
		echo "Accepted-findings policy is invalid: $ACCEPTED_FINDINGS_FILE" >&2
		echo "$validation_errors" >&2
		exit 1
	fi

	expired_entries=$(jq -r --arg today "$TODAY" '
		def accepted_entry_cutoff:
			[.expires_at?, .review_after?]
			| map(select(type == "string" and length > 0))
			| if length == 0 then "9999-12-31" else min end;

		.accepted_findings[]
		| select((. | accepted_entry_cutoff) < $today)
		| "expired accepted finding: " + .path + " " + .rule_id + " expired on " + (. | accepted_entry_cutoff)
	' "$ACCEPTED_FINDINGS_FILE")

	if [ -n "$expired_entries" ]; then
		if [ "$FAIL_ON" = "none" ]; then
			echo "$expired_entries" | sed 's/^/WARNING: /' >&2
		else
			echo "Accepted-findings policy contains expired entries: $ACCEPTED_FINDINGS_FILE" >&2
			echo "$expired_entries" >&2
			exit 1
		fi
	fi
}

if [ "$MODE" = "all" ]; then
	discover_all_skills
else
	discover_changed_skills
fi

if [ -n "$ACCEPTED_FINDINGS_FILE" ]; then
	if ! command -v jq >/dev/null 2>&1; then
		echo "SkillSpector report evaluation requires jq" >&2
		exit 1
	fi
	validate_accepted_findings_policy
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
	echo "SkillSpector report evaluation requires jq" >&2
	exit 1
fi

echo "SkillSpector scan mode: $MODE"
if [ "$MODE" = "changed" ]; then
	echo "Base ref: $BASE_REF"
fi
echo "Output directory: $OUTPUT_DIR"
echo "Static only: $([ "$SEMANTIC" -eq 0 ] && printf 'yes' || printf 'no')"
echo "Fail threshold: $FAIL_ON"
if [ -n "$ACCEPTED_FINDINGS_FILE" ]; then
	echo "Accepted findings: $ACCEPTED_FINDINGS_FILE"
fi
echo "Skills: ${#SKILL_DIRS[@]}"

SCAN_FAILED=0
THRESHOLD_FAILED=0
for skill_dir in "${SKILL_DIRS[@]}"; do
	skill_repo_rel=${skill_dir#"$REPO_ROOT"/}
	stem=$(report_stem_for_skill "$skill_dir")
	json_report="$OUTPUT_DIR/$stem.json"
	log_file="$OUTPUT_DIR/$stem.log"
	primary_ext=$(extension_for_format "$FORMAT")
	primary_report="$OUTPUT_DIR/$stem.$primary_ext"
	scan_dir=$(prepare_scan_input "$skill_dir")

	echo "Scanning $skill_dir"
	if [ "$scan_dir" != "$skill_dir" ]; then
		echo "  Excluding reference source snapshots from scan input"
	fi
	if ! run_scan_format "$scan_dir" "json" "$json_report" "$log_file"; then
		SCAN_FAILED=1
		continue
	fi
	echo "  JSON report: $json_report"

	total_findings=$(finding_count "$json_report")
	accepted_findings=$(accepted_finding_count "$json_report" "$skill_repo_rel")
	enforceable_findings=$((total_findings - accepted_findings))
	echo "  Findings: total=$total_findings accepted=$accepted_findings enforceable=$enforceable_findings"

	if [ "$FORMAT" != "json" ]; then
		if ! run_scan_format "$scan_dir" "$FORMAT" "$primary_report" "$log_file"; then
			SCAN_FAILED=1
			continue
		fi
		echo "  $FORMAT report: $primary_report"
	fi

	if threshold_failed_for_report "$json_report" "$FAIL_ON" "$skill_repo_rel"; then
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
