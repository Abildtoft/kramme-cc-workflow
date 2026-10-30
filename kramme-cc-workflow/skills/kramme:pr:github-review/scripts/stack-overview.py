#!/usr/bin/env python3
"""Measure a Pull Request stack for a stack-level review: layer sizes, shared files, and database changes.

  python3 stack-overview.py --repo <owner/name> --context <file|->

`--context` is the JSON that `scripts/resolve-stack-context.py` prints for any layer of the stack, read from
a file or, with `-`, from standard input. The overview covers a linear stack whose layers all have open Pull
Requests. It fetches the trunk and each layer's `pull/<number>/head` from `origin`, then reads only local Git
objects. It never writes to GitHub and never changes branches, the index, or the working tree.

Prints one JSON document on one line. Exit 1 means the stack cannot be measured, and stderr says why. Exit 2
means an invalid invocation.

Each layer is measured as GitHub shows it: from the merge base with its parent layer's head (the trunk for
the bottom layer) to its own head. Changed lines fall into five groups:

- `production`: source files that are not tests;
- `tests`: test files and directories;
- `database`: migrations and schema files;
- `generated`: lockfiles and paths that the trunk's `.github/pr-risk.json` lists under `generated_paths`;
- `other`: documentation, data, configuration, fixtures, and snapshots.

Files are grouped by the same classifier `kramme:pr:triage-risk` uses. Only the trunk's risk policy can mark a
file generated, so a layer cannot hide code by giving it a generated-looking name.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import re
import subprocess
import sys
from collections.abc import Sequence
from functools import cache
from pathlib import Path, PurePosixPath
from types import ModuleType
from typing import Any

SCHEMA_VERSION = 1
LOCAL_TIMEOUT = 120
NETWORK_TIMEOUT = 180
MAX_HOT_FILES = 15
GROUPS = ("production", "tests", "database", "generated", "other")
# Files these groups share between layers make a later layer build on an earlier one.
STRUCTURAL_GROUPS = frozenset({"production", "database"})
PR_FIELDS = "number,title,url,state,isDraft,headRefName,headRefOid,baseRefName,reviewDecision,statusCheckRollup"
DIFF_OPTIONS = ("--no-color", "--no-ext-diff", "--no-textconv", "--no-renames", "-z")
OID_RE = re.compile(r"[0-9a-f]{40}(?:[0-9a-f]{24})?")
REPO_RE = re.compile(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+")
LEADING_NUMBER_RE = re.compile(r"\d+")
PASSING_CONCLUSIONS = frozenset({"SUCCESS", "NEUTRAL", "SKIPPED"})
PLUGIN_SCRIPTS = Path(__file__).resolve().parents[3] / "scripts"

Json = dict[str, Any]


class StackError(Exception):
    """The stack cannot be measured; the message says why."""


@cache
def risk_signals() -> ModuleType:
    """The `kramme:pr:triage-risk` signal module, which imports its pattern tables as a sibling module."""
    sys.path.insert(0, str(PLUGIN_SCRIPTS))
    spec = importlib.util.spec_from_file_location("risk_signals", PLUGIN_SCRIPTS / "risk-signals.py")
    if spec is None or spec.loader is None:
        raise StackError(f"could not load {PLUGIN_SCRIPTS / 'risk-signals.py'}")
    module = importlib.util.module_from_spec(spec)
    # Dataclasses look their module up in sys.modules while the class is built.
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def environment() -> dict[str, str]:
    return dict(os.environ, GH_PROMPT_DISABLED="1", GIT_TERMINAL_PROMPT="0", GIT_OPTIONAL_LOCKS="0", NO_COLOR="1")


def run(argv: Sequence[str], timeout: int) -> subprocess.CompletedProcess[bytes]:
    """Run without a shell; a timeout or launch failure becomes exit 124 or 127 with the reason on stderr."""
    try:
        return subprocess.run(
            list(argv), env=environment(), stdin=subprocess.DEVNULL, capture_output=True, timeout=timeout
        )
    except subprocess.TimeoutExpired:
        return subprocess.CompletedProcess(list(argv), 124, b"", f"timed out after {timeout}s".encode())
    except OSError as error:
        return subprocess.CompletedProcess(list(argv), 127, b"", str(error).encode())


def tail(data: bytes) -> str:
    return " ".join(data.decode("utf-8", "replace").split())[-300:]


def git(*args: str) -> str:
    result = run(["git", *args], LOCAL_TIMEOUT)
    if result.returncode != 0:
        raise StackError(f"`git {args[0]}` failed: {tail(result.stderr) or f'exit {result.returncode}'}")
    return result.stdout.decode("utf-8", "replace")


def gh_json(*args: str, what: str) -> Any:
    result = run(["gh", *args], LOCAL_TIMEOUT)
    if result.returncode != 0:
        raise StackError(f"could not read {what}: {tail(result.stderr) or f'gh exited {result.returncode}'}")
    try:
        return json.loads(result.stdout or b"null")
    except ValueError as error:
        raise StackError(f"could not parse {what}: {error}") from error


def has_object(spec: str) -> bool:
    return run(["git", "cat-file", "-e", spec], LOCAL_TIMEOUT).returncode == 0


def is_ancestor(ancestor: str, descendant: str) -> bool:
    return run(["git", "merge-base", "--is-ancestor", ancestor, descendant], LOCAL_TIMEOUT).returncode == 0


def valid_branch(name: Any) -> bool:
    if not isinstance(name, str) or not name:
        return False
    checked = run(["git", "check-ref-format", "--branch", name], LOCAL_TIMEOUT)
    return checked.returncode == 0 and checked.stdout.decode("utf-8", "replace").strip() == name


def read_context(source: str) -> Json:
    try:
        text = sys.stdin.read() if source == "-" else Path(source).read_text(encoding="utf-8")
        context = json.loads(text)
    except (OSError, ValueError) as error:
        raise StackError(f"could not read the stack context: {error}") from error
    if not isinstance(context, dict):
        raise StackError("could not read the stack context: expected a JSON object")
    return context


def stack_layers(context: Json) -> tuple[str, list[int], int]:
    """The trunk, each layer's Pull Request number from the bottom up, and the reviewed layer's position."""
    truncated = next((note for note in context.get("notes", []) if note.startswith("stopped after ")), None)
    if truncated:
        raise StackError(f"the stack context is incomplete: {truncated}")
    trunk, position, own = context.get("trunk"), context.get("position"), context.get("pr")
    if (
        context.get("state") != "stacked"
        or not isinstance(position, int)
        or not isinstance(trunk, str)
        or not valid_branch(trunk)
    ):
        summary = context.get("summary") or context.get("reason") or "the stack context is incomplete"
        raise StackError(f"this is not a stack whose layers are all known: {summary}")
    head = {"branch": context.get("head"), "pr": own.get("number") if isinstance(own, dict) else None}
    below, above = context.get("downstack"), context.get("upstack")
    numbers = []
    for entry in [*(below if isinstance(below, list) else []), head, *(above if isinstance(above, list) else [])]:
        number = entry.get("pr") if isinstance(entry, dict) else None
        if not isinstance(number, int) or number < 1:
            branch = entry.get("branch") if isinstance(entry, dict) else entry
            raise StackError(f"layer `{branch}` has no open Pull Request; every layer needs one to be measured")
        numbers.append(number)
    return trunk, numbers, position


def pull_request(repo: str, number: int) -> Json:
    data = gh_json("pr", "view", str(number), "--repo", repo, "--json", PR_FIELDS, what=f"Pull Request #{number}")
    if (
        not isinstance(data, dict)
        or data.get("number") != number
        or not (isinstance(data.get("headRefOid"), str) and OID_RE.fullmatch(data["headRefOid"]))
        or not valid_branch(data.get("headRefName"))
        or not valid_branch(data.get("baseRefName"))
    ):
        raise StackError(f"could not parse Pull Request #{number}")
    if data.get("state") != "OPEN":
        raise StackError(f"Pull Request #{number} is {str(data.get('state')).lower()}, not open")
    return data


def check_chain(trunk: str, pulls: list[Json]) -> None:
    for index, pull in enumerate(pulls):
        expected = trunk if index == 0 else pulls[index - 1]["headRefName"]
        if pull["baseRefName"] != expected:
            raise StackError(
                f"#{pull['number']} targets `{pull['baseRefName']}`, not `{expected}`, "
                "so the layers do not form one linear stack"
            )


def fetch(trunk: str, pulls: list[Json]) -> str:
    """Fetch the trunk and every layer head; return the trunk's tip."""
    refspecs = [f"+refs/heads/{trunk}:refs/remotes/origin/{trunk}", *(f"pull/{p['number']}/head" for p in pulls)]
    result = run(["git", "fetch", "--quiet", "--no-tags", "origin", *refspecs], NETWORK_TIMEOUT)
    if result.returncode != 0:
        raise StackError(f"could not fetch the stack from origin: {tail(result.stderr) or 'git fetch failed'}")
    try:
        records = Path(git("rev-parse", "--git-path", "FETCH_HEAD").strip()).read_text(encoding="utf-8").splitlines()
    except OSError as error:
        raise StackError(f"could not read the fetched heads: {error}") from error
    fetched = {}
    for record in records:
        oid, _, description = record.split("\t", 2)
        ref = description.partition(" of ")[0]
        fetched[ref] = oid
    for pull in pulls:
        if fetched.get(f"'refs/pull/{pull['number']}/head'") != pull["headRefOid"]:
            raise StackError(f"#{pull['number']} moved while it was fetched; run the overview again")
    return git("rev-parse", "--verify", f"refs/remotes/origin/{trunk}^{{commit}}").strip()


