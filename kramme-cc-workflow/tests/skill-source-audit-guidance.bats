#!/usr/bin/env bats

setup() {
	cd "$BATS_TEST_DIRNAME/../.."
}

SKILL=".agents/skills/kramme:skill:audit-sources/SKILL.md"
NORMALIZATION_RULES=".agents/skills/kramme:skill:audit-sources/references/normalization-rules.md"
REPORT_TEMPLATE=".agents/skills/kramme:skill:audit-sources/references/report-template.md"

@test "source audit routes raw source code through lossless plain-text normalization" {
	grep -qF 'Use `--type markdown` as the lossless plain-text mode' "$SKILL"
	grep -qF 'raw source code, and any other non-HTML `text/plain` response' "$SKILL"
	grep -qF 'source code served as `text/plain`' "$NORMALIZATION_RULES"
	grep -qF '`--type markdown` option is the lossless mode for all such non-HTML text' "$NORMALIZATION_RULES"
}

@test "source audit persists a hash initialized on an unchanged GitHub source" {
	grep -qF 'mark "baseline initialized", and stage the new hash for Phase 5' "$SKILL"
	grep -qF 'for each changed or baseline-initialized source' "$SKILL"
	grep -qF 'on an `unchanged` GitHub source that step 1 does not cover' "$SKILL"
}

@test "source audit report covers moved sources and truncated commit windows" {
	grep -qF 'report the count as "at least `commit_count`"' "$SKILL"
	grep -qF 'moved or gone sources with `path_status` and `move_candidates`' "$SKILL"
	grep -qF '| Moved or gone |' "$REPORT_TEMPLATE"
	grep -qF '### Moved or gone sources' "$REPORT_TEMPLATE"
	grep -qF '**Commit window:**' "$REPORT_TEMPLATE"
}
