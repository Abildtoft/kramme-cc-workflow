#!/usr/bin/env bats
#
# The cleanup command is LLM-driven prose, so these tests exercise the machine-readable
# disposable-artifact registry that Step 1 of the skill derives its inventory from. They
# prove the registry is internally consistent, covers the explicitly cross-checked producer
# sets, leaves no selected disposable behind, and preserves permanent specs in a keep-specs
# pass. The confirmation, dirty-file, Trash, and block-rm-rf
# guards remain prose policy in SKILL.md and are out of scope for this fixture test.

setup() {
	PLUGIN_ROOT="$BATS_TEST_DIRNAME/.."
	REGISTRY="$PLUGIN_ROOT/skills/kramme:workflow-artifacts:cleanup/references/disposable-artifacts.yaml"
	AUTODETECT="$PLUGIN_ROOT/skills/kramme:code:breakdown-findings/references/auto-detect-sources.md"
	CONTRACTS="$PLUGIN_ROOT/scripts/synced-contracts.yaml"
	HELPER="$BATS_TEST_TMPDIR/cleanup_registry.py"
	cat >"$HELPER" <<'PY'
import glob
import fnmatch
import json
import os
import pathlib
import re
import shutil


def load(registry):
    return json.loads(pathlib.Path(registry).read_text())["artifacts"]


def resolve(entry, workroot, homeroot):
    path = entry["path"]
    if path.startswith("~/"):
        return os.path.join(homeroot, path[2:])
    return os.path.join(workroot, path)


def _concrete(pattern):
    return pattern.replace("*", "SAMPLE")


def materialize(entry, workroot, homeroot):
    target = resolve(entry, workroot, homeroot)
    if entry["type"] == "dir":
        os.makedirs(target, exist_ok=True)
        child = entry.get("expected_contents", "artifact.txt").replace("*", "SAMPLE")
        open(os.path.join(target, os.path.basename(child)), "w").close()
    else:
        concrete = _concrete(target)
        parent = os.path.dirname(concrete)
        if parent:
            os.makedirs(parent, exist_ok=True)
        open(concrete, "w").close()


def candidates(entries, workroot, homeroot):
    selected = []
    for entry in entries:
        target = resolve(entry, workroot, homeroot)
        if not remaining(entry, workroot, homeroot):
            continue
        if entry["type"] == "dir" and "condition" in entry:
            condition = os.path.join(workroot, entry["condition"])
            if not os.path.exists(condition):
                continue
            expected = entry["expected_contents"]
            if any(not fnmatch.fnmatch(child, expected) for child in os.listdir(target)):
                continue
        selected.append(entry)
    return selected


def delete(entry, workroot, homeroot):
    target = resolve(entry, workroot, homeroot)
    if entry["type"] == "dir":
        if os.path.isdir(target):
            shutil.rmtree(target)
        return
    for match in glob.glob(target):
        if os.path.isdir(match):
            shutil.rmtree(match)
        elif os.path.exists(match):
            os.remove(match)


def remaining(entry, workroot, homeroot):
    target = resolve(entry, workroot, homeroot)
    if entry["type"] == "dir":
        return os.path.isdir(target)
    return bool(glob.glob(target))


def autodetect_sources(path):
    text = pathlib.Path(path).read_text()
    return re.findall(r"^\s*\d+\.\s+`([^`]+)`", text, re.M)
PY
}

