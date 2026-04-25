#!/usr/bin/env python3
"""Normalize a fetched source (HTML or markdown) for stable snapshot + hash.

Usage:
    cat fetched.html | normalize.py --type html > snapshot.md
    cat fetched.md   | normalize.py --type markdown > snapshot.md

The sha256 hash of the normalized output is written to stderr as:
    sha256:<hex>

Stdlib only — no third-party dependencies. Rules: see references/normalization-rules.md.
"""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
from html.parser import HTMLParser
from typing import Optional
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

STRIP_TAGS = {"script", "style", "noscript", "iframe", "svg", "form", "input", "button", "select"}
STRUCTURAL_DROP_TAGS = {"nav", "header", "footer", "aside"}
VOID_TAGS = {
    "area",
    "base",
    "br",
    "col",
    "embed",
    "hr",
    "img",
    "input",
    "link",
    "meta",
    "param",
    "source",
    "track",
    "wbr",
}
DROP_ATTR_PATTERN = re.compile(
    r"(^|[\s_-])(nav|navigation|sidebar|topbar|header|footer|cookie|banner|breadcrumb|menu|toc-fixed)($|[\s_-])",
    re.IGNORECASE,
)
HEADING_TAGS = {f"h{i}": "#" * i for i in range(1, 7)}
BLOCK_TAGS = {"p", "div", "section", "article", "main", "li", "tr", "blockquote"}
LIST_TAGS = {"ul", "ol"}
PRE_TAGS = {"pre"}
CODE_TAGS = {"code"}
TABLE_TAGS = {"table"}