def checks(rollup: Any) -> str:
    """One state for a Pull Request's status checks: `failing`, `pending`, `passing`, or `none`.

    Only the latest run of each check counts, so a run cancelled because a newer push superseded it does
    not fail the layer.
    """
    latest: dict[str, Json] = {}
    for item in rollup if isinstance(rollup, list) else []:
        if not isinstance(item, dict):
            continue
        if item.get("__typename") != "CheckRun":
            latest[f"status:{item.get('context')}:{len(latest)}"] = item
            continue
        key = f"run:{item.get('workflowName') or ''}:{item.get('name') or ''}"
        started = str(item.get("startedAt") or "")
        if key not in latest or started >= str(latest[key].get("startedAt") or ""):
            latest[key] = item
    states = set()
    for item in latest.values():
        if item.get("__typename") == "CheckRun":
            if item.get("status") != "COMPLETED":
                states.add("pending")
            else:
                states.add("passing" if item.get("conclusion") in PASSING_CONCLUSIONS else "failing")
        else:
            state = item.get("state")
            states.add(
                "passing" if state == "SUCCESS" else "pending" if state in ("PENDING", "EXPECTED") else "failing"
            )
    return next((state for state in ("failing", "pending", "passing") if state in states), "none")


def group_of(path: str, policy: Any) -> str:
    risk = risk_signals()
    kind = risk.classify_kind(path, policy)
    if kind in ("lockfile", "generated"):
        return "generated"
    if kind == "test":
        return "tests"
    if kind == "docs":
        return "other"
    if "path:database" in risk.code_path_signals(path):
        return "database"
    if PurePosixPath(path).suffix.lower() in risk.patterns.SOURCE_SUFFIXES:
        return "production"
    return "other"


