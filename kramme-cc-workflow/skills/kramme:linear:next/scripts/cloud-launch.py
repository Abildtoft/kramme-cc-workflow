#!/usr/bin/env python3
"""Conductor cloud launcher for kramme:linear:next.

The skill keeps issue selection and the user's confirmation. This helper owns the Conductor CLI calls:

  detect                                        Report whether this session runs in a usable Conductor cloud
                                                workspace, with its project ID and this session's model.
  launch --project-id ID --item ISSUE AGENT MODEL [--item ...]
                                                Create one cloud workspace per confirmed issue, in order, whose
                                                first message runs kramme:linear:issue-to-pr ISSUE --ship.

Each call prints one JSON document with `schema_version`, `command`, `status`, `reason`, and `message`. Exit codes:
0 when the call completed; 1 when `launch` stopped before starting every issue; 2 for an invalid invocation.
Conductor does not deduplicate workspace creation, so `launch` stops at the first failure and never retries.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from typing import Any, Dict, NamedTuple, NoReturn, Sequence

JsonDict = Dict[str, Any]

SCHEMA_VERSION = 1
CONDUCTOR = "conductor"
# The first message is read as a user-typed skill invocation: a slash command in Claude Code, a $ mention in Codex.
# A message sent from another session expands in Claude Code only under the plugin-qualified skill name.
INVOCATIONS = {"claude": "/kramme-cc-workflow:kramme-linear-issue-to-pr", "codex": "$kramme:linear:issue-to-pr"}
MAX_ITEMS = 25
TIMEOUT_ENV = "KRAMME_CONDUCTOR_TIMEOUT_SECONDS"
DEFAULT_TIMEOUT = 60
MAX_TIMEOUT = 300
# The Conductor CLI documents exit 2 as a usage error and exit 3 as an authentication error; neither applies a write.
USAGE_EXIT = 2
AUTH_EXIT = 3
ID_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9_-]*")
ISSUE_RE = re.compile(r"[A-Z][A-Z0-9]*-[0-9]+")
MODEL_RE = re.compile(r"[a-z0-9][a-z0-9.-]*")
EXIT_CODES = {"ok": 0, "not_cloud": 0, "unavailable": 0, "stopped": 1, "error": 2}


class Stop(Exception):
    """The helper was invoked incorrectly; nothing was sent to Conductor."""

    def __init__(self, reason: str, message: str) -> None:
        super().__init__(message)
        self.reason = reason
        self.message = message


class JsonArgumentParser(argparse.ArgumentParser):
    def error(self, message: str) -> NoReturn:
        raise Stop("usage", message)


class CliResult(NamedTuple):
    outcome: str
    data: Any
    detail: str


def timeout_seconds() -> int:
    raw = os.environ.get(TIMEOUT_ENV, "")
    if raw.isdigit() and 1 <= int(raw) <= MAX_TIMEOUT:
        return int(raw)
    return DEFAULT_TIMEOUT


def first_line(text: str) -> str:
    for line in text.splitlines():
        if line.strip():
            return line.strip()[:300]
    return ""


def run_cli(args: Sequence[str]) -> CliResult:
    command = [CONDUCTOR, "--json", *args]
    try:
        completed = subprocess.run(list(command), input="", capture_output=True, text=True, timeout=timeout_seconds())
    except subprocess.TimeoutExpired:
        return CliResult("timeout", None, "the Conductor CLI did not answer in time")
    except OSError as error:
        return CliResult("failed", None, f"the Conductor CLI could not run: {error.strerror or error}")
    detail = first_line(completed.stderr) or first_line(completed.stdout)
    if completed.returncode == AUTH_EXIT:
        return CliResult("auth_error", None, detail or "the Conductor credential was rejected")
    if completed.returncode == USAGE_EXIT:
        return CliResult("rejected", None, detail or "the Conductor CLI rejected the request")
    if completed.returncode != 0:
        return CliResult("failed", None, detail or f"the Conductor CLI exited with status {completed.returncode}")
    try:
        return CliResult("ok", json.loads(completed.stdout), "")
    except json.JSONDecodeError:
        return CliResult("malformed", None, "the Conductor CLI returned invalid JSON")


def valid_id(value: object) -> bool:
    return isinstance(value, str) and ID_RE.fullmatch(value) is not None


def unavailable(reason: str, message: str) -> JsonDict:
    return {"status": "unavailable", "reason": reason, "message": message}


def detect() -> JsonDict:
    is_local = os.environ.get("CONDUCTOR_IS_LOCAL")
    if is_local != "0":
        reason = "local_workspace" if is_local == "1" else "not_conductor"
        return {"status": "not_cloud", "reason": reason, "message": "This is not a Conductor cloud workspace."}
    if shutil.which(CONDUCTOR) is None:
        return unavailable("cli_missing", "the Conductor CLI is not installed in this workspace")
    workspace_id = os.environ.get("CONDUCTOR_WORKSPACE_ID", "")
    if not valid_id(workspace_id):
        return unavailable("workspace_id_invalid", "CONDUCTOR_WORKSPACE_ID is missing or invalid")
    lookup = run_cli(["workspace", "get", workspace_id])
    if lookup.outcome == "auth_error":
        return unavailable("auth_error", "this workspace's Conductor credential was rejected")
    if lookup.outcome != "ok":
        return unavailable("workspace_lookup_failed", lookup.detail)
    workspace = lookup.data if isinstance(lookup.data, dict) else {}
    if workspace.get("id") != workspace_id or not valid_id(workspace.get("projectId")):
        return unavailable("project_unknown", "Conductor did not report this workspace's project")
    return {
        "status": "ok",
        "reason": "cloud_workspace",
        "message": "Conductor cloud workspace detected.",
        "project_id": workspace["projectId"],
        "session_model": session_model(),
    }


def session_model() -> str | None:
    session_id = os.environ.get("CONDUCTOR_SESSION_ID", "")
    if not valid_id(session_id):
        return None
    lookup = run_cli(["session", "get", session_id])
    model = lookup.data.get("model") if lookup.outcome == "ok" and isinstance(lookup.data, dict) else None
    return model if isinstance(model, str) and MODEL_RE.fullmatch(model) else None


def validate_items(raw_items: Sequence[Sequence[str]]) -> list[tuple[str, str, str]]:
    if len(raw_items) > MAX_ITEMS:
        raise Stop("too_many_items", f"Start at most {MAX_ITEMS} issues at once.")
    items: list[tuple[str, str, str]] = []
    seen: set[str] = set()
    for issue, agent, model in raw_items:
        if not ISSUE_RE.fullmatch(issue):
            raise Stop("issue_invalid", f"{issue!r} is not a Linear issue identifier such as DISC-123.")
        if issue in seen:
            raise Stop("issue_duplicate", f"{issue} is listed more than once.")
        if agent not in INVOCATIONS:
            raise Stop("agent_invalid", f"{agent!r} cannot run this plugin's skills; use claude or codex.")
        if not MODEL_RE.fullmatch(model):
            raise Stop("model_invalid", f"{model!r} is not a Conductor model id such as opus-5-5-1m.")
        seen.add(issue)
        items.append((issue, agent, model))
    return items


def create_outcome(created: CliResult) -> JsonDict:
    if created.outcome == "ok":
        answer = created.data if isinstance(created.data, dict) else {}
        if valid_id(answer.get("workspaceId")) and valid_id(answer.get("sessionId")):
            deep_link = answer.get("deepLink")
            return {
                "outcome": "created",
                "workspace_id": answer["workspaceId"],
                "session_id": answer["sessionId"],
                "deep_link": deep_link if isinstance(deep_link, str) else None,
            }
        return {"outcome": "unknown", "detail": "Conductor answered without a workspace ID; the workspace may exist"}
    if created.outcome in ("auth_error", "rejected"):
        return {"outcome": created.outcome, "detail": created.detail}
    return {"outcome": "unknown", "detail": f"{created.detail}; the workspace may exist"}


def launch(project_id: str, raw_items: Sequence[Sequence[str]]) -> JsonDict:
    if os.environ.get("CONDUCTOR_IS_LOCAL") != "0":
        raise Stop("not_cloud", "launch runs only in a Conductor cloud workspace.")
    if not valid_id(project_id):
        raise Stop("project_id_invalid", "The project ID is missing or invalid.")
    items = validate_items(raw_items)
    if shutil.which(CONDUCTOR) is None:
        raise Stop("cli_missing", "The Conductor CLI is not installed in this workspace.")
    results: list[JsonDict] = []
    stopped = False
    for issue, agent, model in items:
        message = f"{INVOCATIONS[agent]} {issue} --ship"
        entry: JsonDict = {"issue": issue, "agent": agent, "model": model, "message": message}
        results.append(entry)
        if stopped:
            entry["outcome"] = "not_started"
            continue
        created = run_cli(
            ["workspace", "create", "--project-id", project_id, "--name", issue]
            + ["--agent", agent, "--model", model, "--message", message]
        )
        entry.update(create_outcome(created))
        stopped = entry["outcome"] != "created"
    started = sum(1 for entry in results if entry["outcome"] == "created")
    return {
        "status": "stopped" if stopped else "ok",
        "reason": "launch_stopped" if stopped else "launched",
        "message": f"Started {started} of {len(results)} workspaces.",
        "results": results,
    }


def build_parser() -> JsonArgumentParser:
    parser = JsonArgumentParser(prog="cloud-launch.py", description="Conductor cloud launcher for kramme:linear:next.")
    commands = parser.add_subparsers(dest="command", required=True, parser_class=JsonArgumentParser)
    commands.add_parser("detect", help="Report whether this is a usable Conductor cloud workspace.")
    launch_parser = commands.add_parser("launch", help="Start confirmed issues in new Conductor cloud workspaces.")
    launch_parser.add_argument("--project-id", required=True)
    launch_parser.add_argument("--item", nargs=3, action="append", required=True, metavar=("ISSUE", "AGENT", "MODEL"))
    return parser


def emit(command: str, document: JsonDict) -> int:
    sys.stdout.write(json.dumps({"schema_version": SCHEMA_VERSION, "command": command, **document}) + "\n")
    return EXIT_CODES[document["status"]]


def main(argv: Sequence[str] | None = None) -> int:
    command = "unknown"
    try:
        args = build_parser().parse_args(argv)
        command = args.command
        if command == "detect":
            return emit(command, detect())
        return emit(command, launch(args.project_id, args.item))
    except Stop as stop:
        return emit(command, {"status": "error", "reason": stop.reason, "message": stop.message})


if __name__ == "__main__":
    sys.exit(main())
