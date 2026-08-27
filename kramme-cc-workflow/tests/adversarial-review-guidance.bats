#!/usr/bin/env bats

setup() {
	PLUGIN_ROOT="$BATS_TEST_DIRNAME/.."
	SKILL="$PLUGIN_ROOT/skills/kramme:pr:adversarial-review/SKILL.md"
	CONVERGENCE="$PLUGIN_ROOT/skills/kramme:pr:review-convergence/SKILL.md"
	POLICY="$PLUGIN_ROOT/skills/kramme:pr:review-convergence/references/review-convergence.md"
}

@test "adversarial review is explicit, different-provider, and fail-closed" {
	run python3 - "$SKILL" <<'PY'
import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text()
required = {
    "user-only": "disable-model-invocation: true",
    "provider difference": "require it to differ from `HOST_PROVIDER`",
    "repository consent": "repository-scoped authorization",
    "no same-provider fallback": "Never replace a failed requested provider with the host provider",
    "required failure": "Required adversarial review failed",
    "tree identity": "`reviewed_head` and `reviewed_tree`",
    "requirements ownership": "--consume-requirements-file",
}
missing = [name for name, phrase in required.items() if phrase not in text]
raise SystemExit("missing adversarial review contracts: " + ", ".join(missing) if missing else 0)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "adversarial review uses hardened local profiles and Conductor cloud sessions" {
	run python3 - "$SKILL" <<'PY'
import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text()
required = {
    "tracked snapshot": "temporary tracked-file snapshot",
    "Claude safe mode": "Claude runs with safe mode",
    "Claude tools": "only `Read`, `Grep`, and `Glob`",
    "Codex sandbox": "read-only sandbox",
    "Codex config": "ignored user configuration",
    "raw blobs": "raw regular-file blobs",
    "no text conversion": "text-conversion helpers disabled",
    "Conductor session": "start a different-provider session",
    "no durable artifact": "writes no durable repository artifact",
}
missing = [name for name, phrase in required.items() if phrase not in text]
raise SystemExit("missing execution contracts: " + ", ".join(missing) if missing else 0)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "convergence exposes an opt-in final adversarial gate" {
	run python3 - "$CONVERGENCE" "$POLICY" <<'PY'
import pathlib
import sys

skill = pathlib.Path(sys.argv[1]).read_text()
policy = pathlib.Path(sys.argv[2]).read_text()
required_skill = [
    "--adversarial-review",
    "--adversarial-provider",
    "--adversarial-model",
    "ADVERSARIAL_REVIEW",
    "reject an explicit provider equal to `HOST_PROVIDER` during this parse step",
]
required_policy = [
    "Gate 5: Adversarial Model Review",
    "kramme:pr:adversarial-review",
    "different-provider review",
    "restart the next quality round at applicability evaluation followed by Gate 1",
    "final adversarial review matches the final verified tree",
]
missing = [phrase for phrase in required_skill if phrase not in skill]
missing += [phrase for phrase in required_policy if phrase not in policy]
raise SystemExit("missing convergence contracts: " + ", ".join(missing) if missing else 0)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "adversarial review source provenance is declared" {
	grep -qF 'conductor-parallel-agents' "$PLUGIN_ROOT/skills/kramme:pr:adversarial-review/references/sources.yaml"
	grep -qF 'conductor-api' "$PLUGIN_ROOT/skills/kramme:pr:adversarial-review/references/sources.yaml"
}