def numstat(base: str, head: str) -> dict[str, tuple[int, int]]:
    """Added and deleted lines per changed path; binary files count as zero lines."""
    counts = {}
    for record in git("diff", "--numstat", *DIFF_OPTIONS, base, head).split("\0"):
        parts = record.split("\t", 2)
        if len(parts) == 3:
            added, deleted, path = parts
            counts[path] = (int(added) if added.isdigit() else 0, int(deleted) if deleted.isdigit() else 0)
    return counts


def statuses(base: str, head: str) -> dict[str, str]:
    tokens = git("diff", "--name-status", *DIFF_OPTIONS, base, head).split("\0")
    return {path: status for status, path in zip(tokens[0::2], tokens[1::2]) if path}


def line_count(commit: str, path: str) -> int | None:
    result = run(["git", "cat-file", "-p", f"{commit}:{path}"], LOCAL_TIMEOUT)
    if result.returncode != 0 or b"\0" in result.stdout:
        return None
    data = result.stdout
    return data.count(b"\n") + (1 if data and not data.endswith(b"\n") else 0)


def numbered(path: str) -> tuple[str, int] | None:
    """A migration's directory and leading number, such as (`drizzle`, 125) for `drizzle/0125_x.sql`."""
    pure = PurePosixPath(path)
    match = LEADING_NUMBER_RE.match(pure.name)
    return (str(pure.parent), int(match.group())) if match else None


