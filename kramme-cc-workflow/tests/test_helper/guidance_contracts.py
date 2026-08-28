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


def _action_is_negated(text: str, action_start: int) -> bool:
    sentence_start = max(text.rfind(delimiter, 0, action_start) for delimiter in (".", ";", "\n"))
    prefix = text[max(sentence_start + 1, action_start - 96) : action_start]
    return (
        re.search(
            r"\b(?:do|does|did|should|would|could|must|may|might|will|can)\s+"
            r"(?:not|never)\b(?:\s+\w+){0,4}\s+$",
            prefix,
            re.IGNORECASE,
        )
        is not None
        or re.search(r"\b(?:never|without)\b(?:\s+\w+){0,4}\s+$", prefix, re.IGNORECASE) is not None
    )


def _affirmative_action_positions(text: str, action_pattern: str) -> list[int]:
    positions: list[int] = []
    for match in re.finditer(action_pattern, text, re.IGNORECASE):
        if _action_is_negated(text, match.start()):
            continue
        positions.append(match.start())
    return positions


def _affirmative_action_position(text: str, action_pattern: str) -> int | None:
    positions = _affirmative_action_positions(text, action_pattern)
    return positions[0] if positions else None


def _has_affirmative_action(text: str, action_pattern: str) -> bool:
    return _affirmative_action_position(text, action_pattern) is not None


def _has_negated_action(text: str, action_pattern: str) -> bool:
    return any(_action_is_negated(text, match.start()) for match in re.finditer(action_pattern, text, re.IGNORECASE))


def _explicitly_prohibits(text: str, action_pattern: str) -> bool:
    return (
        re.search(
            rf"\b(?:without|do not|don't|never|neither)\b[^.;]*(?:{action_pattern})",
            text,
            re.IGNORECASE,
        )
        is not None
    )


def _require_drift_self_update_contract(label: str, text: str) -> None:
    blocks = [block.strip() for block in re.split(r"(?m)\n\s*\n|(?=^\s*-\s+)", text) if block.strip()]
    dirty_stop_pattern = (
        r"(?:\bstop\w*\b[^.;]*\bstaged\b[^.;]*\bunstaged\b[^.;]*\buntracked\b|"
        r"\bstaged\b[^.;]*\bunstaged\b[^.;]*\buntracked\b[^.;]*\bstop\w*\b)"
    )
    clean_committed_pattern = r"\bworktree\b[^.;]*\bclean\b[^.;]*\bcommitted\b[^.;]*\bdrift\b"
    explain_pattern = r"\bexplain(?:s|ed|ing)?\b[^.;]*\baffected paths?\b"
    offer_pattern = r"\boffer(?:s|ed|ing)?\b[^.;]*\bupdate\b[^.;]*\bin place\b"
    approval_pattern = (
        r"\bwait(?:s|ed|ing)?\b[^.;]*\bexplicit approval\b[^.;]*\bbefore\b"
        r"[^.;]*\b(?:chang\w*|updat\w*|revis\w*)\b[^.;]*\b(?:it|plan|planning artifact)\b"
    )
    replacement_pattern = r"ask\w*\b[^.;]*(?:refreshed|updated|replacement)\b[^.;]*(?:copy|plan)\b"
    dirty_mutation_pattern = (
        r"\b(?:continue|updat\w*|refresh\w*|revis\w*)\b[^.;]*"
        r"\b(?:staged|unstaged|untracked|uncommitted)\b"
    )

    for block in blocks:
        dirty_stop = _affirmative_action_position(block, dirty_stop_pattern)
        clean_committed = _affirmative_action_position(block, clean_committed_pattern)
        explain = next(
            (
                position
                for position in _affirmative_action_positions(block, explain_pattern)
                if clean_committed is not None and position > clean_committed
            ),
            None,
        )
        offer = _affirmative_action_position(block, offer_pattern)
        approval = _affirmative_action_position(block, approval_pattern)
        if (
            dirty_stop is not None
            and clean_committed is not None
            and explain is not None
            and offer is not None
            and approval is not None
            and dirty_stop < clean_committed < explain < offer < approval
            and _explicitly_prohibits(block, replacement_pattern)
            and not _has_affirmative_action(block, replacement_pattern)
            and not _has_affirmative_action(block, dirty_mutation_pattern)
            and not any(
                _has_negated_action(block, pattern)
                for pattern in (dirty_stop_pattern, explain_pattern, offer_pattern, approval_pattern)
            )
        ):
            return

    raise ContractFailure(
        f"{label} must keep the ordered approval-gated in-place update contract in one guidance block"
    )


def check_drift_self_update_guidance(path: pathlib.Path) -> None:
    _require_drift_self_update_contract("drift self-update guidance", path.read_text(encoding="utf-8"))


