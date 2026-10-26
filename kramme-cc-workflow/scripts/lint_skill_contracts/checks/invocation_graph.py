"""Check that skills only hand work to skills the model and the user can invoke.

Rule (a) fails when a skill tells the model to invoke or delegate to a kramme
skill that sets ``disable-model-invocation: true``; Claude Code rejects that
Skill-tool call. Rule (b) fails when any line, fenced or not, references
``/kramme:x`` or ``$kramme:x`` for a skill that sets ``user-invocable: false``,
because that command never appears in the slash menu.

Rule (a) favours precision over recall and matches only explicit model-executed
hand-off shapes: ``invoke``, ``delegate``, ``skill-tool``, ``engine``,
``conditional-use``, and ``fenced-command``. It deliberately does not match:

- "Run `/kramme:x`", "hand off to", "use `kramme:x` for ...", and "pass ... to",
  which appear far more often as user routes or descriptions than as hand-offs;
- negated, user-addressed, or second-person clauses ("do not invoke", "suggest",
  "the user", "your"), which describe what a person may run;
- adjective uses such as "the invoking `kramme:x` workflow";
- content dependencies ("apply the `kramme:x` contract", "follow the protocol
  from `kramme:x`") and the generic "read the installed `SKILL.md`" fallback,
  which are self-containment concerns rather than invocation edges;
- hand-offs to model-invocable children whose model-invocation contract does not
  name the parent, which need a separate guarded-parent check.

Names that are not shipped skills (agents, removed skills) and self-references
are ignored. ``allowlist`` entries of ``{source, target, reason}`` suppress a
finding; malformed entries fail and entries that suppress nothing warn.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from ..frontmatter import parse_frontmatter, parse_frontmatter_bool
from ..io import read_text, rel, skill_paths
from .types import CheckResult, LintContext

DEFAULT_SKILL_GLOB = "kramme-cc-workflow/skills/*/SKILL.md"
DEFAULT_SCAN_GLOBS = (
    "kramme-cc-workflow/skills/*/**/*.md",
    "kramme-cc-workflow/shared/**/*.md",
    "kramme-cc-workflow/agents/*.md",
)

NAME_PATTERN = re.compile(r"(?<![A-Za-z0-9_:-])([/$]?)(kramme:[a-z0-9-]+(?::[a-z0-9-]+)?)(?![A-Za-z0-9_-])")
FENCE_PATTERN = re.compile(r"^\s*(```|~~~)")
SENTENCE_SPLIT = re.compile(r"(?<=[.!?])\*{0,2}\s+")
CLAUSE_SPLIT = re.compile(r"[;,]\s+|:\s+|\s+[—–]\s+|—")

NEGATION = re.compile(
    r"\b(?:do not|don't|never|not|must not|without|cannot|can't|instead of|rather than)\b",
    re.IGNORECASE,
)
USER_ADDRESS = re.compile(
    r"\b(?:the user|users|suggest|recommend|tell|ask|offer|print|present|point to|optional|human)",
    re.IGNORECASE,
)
SECOND_PERSON = re.compile(r"\byour\b", re.IGNORECASE)

INVOKE_BEFORE = re.compile(r"(?<!\bthe )(?<!\ban )(?<!\ba )\binvok(?:e|es|ing)\s+(?:\*\*)?`$", re.IGNORECASE)
DELEGATE_BEFORE = re.compile(r"\bdelegat(?:e|es|ing)\s+to\s+(?:\*\*)?`?$", re.IGNORECASE)
USE_BEFORE = re.compile(r"\b(?:use|using)\s+(?:\*\*)?`?$", re.IGNORECASE)
SKILL_TOOL_AFTER = re.compile(
    r"^(.{0,80}?)\b(?:via|through|using)\s+(?:the\s+)?(?:Skill tool|skill mechanism|skill-invocation mechanism)",
    re.IGNORECASE,
)
ENGINE_AFTER = re.compile(r"\bas (?:the|its)\b.*?\bengine\b", re.IGNORECASE)
CONDITIONAL_AFTER = re.compile(r"\bwhen it fits\b|\bwhen its\b.*?\bfits\b", re.IGNORECASE)
FENCED_COMMAND_VERB = re.compile(r"\b(?:invoke|delegate to|run)\b", re.IGNORECASE)


@dataclass(frozen=True)
class SkillInfo:
    model_disabled: bool
    user_invocable: bool
    directory: str


@dataclass(frozen=True)
class Finding:
    path: str
    line: int
    target: str
    message: str


def skill_inventory(root: Path, pattern: str) -> tuple[dict[str, SkillInfo], dict[str, str]]:
    skills: dict[str, SkillInfo] = {}
    owners: dict[str, str] = {}
    for path in skill_paths(root, pattern):
        frontmatter = parse_frontmatter(read_text(path)) or {}
        name = frontmatter.get("name") or path.parent.name
        directory = rel(path.parent, root)
        skills[name] = SkillInfo(
            model_disabled=parse_frontmatter_bool(frontmatter, "disable-model-invocation"),
            user_invocable=frontmatter.get("user-invocable", "").strip().lower() != "false",
            directory=directory,
        )
        owners[directory] = name
    return skills, owners


def owning_skill(relative: str, owners: dict[str, str]) -> str | None:
    parts = relative.split("/")
    if "skills" not in parts:
        return None
    index = parts.index("skills")
    return owners.get("/".join(parts[: index + 2]))


def excluded(lead: str, sentence: str) -> bool:
    return bool(NEGATION.search(lead) or USER_ADDRESS.search(lead) or SECOND_PERSON.search(sentence))


def handoff_shape(clause: str, match: re.Match[str]) -> str | None:
    before = clause[: match.start()]
    after = clause[match.end() :]
    if INVOKE_BEFORE.search(before):
        return "invoke"
    if DELEGATE_BEFORE.search(before):
        return "delegate"
    tool = SKILL_TOOL_AFTER.search(after)
    if tool and not NEGATION.search(tool.group(1)):
        return "skill-tool"
    if USE_BEFORE.search(before) and ENGINE_AFTER.search(after):
        return "engine"
    if CONDITIONAL_AFTER.search(after):
        return "conditional-use"
    return None


def handoff_message(path: str, line: int, target: str, shape: str) -> str:
    return (
        f"invocation graph: {path}:{line} hands off to {target} ({shape}), but {target} sets "
        "disable-model-invocation: true; make it a guarded child under an accepted ADR exception, "
        "rewrite the line as a user recommendation, or add an invocation_graph.allowlist entry with a reason"
    )


def hidden_command_message(path: str, line: int, target: str) -> str:
    return (
        f"invocation graph: {path}:{line} tells the user to run /{target}, but {target} sets "
        "user-invocable: false; make it user-invocable or reference it without a slash or dollar command"
    )


def scan_file(relative: str, text: str, skills: dict[str, SkillInfo], owner: str | None) -> list[Finding]:
    findings: list[Finding] = []
    seen: set[tuple[int, str]] = set()

    def known(name: str) -> SkillInfo | None:
        return None if name == owner else skills.get(name)

    def add_handoff(line: int, target: str, shape: str) -> None:
        if (line, target) not in seen:
            seen.add((line, target))
            findings.append(Finding(relative, line, target, handoff_message(relative, line, target, shape)))

    lines = text.splitlines()
    in_fence = False
    for index, line in enumerate(lines):
        number = index + 1
        for match in NAME_PATTERN.finditer(line):
            info = known(match.group(2))
            if match.group(1) and info and not info.user_invocable:
                findings.append(
                    Finding(relative, number, match.group(2), hidden_command_message(relative, number, match.group(2)))
                )

        if FENCE_PATTERN.match(line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue

        for sentence in SENTENCE_SPLIT.split(line):
            for clause in CLAUSE_SPLIT.split(sentence):
                for match in NAME_PATTERN.finditer(clause):
                    info = known(match.group(2))
                    if not info or not info.model_disabled:
                        continue
                    if excluded(clause[: match.start()], sentence):
                        continue
                    shape = handoff_shape(clause, match)
                    if shape:
                        add_handoff(number, match.group(2), shape)

        command = fenced_command(lines, index)
        if command:
            command_number, target = command
            info = known(target)
            sentence = SENTENCE_SPLIT.split(line)[-1]
            clause = CLAUSE_SPLIT.split(sentence)[-1]
            if info and info.model_disabled and FENCED_COMMAND_VERB.search(clause) and not excluded(clause, sentence):
                add_handoff(command_number, target, "fenced-command")
    return findings


def fenced_command(lines: list[str], index: int) -> tuple[int, str] | None:
    if not lines[index].rstrip().endswith(":"):
        return None
    cursor = index + 1
    while cursor < len(lines) and not lines[cursor].strip():
        cursor += 1
    if cursor + 1 >= len(lines) or not FENCE_PATTERN.match(lines[cursor]):
        return None
    match = NAME_PATTERN.match(lines[cursor + 1].strip())
    if not match:
        return None
    return cursor + 2, match.group(2)


def parse_allowlist(config: dict[str, Any], result: CheckResult) -> list[tuple[str, str]]:
    entries = config.get("allowlist", [])
    if not isinstance(entries, list):
        result.failures.append("invocation graph: allowlist must be an array")
        return []
    allowed: list[tuple[str, str]] = []
    for number, entry in enumerate(entries, start=1):
        source = entry.get("source") if isinstance(entry, dict) else None
        target = entry.get("target") if isinstance(entry, dict) else None
        reason = entry.get("reason") if isinstance(entry, dict) else None
        if (
            not isinstance(source, str)
            or not source.strip()
            or not isinstance(target, str)
            or not target.startswith("kramme:")
            or not isinstance(reason, str)
            or not reason.strip()
        ):
            result.failures.append(
                f"invocation graph: allowlist entry {number} requires a source path, a kramme skill target, "
                "and a non-empty reason"
            )
            continue
        allowed.append((source, target))
    return allowed


def check_invocation_graph(context: LintContext) -> CheckResult:
    result = CheckResult()
    config = context.registry.get("invocation_graph")
    if not config:
        return result

    skills, owners = skill_inventory(context.root, config.get("skill_glob", DEFAULT_SKILL_GLOB))
    allowlist = parse_allowlist(config, result)

    paths: set[Path] = set()
    for pattern in config.get("scan_globs", DEFAULT_SCAN_GLOBS):
        paths.update(skill_paths(context.root, pattern))

    findings: list[Finding] = []
    for path in sorted(paths):
        relative = rel(path, context.root)
        findings.extend(scan_file(relative, read_text(path), skills, owning_skill(relative, owners)))

    used: set[tuple[str, str]] = set()
    for finding in sorted(findings, key=lambda item: (item.path, item.line, item.target)):
        key = (finding.path, finding.target)
        if key in allowlist:
            used.add(key)
            continue
        result.failures.append(finding.message)
    for source, target in allowlist:
        if (source, target) not in used:
            result.warnings.append(
                f"invocation graph: allowlist entry {source} -> {target} matches no finding; remove it"
            )
    return result
