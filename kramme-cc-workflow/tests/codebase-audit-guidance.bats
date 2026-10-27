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
	grep -qF '$kramme:code:refactor-opportunities --ranked' "shared/findings/references/findings-intake.md"
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

@test "shared breakdown-ready schema defines provenance, required fields, and scales" {
	local schema="shared/findings/references/breakdown-ready-findings.md"
	local phrase
	for phrase in '## Report Provenance' '## Breakdown-Ready Finding Data' '**Scanned commit:**' '**Base branch:**' \
		'**Generated:**' '**Severity:**' '**Confidence:**' '**Locations:**' '**Evidence:**' '**Suggested fix:**' \
		'**Effort:**' 'Schema: `breakdown-ready-findings v1`.' \
		'| `kramme:code:agent-readiness` | Critical / Important / Suggestion | critical / high / suggestion |'; do
		grep -qF -- "$phrase" "$schema"
	done
}

@test "audit producers name the shared schema and emit both sections" {
	local schema_path='${CLAUDE_PLUGIN_ROOT}/shared/findings/references/breakdown-ready-findings.md'
	local skill template
	for skill in kramme:code:refactor-opportunities kramme:code:agent-readiness kramme:code:outside-view; do
		grep -qF "$schema_path" "skills/$skill/SKILL.md"
	done
	for template in \
		"skills/kramme:code:refactor-opportunities/assets/report-template.md" \
		"shared/codebase-audit/assets/report-template.md" \
		"skills/kramme:code:agent-readiness/assets/audit-report.md" \
		"skills/kramme:code:outside-view/assets/report-template.md"; do
		grep -qF '## Report Provenance' "$template"
		grep -qF '## Breakdown-Ready Finding Data' "$template"
	done
	grep -qF '### RO-001:' "skills/kramme:code:refactor-opportunities/assets/report-template.md"
	run grep -qF '## Detailed Findings' "shared/codebase-audit/assets/report-template.md"
	[ "$status" -eq 1 ]
	grep -qF 'Suggested fix:' "skills/kramme:code:agent-readiness/references/dimension-agent.md"
	run grep -qF 'Findings (with IDs, severity, details)' "skills/kramme:code:agent-readiness/SKILL.md"
	[ "$status" -eq 1 ]
}

@test "both breakdown intakes read the shared schema, provenance, and the dependency audit" {
	local schema_path='${CLAUDE_PLUGIN_ROOT}/shared/findings/references/breakdown-ready-findings.md'
	local skill
	for skill in kramme:code:breakdown-findings kramme:linear:breakdown-findings; do
		grep -qF "$schema_path" "skills/$skill/SKILL.md"
		grep -qF '${CLAUDE_PLUGIN_ROOT}/shared/findings/references/findings-intake.md' "skills/$skill/references/source-intake.md"
	done
	grep -qF "$schema_path" "shared/findings/references/findings-intake.md"
	grep -qF '## Report Provenance' "shared/findings/references/findings-intake.md"
	grep -qF '`DEPENDENCY_AUDIT.md`' "shared/findings/references/findings-intake.md"
	grep -qxF 'DEPENDENCY_AUDIT.md' hooks/confirm-review-artifacts.txt
}

@test "breakdown provenance handles non-git reports and dirty source compatibility" {
	local schema="shared/findings/references/breakdown-ready-findings.md"
	local source
	for source in \
		"skills/kramme:code:outside-view/SKILL.md" \
		"skills/kramme:code:refactor-opportunities/SKILL.md" \
		"skills/kramme:code:agent-readiness/SKILL.md"; do
		grep -qF 'none (not a git repository)' "$source"
	done
	grep -qF 'dirty (<N> paths)' "$schema"
	grep -qF 'Do not combine sources when any provenance says `dirty (<N> paths)`' "$schema"
	grep -qF 'if any source says `dirty (<N> paths)`' "shared/findings/references/findings-intake.md"
}

@test "breakdown intakes preserve schema suggestion severity" {
	local source="shared/findings/references/findings-intake.md"
	grep -qF 'severity (`critical`, `high`, `medium`, `low`, or `suggestion`)' "$source"
}