def _require_standalone_refresh_contract(text: str) -> None:
    section = _markdown_section(text, r"Refresh a Drifted Standalone Plan")
    _require_terms(
        "standalone attachment self-update",
        section,
        (
            "source worktree to be clean",
            "Uncommitted in-scope drift cannot be represented by `Planned at`",
            "`TODO`, `READY`, `DRIFTED`, or `STALE`",
            "`BLOCKED` only for a detached generated plan with named blockers",
            "Reject any `## Workflow State` or `## Execution Result`",
            "no local branch, remote branch, or Pull Request",
            "Never ask the user to provide a refreshed, updated, or replacement plan",
            "creating only this child when absent",
            "temporary revision directory",
            "scope boundary",
            "dependency label",
            "execution-label",
            "canonical-filename",
            "approval to refresh stale evidence alone does not silently authorize a changed implementation boundary",
            "new `{plan-source-object-id}` and `{plan-set-id}`",
            "old source and archive remain unchanged provenance records",
            "set `{plan-input-mode}=archived`",
            "fetched `origin/{base-branch}` tip",
            "`HEAD` to equal that tip",
            "same commit that later seeds the implementation branch",
            "repeat the source-hash, plan/index status, lifecycle, clean-worktree, base-tip, "
            "local-branch, remote-branch, and Pull Request eligibility proofs",
            "Immediately before identity derivation or publication",
            "This repetition occurs after any separate boundary confirmation",
            "pass `git check-ignore`",
            "never copy secret values",
            "not a recovery path for `IN_PROGRESS`, `DONE`, `IMPLEMENTED`, `QUALITY_BLOCKED`, "
            "`COMPLETE`, or `PUBLISHED_BLOCKED` state",
            "never publish or treat a partial archive as valid",
            "every retained temporary or staging path",
            "stop without product edits",
        ),
    )

    required_actions = (
        ("require a clean source worktree", r"\brequire\b[^.;]*\bsource worktree\b[^.;]*\bclean\b"),
        (
            "require the fetched execution base",
            r"\brequire\b[^.;]*\bHEAD\b[^.;]*\bequal\b[^.;]*\btip\b",
        ),
        (
            "wait for refresh approval",
            r"\bwait\b[^.;]*\bexplicit approval\b[^.;]*\bbefore\b[^.;]*\bwriting\b",
        ),
        (
            "repeat eligibility proofs after approval",
            r"\brepeat\b[^.;]*\bsource-hash\b[^.;]*\bPull Request\b[^.;]*\bproofs\b",
        ),
        (
            "require ignored artifact paths",
            r"\brequire\b[^;]*\bpass\b[^;]*\bgit check-ignore\b",
        ),
        (
            "rerun scope closure",
            r"\brerun\b[^.;]*\bcomplete scope-closure procedure\b",
        ),
        (
            "wait for boundary confirmation",
            r"\bwait\b[^.;]*\bexplicit confirmation\b[^.;]*\bbefore publishing\b",
        ),
        (
            "report retained diagnostic paths",
            r"\breport\b[^.;]*\bevery retained temporary or staging path\b",
        ),
        ("stop without product edits", r"\bstop\b[^.;]*\bwithout product edits\b"),
        ("restart validation", r"\brestart\b[^.;]*\bStep 2\b"),
    )
    for action_label, action_pattern in required_actions:
        if not _has_affirmative_action(section, action_pattern) or _has_negated_action(section, action_pattern):
            raise ContractFailure(f"standalone attachment self-update must affirmatively {action_label}")

    replacement_pattern = r"ask\w*\b[^.;]*(?:refreshed|updated|replacement)\b[^.;]*(?:copy|plan)\b"
    if not _explicitly_prohibits(section, replacement_pattern) or _has_affirmative_action(section, replacement_pattern):
        raise ContractFailure("standalone attachment self-update must prohibit replacement-plan requests")


def check_standalone_refresh_guidance(path: pathlib.Path) -> None:
    _require_standalone_refresh_contract(path.read_text(encoding="utf-8"))


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


def check_review_gate_order(path: pathlib.Path) -> None:
    section = _markdown_section(path.read_text(encoding="utf-8"), r"Applicability Evaluation")
    anchors = (
        (
            "regular code-review invocation",
            r"^\s*When active, invoke `kramme:pr:code-review --parallel --inline`",
        ),
        (
            "convention-review invocation",
            r"^\s*When active, invoke `kramme:pr:convention-review --inline`",
        ),
        (
            "overengineering-review invocation",
            r"^\s*When active in normal mode, invoke `kramme:pr:overengineering-review` "
            r"with the exact sentinel-last arguments `--requirements \{work-requirements\}`",
        ),
        (
            "refactor-opportunities invocation",
            r"^\s*When active, invoke `kramme:code:refactor-opportunities` with `pr`",
        ),
    )
    _ordered_regex_anchors(section, anchors, "ordered gate invocations")


Check = Callable[[pathlib.Path], None]

CHECKS: dict[str, Check] = {
    "discovery-result-schema": check_discovery_result_schema,
    "discovery-failure-boundary": check_discovery_failure_boundary,
    "review-gate-order": check_review_gate_order,
    "drift-self-update-guidance": check_drift_self_update_guidance,
    "standalone-refresh-guidance": check_standalone_refresh_guidance,
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