def measure_layer(position: int, pull: Json, parent: str, policy: Any) -> tuple[Json, dict[str, tuple[int, int]]]:
    head = pull["headRefOid"]
    base = git("merge-base", parent, head).strip()
    counts, changed = numstat(base, head), statuses(base, head)
    added, deleted = dict.fromkeys(GROUPS, 0), dict.fromkeys(GROUPS, 0)
    database = []
    for path, (plus, minus) in counts.items():
        group = group_of(path, policy)
        added[group] += plus
        deleted[group] += minus
        if group == "database":
            database.append({"path": path, "status": changed.get(path, "M")})
    layer = {
        "position": position,
        "pr": pull["number"],
        "title": pull.get("title") if isinstance(pull.get("title"), str) else "",
        "url": pull.get("url") if isinstance(pull.get("url"), str) else None,
        "branch": pull["headRefName"],
        "head": head,
        "draft": pull.get("isDraft") is True,
        "review_decision": pull.get("reviewDecision") or None,
        "checks": checks(pull.get("statusCheckRollup")),
        "needs_restack": position > 1 and not is_ancestor(parent, head),
        "commits": int(git("rev-list", "--count", f"{base}..{head}").strip() or 0),
        "files": len(counts),
        "added": added,
        "deleted": deleted,
        "database_files": database,
        "extended_by": [],
    }
    return layer, counts


def hot_files(layers: list[Json], counts: list[dict[str, tuple[int, int]]], stack_base: str, policy: Any) -> list[Json]:
    """Files that two or more layers change, the most shared first, with their size at the top of the stack."""
    touched: dict[str, list[Json]] = {}
    for layer, layer_counts in zip(layers, counts):
        for path, (plus, minus) in layer_counts.items():
            touched.setdefault(path, []).append({"position": layer["position"], "added": plus, "deleted": minus})
    shared = [
        (path, entries)
        for path, entries in touched.items()
        if len(entries) > 1 and group_of(path, policy) != "generated"
    ]
    shared.sort(key=lambda item: (-len(item[1]), -sum(entry["added"] for entry in item[1]), item[0]))
    top = layers[-1]["head"]
    hot = []
    for path, entries in shared[:MAX_HOT_FILES]:
        created = not has_object(f"{stack_base}:{path}")
        hot.append(
            {
                "path": path,
                "layers": entries,
                "end_lines": line_count(top, path),
                "created_in_stack": created,
                # Lines a later layer deleted from a file this stack created: code written and then rewritten.
                "churn": sum(entry["deleted"] for entry in entries[1:]) if created else None,
            }
        )
    return hot


def link_layers(layers: list[Json], counts: list[dict[str, tuple[int, int]]], policy: Any) -> None:
    """Record which later layers change the production or database files each layer changed."""
    structural = [
        {path for path in layer_counts if group_of(path, policy) in STRUCTURAL_GROUPS} for layer_counts in counts
    ]
    for index, layer in enumerate(layers):
        layer["extended_by"] = [
            later["position"]
            for later, paths in zip(layers[index + 1 :], structural[index + 1 :])
            if paths & structural[index]
        ]


