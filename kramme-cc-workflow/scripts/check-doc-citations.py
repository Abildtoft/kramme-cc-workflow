#!/usr/bin/env python3
"""Check that line citations in maintainer guides still point at what they claim.

  python3 check-doc-citations.py [path-to-guide.md ...]

With no paths it checks every top-level Markdown guide in the plugin's docs/
directory. Decision records under docs/decisions/ are excluded because they
describe a point in time. Exit 0 means every citation holds, exit 1 reports the
ones that do not, and exit 2 means a named guide could not be read.

A citation is a backticked `path:line` or `path:start-end` whose path contains a
slash, ends in a source-file extension, or names an existing file, which leaves
out text such as `localhost:3000`. A path resolves against the plugin directory,
then the repository root. A bare file name such as `SKILL.md:89` means the file
most recently cited under that name in the same guide. Each citation must name
lines that exist, and a phrase quoted after it on the same line of the guide must
appear on the cited lines. A bracketed fragment such as the `[s]` in
"execute[s] the plan" is treated as an editorial change, a single quoted word is
taken to be a term rather than a quotation, and quotes inside a code span are
part of that code.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import NamedTuple

PLUGIN_ROOT = Path(__file__).resolve().parent.parent
REPO_ROOT = PLUGIN_ROOT.parent
CITATION = re.compile(r"`([^`\s]+?):(\d+)(?:-(\d+))?`")
SOURCE_FILE = re.compile(r"\.(?:md|js|mjs|ts|py|sh|bats|json|ya?ml|toml|txt)$")
QUOTE = re.compile(r'"([^"]+)"|\u201c([^\u201d]+)\u201d')
CODE_SPAN = re.compile(r"`[^`]*`")
ELLIPSIS = re.compile(r"…|\.\.\.")
EDITORIAL = re.compile(r"\[[^\]\s]*\]")
MARKUP = re.compile(r"[`*]")


class Problem(NamedTuple):
    guide: Path
    line: int
    message: str

    def __str__(self) -> str:
        return f"{self.guide}:{self.line}: {self.message}"


def normalize(text: str) -> str:
    """Reduce text to the words a quotation has to preserve."""
    return " ".join(MARKUP.sub("", text).split()).lower().strip(" ,.;:")


def quoted_fragments(text: str) -> list[str]:
    """Return the normalized quotations in text, split around any ellipses."""
    fragments: list[str] = []
    # Spans pair up left to right, so one holding a quote can go without touching a quote holding a span.
    prose = CODE_SPAN.sub(lambda span: "" if '"' in span.group(0) else span.group(0), text)
    for match in QUOTE.finditer(prose):
        quote = match.group(1) or match.group(2)
        if len(quote.split()) < 2:
            continue
        fragments.extend(part for part in map(normalize, ELLIPSIS.split(EDITORIAL.sub("", quote))) if part)
    return fragments


def resolve(cited: str, known: dict[str, Path], plugin_root: Path, repo_root: Path) -> Path | None:
    """Find the file a citation names, preferring a bare name's latest full citation."""
    if "/" not in cited and cited in known:
        return known[cited]
    for root in (plugin_root, repo_root):
        candidate = root / cited
        if candidate.is_file():
            return candidate
    return None


def names_a_file(cited: str, known: dict[str, Path], plugin_root: Path, repo_root: Path) -> bool:
    """Tell a file citation from other backticked text with a colon and a number."""
    if "://" in cited:
        return False
    return "/" in cited or bool(SOURCE_FILE.search(cited)) or resolve(cited, known, plugin_root, repo_root) is not None


def check_quotes(cited: str, start: int, end: int, source: list[str], window: str) -> list[str]:
    """Report each quotation that does not appear on the cited lines of source."""
    messages: list[str] = []
    cited_text = normalize(" ".join(source[start - 1 : end]))
    for fragment in quoted_fragments(window):
        if fragment in cited_text:
            continue
        found = [number for number, line in enumerate(source, start=1) if fragment in normalize(line)]
        where = f"it is on line {found[0]}" if found else "it is not on any single line of the file"
        messages.append(f'`{cited}:{start}` quotes "{fragment}", but {where}')
    return messages


def check_guide(guide: Path, plugin_root: Path = PLUGIN_ROOT, repo_root: Path = REPO_ROOT) -> tuple[list[Problem], int]:
    """Check one guide and return its problems and the number of citations seen."""
    problems: list[Problem] = []
    known: dict[str, Path] = {}
    count = 0
    for number, line in enumerate(guide.read_text(encoding="utf-8").splitlines(), start=1):
        matches = list(CITATION.finditer(line))
        for index, match in enumerate(matches):
            cited = match.group(1)
            if not names_a_file(cited, known, plugin_root, repo_root):
                continue
            count += 1
            start = int(match.group(2))
            end = int(match.group(3) or start)
            path = resolve(cited, known, plugin_root, repo_root)
            if path is None:
                problems.append(Problem(guide, number, f"`{cited}` does not resolve to a file"))
                continue
            known[path.name] = path
            source = path.read_text(encoding="utf-8").splitlines()
            if not 1 <= start <= end <= len(source):
                problems.append(Problem(guide, number, f"{match.group(0)} is outside the file's {len(source)} lines"))
                continue
            stop = matches[index + 1].start() if index + 1 < len(matches) else len(line)
            for message in check_quotes(cited, start, end, source, line[match.end() : stop]):
                problems.append(Problem(guide, number, message))
    return problems, count


def default_guides(plugin_root: Path = PLUGIN_ROOT) -> list[Path]:
    return sorted((plugin_root / "docs").glob("*.md"))


def main(argv: list[str]) -> int:
    guides = [Path(argument) for argument in argv] or default_guides()
    problems: list[Problem] = []
    count = 0
    for guide in guides:
        try:
            found, seen = check_guide(guide)
        except OSError as error:
            print(f"Could not read {guide}: {error}", file=sys.stderr)
            return 2
        problems.extend(found)
        count += seen
    for problem in problems:
        print(problem, file=sys.stderr)
    print(f"Checked {count} citations in {len(guides)} guides: {len(problems)} problems.")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
