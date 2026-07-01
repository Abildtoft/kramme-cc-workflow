from __future__ import annotations

import json
import re

from ..io import read_text, resolve
from ..strings import is_empty_value
from .types import CheckResult, LintContext


def check_hooks_json(context: LintContext) -> CheckResult:
    result = CheckResult()
    config = context.registry.get("hooks_json")
    if not config:
        return result

    relative_path = config.get("path", "kramme-cc-workflow/hooks/hooks.json")
    path = resolve(context.root, relative_path)
    if not path.exists():
        result.failures.append(f"hooks json: registered path is missing: {relative_path}")
        return result

    try:
        data = json.loads(read_text(path))
    except json.JSONDecodeError as exc:
        result.failures.append(
            f"hooks json: {relative_path} is invalid JSON at line {exc.lineno}, "
            f"column {exc.colno}: {exc.msg}"
        )
        return result

    if not isinstance(data, dict):
        result.failures.append(f"hooks json: {relative_path} must contain a JSON object")
        return result

    hooks = data.get("hooks")
    if not isinstance(hooks, dict):
        result.failures.append(f"hooks json: {relative_path} must contain an object field 'hooks'")
        return result

    allowed_events = set(
        config.get(
            "allowed_events",
            ["PreToolUse", "PostToolUse", "UserPromptSubmit", "SessionStart", "Stop"],
        )
    )
    matcher_required_events = set(config.get("matcher_required_events", ["PreToolUse", "PostToolUse"]))
    allowed_hook_types = set(config.get("allowed_hook_types", ["command"]))
    plugin_root = config.get("plugin_root", "kramme-cc-workflow")
    command_path_regex = config.get(
        "command_path_regex",
        r"\$\{CLAUDE_PLUGIN_ROOT\}/([^\"'\s]+)",
    )

    for event, entries in hooks.items():
        if event not in allowed_events:
            result.failures.append(f"hooks json: {relative_path} has unknown event {event!r}")
        if not isinstance(entries, list):
            result.failures.append(f"hooks json: {relative_path} event {event!r} must be a list")
            continue

        for entry_index, entry in enumerate(entries, start=1):
            entry_label = f"{relative_path} {event}[{entry_index}]"
            if not isinstance(entry, dict):
                result.failures.append(f"hooks json: {entry_label} must be an object")
                continue

            matcher = entry.get("matcher")
            if event in matcher_required_events and not isinstance(matcher, str):
                result.failures.append(f"hooks json: {entry_label} must define a string matcher")
            elif event in matcher_required_events and is_empty_value(matcher):
                result.failures.append(f"hooks json: {entry_label} must define a non-empty matcher")
            elif "matcher" in entry and (not isinstance(matcher, str) or is_empty_value(matcher)):
                result.failures.append(
                    f"hooks json: {entry_label} matcher must be a non-empty string when present"
                )

            hook_entries = entry.get("hooks")
            if not isinstance(hook_entries, list) or not hook_entries:
                result.failures.append(f"hooks json: {entry_label} must define a non-empty hooks list")
                continue

            for hook_index, hook_entry in enumerate(hook_entries, start=1):
                hook_label = f"{entry_label}.hooks[{hook_index}]"
                if not isinstance(hook_entry, dict):
                    result.failures.append(f"hooks json: {hook_label} must be an object")
                    continue

                hook_type = hook_entry.get("type")
                if not isinstance(hook_type, str) or hook_type not in allowed_hook_types:
                    result.failures.append(
                        f"hooks json: {hook_label} has unsupported type {hook_type!r}; "
                        f"expected one of {sorted(allowed_hook_types)!r}"
                    )

                command = hook_entry.get("command")
                if not isinstance(command, str) or is_empty_value(command):
                    result.failures.append(f"hooks json: {hook_label} must define a non-empty command")
                    continue

                for plugin_relative in re.findall(command_path_regex, command):
                    command_path = resolve(context.root, f"{plugin_root}/{plugin_relative}")
                    if not command_path.exists():
                        result.failures.append(
                            f"hooks json: {hook_label} command references missing path "
                            f"{plugin_root}/{plugin_relative}"
                        )
    return result
