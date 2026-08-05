#!/usr/bin/env python3
"""Validate narrow semantic contracts used by guidance-oriented Bats tests."""

from __future__ import annotations

import argparse
import pathlib
import re
import sys
from collections.abc import Callable


class ContractFailure(Exception):
    """Raised with a diagnostic that identifies the missing guidance contract."""


def _contains_term(text: str, term: str) -> bool:
    return (
        re.search(
            rf"(?<!\w){re.escape(term)}s?(?!\w)",
            text,
            re.IGNORECASE,
        )
        is not None
    )


def _markdown_section(text: str, heading_pattern: str) -> str:
    match = re.search(
        rf"(?ms)^##\s+{heading_pattern}\s*$\n(?P<body>.*?)(?=^##\s+|\Z)",
        text,
    )
    if match is None:
        raise ContractFailure(f"missing level-2 section matching /{heading_pattern}/")
    return match.group("body")


def _require_terms(label: str, text: str, terms: tuple[str, ...]) -> None:
    missing = [term for term in terms if not _contains_term(text, term)]
    if missing:
        raise ContractFailure(f"{label} is missing concepts: {', '.join(missing)}")


def _result_field_bullets(section: str) -> list[str]:
    result = re.search(
        r"(?ms)^6\.\s+.*?`INTERVIEW RESULT:`.*?\n",
        section,
    )
    if result is None:
        raise ContractFailure("delegated result schema is missing the numbered INTERVIEW RESULT return block")

    bullets: list[str] = []
    current: list[str] = []
    for line in section[result.end() :].splitlines():
        bullet = re.match(r"^[ \t]+-\s*(?P<body>.*)", line)
        if bullet:
            if current:
                bullets.append(" ".join(current))
            current = [bullet.group("body").strip()]
        elif current and (not line.strip() or line[:1].isspace()):
            if line.strip():
                current.append(line.strip())
        else:
            break
    if current:
        bullets.append(" ".join(current))
    if not bullets:
        raise ContractFailure("delegated result schema is missing the numbered INTERVIEW RESULT return block")
    return bullets


def _is_affirmative_field(text: str) -> bool:
    return (
        re.search(
            r"\b(?:do not|don't|never|without|omit(?:s|ted|ting)?|exclud(?:e|es|ed|ing))\b|"
            r"\bnot\s+(?:validated|included|provided|reported|returned|recorded|present)\b",
            text,
            re.IGNORECASE,
        )
        is None
    )


def check_discovery_result_schema(path: pathlib.Path) -> None:
    section = _markdown_section(path.read_text(encoding="utf-8"), r"Called by Another Skill")
    bullets = _result_field_bullets(section)
    contracts = {
        "hypothesis": ("validated", "hypothesis", "topic", "classification"),
        "decisions": ("decision", "rationale", "impact map", "source"),
        "non-goals": ("non-goal", "rationale", "divergence", "alignment"),
        "confidence": ("initial", "final", "percentage", "round"),
        "evidence profile": ("evidence", "ledger", "topic-coverage", "status"),
        "unresolved gaps": ("missing requirement", "risk", "source"),
    }
    for label, terms in contracts.items():
        if not any(
            _is_affirmative_field(bullet) and all(_contains_term(bullet, term) for term in terms) for bullet in bullets
        ):
            raise ContractFailure(
                f"delegated result schema is missing field '{label}' (required concepts: {', '.join(terms)})"
            )


def _has_affirmative_action(text: str, action_pattern: str) -> bool:
    for match in re.finditer(action_pattern, text, re.IGNORECASE):
        prefix = text[max(0, match.start() - 24) : match.start()]
        if re.search(r"\b(?:do not|don't|never|must not|without)\s+$", prefix, re.IGNORECASE):
            continue
        return True
    return False


def _explicitly_prohibits(text: str, action_pattern: str) -> bool:
    return (
        re.search(
            rf"\b(?:without|do not|don't|never|neither)\b[^.;]*(?:{action_pattern})",
            text,
            re.IGNORECASE,
        )
        is not None
    )


