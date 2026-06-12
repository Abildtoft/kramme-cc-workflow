#!/usr/bin/env bats

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

    grep -qF ".context/demo-reels/<timestamp>/" "$skill/SKILL.md"
    grep -qF "Do not upload, attach, or publish artifacts unless the user explicitly asks" "$skill/SKILL.md"
    grep -qF "\${CLAUDE_PLUGIN_ROOT}/scripts/dev-server/detect-url.sh" "$skill/SKILL.md"
    grep -qF "DEMO_REEL_SKILL_DIR" "$skill/SKILL.md"
    grep -qF "\${CLAUDE_PLUGIN_ROOT}/skills/kramme:visual:demo-reel" "$skill/SKILL.md"
    grep -qF "Test output is verification evidence, not demo evidence" "$skill/SKILL.md"
    grep -qF "Static screenshots" "$skill/references/capture-tiers.md"
    grep -qF "Before/after screenshots" "$skill/references/capture-tiers.md"
    grep -qF "Browser reel" "$skill/references/capture-tiers.md"
    grep -qF "Terminal recording" "$skill/references/capture-tiers.md"
    grep -qF "compound-ce-demo-reel" "$skill/references/sources.yaml"
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
  '

	[ "$status" -eq 0 ]
}

@test "workflow cleanup includes demo reel artifacts" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    grep -qF ".context/demo-reels/" "skills/kramme:workflow-artifacts:cleanup/SKILL.md"
  '

	[ "$status" -eq 0 ]
}
