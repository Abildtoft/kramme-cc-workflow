#!/usr/bin/env bats

setup() {
	cd "$BATS_TEST_DIRNAME/../.."
}

SKILL=".agents/skills/kramme:skill:audit-sources/SKILL.md"
NORMALIZATION_RULES=".agents/skills/kramme:skill:audit-sources/references/normalization-rules.md"

@test "source audit routes raw source code through lossless plain-text normalization" {
	grep -qF 'Use `--type markdown` as the lossless plain-text mode' "$SKILL"
	grep -qF 'raw source code, and any other non-HTML `text/plain` response' "$SKILL"
	grep -qF 'source code served as `text/plain`' "$NORMALIZATION_RULES"
	grep -qF '`--type markdown` option is the lossless mode for all such non-HTML text' "$NORMALIZATION_RULES"
}