def database_changes(layers: list[Json], stack_base: str, trunk_tip: str, policy: Any) -> Json:
    """Database files the trunk gained since the stack branched, and numbering clashes in the stack."""
    trunk_added = [
        path
        for path, status in statuses(stack_base, trunk_tip).items()
        if status == "A" and group_of(path, policy) == "database"
    ]
    trunk_numbers = {key: path for path in trunk_added if (key := numbered(path))}
    collisions, out_of_order = [], []
    highest: dict[str, tuple[int, int, str]] = {}
    stack_numbers: dict[tuple[str, int], tuple[int, str]] = {}
    for layer in layers:
        added = [entry["path"] for entry in layer["database_files"] if entry["status"] == "A"]
        for path in sorted(added, key=lambda item: numbered(item) or ("", 0)):
            key = numbered(path)
            if key is None:
                continue
            if key in trunk_numbers:
                collisions.append({"position": layer["position"], "path": path, "trunk_path": trunk_numbers[key]})
            if key in stack_numbers:
                other_position, other_path = stack_numbers[key]
                collisions.append(
                    {
                        "position": layer["position"],
                        "path": path,
                        "other_position": other_position,
                        "other_path": other_path,
                    }
                )
            else:
                stack_numbers[key] = (layer["position"], path)
            directory, number = key
            previous = highest.get(directory)
            if previous and number < previous[0] and previous[1] < layer["position"]:
                out_of_order.append({"position": layer["position"], "path": path, "after": previous[2]})
            if previous is None or number > previous[0]:
                highest[directory] = (number, layer["position"], path)
    return {
        "trunk_added_since_base": trunk_added,
        "number_collisions": collisions,
        "out_of_order": out_of_order,
    }


def overview(repo: str, context: Json) -> Json:
    trunk, numbers, position = stack_layers(context)
    pulls = [pull_request(repo, number) for number in numbers]
    check_chain(trunk, pulls)
    trunk_tip = fetch(trunk, pulls)
    root = git("rev-parse", "--show-toplevel").strip()
    policy = risk_signals().load_policy(root, trunk_tip)
    notes = (
        [f"the trunk's risk policy is invalid and was ignored: {policy.error}"] if policy.status == "invalid" else []
    )
    stack_base = git("merge-base", trunk_tip, pulls[0]["headRefOid"]).strip()
    layers, counts = [], []
    parent = trunk_tip
    for index, pull in enumerate(pulls, start=1):
        layer, layer_counts = measure_layer(index, pull, parent, policy)
        layers.append(layer)
        counts.append(layer_counts)
        parent = pull["headRefOid"]
    link_layers(layers, counts, policy)
    totals = {
        side: {group: sum(layer[side][group] for layer in layers) for group in GROUPS} for side in ("added", "deleted")
    }
    return {
        "schema_version": SCHEMA_VERSION,
        "trunk": trunk,
        "trunk_tip": trunk_tip,
        "stack_base": stack_base,
        "size": len(layers),
        "reviewed_position": position,
        "layers": layers,
        "totals": totals,
        "hot_files": hot_files(layers, counts, stack_base, policy),
        "database": database_changes(layers, stack_base, trunk_tip, policy),
        "notes": notes,
    }


def repository(value: str) -> str:
    if not REPO_RE.fullmatch(value):
        raise argparse.ArgumentTypeError(f"expected owner/name: {value!r}")
    return value


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Measure a Pull Request stack for a stack-level review.")
    parser.add_argument("--repo", required=True, type=repository)
    parser.add_argument("--context", required=True, help="stack context JSON file, or - for standard input")
    args = parser.parse_args(argv)
    try:
        result = overview(args.repo, read_context(args.context))
    except StackError as error:
        print(f"stack overview: {error}", file=sys.stderr)
        return 1
    print(json.dumps(result, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
