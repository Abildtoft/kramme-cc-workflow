#!/usr/bin/env bats
#
# Guidance contracts for the codebase audit family. The skills are LLM-driven
# prose, so these tests pin the cost, safety, and report contracts as text.

setup() {
	cd "$BATS_TEST_DIRNAME/.."
	REFACTOR_SKILL="skills/kramme:code:refactor-opportunities/SKILL.md"
	RANKED_MODE="skills/kramme:code:refactor-opportunities/references/ranked-mode.md"
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

@test "ranked mode uses the shared workflow rubric and report schema" {
	local resource
	for resource in "$AUDIT_WORKFLOW" "$AUDIT_RUBRIC" "$AUDIT_TEMPLATE"; do
		grep -qF "\${CLAUDE_PLUGIN_ROOT}/$resource" "$REFACTOR_SKILL"
		[ -f "$resource" ]
	done
	grep -qF "\${CLAUDE_PLUGIN_ROOT}/$AUDIT_WORKFLOW" "$RANKED_MODE"
	[ ! -e skills/kramme:code:refactor-opportunities/references/ranked-rubric.md ]
	[ ! -e skills/kramme:code:refactor-opportunities/assets/ranked-report-template.md ]
}

@test "ranked adapter preserves mode gates and rejection handling" {
	grep -qF 'Reject `--team`' "$RANKED_MODE"
	grep -qF 'Phase 3 steps 4-5' "$RANKED_MODE"
	grep -qF 'before final ranking' "$RANKED_MODE"
	grep -qF 'Phase 4 step 9' "$RANKED_MODE"
	grep -qF 'Run this section only when `AUDIT_MODE=team`' "$AUDIT_WORKFLOW"
	grep -qF 'Run this section only when `AUDIT_MODE=solo`; launch no reviewers.' "$AUDIT_WORKFLOW"
}

@test "ranked mode preserves the explicit history baseline" {
	grep -qF '[--ranked [--solo] [--output <path>] [--max-findings N] [--base <ref>]]' <(sed -n '/^argument-hint:/p' "$REFACTOR_SKILL")
	grep -qF 'resolve an explicit `--base <ref>` with `git rev-parse' "$REFACTOR_SKILL"
	grep -qF 'store it as `HISTORY_BASE_REF`' "$REFACTOR_SKILL"
	grep -qF '"${HISTORY_BASE_REF:-HEAD}"' "$REFACTOR_SKILL"
	grep -qF "Use Phase 1's \`HISTORY_BASE_REF\` for churn, co-change, and other history signals" "$RANKED_MODE"
	grep -qF 'never changes the ranked file scope' "$RANKED_MODE"
}

@test "weakness audit is retired and its consumers route to ranked mode" {
	[ ! -e "skills/kramme:code:weakness-audit" ]
	run grep -rqF 'weakness-audit' skills shared
	[ "$status" -eq 1 ]
	grep -qF '/kramme:code:refactor-opportunities --ranked' "skills/kramme:code:outside-view/SKILL.md"
	grep -qF 'kramme:code:refactor-opportunities --ranked' "skills/kramme:code:outside-view/assets/report-template.md"
	grep -qF '$kramme:code:refactor-opportunities --ranked' "skills/kramme:code:breakdown-findings/references/source-intake.md"
	grep -qF 'kramme:code:refactor-opportunities --ranked' "skills/kramme:discovery:strategic-inquiry/SKILL.md"
	grep -qF '`/kramme:code:weakness-audit` → `/kramme:code:refactor-opportunities --ranked`' ../README.md
	run python3 - "skills/kramme:workflow-artifacts:cleanup/references/disposable-artifacts.yaml" <<'PY'
import json
import pathlib
import sys

entries = [
    entry
    for entry in json.loads(pathlib.Path(sys.argv[1]).read_text())["artifacts"]
    if entry["path"] == "CODEBASE_WEAKNESS_REPORT.md"
]
ok = len(entries) == 1 and entries[0]["producer"] == "kramme:code:refactor-opportunities"
raise SystemExit(0 if ok else "CODEBASE_WEAKNESS_REPORT.md must have one entry produced by refactor-opportunities")
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}
