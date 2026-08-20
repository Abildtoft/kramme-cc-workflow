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

required = {
    "public skill description": "Database Expand-Migrate-Contract patterns",
    "persistent-data routing": "persisted data/schema contract → Database Expand/Migrate/Contract",
    "decision-checklist routing": "persisted data or schema contract changes use Database Expand/Migrate/Contract",
    "framework-only boundary": "framework/library-only `kramme:code:migrate` workflow",
    "canonical README": "Database Expand-Migrate-Contract patterns",
}
texts = {
    "public skill description": skill.split("---", 2)[1],
    "persistent-data routing": skill,
    "decision-checklist routing": checklist,
    "framework-only boundary": checklist,
    "canonical README": readme,
}
missing = [name for name, phrase in required.items() if phrase not in texts[name]]
raise SystemExit("missing database routing contracts: " + ", ".join(missing) if missing else 0)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "database phase status is authoritative for resume and completion" {
	run python3 - "$SKILL" "$MIGRATION_PATTERNS" <<'PY'
import pathlib
import sys

skill = pathlib.Path(sys.argv[1]).read_text()
patterns = pathlib.Path(sys.argv[2]).read_text()

required_skill = {
    "authoritative plan section": "## Database Migration Phase Status (authoritative when Database Expand/Migrate/Contract is selected)",
    "resume traversal": "`## Database Migration Phase Status` to find the earliest incomplete exit criterion",
    "resume authority": "database phase-status checklist is the authoritative state",
    "operator gate": "Operator readiness — the named datastore owner reviewed the production phase plan",
    "step 4.2 exit": "the plan's `Operator readiness` phase-status item must also name the datastore owner",
    "pre-contraction recovery gate": "every phase-status item through `Recovery` must be checked with evidence before contraction begins",
    "step 4.4 exit": "every item in `## Database Migration Phase Status` must also be checked with evidence",
    "overall completion": "additional completion gates. The generic four gates never override or replace them",
}
missing = [name for name, phrase in required_skill.items() if phrase not in skill]
phase_section = skill.split("## Database Migration Phase Status", 1)[1].split("```", 1)[0]
if phase_section.count("Evidence:") < 8:
    missing.append("evidence field for every database phase")
if "authoritative resumable state" not in patterns:
    missing.append("reference-to-plan authority")
raise SystemExit("missing database phase-state contracts: " + ", ".join(missing) if missing else 0)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "database expansion preserves mixed-version write compatibility" {
	run python3 - "$MIGRATION_PATTERNS" <<'PY'
import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text()
required = {
    "pre-write compatibility state": "expanded schema before transitional writes or backfill",
    "partially migrated compatibility state": "partially migrated data while old and new shapes coexist",
    "constraint compatibility": "compatibility-preserving for old writers",
    "deferred enforcement": "defer incompatible enforcement or validation until those writers are absent",
}
missing = [name for name, phrase in required.items() if phrase not in text]
raise SystemExit("missing mixed-version compatibility contracts: " + ", ".join(missing) if missing else 0)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}