@test "both cleanup contracts are registered" {
	run python3 - "$CONTRACTS" <<'PY'
import json
import pathlib
import sys

registry = json.loads(pathlib.Path(sys.argv[1]).read_text())
registered = {c["name"] for c in registry.get("required_file_contracts", [])}
needed = {"workflow-artifact-cleanup-names", "workflow-artifact-cleanup-registry"}
missing = sorted(needed - registered)
raise SystemExit("missing required_file_contracts: " + ", ".join(missing) if missing else 0)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "every registry entry declares required fields and known vocabulary" {
	run python3 - "$REGISTRY" <<'PY'
import json
import pathlib
import sys

artifacts = json.loads(pathlib.Path(sys.argv[1]).read_text())["artifacts"]
categories = {"working-dir", "shared-diagram", "permanent-spec"}
retentions = {"disposable", "permanent"}
types = {"file", "glob", "dir"}
errors = []
seen = set()
for entry in artifacts:
    ident = entry.get("id", "?")
    for field in ("id", "path", "type", "category", "retention"):
        if field not in entry:
            errors.append(f"{ident}: missing {field}")
    if ident in seen:
        errors.append(f"duplicate id: {ident}")
    seen.add(ident)
    if entry.get("category") not in categories:
        errors.append(f"{ident}: bad category {entry.get('category')!r}")
    if entry.get("retention") not in retentions:
        errors.append(f"{ident}: bad retention {entry.get('retention')!r}")
    if entry.get("type") not in types:
        errors.append(f"{ident}: bad type {entry.get('type')!r}")
    if "condition" in entry and "expected_contents" not in entry:
        errors.append(f"{ident}: condition without expected_contents")
    if entry.get("category") == "permanent-spec" and entry.get("retention") != "permanent":
        errors.append(f"{ident}: permanent-spec must be retention permanent")
raise SystemExit("\n".join(errors) if errors else 0)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "registry registers the artifacts named by finding WA-007" {
	run python3 - "$REGISTRY" <<'PY'
import json
import pathlib
import sys

paths = {a["path"] for a in json.loads(pathlib.Path(sys.argv[1]).read_text())["artifacts"]}
needed = ["REFACTOR_OPPORTUNITIES_OVERVIEW.md", "AGENT_NATIVE_AUDIT.md", ".context/session-search/"]
missing = [p for p in needed if p not in paths]
raise SystemExit("missing registry entries: " + ", ".join(missing) if missing else 0)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "every auto-detect findings source is a disposable registry entry" {
	run python3 - "$REGISTRY" "$AUTODETECT" <<'PY'
import json
import pathlib
import re
import sys

disposable = {
    a["path"]
    for a in json.loads(pathlib.Path(sys.argv[1]).read_text())["artifacts"]
    if a["retention"] == "disposable"
}
sources = re.findall(r"^\s*\d+\.\s+`([^`]+)`", pathlib.Path(sys.argv[2]).read_text(), re.M)
missing = [s for s in sources if s not in disposable]
raise SystemExit(
    "auto-detect sources not registered as disposable: " + ", ".join(missing) if missing else 0
)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "conditional directories require their marker and expected contents" {
	run python3 - "$REGISTRY" "$BATS_TEST_TMPDIR" "$HELPER" <<'PY'
import importlib.util
import os
import sys

registry, tmp, helper = sys.argv[1], sys.argv[2], sys.argv[3]
spec = importlib.util.spec_from_file_location("cleanup_registry", helper)
c = importlib.util.module_from_spec(spec)
spec.loader.exec_module(c)

entries = [a for a in c.load(registry) if "condition" in a]
errors = []
for entry in entries:
    work = os.path.join(tmp, entry["id"])
    home = os.path.join(work, "home")
    os.makedirs(home, exist_ok=True)
    c.materialize(entry, work, home)
    if c.candidates([entry], work, home):
        errors.append(f"selected without marker: {entry['id']}")

    marker = {"path": entry["condition"], "type": "file"}
    c.materialize(marker, work, home)
    open(os.path.join(c.resolve(entry, work, home), "unexpected.txt"), "w").close()
    if c.candidates([entry], work, home):
        errors.append(f"selected with unexpected contents: {entry['id']}")
    if not c.remaining(entry, work, home):
        errors.append(f"conditional directory was deleted: {entry['id']}")
raise SystemExit("\n".join(errors) if errors else 0)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "registry-driven cleanup removes every selected disposable and keeps specs" {
	run python3 - "$REGISTRY" "$BATS_TEST_TMPDIR" "$HELPER" <<'PY'
import importlib.util
import os
import sys

registry, tmp, helper = sys.argv[1], sys.argv[2], sys.argv[3]
spec = importlib.util.spec_from_file_location("cleanup_registry", helper)
c = importlib.util.module_from_spec(spec)
spec.loader.exec_module(c)

work = os.path.join(tmp, "work")
home = os.path.join(tmp, "home")
os.makedirs(work, exist_ok=True)
os.makedirs(home, exist_ok=True)

artifacts = c.load(registry)
for entry in artifacts:
    c.materialize(entry, work, home)

disposables = c.candidates(
    [a for a in artifacts if a["retention"] == "disposable"], work, home
)
permanents = [a for a in artifacts if a["retention"] == "permanent"]

# Keep-specs pass: delete every disposable, leave permanent specs untouched.
for entry in disposables:
    c.delete(entry, work, home)

errors = []
for entry in disposables:
    if c.remaining(entry, work, home):
        errors.append(f"disposable survived cleanup: {entry['id']} ({entry['path']})")
for entry in permanents:
    if not c.remaining(entry, work, home):
        errors.append(f"permanent spec wrongly deleted: {entry['id']} ({entry['path']})")
raise SystemExit("\n".join(errors) if errors else 0)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "auto mode selects only working-dir disposables" {
	run python3 - "$REGISTRY" "$BATS_TEST_TMPDIR" "$HELPER" <<'PY'
import importlib.util
import os
import sys

registry, tmp, helper = sys.argv[1], sys.argv[2], sys.argv[3]
spec = importlib.util.spec_from_file_location("cleanup_registry", helper)
c = importlib.util.module_from_spec(spec)
spec.loader.exec_module(c)

work = os.path.join(tmp, "work")
home = os.path.join(tmp, "home")
os.makedirs(work, exist_ok=True)
os.makedirs(home, exist_ok=True)

artifacts = c.load(registry)
visual_diagrams = [a for a in artifacts if a["id"] == "visual-diagrams"]
if len(visual_diagrams) != 1:
    raise SystemExit(f"expected one visual-diagrams entry, found {len(visual_diagrams)}")
visual_diagram = visual_diagrams[0]
expected_visual_contract = {
    "path": "~/.kramme-cc-workflow/diagrams/*.html",
    "category": "shared-diagram",
    "retention": "disposable",
}
actual_visual_contract = {
    field: visual_diagram.get(field) for field in expected_visual_contract
}
if actual_visual_contract != expected_visual_contract:
    raise SystemExit(
        f"visual-diagrams contract changed: {actual_visual_contract!r}"
    )
for entry in artifacts:
    c.materialize(entry, work, home)

auto = c.candidates(
    [
        a
        for a in artifacts
        if a["retention"] == "disposable" and a["category"] == "working-dir"
    ],
    work,
    home,
)
kept = [a for a in artifacts if a not in auto]

for entry in auto:
    c.delete(entry, work, home)

errors = []
if not c.remaining(visual_diagram, work, home):
    errors.append("auto wrongly deleted shared visual diagrams")
for entry in auto:
    if c.remaining(entry, work, home):
        errors.append(f"auto disposable survived: {entry['id']} ({entry['path']})")
for entry in kept:
    if not c.remaining(entry, work, home):
        errors.append(
            f"auto wrongly deleted {entry['category']}/{entry['retention']}: "
            f"{entry['id']} ({entry['path']})"
        )
raise SystemExit("\n".join(errors) if errors else 0)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}
