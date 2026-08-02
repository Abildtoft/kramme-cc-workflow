#!/usr/bin/env bats

setup() {
	PLUGIN_ROOT="$BATS_TEST_DIRNAME/.."
	SKILL="$PLUGIN_ROOT/skills/kramme:launch:rollout/SKILL.md"
	FLAG_RULES="$PLUGIN_ROOT/skills/kramme:launch:rollout/references/feature-flag-rules.md"
	CHECKLIST="$PLUGIN_ROOT/skills/kramme:launch:rollout/references/pre-launch-checklist.md"
	THRESHOLDS="$PLUGIN_ROOT/skills/kramme:launch:rollout/references/rollout-thresholds.md"
}

@test "launch rollout keeps policy precedence and evidence gates" {
	run python3 - "$SKILL" <<'PY'
import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text()
precedence = [
    "1. **Explicit user or organization policy.**",
    "2. **Observed system evidence.**",
    "3. **Confirmed fallback.**",
]
positions = [text.find(phrase) for phrase in precedence]
missing = [phrase for phrase, position in zip(precedence, positions) if position < 0]
if positions != sorted(positions):
    missing.append("policy precedence order")

required = {
    "confirmed fallback": "FALLBACK — confirmation required",
    "rollback boundary": "missing rollback controls stop the rollout before production exposure",
    "baseline boundary": "Missing baselines stop advancement beyond the initial limited exposure",
    "sample and time gate": "both its monitoring window and its sample-sufficiency rule pass",
}
missing.extend(name for name, phrase in required.items() if phrase not in text)
raise SystemExit("missing rollout policy contracts: " + ", ".join(missing) if missing else 0)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "launch rollout keeps threshold selection evidence-based" {
	run python3 - "$THRESHOLDS" <<'PY'
import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text()
precedence = [
    "1. Explicit user or organization release policy",
    "2. Observed system evidence",
    "3. A clearly labeled fallback proposal confirmed by the operator",
]
positions = [text.find(phrase) for phrase in precedence]
missing = [phrase for phrase, position in zip(precedence, positions) if position < 0]
if positions != sorted(positions):
    missing.append("threshold source precedence order")

required = {
    "time and sample gate": "A monitoring window must pass two gates: enough elapsed time to cover relevant failure modes and enough observations to support the decision.",
    "fallback scope": "A user-confirmed fallback becomes the active decision rule for that rollout, but it does not become a universal standard.",
    "fallback is not evidence": "Do not guess a baseline, substitute a fallback threshold for evidence, or advance to broader external exposure.",
}
missing.extend(name for name, phrase in required.items() if phrase not in text)
raise SystemExit("missing threshold selection contracts: " + ", ".join(missing) if missing else 0)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "launch rollout keeps missing requirements gate-aware" {
	run python3 - "$SKILL" "$CHECKLIST" <<'PY'
import pathlib
import sys

skill = pathlib.Path(sys.argv[1]).read_text()
checklist = pathlib.Path(sys.argv[2]).read_text()
required_skill = {
    "marker boundary": "An unresolved marker blocks the current gate when the item is unowned, nondeferrable at that gate, or has reached its stop boundary.",
    "red flag boundary": "Any `MISSING REQUIREMENT` is unowned, nondeferrable at the current gate, or has reached its recorded stop boundary without being resolved.",
    "gate verification": "No unresolved `MISSING REQUIREMENT` blocks this gate: each open item remains owned and deferrable until a later recorded stop boundary.",
}
missing = [name for name, phrase in required_skill.items() if phrase not in skill]
if "No unresolved `MISSING REQUIREMENT` blocks step 1" not in checklist:
    missing.append("step 1 sign-off boundary")
if "No `MISSING REQUIREMENT` remains unresolved." in checklist:
    missing.append("unconditional sign-off halt")
raise SystemExit("missing gate-aware deferral contracts: " + ", ".join(missing) if missing else 0)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "launch rollout keeps flags optional and rollback-only controls reusable" {
	run python3 - "$SKILL" "$FLAG_RULES" "$CHECKLIST" <<'PY'
import pathlib
import sys

skill = pathlib.Path(sys.argv[1]).read_text()
flag_rules = pathlib.Path(sys.argv[2]).read_text()
checklist = pathlib.Path(sys.argv[3]).read_text()

required = {
    "optional flag platform": (skill, "No feature-flag platform is a capability input, not automatically a blocker."),
    "rollback-only exception": (skill, "A rollback-only mechanism does not make a full-exposure deployment staged."),
    "reusable control retained": (skill, "N/A — reusable rollback capability retained"),
    "rollback is not cohort control": (flag_rules, "This supplies rollback, not cohort control"),
    "credible alternative": (flag_rules, '"we can redeploy" without timing and authority is not a rollback control'),
    "stop without rollback": (checklist, "No production exposure is planned without a credible rollback control."),
}
missing = [name for name, (text, phrase) in required.items() if phrase not in text]
raise SystemExit("missing alternative-control contracts: " + ", ".join(missing) if missing else 0)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}