@test "shared resumable fan-out contract defines identity, persistence, re-entry, and cleanup" {
	local contract="shared/agents/references/resumable-fanout.md"
	local phrase
	for phrase in 'git check-ignore -q -- .context/<skill-slug>/' 'scripts/worktree-tree-id.sh' \
		'git hash-object --stdin' 'Write `manifest.json` before launching any agent' \
		'<!-- fanout-result: <id> complete -->' 'reuse its roster exactly' 'within the last 24 hours' \
		'A complete run is never resumed.' 'Never use `rm -rf`.' \
		'`Agents launched: N` counts only agents launched by this invocation.' 'Agents reused: <M> (run <run-id>)'; do
		grep -qF -- "$phrase" "$contract"
	done
}

@test "audit fan-outs adopt the resumable contract and register their run directories" {
	local contract_path='${CLAUDE_PLUGIN_ROOT}/shared/agents/references/resumable-fanout.md'
	local tree_path='${CLAUDE_PLUGIN_ROOT}/scripts/worktree-tree-id.sh'
	local skill
	for skill in kramme:code:refactor-opportunities kramme:code:agent-readiness kramme:code:outside-view; do
		grep -qF "$contract_path" "skills/$skill/SKILL.md"
		grep -qF "$tree_path" "skills/$skill/SKILL.md"
	done
	grep -qF 'the challenge reviewer is stage 2' "skills/kramme:code:refactor-opportunities/references/ranked-mode.md"
	grep -qF 'never relaunch a rater that has a result' "skills/kramme:code:outside-view/SKILL.md"
	grep -qF 'Raters never receive the run directory path' "skills/kramme:code:outside-view/SKILL.md"
	grep -qF 'the resolved `OUTPUT_PATH`' "skills/kramme:code:outside-view/SKILL.md"
	grep -qF 'the execution mode (`team` or `solo`)' "skills/kramme:code:refactor-opportunities/SKILL.md"
	grep -qF -- '--exclude AGENT_NATIVE_AUDIT.md' "skills/kramme:code:agent-readiness/SKILL.md"
	grep -qF -- '--exclude "$OUTPUT_PATH"' "skills/kramme:code:outside-view/SKILL.md"
	grep -qF -- '--exclude <each report output path this skill can write>' "skills/kramme:code:refactor-opportunities/SKILL.md"
	grep -qF 'End the run with `Agents launched: N`' "skills/kramme:code:refactor-opportunities/SKILL.md"
	run python3 - "skills/kramme:workflow-artifacts:cleanup/references/disposable-artifacts.yaml" <<'PY'
import json
import pathlib
import sys

entries = {entry["path"]: entry for entry in json.loads(pathlib.Path(sys.argv[1]).read_text())["artifacts"]}
wanted = (".context/code-refactor-opportunities/", ".context/code-agent-readiness/", ".context/code-outside-view/")
missing = [
    path
    for path in wanted
    if entries.get(path, {}).get("type") != "dir" or entries[path].get("retention") != "disposable"
]
raise SystemExit("unregistered run directories: " + ", ".join(missing) if missing else 0)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "audit fan-outs select subagent models through the shared policy before work" {
	run python3 - "$PWD" <<'PY'
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
policy = "${CLAUDE_PLUGIN_ROOT}/shared/pr-review/references/model-selection.md"
first_step = {
    "kramme:code:refactor-opportunities": "## Workflow",
    "kramme:code:agent-readiness": "## Step 1: Detect Codebase Context",
    "kramme:code:outside-view": "### 1. Minimal Orient",
}
errors = []
for skill, step in first_step.items():
    text = (root / f"skills/{skill}/SKILL.md").read_text()
    hint = next(line for line in text.splitlines() if line.startswith("argument-hint:"))
    if "[--subagent-model <model>]" not in hint:
        errors.append(f"{skill}: argument hint lacks the model flag")
    if policy not in text or "## Non-Review Subagent Roles" not in text:
        errors.append(f"{skill}: does not load the non-review model policy")
    elif text.index(policy) > text.index(step):
        errors.append(f"{skill}: model policy is read after work starts")
    if "`subagent_model` key slot" not in text:
        errors.append(f"{skill}: selection is not recorded in the resume key")
raise SystemExit("\n".join(errors) if errors else 0)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
	grep -qF 'with the model selected under **Subagent models**' "skills/kramme:code:refactor-opportunities/references/ranked-mode.md"
	grep -qF 'keeps its own provider and isolation policy' "skills/kramme:code:outside-view/SKILL.md"
}