class _Normalizer(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self._out: list[str] = []
        self._skip_depth = 0
        self._heading_prefix: Optional[str] = None
        self._in_pre = False
        self._in_code = False
        self._link_href: Optional[str] = None
        self._link_text_buf: list[str] = []
        self._collecting_link = False
        self._list_stack: list[str] = []
        self._li_pending = False

    # --- helpers ---

    def _attr_value(self, attrs: list[tuple[str, Optional[str]]], attr_name: str) -> str:
        for name, value in attrs:
            if name == attr_name and value:
                return value
        return ""

    def _attr_alt(self, attrs: list[tuple[str, Optional[str]]]) -> str:
        for name, value in attrs:
            if name == "alt" and value:
                return value
        return ""

    def _attr_href(self, attrs: list[tuple[str, Optional[str]]]) -> Optional[str]:
        for name, value in attrs:
            if name == "href" and value:
                return value
        return None

    def _emit(self, text: str) -> None:
        if self._collecting_link:
            self._link_text_buf.append(text)
        else:
            self._out.append(text)

    # --- HTMLParser interface ---

    def handle_starttag(self, tag: str, attrs: list[tuple[str, Optional[str]]]) -> None:
        if self._skip_depth:
            if tag not in VOID_TAGS:
                self._skip_depth += 1
            return

        if tag in STRIP_TAGS:
            if tag not in VOID_TAGS:
                self._skip_depth = 1
            return

        if tag in STRUCTURAL_DROP_TAGS:
            self._skip_depth = 1
            return

        cls = self._attr_value(attrs, "class")
        elem_id = self._attr_value(attrs, "id")
        if (cls and DROP_ATTR_PATTERN.search(cls)) or (elem_id and DROP_ATTR_PATTERN.search(elem_id)):
            if tag not in VOID_TAGS:
                self._skip_depth = 1
            return

        if tag in HEADING_TAGS:
            self._out.append("\n\n")
            self._heading_prefix = HEADING_TAGS[tag]
            self._out.append(self._heading_prefix + " ")
            return

        if tag in PRE_TAGS:
            self._in_pre = True
            self._out.append("\n\n```\n")
            return

        if tag in CODE_TAGS and not self._in_pre:
            self._in_code = True
            self._emit("`")
            return

        if tag == "br":
            self._emit("\n")
            return

        if tag == "hr":
            self._out.append("\n\n---\n")
            return

        if tag == "img":
            alt = self._attr_alt(attrs)
            self._emit(f"[image: {alt}]" if alt else "[image]")
            return

        if tag == "a":
            href = self._attr_href(attrs)
            if href:
                self._link_href = _normalize_url(href)
                self._link_text_buf = []
                self._collecting_link = True
            return

        if tag in LIST_TAGS:
            self._list_stack.append("ol" if tag == "ol" else "ul")
            self._out.append("\n")
            return

        if tag == "li":
            self._out.append("\n")
            marker = "- " if (not self._list_stack or self._list_stack[-1] == "ul") else "1. "
            self._out.append(marker)
            self._li_pending = True
            return

        if tag in BLOCK_TAGS:
            self._out.append("\n\n")
            return

        if tag in TABLE_TAGS:
            self._out.append("\n\n")
            return

        if tag in {"th", "td"}:
            self._out.append("| ")
            return

    def handle_startendtag(self, tag: str, attrs: list[tuple[str, Optional[str]]]) -> None:
        self.handle_starttag(tag, attrs)
        if tag not in VOID_TAGS:
            self.handle_endtag(tag)

    def handle_endtag(self, tag: str) -> None:
        if self._skip_depth:
            if tag not in VOID_TAGS:
                self._skip_depth -= 1
            return

        if tag in HEADING_TAGS:
            self._out.append("\n")
            self._heading_prefix = None
            return

        if tag in PRE_TAGS:
            self._in_pre = False
            self._out.append("\n```\n")
            return

        if tag in CODE_TAGS and not self._in_pre:
            self._in_code = False
            self._emit("`")
            return

        if tag == "a" and self._collecting_link:
            text = "".join(self._link_text_buf).strip() or self._link_href or ""
            href = self._link_href or ""
            self._out.append(f"[{text}]({href})")
            self._collecting_link = False
            self._link_href = None
            self._link_text_buf = []
            return

        if tag in LIST_TAGS and self._list_stack:
            self._list_stack.pop()
            return

        if tag in {"th", "td"}:
            self._out.append(" ")
            return

        if tag == "tr":
            self._out.append(" |\n")
            return

    def handle_data(self, data: str) -> None:
        if self._skip_depth:
            return
        if self._in_pre:
            self._out.append(data)
            return
        text = data
        if not self._li_pending:
            text = re.sub(r"\s+", " ", text)
        else:
            text = re.sub(r"\s+", " ", text).lstrip()
            self._li_pending = False
        self._emit(text)


_TRACKING_PARAM_NAMES = {"ref", "fbclid", "gclid", "mc_eid", "mc_cid"}


def _is_tracking_param(name: str) -> bool:
    normalized = name.lower()
    return normalized.startswith("utm_") or normalized in _TRACKING_PARAM_NAMES


def _normalize_url(url: str) -> str:
    parsed = urlsplit(url)
    query = urlencode(
        [(key, value) for key, value in parse_qsl(parsed.query, keep_blank_values=True) if not _is_tracking_param(key)],
        doseq=True,
    )
    scheme = parsed.scheme.lower() if parsed.scheme.lower() in {"http", "https"} else parsed.scheme
    netloc = parsed.netloc.lower() if scheme in {"http", "https"} else parsed.netloc
    return urlunsplit((scheme, netloc, parsed.path, query, parsed.fragment))


_MARKDOWN_LINK_RE = re.compile(r"(?<!!)\[([^\]\n]+)\]\(([^)\s]+)(\s+(?:\"[^\"]*\"|'[^']*'|\([^)]+\)))?\)")


def _normalize_markdown_links(text: str) -> str:
    def replace(match: re.Match[str]) -> str:
        label = match.group(1)
        url = _normalize_url(match.group(2))
        title = match.group(3) or ""
        return f"[{label}]({url}{title})"

    return _MARKDOWN_LINK_RE.sub(replace, text)


_VOLATILE_LINE_PATTERNS = [
    re.compile(r"^\s*Build\s+[a-f0-9]{6,}\s*$", re.IGNORECASE),
    re.compile(r"^\s*Generated on\s+\d{4}-\d{2}-\d{2}(\s+\d{2}:\d{2})?\s*$", re.IGNORECASE),
    re.compile(r"^\s*v\d+\.\d+\.\d+(-\w+)?\s*$"),
    re.compile(r"^\s*Last updated\s*:?.*$", re.IGNORECASE),
    re.compile(r"^\s*Views?\s*:?\s*\d[\d,]*\s*$", re.IGNORECASE),
]
_COPYRIGHT_RE = re.compile(r"(Copyright|©)\s*(\d{4})", re.IGNORECASE)


def _final_normalize(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    lines = text.split("\n")

    cleaned: list[str] = []
    for line in lines:
        stripped = line.rstrip()
        if any(p.match(stripped) for p in _VOLATILE_LINE_PATTERNS):
            continue
        stripped = _COPYRIGHT_RE.sub(r"\1 YEAR", stripped)
        cleaned.append(stripped)

    text = "\n".join(cleaned)
    text = re.sub(r"\n{3,}", "\n\n", text)
    text = text.strip("\n") + "\n"
    return text


def normalize_html(raw: str) -> str:
    parser = _Normalizer()
    parser.feed(raw)
    parser.close()
    return _final_normalize("".join(parser._out))


def normalize_markdown(raw: str) -> str:
    return _final_normalize(_normalize_markdown_links(raw))


def main() -> int:
    ap = argparse.ArgumentParser(description="Normalize fetched source for stable snapshot + hash.")
    ap.add_argument("--type", choices=("html", "markdown"), default="html")
    args = ap.parse_args()

    raw = sys.stdin.read()
    normalized = normalize_html(raw) if args.type == "html" else normalize_markdown(raw)

    sys.stdout.write(normalized)
    digest = hashlib.sha256(normalized.encode("utf-8")).hexdigest()
    sys.stderr.write(f"sha256:{digest}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
