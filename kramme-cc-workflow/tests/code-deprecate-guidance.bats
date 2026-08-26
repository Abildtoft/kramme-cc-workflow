#!/usr/bin/env bats

setup() {
	PLUGIN_ROOT="$BATS_TEST_DIRNAME/.."
	SKILL="$PLUGIN_ROOT/skills/kramme:code:deprecate/SKILL.md"
	DECISION_CHECKLIST="$PLUGIN_ROOT/skills/kramme:code:deprecate/references/decision-checklist.md"
	MIGRATION_PATTERNS="$PLUGIN_ROOT/skills/kramme:code:deprecate/references/migration-patterns.md"
	README="$PLUGIN_ROOT/../README.md"
}

@test "database migration pattern is routed before generic migration cost" {
	run python3 - "$SKILL" "$DECISION_CHECKLIST" "$README" <<'PY'
import pathlib
import sys

skill = pathlib.Path(sys.argv[1]).read_text()
checklist = pathlib.Path(sys.argv[2]).read_text()
readme = pathlib.Path(sys.argv[3]).read_text()

skill_frontmatter = skill.split("---", 2)[1]
step_one = skill.split("## Step 1 —", 1)[1].split("## Step 2 —", 1)[0]
question_four = next(line for line in step_one.splitlines() if line.startswith("4. **"))
cost_section = checklist.split("## 4. What is the migration cost for dependents?", 1)[1].split("---", 1)[0]

required = {
    "public skill description": "Database Expand-Migrate-Contract patterns",
    "persistent-data routing": "persisted data/schema contract → Database Expand/Migrate/Contract at every cost tier",
    "decision-checklist routing": "use Database Expand/Migrate/Contract regardless of whether dependent work is Low, Medium, or High",
    "framework-only boundary": "framework/library-only `kramme:code:migrate` workflow",
    "framework migration route": "Framework or library version migration",
    "canonical README": "Database Expand-Migrate-Contract patterns",
}
texts = {
    "public skill description": skill_frontmatter,
    "persistent-data routing": question_four,
    "decision-checklist routing": cost_section,
    "framework-only boundary": cost_section,
    "framework migration route": cost_section,
    "canonical README": readme,
}
missing = [name for name, phrase in required.items() if phrase not in texts[name]]
if question_four.find("persisted data/schema contract") > question_four.find("Then estimate"):
    missing.append("Step 1 chooses the persistence boundary before cost")
if cost_section.find("Persisted data or schema contract") > cost_section.find("Other boundaries, Low"):
    missing.append("decision checklist chooses the persistence boundary before cost tiers")
raise SystemExit("missing database routing contracts: " + ", ".join(missing) if missing else 0)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "database phase status is authoritative for resume and completion" {
	run python3 - "$SKILL" "$MIGRATION_PATTERNS" <<'PY'
import pathlib
import re
import sys

skill = pathlib.Path(sys.argv[1]).read_text()
patterns = pathlib.Path(sys.argv[2]).read_text()

required_skill = {
    "authoritative plan section": "## Database Migration Phase Status (authoritative when Database Expand/Migrate/Contract is selected)",
    "resume traversal": "`## Database Migration Phase Status` to find the earliest incomplete exit criterion",
    "resume authority": "database phase-status checklist is the authoritative state",
    "operator gate": "Operator readiness — the named datastore owner reviewed the production phase plan",
    "pre-expand readiness": "complete the plan's `Operator readiness` gate before the first production schema operation",
    "step 4.1 exit": "before production Expand begins",
    "pre-contraction recovery gate": "every phase-status item through `Recovery` must be checked with evidence before contraction begins",
    "step 4.4 exit": "every item in `## Database Migration Phase Status` must also be checked with evidence",
    "overall completion": "additional completion gates. The generic four gates never override or replace them",
    "historical migration references retained": "retain required migration-history and audit artifacts",
    "application removal before contraction": "first deploy and verify removal or disablement of legacy application reads and writes while the expanded schema remains",
    "standalone contraction deployment": "Contract the old schema shape only in a separate later deployment",
}
missing = [name for name, phrase in required_skill.items() if phrase not in skill]
phase_section = skill.split("## Database Migration Phase Status", 1)[1].split("```", 1)[0]
expected_phases = [
    "Operator readiness",
    "Expand",
    "Transitional writes",
    "Backfill",
    "Read cutover",
    "Observation",
    "Recovery",
    "Contract",
]
phase_entries = re.findall(
    r"^- \[ \] ([^—\n]+?) —(.+)\n  - Evidence: (.+)$",
    phase_section,
    re.MULTILINE,
)
actual_phases = [name for name, _description, _evidence in phase_entries]
if actual_phases != expected_phases:
    missing.append("ordered database phases with paired evidence fields")
phase_descriptions = {name: description for name, description, _evidence in phase_entries}
phase_requirements = {
    "Operator readiness": ["datastore owner reviewed", "commands and recovery actions were rehearsed"],
    "Expand": ["additive schema supports every named old/new application combination"],
    "Transitional writes": ["partial-failure", "retry", "ordering", "repair", "observable"],
    "Backfill": [
        "every retained record and value required by the new contract is covered",
        "every exclusion has an explicit safe disposition",
        "reconciliation passes",
        "batching/throttling",
    ],
    "Read cutover": ["deployed independently", "rollback remains schema-compatible", "old writes remain supported"],
    "Observation": ["named window passed", "without an unresolved regression"],
    "Recovery": ["recovery was tested for each phase", "verified backup or restoration source", "rather than a schema-only down migration"],
    "Contract": ["no longer require the old shape before destructive removal"],
}
for phase, phrases in phase_requirements.items():
    description = phase_descriptions.get(phase, "")
    missing.extend(f"{phase} semantics: {phrase}" for phrase in phrases if phrase not in description)
required_patterns = {
    "reference-to-plan authority": "authoritative resumable state",
    "operator readiness before expand": "before the first production schema operation",
    "complete retained-data coverage": "Every retained record and value required by the new contract is covered",
    "new-only writes before contraction": "Verify new-only writes, then remove `name` in a later contraction",
    "standalone destructive contraction": "perform destructive removal as its own deployment",
}
missing.extend(name for name, phrase in required_patterns.items() if phrase not in patterns)
raise SystemExit("missing database phase-state contracts: " + ", ".join(missing) if missing else 0)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "database expansion preserves mixed-version write compatibility" {
	run python3 - "$MIGRATION_PATTERNS" <<'PY'
import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text()
database_pattern = text.split("## Database Expand/Migrate/Contract", 1)[1].split("## Pattern comparison", 1)[0]
expand_phase = database_pattern.split("**Step 4.1 —", 1)[1].split("**Step 4.2 —", 1)[0]
required = {
    "old application compatibility": "Prove the old application against the expanded schema",
    "pre-write compatibility state": "expanded schema before transitional writes or backfill",
    "partially migrated compatibility state": "partially migrated data while old and new shapes coexist",
    "supported mixed-version matrix": "Name every supported mixed-version combination",
    "constraint compatibility": "compatibility-preserving for old writers",
    "deferred enforcement": "defer incompatible enforcement or validation until those writers are absent",
}
missing = [name for name, phrase in required.items() if phrase not in expand_phase]
raise SystemExit("missing mixed-version compatibility contracts: " + ", ".join(missing) if missing else 0)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "deprecation stop rules have authoritative workflow owners" {
	local remove_old

	remove_old="$(sed -n '/^### 4.4 Remove old$/,/^---$/p' "$SKILL")"

	grep -qF "Execute in order. Do not compress or overlap" "$SKILL"
	grep -qF "Do not remove zombie code. Do not proceed past this step." "$SKILL"
	grep -qF 'Before executing this step, resolve every open `UNVERIFIED` from any step.' <<<"$remove_old"
	grep -qF 'ASK FIRST: removing with open UNVERIFIED markers' <<<"$remove_old"
	grep -qF "and do not proceed" <<<"$remove_old"
	grep -qF "no active consumer or obsolete application reference remains" "$SKILL"
	grep -qF 'Completion state is owned by `DEPRECATION_PLAN_<slug>.md`.' "$SKILL"
}
