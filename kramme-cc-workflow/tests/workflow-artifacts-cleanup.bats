#!/usr/bin/env bats
#
# The cleanup command is LLM-driven prose, so these tests exercise the machine-readable
# disposable-artifact registry that Step 1 of the skill derives its inventory from. They
# prove the registry is internally consistent, covers the explicitly cross-checked producer
# sets, leaves no selected disposable behind, preserves permanent specs in a keep-specs
# pass, and confines the direct-user --siw mode to the siw/ workspace. The confirmation,
# dirty-file, Trash, and block-rm-rf guards remain prose policy in SKILL.md and
# references/siw-mode.md; only their argument rules are pinned here as text.

load 'test_helper/common'

setup() {
	PLUGIN_ROOT="$BATS_TEST_DIRNAME/.."
	REGISTRY="$PLUGIN_ROOT/skills/kramme:workflow-artifacts:cleanup/references/disposable-artifacts.yaml"
	CLEANUP_SKILL="$PLUGIN_ROOT/skills/kramme:workflow-artifacts:cleanup/SKILL.md"
	SIW_MODE_REF="$PLUGIN_ROOT/skills/kramme:workflow-artifacts:cleanup/references/siw-mode.md"
	AUTODETECT="$PLUGIN_ROOT/skills/kramme:code:breakdown-findings/references/auto-detect-sources.md"
	HELPER="$BATS_TEST_TMPDIR/cleanup_registry.py"
	cat >"$HELPER" <<'PY'
import glob
import fnmatch
import json
import os
import pathlib
import shutil


def load(registry):
    return json.loads(pathlib.Path(registry).read_text())["artifacts"]


def in_scope(entry, mode):
    return mode in entry.get("scopes", ["default"])


def resolve(entry, workroot, homeroot):
    path = entry["path"]
    if path.startswith("~/"):
        return os.path.join(homeroot, path[2:])
    return os.path.join(workroot, path)


def _concrete(pattern):
    return pattern.replace("*", "SAMPLE")


def _filtered(entry, name):
    if "match_any" in entry and not any(
        fnmatch.fnmatchcase(name, pattern) for pattern in entry["match_any"]
    ):
        return False
    return not any(fnmatch.fnmatchcase(name, pattern) for pattern in entry.get("exclude", []))


def expand(entry, workroot, homeroot):
    target = resolve(entry, workroot, homeroot)
    if entry["type"] == "dir":
        return [target] if os.path.isdir(target) else []
    if entry["type"] == "glob":
        return sorted(
            match for match in glob.glob(target) if _filtered(entry, os.path.basename(match))
        )
    return [target] if os.path.exists(target) else []


def materialize(entry, workroot, homeroot):
    target = resolve(entry, workroot, homeroot)
    if entry["type"] == "dir":
        os.makedirs(target, exist_ok=True)
        child = entry.get("expected_contents", "artifact.txt").replace("*", "SAMPLE")
        open(os.path.join(target, os.path.basename(child)), "w").close()
    else:
        if "match_any" in entry:
            concrete = os.path.join(os.path.dirname(target), _concrete(entry["match_any"][0]))
        elif entry["type"] == "glob":
            concrete = _concrete(target)
        else:
            concrete = target
        parent = os.path.dirname(concrete)
        if parent:
            os.makedirs(parent, exist_ok=True)
        open(concrete, "w").close()


def candidates(entries, workroot, homeroot, mode="default"):
    selected = []
    for entry in entries:
        if not in_scope(entry, mode):
            continue
        target = resolve(entry, workroot, homeroot)
        if not remaining(entry, workroot, homeroot):
            continue
        if entry["type"] == "dir" and "condition" in entry:
            condition = os.path.join(workroot, entry["condition"])
            if mode != "siw" and not os.path.exists(condition):
                continue
            expected = entry["expected_contents"]
            allowed = [expected, ".gitkeep"] if mode == "siw" else [expected]
            if any(
                not any(fnmatch.fnmatch(child, pattern) for pattern in allowed)
                for child in os.listdir(target)
            ):
                continue
        selected.append(entry)
    return selected


def delete(entry, workroot, homeroot):
    for match in expand(entry, workroot, homeroot):
        if os.path.isdir(match):
            shutil.rmtree(match)
        elif os.path.exists(match):
            os.remove(match)


def remaining(entry, workroot, homeroot):
    return bool(expand(entry, workroot, homeroot))


PY
}

