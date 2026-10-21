#!/usr/bin/env bats
#
# Guidance contracts for the codebase audit family. The skills are LLM-driven
# prose, so these tests pin the cost, safety, and report contracts as text.

setup() {
	cd "$BATS_TEST_DIRNAME/.."
	REFACTOR_SKILL="skills/kramme:code:refactor-opportunities/SKILL.md"
	RANKED_MODE="skills/kramme:code:refactor-opportunities/references/ranked-mode.md"
	WEAKNESS_SKILL="skills/kramme:code:weakness-audit/SKILL.md"
	AUDIT_WORKFLOW="shared/codebase-audit/references/audit-workflow.md"
	AUDIT_RUBRIC="shared/codebase-audit/references/audit-rubric.md"
	AUDIT_TEMPLATE="shared/codebase-audit/assets/report-template.md"
	CONVERGENCE_POLICY="skills/kramme:pr:review-convergence/references/review-convergence.md"
}

@test "refactor opportunities advertises ranked mode and keeps it user-only" {
	grep -qF -- '--ranked' <(sed -n '/^argument-hint:/p' "$REFACTOR_SKILL")
	grep -qxF 'disable-model-invocation: false' "$REFACTOR_SKILL"
	grep -qF "Honor \`--ranked\` only when the user's own message typed \`--ranked\`" "$REFACTOR_SKILL"
	grep -qF 'must never add `--ranked`' "$REFACTOR_SKILL"
	grep -qF 'stop before launching any agent' "$REFACTOR_SKILL"
	grep -qF 'read `references/ranked-mode.md` now' "$REFACTOR_SKILL"
}

@test "review convergence passes only the PR scope to the refactor gate" {
	grep -qF 'invoke `kramme:code:refactor-opportunities` with `pr`' "$CONVERGENCE_POLICY"
	run grep -qF -- '--ranked' "$CONVERGENCE_POLICY"
	[ "$status" -eq 1 ]
}

@test "ranked mode keeps the weakness report contract" {
	grep -qF 'CODEBASE_WEAKNESS_REPORT.md' "$RANKED_MODE"
	grep -qF 'Assign stable IDs `WA-001`, `WA-002`, ... after sorting.' "$AUDIT_WORKFLOW"
	grep -qF 'Default is `20`; cap at `30` unless the user explicitly asks for a broader inventory.' "$AUDIT_WORKFLOW"
	grep -qF 'For the full nine-reviewer set, the quorum is at least seven successful research reviewers.' "$AUDIT_WORKFLOW"
	grep -qF 'Ranked mode audits full, path, or feature scopes.' "$RANKED_MODE"
	grep -qF 'Agent Teams are not required' "$RANKED_MODE"
	grep -qF 'Re-run with --ranked --solo for the lower-coverage fallback.' "$RANKED_MODE"
	grep -qF 'End the run with `Agents launched: N`' "$AUDIT_WORKFLOW"
	grep -qF '**Challenge reviewer**' "$AUDIT_WORKFLOW"
	grep -qF 'priority_score = (impact * 3) + (confidence * 2) + breadth + urgency + leverage + effort' "$AUDIT_RUBRIC"
	local heading
	for heading in '### WA-001: {Finding title}' '## Top Weaknesses' '## Cross-Cutting Themes' \
		'## Filtered Candidates and Near Misses' '## Impressions (Unverified)' '## Coverage Notes' '## Team Review'; do
		grep -qF "$heading" "$AUDIT_TEMPLATE"
	done
}

@test "audit entrypoints use one shared workflow rubric and report schema" {
	local skill resource
	for skill in "$REFACTOR_SKILL" "$WEAKNESS_SKILL"; do
		for resource in "$AUDIT_WORKFLOW" "$AUDIT_RUBRIC" "$AUDIT_TEMPLATE"; do
			grep -qF "\${CLAUDE_PLUGIN_ROOT}/$resource" "$skill"
			[ -f "$resource" ]
		done
	done
	grep -qF "\${CLAUDE_PLUGIN_ROOT}/$AUDIT_WORKFLOW" "$RANKED_MODE"
	[ ! -e skills/kramme:code:refactor-opportunities/references/ranked-rubric.md ]
	[ ! -e skills/kramme:code:refactor-opportunities/assets/ranked-report-template.md ]
	[ ! -e skills/kramme:code:weakness-audit/references/audit-rubric.md ]
	[ ! -e skills/kramme:code:weakness-audit/assets/report-template.md ]
}

@test "audit adapters preserve mode gates and rejection handling" {
	grep -qxF 'disable-model-invocation: true' "$WEAKNESS_SKILL"
	grep -qF 'Optional `--team` is accepted as a no-op compatibility flag' "$WEAKNESS_SKILL"
	grep -qF 'Agent Teams must be enabled' skills/kramme:code:weakness-audit/references/team-mode.md
	grep -qF 'Reject `--team`' "$RANKED_MODE"
	grep -qF 'Phase 3 steps 4-5' "$RANKED_MODE"
	grep -qF 'before final ranking' "$RANKED_MODE"
	grep -qF 'Phase 4 step 9' "$RANKED_MODE"
	grep -qF 'Run this section only when `AUDIT_MODE=team`' "$AUDIT_WORKFLOW"
	grep -qF 'Run this section only when `AUDIT_MODE=solo`; launch no reviewers.' "$AUDIT_WORKFLOW"
}
