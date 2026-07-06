#!/usr/bin/env bats

assert_required_contracts_registered() {
	cd "$BATS_TEST_DIRNAME/.."
	python3 - "$@" <<'PY'
import json
import pathlib
import sys

registry = json.loads(pathlib.Path("scripts/synced-contracts.yaml").read_text())
registered = {contract["name"] for contract in registry.get("required_file_contracts", [])}
missing = sorted(set(sys.argv[1:]) - registered)
if missing:
    raise SystemExit(f"missing required_file_contracts: {', '.join(missing)}")
PY
}

@test "visual demo reel skill has required local evidence guidance" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:visual:demo-reel"

    test -f "$skill/SKILL.md"
    test -f "$skill/references/capture-tiers.md"
    test -f "$skill/references/secret-preflight.md"
    test -f "$skill/references/tier-static-screenshots.md"
    test -f "$skill/references/tier-before-after-screenshots.md"
    test -f "$skill/references/tier-browser-reel.md"
    test -f "$skill/references/tier-terminal-recording.md"
    test -f "$skill/references/sources.yaml"
    test -f "$skill/scripts/demo_reel_helper.py"

    grep -q "^## Workflow" "$skill/SKILL.md"
    grep -q "^## Selection Rules" "$skill/references/capture-tiers.md"
  '

	assert_required_contracts_registered \
		visual-demo-reel-guidance \
		visual-demo-reel-capture-tiers \
		visual-demo-reel-source-manifest

	[ "$status" -eq 0 ]
}

@test "visual demo reel helper compiles and runs preflight" {
	if ! command -v python3 >/dev/null 2>&1; then
		skip "python3 is required for demo reel helper tests"
	fi

	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    script="skills/kramme:visual:demo-reel/scripts/demo_reel_helper.py"

    python3 -m py_compile "$script"

    preflight_output=$(python3 "$script" preflight)
    printf "%s" "$preflight_output" | grep -qF "\"vhs\""
    printf "%s" "$preflight_output" | grep -qF "\"ffmpeg\""

    # The recommend subcommand was removed as dead code; tier selection is manual.
    ! grep -qF "recommend" "$script"
  '

	[ "$status" -eq 0 ]
}

@test "visual demo reel helper handles timestamp collisions" {
	if ! command -v python3 >/dev/null 2>&1; then
		skip "python3 is required for demo reel helper tests"
	fi

	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    script="skills/kramme:visual:demo-reel/scripts/demo_reel_helper.py"
    tmp=$(mktemp -d)
    trap '"'"'rm -rf "$tmp"'"'"' EXIT

    first=$(python3 "$script" create-run-dir --repo-root "$tmp" --timestamp 20260609T000000Z)
    second=$(python3 "$script" create-run-dir --repo-root "$tmp" --timestamp 20260609T000000Z)

    test "$first" != "$second"
    test -d "$first"
    test -d "$second"
    test -f "$first/manifest.json"
    test -f "$second/manifest.json"
  '

	[ "$status" -eq 0 ]
}

@test "workflow cleanup includes demo reel artifacts" {
	assert_required_contracts_registered workflow-artifact-cleanup-names
}