def check_discovery_failure_boundary(path: pathlib.Path) -> None:
    section = _markdown_section(path.read_text(encoding="utf-8"), r"Step 2: Delegate the Interview")
    boundary = next(
        (
            paragraph
            for paragraph in re.split(r"\n\s*\n", section)
            if "INTERVIEW RESULT:" in paragraph and re.search(r"required fields?", paragraph, re.IGNORECASE)
        ),
        "",
    )
    required_patterns = {
        "delegation error trigger": r"\berrors?\b",
        "delegation timeout trigger": r"times?\s+out|\btimeouts?\b",
        "missing result marker trigger": (
            r"(?:\b(?:absent|missing)\b[^.]*`?INTERVIEW RESULT:`?|"
            r"\b(?:without|lacks?|omits?)\b[^.]*`?INTERVIEW RESULT:`?[^.]*\bmarker\b)"
        ),
        "missing required-field trigger": (
            r"\b(?:missing|omits?|lacks?)\b[^.]*\brequired fields?\b|"
            r"\bwithout\b[^.]*\brequired fields?\b"
        ),
    }
    missing = [
        label
        for label, pattern in required_patterns.items()
        if not re.search(pattern, boundary, re.IGNORECASE | re.DOTALL)
    ]
    failure_sentence = next(
        (
            sentence
            for sentence in re.split(r"(?<=[.!?])\s+", boundary)
            if all(re.search(pattern, sentence, re.IGNORECASE | re.DOTALL) for pattern in required_patterns.values())
            and _has_affirmative_action(sentence, r"\b(?:stop|halt)\b")
        ),
        "",
    )
    if not failure_sentence:
        missing.append("affirmative malformed-payload stop clause")
    if not _explicitly_prohibits(boundary, r"replay(?:ing)?"):
        missing.append("no interview replay")
    if not _explicitly_prohibits(
        boundary,
        r"(?:writ(?:e|es|ing|ten)\b[^.;]*\bSIW artifact|SIW artifact\b[^.;]*\bwrit\w*)",
    ):
        missing.append("no SIW artifact write")
    if not _explicitly_prohibits(boundary, r"emit(?:s|ting)?\b[^.;]*`?PLAN:"):
        missing.append("no PLAN emission")
    if not boundary:
        missing.insert(0, "INTERVIEW RESULT required-field validation paragraph")
    if missing:
        raise ContractFailure("delegation failure boundary is missing: " + ", ".join(missing))


def _affirmative_entry_state_capture_position(text: str) -> int | None:
    for clause_match in re.finditer(r"[^.!?\n]+(?:[.!?]+|\n|$)", text):
        clause = clause_match.group()
        capture = re.search(r"\b(?:capture|record|store)\b", clause, re.IGNORECASE)
        if capture is None:
            continue
        if re.search(
            r"\b(?:do not|don't|never|must not)\s+(?:ever\s+)?(?:capture|record|store)\b",
            clause,
            re.IGNORECASE,
        ):
            continue
        if not all(_contains_term(clause, term) for term in ("{intake-head}", "{intake-branch}")):
            continue
        if not re.search(r"\b(?:current|entry)\b", clause, re.IGNORECASE):
            continue
        if not re.search(r"\b(?:commit|HEAD)\b", clause, re.IGNORECASE):
            continue
        if not re.search(r"\bbranch\b", clause, re.IGNORECASE):
            continue
        return clause_match.start() + capture.start()
    return None


def _first_branch_mutation_position(text: str) -> int | None:
    mutation = re.search(
        r"(?im)(?:^|[.!?;]\s+)"
        r"(?:(?:then|next),?\s+)?"
        r"(?:"
        r"(?:switch|check\s+out|checkout|create)\b[^.!?;\n]*\bbranch\b|"
        r"(?:run|execute)\s+`?git\s+(?:switch|checkout)\b"
        r")",
        text,
    )
    return mutation.start() if mutation else None


def check_issue_intake_state(path: pathlib.Path) -> None:
    section = _markdown_section(path.read_text(encoding="utf-8"), r"Step 2: Resolve the Issue and Branch")
    first_item = re.search(r"(?ms)^1\.\s+(?P<body>.*?)(?=^2\.\s+)", section)
    if first_item is None:
        raise ContractFailure("issue intake contract is missing numbered item 1")
    item = first_item.group("body")
    capture_position = _affirmative_entry_state_capture_position(item)
    mutation_position = _first_branch_mutation_position(item)
    if capture_position is None or (mutation_position is not None and mutation_position < capture_position):
        raise ContractFailure("issue intake item 1 does not affirmatively record its entry state")
    _require_terms(
        "issue intake item 1",
        item,
        ("git status --porcelain", "{intake-head}", "{intake-branch}"),
    )


