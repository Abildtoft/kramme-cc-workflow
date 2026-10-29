#!/usr/bin/env python3
"""Summarize one repository's recent agent sessions as aggregate practice signals.

Usage:
  session-signals.py --cwd-prefix PATH [--cwd-prefix PATH ...] [--days N] [--limit N]
                     [--claude-projects DIR] [--codex-sessions DIR]

Finds Claude Code and Codex JSONL transcripts whose recorded working directory is at
or under a --cwd-prefix, reads the --limit most recently modified ones from the last
--days days, and prints one JSON object of counts to stdout.

Privacy contract: the output holds counts, medians, dates, host setting values
(effort, model, permission mode, approval policy), and tool, shell program, skill,
and subagent names. It never holds prompt text, command lines, tool output, or
transcript paths.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import statistics
import sys
import time
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Callable, DefaultDict, Dict, Iterator, List, Optional, Sequence, Set, Tuple

import signal_patterns as patterns

JsonObject = Dict[str, Any]


def as_object(value: object) -> JsonObject:
    return value if isinstance(value, dict) else {}


def as_list(value: object) -> List[Any]:
    return value if isinstance(value, list) else []


def as_str(value: object) -> str:
    return value if isinstance(value, str) else ""


class SessionStats:
    """Counts for one transcript; holds no transcript text."""

    def __init__(self, platform: str) -> None:
        self.platform = platform
        self.cwd = self.first_ts = self.last_ts = ""
        self.counts: Counter[str] = Counter()
        self.tallies: DefaultDict[str, Counter[str]] = defaultdict(Counter)
        self.tool_max: Counter[str] = Counter()
        self.thinking_ms: List[float] = []
        self.first_prompt_chars: Optional[int] = None
        self.aligned_by_skill = False
        self.explore_before_first_edit = self.sequence = 0
        self.last_edit_at = self.last_check_at = -1

    def see_timestamp(self, value: object) -> None:
        stamp = as_str(value)
        if stamp:
            self.first_ts = self.first_ts or stamp
            self.last_ts = stamp

    def add_prompt(self, text: str) -> None:
        body = patterns.prompt_body(text)
        if not body:
            return
        self.counts["prompts"] += 1
        if self.first_prompt_chars is None:
            self.first_prompt_chars = len(body)
        if patterns.is_nudge(body):
            self.counts["nudges"] += 1
        elif patterns.is_correction(body):
            self.counts["corrections"] += 1

    def add_skill(self, name: str) -> None:
        self.tallies["skills"][name] += 1
        if patterns.REVIEW_NAME.search(name):
            self.counts["reviews"] += 1
        if patterns.ALIGNMENT_SKILL.search(name):
            self.aligned_by_skill = True
        if patterns.VERIFY_SKILL.search(name):
            self.mark_check()

    def mark_check(self) -> None:
        self.counts["checks"] += 1
        self.last_check_at = self.sequence

    def add_tool_call(self, name: str, command: str = "", detail: str = "") -> str:
        """Record one tool call and return the attribution key for its output."""
        self.sequence += 1
        group = patterns.tool_group(name)
        self.tallies["tool_calls"][group] += 1
        if name in patterns.EDIT_TOOLS:
            if not self.counts["edits"]:
                self.explore_before_first_edit = self.counts["explorations"]
            self.counts["edits"] += 1
            self.last_edit_at = self.sequence
        elif name in patterns.EXPLORE_TOOLS:
            self.counts["explorations"] += 1
        elif name.endswith("AskUserQuestion") or name.startswith("request_user_input"):
            self.counts["questions"] += 1
        elif name == "ExitPlanMode":
            self.counts["plan_exits"] += 1
        elif name in patterns.SUBAGENT_TOOLS:
            self.tallies["subagents"][detail or "default"] += 1
            if patterns.REVIEW_NAME.search(detail):
                self.counts["reviews"] += 1
        elif name == "Skill" and detail:
            self.add_skill(detail)
        elif name in patterns.SHELL_TOOLS and command:
            checked, program = patterns.classify_command(command)
            if checked:
                self.mark_check()
            if program in patterns.EXPLORE_PROGRAMS:
                self.counts["explorations"] += 1
            if program:
                self.tallies["program_calls"][program] += 1
                return f"{group}\0{program}"
        return group

    def add_output(self, key: str, chars: int) -> None:
        group, _, program = key.partition("\0")
        self.tallies["tool_chars"][group] += chars
        self.tool_max[group] = max(self.tool_max[group], chars)
        if program:
            self.tallies["program_chars"][program] += chars

    @property
    def aligned(self) -> bool:
        return bool(self.counts["questions"] or self.counts["plan_exits"] or self.aligned_by_skill)

    @property
    def ended_unchecked(self) -> bool:
        return self.counts["edits"] > 0 and self.last_edit_at > self.last_check_at


def iter_records(path: Path, stats: Dict[str, int]) -> Iterator[JsonObject]:
    with path.open(encoding="utf-8", errors="replace") as handle:
        for line in handle:
            if not line.strip():
                continue
            try:
                record = json.loads(line)
            except ValueError:
                stats["unparsed_lines"] += 1
                continue
            if isinstance(record, dict):
                yield record
            else:
                stats["unparsed_lines"] += 1


def text_blocks(content: object) -> str:
    if isinstance(content, str):
        return content
    return "\n".join(as_str(as_object(block).get("text")) for block in as_list(content))


def result_chars(content: object) -> int:
    if isinstance(content, str):
        return len(content)
    if isinstance(content, list):
        return len(text_blocks(content))
    if isinstance(content, dict):
        return len(json.dumps(content))
    return 0


def under_prefix(cwd: str, prefixes: Sequence[str]) -> bool:
    return any(cwd == prefix or cwd.startswith(prefix + "/") for prefix in prefixes)


def parse_claude(path: Path, stats: Dict[str, int]) -> SessionStats:
    session = SessionStats("claude-code")
    output_keys: Dict[str, str] = {}
    seen_requests: Set[str] = set()
    for record in iter_records(path, stats):
        kind = record.get("type")
        if kind not in ("user", "assistant") or record.get("isSidechain") is True:
            continue
        session.cwd = session.cwd or as_str(record.get("cwd"))
        session.see_timestamp(record.get("timestamp"))
        message = as_object(record.get("message"))
        content = message.get("content")
        if kind == "assistant":
            request = as_str(record.get("requestId")) or as_str(message.get("id"))
            if request not in seen_requests:
                seen_requests.add(request)
                if as_str(record.get("effort")):
                    session.tallies["effort"][record["effort"]] += 1
                if as_str(message.get("model")) and message["model"] != "<synthetic>":
                    session.tallies["models"][message["model"]] += 1
                if isinstance(record.get("thinkingDurationMs"), (int, float)):
                    session.thinking_ms.append(float(record["thinkingDurationMs"]))
            for block in map(as_object, as_list(content)):
                if block.get("type") != "tool_use":
                    continue
                tool_input = as_object(block.get("input"))
                detail = as_str(tool_input.get("skill")) or as_str(tool_input.get("subagent_type"))
                key = session.add_tool_call(as_str(block.get("name")), as_str(tool_input.get("command")), detail)
                output_keys[as_str(block.get("id"))] = key
            continue
        decision = as_object(record.get("permissionDecision"))
        if decision:
            session.tallies["permission_decisions"][f"{decision.get('source')}:{decision.get('decision')}"] += 1
        if as_str(record.get("permissionMode")):
            session.tallies["permission_modes"][record["permissionMode"]] += 1
        results = [block for block in map(as_object, as_list(content)) if block.get("type") == "tool_result"]
        for result in results:
            key = output_keys.get(as_str(result.get("tool_use_id")), "unknown")
            session.add_output(key, result_chars(result.get("content")))
        if (
            results
            or record.get("isMeta") is True
            or record.get("isCompactSummary") is True
            or as_object(record.get("origin")).get("kind") == "task-notification"
        ):
            continue
        if record.get("promptSource") == "system" or record.get("turnOrigin") in ("task_notification", "scheduled"):
            continue
        text = text_blocks(content).strip()
        command = patterns.COMMAND_NAME.search(text)
        if text.startswith(patterns.INTERRUPT_PREFIX):
            session.counts["interrupts"] += 1
        elif command:
            session.counts["prompts"] += 1
            session.counts["slash_commands"] += 1
            if ":" in command.group(1):
                session.add_skill(command.group(1))
        elif text and not text.startswith(patterns.NON_PROMPT_PREFIXES):
            session.add_prompt(text)
    return session


def codex_command(payload: JsonObject) -> str:
    try:
        arguments = as_object(json.loads(as_str(payload.get("arguments")) or "{}"))
    except ValueError:
        arguments = {}
    command = arguments.get("command", arguments.get("cmd", as_object(payload.get("action")).get("command")))
    parts = [as_str(part) for part in as_list(command)]
    if len(parts) >= 3 and os.path.basename(parts[0]) in ("bash", "sh", "zsh") and parts[1] in ("-c", "-lc"):
        return parts[2]
    return " ".join(parts) if parts else as_str(command)


def parse_codex(path: Path, stats: Dict[str, int], prefixes: Sequence[str]) -> Optional[SessionStats]:
    session = SessionStats("codex")
    output_keys: Dict[str, str] = {}
    for index, record in enumerate(iter_records(path, stats)):
        payload = as_object(record.get("payload"))
        kind, item = record.get("type"), payload.get("type")
        if index == 0:
            source = payload.get("source")
            if payload.get("thread_source") == "subagent" or (isinstance(source, dict) and "subagent" in source):
                stats["skipped_subagent_threads"] += 1
                return None
            if kind == "session_meta" and not under_prefix(as_str(payload.get("cwd")), prefixes):
                stats["sessions_outside_prefix"] += 1
                return None
        session.see_timestamp(record.get("timestamp"))
        if kind == "session_meta":
            session.cwd = session.cwd or as_str(payload.get("cwd"))
        elif kind == "turn_context":
            for field, tally in (("effort", "effort"), ("model", "models"), ("approval_policy", "approval_policies")):
                if as_str(payload.get(field)):
                    session.tallies[tally][payload[field]] += 1
        elif kind == "event_msg" and item == "turn_aborted":
            session.counts["interrupts"] += 1
        elif kind == "response_item" and item == "message" and payload.get("role") == "user":
            text = "\n".join(as_str(as_object(block).get("text")) for block in as_list(payload.get("content")))
            if not text.lstrip().startswith(patterns.CODEX_INJECTED_PREFIXES):
                session.add_prompt(text)
        elif kind == "response_item" and item in ("function_call", "custom_tool_call", "local_shell_call"):
            name = as_str(payload.get("name")) or "local_shell"
            key = session.add_tool_call(name, codex_command(payload) if name in patterns.SHELL_TOOLS else "")
            output_keys[as_str(payload.get("call_id"))] = key
        elif kind == "response_item" and item in ("function_call_output", "custom_tool_call_output"):
            key = output_keys.get(as_str(payload.get("call_id")), "unknown")
            session.add_output(key, result_chars(payload.get("output")))
    return session


def modified_at(path: Path) -> float:
    try:
        return path.stat().st_mtime
    except OSError:
        return 0.0


def discover(
    prefixes: Sequence[str], claude_root: Path, codex_root: Path, cutoff: float
) -> List[Tuple[float, str, Path]]:
    """List candidate transcripts, newest first; Claude project directories encode their working directory."""
    candidates: List[Tuple[float, str, Path]] = []
    encoded = [re.sub(r"[^A-Za-z0-9]", "-", prefix) for prefix in prefixes]
    if claude_root.is_dir():
        for project in claude_root.iterdir():
            if project.is_dir() and any(project.name.startswith(code) for code in encoded):
                candidates.extend((modified_at(path), "claude-code", path) for path in project.glob("*.jsonl"))
    if codex_root.is_dir():
        candidates.extend((modified_at(path), "codex", path) for path in codex_root.rglob("rollout-*.jsonl"))
    return sorted((c for c in candidates if c[0] >= cutoff), key=lambda c: c[0], reverse=True)


def median(values: Sequence[float]) -> Optional[float]:
    return round(statistics.median(values), 1) if values else None


def top(counter: Counter[str], limit: int) -> JsonObject:
    return dict(counter.most_common(limit))


def summarize(sessions: List[SessionStats], args: argparse.Namespace, stats: Dict[str, int]) -> JsonObject:
    changed = [s for s in sessions if s.counts["edits"]]
    asked = [s.counts["questions"] for s in sessions if s.counts["questions"]]
    tally: DefaultDict[str, Counter[str]] = defaultdict(Counter)
    tool_max: Counter[str] = Counter()
    for session in sessions:
        for name, counter in session.tallies.items():
            tally[name].update(counter)
        for tool, chars in session.tool_max.items():
            tool_max[tool] = max(tool_max[tool], chars)

    def count(name: str, group: Sequence[SessionStats] = sessions) -> int:
        return sum(s.counts[name] for s in group)

    def having(name: str, group: Sequence[SessionStats] = sessions) -> int:
        return sum(1 for s in group if s.counts[name])

    tool_chars = tally["tool_chars"]
    all_chars = sum(tool_chars.values())
    mcp_chars = sum(chars for tool, chars in tool_chars.items() if tool.startswith("mcp__"))
    dates = [stamp[:10] for s in sessions for stamp in (s.first_ts, s.last_ts) if stamp]
    return {
        "scope": {"cwd_prefixes": list(args.cwd_prefix), "days": args.days, "limit": args.limit},
        "sessions": {
            "analyzed": len(sessions),
            "by_platform": dict(Counter(s.platform for s in sessions)),
            "first_date": min(dates, default=None),
            "last_date": max(dates, default=None),
        },
        "prompts": {
            "total": count("prompts"),
            "median_per_session": median([s.counts["prompts"] for s in sessions]),
            "short_nudges": count("nudges"),
            "corrections": count("corrections"),
            "sessions_with_corrections": having("corrections"),
            "interrupts": count("interrupts"),
            "slash_commands": count("slash_commands"),
            "median_first_prompt_chars": median([s.first_prompt_chars for s in sessions if s.first_prompt_chars]),
        },
        "alignment": {
            "sessions_with_questions": len(asked),
            "questions": sum(asked),
            "median_questions_when_asked": median(asked),
            "max_questions_in_a_session": max(asked, default=0),
            "plan_approvals": count("plan_exits"),
            "sessions_with_edits_and_alignment": sum(1 for s in changed if s.aligned),
            "sessions_corrected_without_alignment": sum(
                1 for s in changed if s.counts["corrections"] and not s.aligned
            ),
        },
        "changes": {
            "sessions_with_edits": len(changed),
            "edits": count("edits", changed),
            "median_exploration_calls_before_first_edit": median([s.explore_before_first_edit for s in changed]),
        },
        "verification": {
            "check_runs": count("checks"),
            "sessions_with_edits_and_checks": having("checks", changed),
            "sessions_ending_after_unchecked_edits": sum(1 for s in changed if s.ended_unchecked),
        },
        "review": {"sessions_with_edits_and_automated_review": having("reviews", changed)},
        "effort": {
            "requests_by_level": top(tally["effort"], 10),
            "median_thinking_seconds": median([ms / 1000 for s in sessions for ms in s.thinking_ms]),
        },
        "models": top(tally["models"], 5),
        "permissions": {
            "modes": top(tally["permission_modes"], 10),
            "decisions_by_source": top(tally["permission_decisions"], 10),
            "codex_approval_policies": top(tally["approval_policies"], 10),
        },
        "subagents": {"launches": sum(tally["subagents"].values()), "by_type": top(tally["subagents"], 8)},
        "skills": top(tally["skills"], 15),
        "tool_output": {
            "total_chars": all_chars,
            "mcp_share": round(mcp_chars / all_chars, 3) if all_chars else 0,
            "by_tool": [
                {"tool": tool, "calls": tally["tool_calls"][tool], "chars": chars, "max_chars": tool_max[tool]}
                for tool, chars in tool_chars.most_common(8)
            ],
            "by_shell_program": [
                {"program": program, "calls": tally["program_calls"][program], "chars": chars}
                for program, chars in tally["program_chars"].most_common(8)
            ],
        },
        "diagnostics": stats,
    }


def bounded_int(low: int, high: int) -> Callable[[str], int]:
    def parse(value: str) -> int:
        number = int(value)
        if not low <= number <= high:
            raise argparse.ArgumentTypeError(f"must be between {low} and {high}")
        return number

    return parse


def normalize_prefixes(raw: Sequence[str]) -> List[str]:
    """Absolute and symlink-resolved forms of each prefix, without trailing slashes."""
    prefixes: List[str] = []
    for value in raw:
        absolute = os.path.abspath(os.path.expanduser(value))
        for form in (absolute, os.path.realpath(absolute)):
            form = form.rstrip("/")
            if form not in prefixes:
                prefixes.append(form)
    return prefixes


def main(argv: Optional[Sequence[str]] = None) -> int:
    home = Path.home()
    claude_default = Path(os.environ.get("CLAUDE_CONFIG_DIR") or home / ".claude") / "projects"
    codex_default = Path(os.environ.get("CODEX_HOME") or home / ".codex") / "sessions"
    parser = argparse.ArgumentParser(description="Summarize recent agent sessions as aggregate practice signals.")
    parser.add_argument("--cwd-prefix", action="append", required=True, help="repository or worktree path; repeatable")
    parser.add_argument("--days", type=bounded_int(1, 365), default=30)
    parser.add_argument("--limit", type=bounded_int(1, 200), default=30)
    parser.add_argument("--claude-projects", type=Path, default=claude_default)
    parser.add_argument("--codex-sessions", type=Path, default=codex_default)
    args = parser.parse_args(argv)
    args.cwd_prefix = normalize_prefixes(args.cwd_prefix)

    keys = ("files_considered", "unreadable_files", "unparsed_lines", "skipped_subagent_threads")
    stats = dict.fromkeys((*keys, "sessions_outside_prefix"), 0)
    sessions: List[SessionStats] = []
    cutoff = time.time() - args.days * 86400
    for _, platform, path in discover(args.cwd_prefix, args.claude_projects, args.codex_sessions, cutoff):
        if len(sessions) >= args.limit:
            break
        stats["files_considered"] += 1
        try:
            if platform == "claude-code":
                session: Optional[SessionStats] = parse_claude(path, stats)
            else:
                session = parse_codex(path, stats, args.cwd_prefix)
        except OSError:
            stats["unreadable_files"] += 1
            continue
        if session is None:
            continue
        if not under_prefix(session.cwd, args.cwd_prefix):
            stats["sessions_outside_prefix"] += 1
            continue
        sessions.append(session)
    json.dump(summarize(sessions, args, stats), sys.stdout, indent=1)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
