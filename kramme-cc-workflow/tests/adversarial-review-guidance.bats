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
    "guarded model invocation": "disable-model-invocation: false",
    "contract": "### Model Invocation Contract",
    "single parent": "No other parent workflow is authorized by this model-invocation exception",
    "user consent": "came from the user",
    "no base override": "A model caller never passes `--base`",
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

@test "adversarial review declares shell access and uses scanner-safe cleanup and modes" {
	run python3 - "$SKILL" "$PLUGIN_ROOT/skills/kramme:pr:adversarial-review/scripts/run-adversarial-review.sh" <<'PY'
import pathlib
import sys

skill = pathlib.Path(sys.argv[1]).read_text()
runner = pathlib.Path(sys.argv[2]).read_text()
assert "permissions:\n  - shell\n" in skill
assert 'rmdir -- "$REQUIREMENTS_TEMP_DIR"' not in skill
assert 'chmod u=rwx,go=rx "$snapshot_path"' in runner
assert 'chmod u=rw,go=r "$snapshot_path"' in runner
assert 'chmod 755 "$snapshot_path"' not in runner
assert 'chmod 644 "$snapshot_path"' not in runner
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
    "internal callers never hold the user's cross-provider consent",
    "A model that invokes this skill never adds it on its own initiative",
]
required_policy = [
    "Gate 5: Adversarial Model Review",
    "kramme:pr:adversarial-review",
    "different-provider review",
    "restart the next quality round at applicability evaluation followed by Gate 1",
    "final adversarial review matches the final verified tree",
    "never pass `--base`",
    "exists only because the user requested `--adversarial-review`",
]
missing = [phrase for phrase in required_skill if phrase not in skill]
missing += [phrase for phrase in required_policy if phrase not in policy]
raise SystemExit("missing convergence contracts: " + ", ".join(missing) if missing else 0)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "internal convergence callers never forward the adversarial opt-in" {
	run bash -c '
    set -e
    cd "'"$BATS_TEST_DIRNAME"'/.."
    for caller in skills/kramme:linear:issue-to-pr/SKILL.md skills/kramme:linear:issue-to-pr/references/shipping-contract.md skills/kramme:code:plan-to-pr/SKILL.md skills/kramme:code:plan-to-pr/references/shipping-contract.md; do
      if grep -qF -- "--adversarial-review" "$caller"; then echo "$caller forwards --adversarial-review"; exit 1; fi
    done
    grep -qF "never forwards \`--adversarial-review\`" skills/kramme:linear:issue-to-pr/references/delegated-skills.md
    grep -qF "### Hand-off repair exceptions" docs/decisions/2026-08-29-model-invocable-orchestration-children.md
    grep -qF "is model-invocable only as Gate 5 of \`kramme:pr:review-convergence\`" docs/decisions/2026-08-29-model-invocable-orchestration-children.md
  '

	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "adversarial review source provenance is declared" {
	grep -qF 'conductor-parallel-agents' "$PLUGIN_ROOT/skills/kramme:pr:adversarial-review/references/sources.yaml"
	grep -qF 'conductor-api' "$PLUGIN_ROOT/skills/kramme:pr:adversarial-review/references/sources.yaml"
}