def _without_nonoperational_sections(text: str) -> str:
    kept: list[str] = []
    skipped_heading_level: int | None = None
    for line in text.splitlines(keepends=True):
        heading = re.match(r"^(?P<marks>#{2,6})\s+(?P<title>.+?)\s*$", line)
        if skipped_heading_level is not None:
            if heading is None or len(heading.group("marks")) > skipped_heading_level:
                continue
            skipped_heading_level = None
        if heading and re.search(
            r"\b(?:historical|examples?|legacy|deprecated|obsolete)\b",
            heading.group("title"),
            re.IGNORECASE,
        ):
            skipped_heading_level = len(heading.group("marks"))
            continue
        kept.append(line)
    return "".join(kept)


def _ordered_regex_anchors(text: str, anchors: tuple[tuple[str, str], ...], label: str) -> None:
    positions: list[tuple[str, int]] = []
    for anchor_name, pattern in anchors:
        match = re.search(pattern, text, re.IGNORECASE | re.MULTILINE)
        if match is None:
            raise ContractFailure(f"{label} is missing anchor '{anchor_name}'")
        positions.append((anchor_name, match.start()))
    for index in range(len(positions) - 1):
        current = positions[index]
        following = positions[index + 1]
        if current[1] >= following[1]:
            raise ContractFailure(f"{label} is wrong: '{current[0]}' must precede '{following[0]}'")


def check_issue_stage_order(path: pathlib.Path) -> None:
    text = _without_nonoperational_sections(path.read_text(encoding="utf-8"))
    _ordered_regex_anchors(
        text,
        (
            (
                "branch boundary resolution",
                r"^\s*(?:\d+\.\s+)?(?:run|execute|require)\s+"
                r'`git ls-remote --heads origin "refs/heads/\{issue-branch\}"`',
            ),
            (
                "implementation delegation",
                r"^\s*Otherwise\s+(?:invoke|call)\s+`kramme:siw:issue-implement`.*\{issue-id\}\s+--auto",
            ),
            ("commit boundary", r"^\s*4\.\s+Stage only classified paths\b"),
            (
                "completion delegation",
                r"^(?![^\n]*\b(?:do not|don't|never|must not)\s+(?:invoke|call)\b)"
                r"[^\n]*\b(?:invoke|call)\s+`kramme:pr:complete-work`\s+once\b.*$",
            ),
        ),
        "issue stage order",
    )


def check_review_gate_order(path: pathlib.Path) -> None:
    section = _markdown_section(path.read_text(encoding="utf-8"), r"Ordered Gates")
    anchors = (
        (
            "regular code-review invocation",
            r"^\s*(?:[-*]\s+)?(?:invoke|call)\s+`kramme:pr:code-review --parallel --inline`",
        ),
        (
            "convention-review invocation",
            r"^\s*(?:[-*]\s+)?(?:invoke|call)\s+`kramme:pr:convention-review --inline`",
        ),
        (
            "refactor-opportunities invocation",
            r"^\s*(?:[-*]\s+)?(?:invoke|call)\s+`kramme:code:refactor-opportunities pr`",
        ),
    )
    _ordered_regex_anchors(section, anchors, "ordered gate invocations")


