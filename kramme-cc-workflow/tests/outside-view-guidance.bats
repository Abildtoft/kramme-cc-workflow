#!/usr/bin/env bats

setup() {
	PLUGIN_ROOT="$BATS_TEST_DIRNAME/.."
	SKILL="$PLUGIN_ROOT/skills/kramme:code:outside-view/SKILL.md"
	PERSONAS="$PLUGIN_ROOT/skills/kramme:code:outside-view/references/personas.md"
	TEMPLATE="$PLUGIN_ROOT/skills/kramme:code:outside-view/assets/report-template.md"
}

@test "outside-view cross-model rating is opt-in, different-family, and fail-closed" {
	run python3 - "$SKILL" "$PERSONAS" <<'PY'
import pathlib
import sys

skill = pathlib.Path(sys.argv[1]).read_text()
personas = pathlib.Path(sys.argv[2]).read_text()

required = {
    "opt-in argument": "--cross-model",
    "repository consent": "explicit repository-scoped opt-in",
    "host-family gate": "different from `HOST_MODEL_FAMILY`",
    "isolation profile": "verified isolation profile",
    "no raw CLI": "A raw `codex exec`, `gemini`, or equivalent command",
}
combined = skill + "\n" + personas
missing = [name for name, phrase in required.items() if phrase not in combined]
if "--no-cross-model" in combined:
    missing.append("legacy default-on flag still present")
raise SystemExit("missing cross-model contracts: " + ", ".join(missing) if missing else 0)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "outside-view enforces supported rater bounds and a successful quorum" {
	run python3 - "$SKILL" <<'PY'
import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text()
required = {
    "hard bounds": "RATER_COUNT < 3` or `RATER_COUNT > 6",
    "success quorum": "at least 3 successful, parseable in-repo raters",
    "preserve report": "stop without overwriting `OUTPUT_PATH`",
    "successful denominators": "successful, parseable raters only",
}
missing = [name for name, phrase in required.items() if phrase not in text]
raise SystemExit("missing rater contracts: " + ", ".join(missing) if missing else 0)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "outside-view history persists every blind-spot fingerprint" {
	run python3 - "$SKILL" "$TEMPLATE" <<'PY'
import pathlib
import sys

skill = pathlib.Path(sys.argv[1]).read_text()
template = pathlib.Path(sys.argv[2]).read_text()
required_skill = [
    "durable fingerprint",
    "complete blind-spot fingerprint list",
    "every blind-spot `fingerprint: title`",
]
missing = [phrase for phrase in required_skill if phrase not in skill]
if "| Blind spots |" not in template:
    missing.append("Blind spots history column")
if "source for recurrence counting" not in template:
    missing.append("recurrence source contract")
raise SystemExit("missing history contracts: " + ", ".join(missing) if missing else 0)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "outside-view clustering covers semantic paraphrases and minority support" {
	run python3 - "$SKILL" <<'PY'
import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text()
required = {
    "semantic grouping": "even when raters use different wording",
    "split definition": "any non-majority multi-rater cluster",
    "single voice": "exactly one supporting rater",
}
missing = [name for name, phrase in required.items() if phrase not in text]
if "Merge only near-verbatim duplicates" in text:
    missing.append("contradictory near-verbatim rule still present")
raise SystemExit("missing clustering contracts: " + ", ".join(missing) if missing else 0)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "outside-view revalidates canonical output containment before overwrite" {
	run python3 - "$SKILL" <<'PY'
import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text()
required = {
    "canonical root": "canonical working-tree root",
    "leaf symlink": "existing output that is a symlink",
    "parent symlink": "existing symlink in its parent path",
    "pre-write recheck": "Repeat the canonical containment",
}
missing = [name for name, phrase in required.items() if phrase not in text]
raise SystemExit("missing output-boundary contracts: " + ", ".join(missing) if missing else 0)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}