@test "cleanup skill retains registry safety policies" {
	run python3 - "$CLEANUP_SKILL" <<'PY'
import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text()
policies = {
    "conditional-directory gate": "any entry's `condition` marker",
    "permanent-spec retention": "every `permanent-spec` entry",
    "auto-mode isolation": (
        "Never include shared diagram files or permanent specs in the auto-selected artifact set."
    ),
    "project-local symlink rejection": "walk every existing component from that root to the match without following symlinks",
    "pre-delete containment recheck": "repeat the project-local non-symlink component walk and canonical containment proof",
}
missing = [name for name, phrase in policies.items() if phrase not in text]
raise SystemExit("missing cleanup safety policies: " + ", ".join(missing) if missing else 0)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "both cleanup contracts are registered" {
	assert_required_contracts_registered \
		workflow-artifact-cleanup-names \
		workflow-artifact-cleanup-registry
}

@test "every registry entry declares required fields and known vocabulary" {
	run python3 - "$REGISTRY" <<'PY'
import fnmatch
import glob
import json
import pathlib
import sys

artifacts = json.loads(pathlib.Path(sys.argv[1]).read_text())["artifacts"]
categories = {"working-dir", "shared-diagram", "permanent-spec"}
retentions = {"disposable", "permanent"}
types = {"file", "glob", "dir"}
conditional_contracts = {
    "siw/issues/": "ISSUE-*.md",
    "siw/qa-intake/": "QA-INTAKE-*.md",
}
detectors = [
    entry
    for entry in artifacts
    if entry.get("type") == "glob"
    and "match_any" in entry
    and "siw" in entry.get("scopes", ["default"])
]


def detector_covers(entry):
    # A named permanent spec the siw detector already matches stays default-only.
    if entry.get("type") != "file" or entry.get("category") != "permanent-spec":
        return False
    path = entry.get("path", "")
    name = path.rsplit("/", 1)[-1]
    return any(
        fnmatch.fnmatchcase(path, detector["path"])
        and any(fnmatch.fnmatchcase(name, pattern) for pattern in detector["match_any"])
        and not any(fnmatch.fnmatchcase(name, pattern) for pattern in detector.get("exclude", []))
        for detector in detectors
    )


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
    path = entry.get("path", "")
    if entry.get("category") != "shared-diagram":
        path_parts = path.split("/")
        if pathlib.PurePosixPath(path).is_absolute() or any(
            part in {".", ".."} for part in path_parts
        ):
            errors.append(f"{ident}: project-local path escapes its workspace: {path!r}")
    if glob.has_magic(path) != (entry.get("type") == "glob"):
        errors.append(f"{ident}: path/type mismatch for {path!r}")
    if path.endswith("/") != (entry.get("type") == "dir"):
        errors.append(f"{ident}: directory path/type mismatch for {path!r}")
    if path.startswith("~/") != (entry.get("category") == "shared-diagram"):
        errors.append(f"{ident}: global path/category mismatch for {path!r}")
    if (entry.get("retention") == "permanent") != (
        entry.get("category") == "permanent-spec"
    ):
        errors.append(f"{ident}: category/retention mismatch")
    scopes = entry.get("scopes", ["default"])
    if not scopes or not set(scopes) <= {"default", "siw"} or len(set(scopes)) != len(scopes):
        errors.append(f"{ident}: bad scopes {scopes!r}")
    covered = detector_covers(entry)
    if covered and "siw" in scopes:
        errors.append(f"{ident}: detector-covered spec must not repeat in siw scope")
    if path.startswith("siw/") != ("siw" in scopes or covered):
        errors.append(f"{ident}: siw scope must cover exactly the siw/ entries")
    if ("match_any" in entry or "exclude" in entry) and entry.get("type") != "glob":
        errors.append(f"{ident}: match_any/exclude require a glob entry")
    if "condition" in entry and "expected_contents" not in entry:
        errors.append(f"{ident}: condition without expected_contents")
    if "condition" in entry:
        expected_contents = conditional_contracts.get(path)
        if expected_contents is None:
            errors.append(f"{ident}: unknown conditional directory contract for {path!r}")
        elif entry.get("expected_contents") != expected_contents:
            errors.append(
                f"{ident}: expected_contents must be {expected_contents!r}"
            )
        if entry["condition"] != "siw/OPEN_ISSUES_OVERVIEW.md":
            errors.append(f"{ident}: condition must use the SIW issue-state marker")
        marker = next((candidate for candidate in artifacts if candidate.get("path") == entry["condition"]), None)
        if marker is None:
            errors.append(f"{ident}: condition is not a registered artifact")
        elif marker.get("type") != "file":
            errors.append(f"{ident}: condition must reference a literal file")
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

@test "shared review convergence cleanup registers only known report files" {
	run python3 - "$REGISTRY" <<'PY'
import json
import pathlib
import sys

artifacts = json.loads(pathlib.Path(sys.argv[1]).read_text())["artifacts"]
paths = {entry["path"]: entry for entry in artifacts}
archive = ".context/linear-issue-to-pr/reviews/"
expected = {
    archive + "REVIEW_OVERVIEW.md",
    archive + "CONVENTION_REVIEW_OVERVIEW.md",
    archive + "OVERENGINEERING_REVIEW_OVERVIEW.md",
    archive + "REFACTOR_OPPORTUNITIES_OVERVIEW.md",
}
legacy = {
    ".context/linear-issue-to-pr/REVIEW_OVERVIEW.md",
    ".context/linear-issue-to-pr/CONVENTION_REVIEW_OVERVIEW.md",
    ".context/linear-issue-to-pr/OVERENGINEERING_REVIEW_OVERVIEW.md",
    ".context/linear-issue-to-pr/REFACTOR_OPPORTUNITIES_OVERVIEW.md",
}
missing = sorted(expected - paths.keys())
errors = [f"missing archive report: {path}" for path in missing]
errors.extend(f"missing legacy report: {path}" for path in sorted(legacy - paths.keys()))
if archive in paths:
    errors.append("whole workflow archive must not be registered as disposable")
for path in (expected | legacy) & paths.keys():
    if paths[path]["type"] != "file":
        errors.append(f"archive report must be a file: {path}")
raise SystemExit("\n".join(errors) if errors else 0)
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

artifacts = c.load(registry)
entries = [a for a in artifacts if "condition" in a]
errors = []
for entry in entries:
    work = os.path.join(tmp, entry["id"])
    home = os.path.join(work, "home")
    os.makedirs(home, exist_ok=True)
    c.materialize(entry, work, home)
    if c.candidates([entry], work, home):
        errors.append(f"selected without marker: {entry['id']}")

    marker = next(a for a in artifacts if a["path"] == entry["condition"])
    c.materialize(marker, work, home)
    selected = c.candidates([entry], work, home)
    if selected != [entry]:
        errors.append(f"not selected with marker and expected contents: {entry['id']}")
    else:
        c.delete(entry, work, home)
        if c.remaining(entry, work, home):
            errors.append(f"selected conditional directory survived cleanup: {entry['id']}")

    c.materialize(entry, work, home)
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
for entry in artifacts:
    if not c.in_scope(entry, "default") and not c.remaining(entry, work, home):
        errors.append(f"siw-only entry deleted by default cleanup: {entry['id']} ({entry['path']})")
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

@test "siw scope adds the discovery handoffs, temporary files, and full spec set" {
	run python3 - "$REGISTRY" "$SIW_MODE_REF" <<'PY'
import json
import pathlib
import re
import sys

artifacts = json.loads(pathlib.Path(sys.argv[1]).read_text())["artifacts"]
by_path = {entry["path"]: entry for entry in artifacts}
errors = []
siw_only = {
    "siw/DISCOVERY_BRIEF.md": "disposable",
    "siw/SPEC_STRENGTHENING_PLAN.md": "disposable",
    "siw/SIW_*.md": "disposable",
    "siw/*.md": "permanent",
    "siw/supporting-specs/": "permanent",
    "siw/contracts/": "permanent",
}
for path, retention in siw_only.items():
    entry = by_path.get(path)
    if entry is None:
        errors.append(f"missing siw-only entry: {path}")
        continue
    if entry.get("scopes") != ["siw"]:
        errors.append(f"{path}: must be selected only by --siw, got {entry.get('scopes')!r}")
    if entry["retention"] != retention:
        errors.append(f"{path}: retention must be {retention}")

detector = by_path.get("siw/*.md", {})
if detector.get("match_any") != ["*SPEC*.md", "*SPECIFICATION*.md", "*PLAN*.md", "*DESIGN*.md"]:
    errors.append(f"spec detector match_any changed: {detector.get('match_any')!r}")
text = pathlib.Path(sys.argv[2]).read_text()
synced = re.search(
    r"Synced SIW spec-exclusion contract \(keep aligned across SIW spec detectors\):\s*((?:`[^`]+`,\s*)+`[^`]+`)\.",
    text,
)
if synced is None:
    errors.append("siw-mode.md lost the synced SIW spec-exclusion contract")
else:
    contract = re.findall(r"`([^`]+)`", synced.group(1))
    if detector.get("exclude") != contract:
        errors.append(f"spec detector exclude {detector.get('exclude')!r} != synced contract {contract!r}")
    if "PRODUCT_AUDIT.md" not in contract:
        errors.append("PRODUCT_AUDIT.md must stay excluded as a legacy SIW report name")
if "```bash" in text or "find siw" in text:
    errors.append("siw-mode.md must not repeat the registry filters as an inline command")
raise SystemExit("\n".join(errors) if errors else 0)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "siw mode retires only the siw workspace and keeps specs until confirmed" {
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
marker = "siw/OPEN_ISSUES_OVERVIEW.md"
for entry in artifacts:
    # Leave the issue-state marker absent: --siw must not require it.
    if entry["path"] != marker:
        c.materialize(entry, work, home)
for directory in ("siw/issues", "siw/supporting-specs"):
    open(os.path.join(work, directory, ".gitkeep"), "w").close()

errors = []
siw_entries = [a for a in artifacts if c.in_scope(a, "siw")]
outside = [a for a in artifacts if not c.in_scope(a, "siw")]
temporary = c.candidates(
    [a for a in siw_entries if a["retention"] == "disposable"], work, home, mode="siw"
)
permanent = c.candidates(
    [a for a in siw_entries if a["retention"] == "permanent"], work, home, mode="siw"
)

temporary_names = {"DISCOVERY_BRIEF.md", "SPEC_STRENGTHENING_PLAN.md", "LOG.md"}
for entry in permanent:
    for match in c.expand(entry, work, home):
        name = os.path.basename(match.rstrip("/"))
        if name in temporary_names or name.startswith(("SIW_", "AUDIT_")):
            errors.append(f"spec detector matched a temporary file: {match}")

# Every SIW path is listed once, and the detector alone lists the named permanent specs.
listed = [match for entry in temporary + permanent for match in c.expand(entry, work, home)]
duplicates = sorted({match for match in listed if listed.count(match) > 1})
if duplicates:
    errors.append(f"--siw lists paths more than once: {duplicates!r}")
named_specs = [
    a
    for a in outside
    if a["category"] == "permanent-spec" and a["path"].startswith("siw/")
]
if not named_specs:
    errors.append("expected named SIW permanent specs outside the siw scope")
for entry in named_specs:
    if c.resolve(entry, work, home) not in listed:
        errors.append(f"spec detector missed named permanent spec: {entry['path']}")
outside = [a for a in outside if a not in named_specs]

selected_ids = {entry["id"] for entry in temporary}
for ident in ("siw-issues", "siw-qa-intake", "siw-discovery-brief", "siw-spec-strengthening-plan"):
    if ident not in selected_ids:
        errors.append(f"--siw did not select {ident}")

# "Temporary files only": every SIW disposable goes; specs and non-SIW artifacts stay.
for entry in temporary:
    c.delete(entry, work, home)
for entry in temporary:
    if c.remaining(entry, work, home):
        errors.append(f"siw temporary survived: {entry['id']}")
for entry in permanent:
    if not c.remaining(entry, work, home):
        errors.append(f"siw permanent deleted without confirmation: {entry['id']}")
for entry in named_specs:
    if not c.remaining(entry, work, home):
        errors.append(f"named permanent spec deleted without confirmation: {entry['path']}")
for entry in outside:
    if not c.remaining(entry, work, home):
        errors.append(f"--siw deleted a non-SIW artifact: {entry['id']} ({entry['path']})")

# "All SIW files": specifications go too, leaving siw/ empty for the non-recursive rmdir.
for entry in permanent:
    c.delete(entry, work, home)
for entry in permanent:
    if c.remaining(entry, work, home):
        errors.append(f"siw permanent survived explicit opt-in: {entry['id']}")
leftover = os.listdir(os.path.join(work, "siw"))
if leftover:
    errors.append(f"siw/ not empty after full SIW cleanup: {leftover!r}")
for entry in outside:
    if not c.remaining(entry, work, home):
        errors.append(f"--siw deleted a non-SIW artifact: {entry['id']} ({entry['path']})")

# Unexpected children still block a conditional directory in --siw mode.
issues = next(a for a in artifacts if a["id"] == "siw-issues")
c.materialize(issues, work, home)
open(os.path.join(work, "siw/issues/notes.txt"), "w").close()
if c.candidates([issues], work, home, mode="siw"):
    errors.append("--siw selected siw/issues/ with unexpected contents")
raise SystemExit("\n".join(errors) if errors else 0)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "siw flag is direct-user-only and mutually exclusive with auto" {
	run python3 - "$CLEANUP_SKILL" "$SIW_MODE_REF" "$PLUGIN_ROOT" <<'PY'
import pathlib
import sys

skill = pathlib.Path(sys.argv[1]).read_text()
siw_mode = pathlib.Path(sys.argv[2]).read_text()
root = pathlib.Path(sys.argv[3])
errors = []
required = {
    "SKILL.md": (
        skill,
        [
            'argument-hint: "[--auto | --siw]"',
            "disable-model-invocation: false",
            "Honor `--siw` only when the user typed the slash command or `$` mention with `--siw`, or explicitly asked in this session to retire the SIW workspace or to run cleanup with `--siw`.",
            "A model caller must never pass `--siw` on its own initiative, including after `kramme:siw:transfer-to-linear` prints its removal suggestion inside an autonomous loop",
            "when `--siw` is present without that user request, stop without scanning or deleting anything.",
            "A direct user request still goes through every SIW confirmation.",
            "for any other `--`-prefixed flag, stop with `Usage: /kramme:workflow-artifacts:cleanup [--auto | --siw]` and delete nothing.",
            "Ignore free text that is not a flag.",
            "the git top-level when inside a repository, otherwise the current working directory",
            "apply the pre-scan warning and the Step 1 through Step 5 overrides",
            "--siw cannot be combined with --auto; SIW cleanup always confirms.",
            "read `references/siw-mode.md` before Step 1",
            "Never include shared diagram files or permanent specs in the auto-selected artifact set.",
        ],
    ),
    "siw-mode.md": (
        siw_mode,
        [
            "run /kramme:siw:transfer-to-linear and verify the migration before continuing.",
            "Select only registry entries whose `scopes` include `siw`.",
            'Omit "All SIW files" when `found_permanent` is empty.',
            'Permanent files are kept unless the user selects "All SIW files".',
            "`--siw` is direct-user-only and never runs with `--auto`",
            "the non-recursive `rmdir siw`",
        ],
    ),
}
for name, (text, phrases) in required.items():
    errors.extend(f"{name} missing: {phrase}" for phrase in phrases if phrase not in text)

if "Accept only `--auto` and `--siw`" in skill:
    errors.append("default cleanup must keep ignoring free-text arguments")
adr = (root / "docs/decisions/2026-08-29-model-invocable-orchestration-children.md").read_text()
for phrase in (
    "- Amended: 2026-10-15",
    "the user typed the slash command or `$` mention with `--siw`, or explicitly asked in this session to retire the SIW workspace or to run cleanup with `--siw`",
    "`--siw` combined with `--auto` fails closed before any scan or deletion",
):
    if phrase not in adr:
        errors.append(f"model-invocation ADR missing: {phrase}")

if "siw:remove" in skill or "siw:remove" in siw_mode:
    errors.append("cleanup still routes to the removed kramme:siw:remove")
if (root / "skills/kramme:siw:remove").exists():
    errors.append("kramme:siw:remove must be deleted")

# The only authorized model parent passes --auto and never --siw.
parent_dir = root / "skills/kramme:linear:issue-to-pr"
for path in parent_dir.rglob("*.md"):
    if "cleanup --siw" in path.read_text():
        errors.append(f"model parent passes --siw: {path.relative_to(root)}")
if "Invoke `kramme:workflow-artifacts:cleanup --auto`" not in (parent_dir / "SKILL.md").read_text():
    errors.append("issue-to-pr no longer pins its cleanup --auto handoff")
raise SystemExit("\n".join(errors) if errors else 0)
PY
	[ "$status" -eq 0 ] || { echo "$output"; false; }
}
