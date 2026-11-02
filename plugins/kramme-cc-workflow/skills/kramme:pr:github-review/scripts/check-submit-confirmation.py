#!/usr/bin/env python3
"""Decide whether a user message confirms submitting the prepared GitHub review.

kramme:pr:github-review is report-only by default. It may submit the prepared
review only after the user sends a separate message that names the action, the
Pull Request, and the review event, for example:

    Post the prepared review to PR 8683 as request changes

Usage: check-submit-confirmation.py --pr <number> --repo <owner/name> < message.txt

Reads the user's message verbatim on stdin. On acceptance, prints the GitHub
review event (REQUEST_CHANGES, COMMENT, or APPROVE) and exits 0. Otherwise
prints the reason to stderr and exits 1. Exits 2 on usage errors.

The check is deliberately strict. A request to review (even one that also asks
to post), an invocation of this skill, a bare "yes", a question, a conditional
or negated sentence, a message naming another Pull Request, or one naming zero
or several events is refused, so the skill asks the user to restate the action
instead of guessing.
"""

from __future__ import annotations

import argparse
import re
import sys

SKILL_NAME = re.compile(r"kramme:pr:github-review\b", re.IGNORECASE)
REVIEW_REQUEST = re.compile(r"\b(?:re-?)?review\s+(?:this|that|it|my|PR\b|pull\b|#?\d)", re.IGNORECASE)
NEGATION_OR_CONDITION = re.compile(
    r"\b(?:not|never|no|don'?t|doesn'?t|won'?t|shouldn'?t|cannot|refus(?:e|es|ed|ing)|declin(?:e|es|ed|ing)|wait|hold|cancel|stop|later|unless|if|until)\b|n't\b",
    re.IGNORECASE,
)
POST_VERB = re.compile(r"\b(?:post|submit|publish|send)\b", re.IGNORECASE)
REVIEW_NOUN = re.compile(r"\breview\b", re.IGNORECASE)
PR_REFERENCES = (
    re.compile(r"\b(?:PR|pull\s+request)\s*#?\s*(\d+)\b", re.IGNORECASE),
    re.compile(r"(?<![\w/])#(\d+)\b"),
    re.compile(r"/pull/(\d+)\b"),
)
GITHUB_PR_URL = re.compile(
    r"https?://github\.com/([^/\s?#]+)/([^/\s?#]+)/pull/(\d+)\b",
    re.IGNORECASE,
)
EVENTS = {
    "REQUEST_CHANGES": re.compile(r"\brequest(?:ing|ed)?[\s_-]+changes\b|\bchanges[\s_-]+requested\b", re.IGNORECASE),
    "APPROVE": re.compile(r"\bapprov(?:e|ed|al|ing)\b", re.IGNORECASE),
    "COMMENT": re.compile(r"\bas\s+(?:an?\s+)?comment\b|\bcomment[\s_-]+only\b", re.IGNORECASE),
}
EXAMPLE = "Post the prepared review to PR {pr} as request changes | as comment | as approve"


def refusal(text: str, pr: str, repo: str) -> str | None:
    """Return why ``text`` is not a confirmation for ``pr``, or None when it is."""
    text = text.replace("\u2018", "'").replace("\u2019", "'")
    if not text.strip():
        return "the message is empty"
    if SKILL_NAME.search(text):
        return "invoking kramme:pr:github-review is not a confirmation to write to GitHub"
    if REVIEW_REQUEST.search(text):
        return "a request to review the Pull Request is not a confirmation to write to GitHub"
    if "?" in text:
        return "a question is not a confirmation"
    if NEGATION_OR_CONDITION.search(text):
        return "the message is negated, deferred, or conditional"
    if not (POST_VERB.search(text) and REVIEW_NOUN.search(text)):
        return "the message does not ask to post or submit the review"
    named = {number for pattern in PR_REFERENCES for number in pattern.findall(text)}
    if not named:
        return f"the message does not name PR {pr}"
    if named != {pr}:
        others = ", ".join(sorted(named - {pr})) or pr
        return f"the message names another Pull Request ({others})"
    expected_repository = repo.casefold()
    named_repositories = {f"{match.group(1)}/{match.group(2)}".casefold() for match in GITHUB_PR_URL.finditer(text)}
    if named_repositories and named_repositories != {expected_repository}:
        others = ", ".join(sorted(named_repositories - {expected_repository})) or repo
        return f"the message names another repository ({others})"
    return None


def requested_events(text: str) -> list[str]:
    return [event for event, pattern in EVENTS.items() if pattern.search(text)]


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--pr", required=True, help="the Pull Request number the prepared review targets")
    parser.add_argument("--repo", required=True, help="the owner/name repository the prepared review targets")
    args = parser.parse_args(argv)
    pr = args.pr.lstrip("#")
    if not pr.isdigit() or not re.fullmatch(r"[^/\s]+/[^/\s]+", args.repo):
        print(
            f"Expected a Pull Request number and owner/name repository, got '{args.pr}' and '{args.repo}'.",
            file=sys.stderr,
        )
        return 2

    text = sys.stdin.read()
    reason = refusal(text, pr, args.repo)
    events = requested_events(text) if reason is None else []
    if reason is None and len(events) != 1:
        reason = "the message must name exactly one review event"
    if reason is not None:
        print(f"Not a confirmation: {reason}. Ask the user to send: {EXAMPLE.format(pr=pr)}", file=sys.stderr)
        return 1

    print(events[0])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
