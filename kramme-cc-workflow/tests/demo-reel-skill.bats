#!/usr/bin/env bats

load 'test_helper/common'

@test "visual demo reel skill has required local evidence guidance" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    skill="skills/kramme:visual:demo-reel"

    test -f "$skill/SKILL.md"
    test -f "$skill/references/capture-tiers.md"
    test -f "$skill/references/secret-preflight.md"
    test -f "$skill/references/environment-startup.md"
    test -f "$skill/references/tier-static-screenshots.md"
    test -f "$skill/references/tier-before-after-screenshots.md"
    test -f "$skill/references/tier-browser-reel.md"
    test -f "$skill/references/tier-terminal-recording.md"
    test -f "$skill/references/sources.yaml"
    test -f "$skill/scripts/demo_reel_helper.py"

    grep -q "^## Workflow" "$skill/SKILL.md"
    grep -q "^## Selection Rules" "$skill/references/capture-tiers.md"
    grep -qF "disable-model-invocation: false" "$skill/SKILL.md"
    grep -qF "### Model Invocation Contract" "$skill/SKILL.md"
    grep -qF "exact child of \`kramme:pr:generate-description\`" "$skill/SKILL.md"
    grep -qF -- "--for-pr-description --base-commit <oid>" "$skill/SKILL.md"
    grep -qF "No other parent workflow is authorized by this model-invocation exception" "$skill/SKILL.md"
    grep -qF "Require delegated callers to put trusted flags before exactly one \`--\` separator" "$skill/SKILL.md"
    grep -qF "git -C \"\$REPO_ROOT\" check-ignore -q -- .context/demo-reels/" "$skill/SKILL.md"
    grep -qF "otherwise return \`Tier: skipped\` in delegated mode" "$skill/SKILL.md"
    grep -qF "Accept it only with valid delegated PR mode; otherwise reject it" "$skill/SKILL.md"
    grep -qF "when \`START_IF_EASY=true\` and the target is UI-facing" "$skill/SKILL.md"
    grep -qF "Never automatically execute a new or modified command supplied by the branch under review" "$skill/references/environment-startup.md"
    grep -qF "For at most 60 seconds" "$skill/references/environment-startup.md"
    grep -qF "Never kill by port, executable name, or pattern" "$skill/references/environment-startup.md"
    grep -qF "return \`Tier: skipped\` with the reason in delegated mode" "$skill/references/capture-tiers.md"
    grep -qF "In delegated mode, return \`Tier: skipped\` with the safety reason instead of asking" "$skill/references/secret-preflight.md"
    grep -qF "return \`Tier: skipped\` in delegated mode" "$skill/references/tier-static-screenshots.md"
    grep -qF "Manifest: <DEMO_REEL_DIR>/manifest.json" "$skill/SKILL.md"
  '

	assert_required_contracts_registered \
		visual-demo-reel-guidance \
		visual-demo-reel-environment-startup \
		visual-demo-reel-capture-tiers \
		visual-demo-reel-source-manifest \
		visual-demo-reel-model-invocation-contract

	[ "$status" -eq 0 ]
}

@test "visual demo reel helper rejects symlinked artifact parents" {
	if ! command -v python3 >/dev/null 2>&1; then
		skip "python3 is required for demo reel helper tests"
	fi

	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    script="skills/kramme:visual:demo-reel/scripts/demo_reel_helper.py"
    repo=$(mktemp -d)
    outside=$(mktemp -d)
    trap '"'"'rm -rf "$repo" "$outside"'"'"' EXIT
    ln -s "$outside" "$repo/.context"

    if python3 "$script" create-run-dir --repo-root "$repo" --timestamp 20260609T000000Z; then
      exit 1
    fi
    test ! -e "$outside/demo-reels"
  '

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
    grep -qF "\"schema_version\": 1" "$first/manifest.json"
  '

	[ "$status" -eq 0 ]
}

@test "workflow cleanup includes demo reel artifacts" {
	assert_required_contracts_registered workflow-artifact-cleanup-names
}