def check_detached_plan_compatibility(root: pathlib.Path) -> None:
    if not root.is_dir():
        raise ContractFailure("detached-plan compatibility check requires the plugin root directory")

    def read(relative: str) -> str:
        return (root / relative).read_text(encoding="utf-8")

    breakdown = read("skills/kramme:code:breakdown-findings/SKILL.md")
    plan_template = read("skills/kramme:code:breakdown-findings/assets/plan-template.md")
    generation_checks = read("skills/kramme:code:breakdown-findings/references/generation-checks.md")
    reconcile = read("skills/kramme:code:breakdown-findings/references/reconcile-workflow.md")
    plan_to_pr = read("skills/kramme:code:plan-to-pr/SKILL.md")
    attachment_input = read("skills/kramme:code:plan-to-pr/references/attachment-input.md")
    standalone_index = read("skills/kramme:code:plan-to-pr/assets/standalone-index-template.md")
    routing = read("skills/kramme:code:work-from-plan/references/routing.md")

    _require_terms(
        "detachable-plan generation",
        breakdown,
        ("file-level", "repository-relative file", "existing directory", "missing path", "one intended file"),
    )
    _require_terms(
        "detachable-plan scope template",
        plan_template,
        ("repository-relative file", "existing directory", "missing path", "one intended file"),
    )
    _require_terms(
        "detachable-plan generation checks",
        generation_checks,
        ("repository-relative file", "existing directory", "missing path", "one intended file"),
    )
    _require_terms(
        "standalone attachment index",
        standalone_index,
        ("**Attachment contract:** {attachment-contract}", "{sequencing-summary}", "## Dependency Map"),
    )
    _require_terms(
        "detached direct routing",
        routing,
        (
            "concrete prerequisite-readiness section",
            "treat the prerequisite as satisfied",
            "without requesting an index, sibling plan, tracker status, or landing record",
            "proven present from self-contained repository-state evidence",
        ),
    )
    _require_terms(
        "reconciled prerequisite evidence",
        reconcile,
        (
            "dependency changes are confirmed",
            "same confirmed write",
            "Prerequisite Readiness Evidence",
            "repository-only pass/fail decision",
        ),
    )

    branch_step = _markdown_section(plan_to_pr, r"Step 4: Establish the Plan Branch")
    runtime_only_status = (
        "Keep a detached plan's archived plan/index status unchanged throughout the nonterminal lifecycle"
    )
    if runtime_only_status not in branch_step:
        raise ContractFailure("detached readiness is not kept runtime-only throughout the nonterminal lifecycle")
    if "atomically change only their status fields to `READY`" in branch_step:
        raise ContractFailure("detached readiness is still persisted before a workflow checkpoint exists")
    _require_terms(
        "interrupted detached checkpoint recovery",
        branch_step,
        (
            "one bounded exception",
            "exactly one commit",
            "exact equality with the normalized standalone scope",
            "repeat every prerequisite-evidence assertion",
            "validated temporary plan sibling",
            "atomically rename",
        ),
    )

    implementation_step = _markdown_section(plan_to_pr, r"Step 5: Implement the Plan")
    _require_terms(
        "first-checkpoint readiness transition",
        implementation_step,
        (
            "validated temporary sibling",
            "atomically rename",
            "matching index row at their original `BLOCKED` status",
            "readiness remains runtime-only",
            "rather than creating a cross-file transaction",
        ),
    )

    archive_validation = _markdown_section(attachment_input, r"Validate a Normalized Archive")
    _require_terms(
        "archived detached classification",
        archive_validation,
        (
            "set `DETACHED_GENERATED_PLAN=true`",
            "set `DETACHED_GENERATED_PLAN=false`",
            "derive `{attachment-contract}`",
            "the immutable plan has no attachment-contract field",
            "persisted status remains `BLOCKED`",
        ),
    )

    legacy_consumers = (
        "skills/kramme:code:plan-to-pr/references/attachment-input.md",
        "skills/kramme:pr:complete-work/references/standalone-scope-handoff.md",
        "skills/kramme:pr:fix-ci/references/scoped-plan.md",
    )
    for relative in legacy_consumers:
        text = read(relative)
        _require_terms(
            f"legacy standalone migration in {relative}",
            text,
            (
                "legacy normalized independent archive",
                "one-time deterministic migration",
                "temporary index sibling",
                "Attachment contract",
                "independent plan",
            ),
        )
        if "non-`W##L`" not in text:
            raise ContractFailure(f"legacy standalone migration in {relative} is not limited to non-W##L archives")
        if re.search(r"\batomic(?:ally)?\b[^.]*\brename(?:d)?\b", text, re.IGNORECASE) is None:
            raise ContractFailure(f"legacy standalone migration in {relative} lacks an atomic index rename")

    for relative in legacy_consumers:
        text = read(relative)
        _require_terms(
            f"detached nonterminal classification in {relative}",
            text,
            (
                "DETACHED_GENERATED_PLAN=true",
                "DETACHED_GENERATED_PLAN=false",
                "BLOCKED",
            ),
        )


Check = Callable[[pathlib.Path], None]

CHECKS: dict[str, Check] = {
    "discovery-result-schema": check_discovery_result_schema,
    "discovery-failure-boundary": check_discovery_failure_boundary,
    "issue-intake-state": check_issue_intake_state,
    "issue-stage-order": check_issue_stage_order,
    "review-gate-order": check_review_gate_order,
    "detached-plan-compatibility": check_detached_plan_compatibility,
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("check", choices=sorted(CHECKS))
    parser.add_argument("path", type=pathlib.Path)
    args = parser.parse_args()
    try:
        CHECKS[args.check](args.path)
    except (ContractFailure, OSError, UnicodeError) as error:
        print(f"contract check failed: {error}", file=sys.stderr)
        return 1
    print(f"contract check passed: {args.check}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
