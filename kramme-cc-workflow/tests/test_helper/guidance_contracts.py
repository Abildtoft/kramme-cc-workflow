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


def _require_single_opening_metadata_field(label: str, text: str, field: str) -> None:
    metadata = re.search(
        r"(?ms)^#\s+[^\n]+\n\s*\n(?P<body>\S[^\n]*(?:\n(?!\s*\n)\S[^\n]*)*)",
        text,
    )
    if metadata is None:
        raise ContractFailure(f"{label} is missing an opening metadata paragraph")
    total_count = text.count(field)
    opening_count = metadata.group("body").count(field)
    if total_count != 1 or opening_count != 1:
        raise ContractFailure(
            f"{label} must contain {field!r} exactly once in opening metadata "
            f"(total={total_count}, opening={opening_count})"
        )


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
    sentence_start = max(
        text.rfind(delimiter, 0, action_start) for delimiter in (".", ";", "\n")
    )
    prefix = text[max(sentence_start + 1, action_start - 96) : action_start]
    return (
        re.search(
            r"\b(?:do|does|did|should|would|could|must|may|might|will|can)\s+"
            r"(?:not|never)\b(?:\s+\w+){0,4}\s+$",
            prefix,
            re.IGNORECASE,
        )
        is not None
        or re.search(r"\b(?:never|without)\b(?:\s+\w+){0,4}\s+$", prefix, re.IGNORECASE)
        is not None
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
    return any(
        _action_is_negated(text, match.start())
        for match in re.finditer(action_pattern, text, re.IGNORECASE)
    )


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
        if not _has_affirmative_action(section, action_pattern) or _has_negated_action(
            section, action_pattern
        ):
            raise ContractFailure(
                f"standalone attachment self-update must affirmatively {action_label}"
            )

    replacement_pattern = r"ask\w*\b[^.;]*(?:refreshed|updated|replacement)\b[^.;]*(?:copy|plan)\b"
    if not _explicitly_prohibits(section, replacement_pattern) or _has_affirmative_action(
        section, replacement_pattern
    ):
        raise ContractFailure(
            "standalone attachment self-update must prohibit replacement-plan requests"
        )


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
    generated_index = read("skills/kramme:code:breakdown-findings/assets/index-template.md")
    generation_checks = read("skills/kramme:code:breakdown-findings/references/generation-checks.md")
    plan_requirements = read("skills/kramme:code:breakdown-findings/references/plan-content-requirements.md")
    scope_closure = read("skills/kramme:code:breakdown-findings/references/scope-closure.md")
    reconcile = read("skills/kramme:code:breakdown-findings/references/reconcile-workflow.md")
    plan_to_pr = read("skills/kramme:code:plan-to-pr/SKILL.md")
    attachment_input = read("skills/kramme:code:plan-to-pr/references/attachment-input.md")
    standalone_index = read("skills/kramme:code:plan-to-pr/assets/standalone-index-template.md")
    completion = read("skills/kramme:pr:complete-work/SKILL.md")
    scope_handoff = read("skills/kramme:pr:complete-work/references/standalone-scope-handoff.md")
    scoped_ci = read("skills/kramme:pr:fix-ci/references/scoped-plan.md")
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
    scope_contract = "**Scope contract:** exact files"
    _require_single_opening_metadata_field("detachable-plan scope template", plan_template, scope_contract)
    _require_single_opening_metadata_field("generated index scope contract", generated_index, scope_contract)
    _require_terms(
        "detachable-plan generation checks",
        generation_checks,
        ("repository-relative file", "existing directory", "missing path", "one intended file"),
    )
    _require_terms(
        "detachable-plan scope closure workflow",
        scope_closure,
        (
            "acceptance criterion",
            "all repository references",
            "manual translation",
            "call site",
            "generated artifacts",
            "modify",
            "verify-only",
            "irrelevant",
            "No required edit appears in **Out of Scope**",
            "artifact, reviewer, or verification path",
            "Do not invent a runtime path",
            "pre-clustered handoff mode",
            "return to Phase 2",
            "request a corrected handoff",
        ),
    )
    handoff_boundary = next(
        (paragraph for paragraph in re.split(r"\n\s*\n", scope_closure) if "pre-clustered handoff mode" in paragraph),
        "",
    )
    if not _has_affirmative_action(handoff_boundary, r"\bstop\b") or not _explicitly_prohibits(
        handoff_boundary,
        r"(?:expand|split|merge|resequence)",
    ):
        raise ContractFailure("scope closure must stop rather than changing fixed pre-clustered handoff boundaries")
    non_runtime_trace = next(
        (
            paragraph
            for paragraph in re.split(r"\n\s*\n", scope_closure)
            if "artifact or workflow entry point" in paragraph
        ),
        "",
    )
    if not _explicitly_prohibits(non_runtime_trace, r"invent(?:ing)?\s+(?:a\s+)?runtime path"):
        raise ContractFailure("scope closure must not require fabricated runtime paths for non-runtime work")
    _require_terms(
        "detachable-plan scope closure generation",
        breakdown,
        (
            "references/scope-closure.md",
            "A clean drift check proves only that listed files have not changed",
            "an acceptance criterion lacks both an implementation path and proof path",
        ),
    )
    _require_terms(
        "detachable-plan scope closure template",
        plan_template,
        (
            "## Scope Closure Evidence",
            "Applicable path traced",
            "Repository search / references",
            "Path disposition",
            "modify / verify-only / irrelevant",
        ),
    )
    for label, text in (
        ("generated plan drift self-update", plan_template),
        ("generated index drift self-update", generated_index),
        ("plan-content drift self-update", plan_requirements),
        ("generation-check drift self-update", generation_checks),
    ):
        _require_drift_self_update_contract(label, text)
    _require_standalone_refresh_contract(attachment_input)
    _require_terms(
        "standalone stale-status reachability",
        attachment_input,
        (
            "Accept `DRIFTED` or `STALE` only as lifecycle-free pre-execution input",
            "Require the current standalone plan/index status to be `TODO`, `READY`, `DRIFTED`, or `STALE`",
            "accept matching plan/index status `DRIFTED` or `STALE` only as pre-execution input",
            "replace a `DRIFTED` or `STALE` status with `TODO`, `READY`, or the validated "
            "detached-plan `BLOCKED` state",
        ),
    )
    plan_validation = _markdown_section(plan_to_pr, r"Step 2: Validate the Plan Set")
    _require_terms(
        "plan-to-PR standalone self-update routing",
        plan_validation,
        (
            "Refresh a Drifted Standalone Plan",
            "wait for explicit approval",
            "new immutable source snapshot",
            "content-derived archive",
            "Never rewrite or delete the original attachment or established archive",
            "never ask the user to provide a refreshed plan",
        ),
    )
    prerequisite_validation = _markdown_section(plan_to_pr, r"Step 4: Establish the Plan Branch")
    _require_terms(
        "detached prerequisite refresh routing",
        prerequisite_validation,
        (
            "absent because the prerequisite has not landed",
            "retry after the prerequisite lands",
            "fetched-base evidence",
            "route an otherwise eligible lifecycle-free standalone plan through `Refresh a Drifted Standalone Plan`",
            "never request replacement input",
            "do not ask for `PR_PLAN_INDEX.md`",
        ),
    )
    _require_terms(
        "standalone attachment index",
        standalone_index,
        (
            "**Attachment contract:** {attachment-contract}",
            "**Scope contract:** exact files",
            "{sequencing-summary}",
            "## Dependency Map",
        ),
    )
    for label, text in (
        ("plan-to-PR scope classification", plan_to_pr),
        ("completion scope classification", scope_handoff),
        ("scoped CI classification", scoped_ci),
    ):
        _require_terms(
            label,
            text,
            (
                "**Scope contract:** exact files",
                "PLAN_SCOPE_MODE=exact-files",
                "PLAN_SCOPE_MODE=containment",
                "legacy compatibility",
                "marker present in only part of the set",
                "never infer exact-file mode from file-shaped paths alone",
            ),
        )
    _require_terms(
        "completion scope handoff",
        completion,
        ("marked generated plan sets", "unmarked legacy generated sets"),
    )
    implementation_scope = _markdown_section(plan_to_pr, r"Step 5: Implement the Plan")
    completion_scope = _markdown_section(scope_handoff, r"Preserve Exact-File Scope")
    scoped_ci_scope = _markdown_section(scoped_ci, r"Preserve Scope")
    _require_terms(
        "plan-to-PR exact-file enforcement",
        implementation_scope,
        (
            "exact equality for `PLAN_SCOPE_MODE=exact-files`",
            "otherwise exact path or directory containment",
            "re-run the Git-admin, file-level, and batched index-aware ignored-path eligibility checks",
        ),
    )
    _require_terms(
        "completion exact-file enforcement",
        completion_scope,
        (
            "Every dirty, staged, or committed path membership check uses exact equality",
            "Directory containment applies only when `PLAN_SCOPE_MODE=containment`",
            "apply it to every `PLAN_SCOPE_MODE=exact-files` archive",
        ),
    )
    _require_terms(
        "scoped CI exact-file enforcement",
        scoped_ci_scope,
        (
            "every dirty, staged, committed, or proposed path that is not exactly one",
            "run `RECHECK_STANDALONE_SCOPE` for exact-file mode",
            "For `containment`, require each path to equal one validated path or remain below",
        ),
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
    reconcile_lifecycle = _markdown_section(reconcile, r"2. Reconstruct and Classify the Plan Graph")
    _require_terms(
        "in-progress drift lifecycle",
        reconcile_lifecycle,
        (
            "Only an executor may move a plan to `IN_PROGRESS`",
            "ordinary in-scope implementation changes after `Planned at` are expected",
            "move `IN_PROGRESS` to `BLOCKED`, `DRIFTED`, or `STALE`",
            "unexpected changes that are inconsistent with active implementation",
            "Reset `IN_PROGRESS` for any other reason only when the user explicitly requests that transition",
        ),
    )

    _require_terms(
        "attachment-first input routing",
        plan_to_pr,
        (
            "Select the input contract from the validated path before applying any plan-set rule",
            "A file below `.context/attachments/` is always one standalone attachment",
            "never search for them, require them, or ask the user to attach them",
            "The validated path is the sole intake classifier",
            "Do not inspect the repository root or attachment directory for a source index",
        ),
    )
    intake_routing = _markdown_section(plan_to_pr, r"Step 1: Parse Arguments")
    _ordered_regex_anchors(
        intake_routing,
        (
            ("path classifier", r"validated path is the sole intake classifier"),
            ("attachment contract load", r"For attachment input, read `references/attachment-input\.md`"),
            ("root set inventory", r"For root input, require sibling `PR_PLAN_INDEX\.md`"),
        ),
        "attachment intake before generated-set inventory",
    )
    _require_terms(
        "attachment-only validation branch",
        plan_validation,
        (
            "Branch on `{plan-input-mode}` before reading companion artifacts",
            "For `attachment`, read only the selected attachment",
            "A valid detached `W##L` attachment is not an incomplete generated set",
            "absence of companion plans is expected",
            "never replace that diagnosis with a request for the complete `PR_PLAN_*.md` set",
        ),
    )
    _ordered_regex_anchors(
        plan_validation,
        (
            ("attachment-only read", r"For `attachment`, read only the selected attachment"),
            ("attachment classification", r"For attachment input, set `STANDALONE_ATTACHMENT=true`"),
            ("indexed-set validation", r"For root or archived input, require the index"),
        ),
        "attachment classification before indexed-set validation",
    )
    root_classification = re.search(
        r"(?ms)^\s+- For root input, require the selected basename.*?(?=^\s+- For archived input,)",
        plan_validation,
    )
    if root_classification is None:
        raise ContractFailure("root input is missing its generated-set classification block")
    _require_terms(
        "root generated-set classification",
        root_classification.group(0),
        (
            "set `STANDALONE_ATTACHMENT=false`",
            "Read the index and every implementation plan it references",
            "set `PLAN_SCOPE_MODE=exact-files`",
            "set `PLAN_SCOPE_MODE=containment`",
        ),
    )
    _require_terms(
        "attachment reference routing invariant",
        attachment_input,
        (
            "the attachment is deliberately the complete input",
            "Select this contract from its validated location before interpreting its content",
            "Do not search for or request the source `PR_PLAN_INDEX.md`",
            "they never change a direct attachment into root input",
            "Diagnose a failure against the exact self-contained field or evidence requirement",
        ),
    )
    _require_terms(
        "archived status disagreement repair",
        plan_validation,
        (
            "The index status is authoritative",
            "archived input with a status-only mismatch",
            "no `## Workflow State` or `## Execution Result`",
            "both values to be recognized lifecycle statuses",
            "changes only the selected plan header to the index status",
            "restart Step 2",
            "interruption between the executor's two status-file replacements",
            "lifecycle-bearing mismatch",
        ),
    )

    branch_step = _markdown_section(plan_to_pr, r"Step 4: Establish the Plan Branch")
    runtime_only_status = "Keep the detached plan's archived plan/index status unchanged while proving prerequisites"
    if runtime_only_status not in branch_step:
        raise ContractFailure("detached readiness is not kept runtime-only until implementation begins")
    if "do not persist `READY`" not in branch_step:
        raise ContractFailure("detached readiness still permits a persisted READY transition")
    if "atomically change only their status fields to `READY`" in branch_step:
        raise ContractFailure("detached readiness is still persisted before a workflow checkpoint exists")
    _require_terms(
        "interrupted detached checkpoint recovery",
        branch_step,
        (
            "detached generated attachment",
            "one bounded exception",
            "archive must have no workflow state or execution result",
            "worktree must be clean",
            "no remote branch or Pull Request",
            "exactly one commit",
            "commit subject to contain `{execution-label}`",
            "exact equality with the normalized standalone scope",
            "repeat every prerequisite-evidence assertion",
            "explicitly authorizes that exact full commit OID",
            "validated temporary plan sibling",
            "atomically rename",
        ),
    )

    implementation_step = _markdown_section(plan_to_pr, r"Step 5: Implement the Plan")
    _require_terms(
        "first-checkpoint readiness transition",
        implementation_step,
        (
            "change the selected plan header and matching index row together",
            "complete temporary siblings",
            "to `IN_PROGRESS`",
            "replace `{active-plan}` first",
            "replace `{active-index}` last as the authoritative commit point",
            "archived-input repair in Step 2 deterministically restores agreement",
            "never begin source edits over mismatched plan state",
            "matching index row at `IN_PROGRESS`",
        ),
    )
    _require_terms(
        "pre-edit delegate failure status restoration",
        implementation_step,
        (
            "clean pre-delegation snapshot",
            "compare `HEAD` and the source worktree",
            "When both are unchanged and this invocation changed the status",
            "restore the selected plan header first and the authoritative index row last",
            "to `CLAIM_PRIOR_STATUS`",
            "When source work or a commit exists",
            "retain `IN_PROGRESS`",
            "exact changed paths",
            "no implementation work began",
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
            "matching plan/index status `IN_PROGRESS`",
            "interrupted executor-owned retry",
        ),
    )

    legacy_consumers = (
        (
            "skills/kramme:code:plan-to-pr/references/attachment-input.md",
            archive_validation,
        ),
        (
            "skills/kramme:pr:complete-work/references/standalone-scope-handoff.md",
            _markdown_section(scope_handoff, r"Validate Standalone Provenance"),
        ),
        (
            "skills/kramme:pr:fix-ci/references/scoped-plan.md",
            _markdown_section(scoped_ci, r"Validate the Archive"),
        ),
    )
    for relative, migration_section in legacy_consumers:
        text = read(relative)
        _require_terms(
            f"legacy standalone migration in {relative}",
            migration_section,
            (
                "legacy normalized independent archive",
                "one-time deterministic migration",
                "temporary index sibling",
                "Attachment contract",
                "independent plan",
                "preserves every other byte",
                "leave the previous index intact",
            ),
        )
        if "non-`W##L`" not in migration_section:
            raise ContractFailure(f"legacy standalone migration in {relative} is not limited to non-W##L archives")
        if re.search(r"\b(?:re-read and validate|writing and validating)\b", migration_section, re.IGNORECASE) is None:
            raise ContractFailure(f"legacy standalone migration in {relative} lacks staged index validation")
        _ordered_regex_anchors(
            migration_section,
            (
                (
                    "complete proof",
                    r"(?:after|only after)[^.]*\b(?:proofs?|legacy candidate)\b[^.]*\bpass(?:es)?\b",
                ),
                ("temporary sibling", r"\btemporary index sibling\b"),
                ("atomic rename", r"\batomic(?:ally)?\b[^.]*\brename(?:d)?\b"),
                ("post-rename revalidation", r"\b(?:repeat items|re-read and repeat)\b"),
                ("failure preservation", r"\b(?:on any [^.]*failure|on failure)[^.]*leave the previous index intact\b"),
            ),
            f"legacy standalone migration in {relative}",
        )
        _require_terms(
            f"detached nonterminal classification in {relative}",
            text,
            (
                "DETACHED_GENERATED_PLAN=true",
                "DETACHED_GENERATED_PLAN=false",
                "BLOCKED",
                "IN_PROGRESS",
            ),
        )


Check = Callable[[pathlib.Path], None]

CHECKS: dict[str, Check] = {
    "discovery-result-schema": check_discovery_result_schema,
    "discovery-failure-boundary": check_discovery_failure_boundary,
    "issue-intake-state": check_issue_intake_state,
    "issue-stage-order": check_issue_stage_order,
    "review-gate-order": check_review_gate_order,
    "drift-self-update-guidance": check_drift_self_update_guidance,
    "standalone-refresh-guidance": check_standalone_refresh_guidance,
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
