#!/usr/bin/env python3
"""Static validation for a generated PR walkthrough HTML file."""

from __future__ import annotations

import argparse
import json
import re
import sys
from html.parser import HTMLParser
from pathlib import Path
from pathlib import PurePosixPath
from typing import Any

REQUIRED_GRAPH_IDS = ["system-overview", "data-flow", "code-dependency", "user-action"]
REQUIRED_LABELS = [
    "Fit to view",
    "Reset zoom",
    "System overview",
    "Data flow",
    "Code dependency",
    "User action",
    "Previous tour step",
    "Next tour step",
    "Restart tour",
]
D3_VENDOR_SCRIPT_ID = "d3-vendor"
EXPLICIT_SCHEME_RE = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*:")
SAFE_HREF_SCHEMES = {"http", "https", "mailto"}
SAFE_DATA_MEDIA_RE = re.compile(
    r"^data:(image/(?:avif|gif|jpe?g|png|webp)|video/(?:mp4|webm));base64,[a-z0-9+/=\s]+$",
    re.IGNORECASE,
)


class WalkthroughParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.in_data_script = False
        self.in_runtime_script = False
        self.data_script = ""
        self.runtime_scripts: list[str] = []
        self._runtime_script_chunks: list[str] = []
        self.script_srcs: list[str] = []
        self.has_d3_vendor_script = False
        self.in_vendor_script = False

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attr_map = dict(attrs)
        if tag == "script":
            if attr_map.get("id") == "pr-walkthrough-data":
                self.in_data_script = True
            elif (
                attr_map.get("id") == D3_VENDOR_SCRIPT_ID
                and attr_map.get("data-vendor") == "d3"
                and not attr_map.get("src")
            ):
                self.has_d3_vendor_script = True
                self.in_vendor_script = True
            elif attr_map.get("src"):
                self.script_srcs.append(attr_map["src"] or "")
            else:
                self.in_runtime_script = True
                self._runtime_script_chunks = []

    def handle_endtag(self, tag: str) -> None:
        if tag == "script" and self.in_data_script:
            self.in_data_script = False
        elif tag == "script" and self.in_vendor_script:
            self.in_vendor_script = False
        elif tag == "script" and self.in_runtime_script:
            self.runtime_scripts.append("".join(self._runtime_script_chunks))
            self.in_runtime_script = False
            self._runtime_script_chunks = []

    def handle_data(self, data: str) -> None:
        if self.in_data_script:
            self.data_script += data
        elif self.in_runtime_script:
            self._runtime_script_chunks.append(data)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--html", required=True, type=Path, help="Generated walkthrough HTML file.")
    return parser.parse_args()


def load_html(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError as exc:
        raise SystemExit(f"{path}: cannot read file: {exc}") from exc


def parse_embedded_data(
    html_text: str,
) -> tuple[dict[str, Any] | None, list[str], list[str], list[str]]:
    parser = WalkthroughParser()
    parser.feed(html_text)
    errors = []
    if parser.script_srcs:
        errors.append("HTML must not load external scripts")
    if not parser.has_d3_vendor_script:
        errors.append(f"missing vendored D3 inline script with id {D3_VENDOR_SCRIPT_ID}")
    if not parser.data_script.strip():
        errors.append("missing embedded JSON script with id pr-walkthrough-data")
        return None, errors, parser.runtime_scripts, parser.script_srcs
    try:
        data = json.loads(parser.data_script)
    except json.JSONDecodeError as exc:
        errors.append(f"embedded walkthrough JSON is invalid: {exc}")
        return None, errors, parser.runtime_scripts, parser.script_srcs
    if not isinstance(data, dict):
        errors.append("embedded walkthrough JSON must be an object")
        return None, errors, parser.runtime_scripts, parser.script_srcs
    return data, errors, parser.runtime_scripts, parser.script_srcs


def node_text(node: dict[str, Any]) -> str:
    pieces: list[str] = []
    for key in ("title", "summary"):
        value = node.get(key)
        if value:
            pieces.append(str(value))
    details = node.get("details")
    if isinstance(details, list):
        pieces.extend(str(item) for item in details if item)
    return " ".join(pieces).strip()


def has_control_chars(value: str) -> bool:
    return any(ord(char) < 32 or ord(char) == 127 for char in value)


def has_explicit_scheme(value: str) -> bool:
    return bool(EXPLICIT_SCHEME_RE.match(value))


def is_safe_href(value: Any) -> bool:
    text = str(value or "").strip()
    if not text or has_control_chars(text) or text.startswith("//"):
        return False
    if not has_explicit_scheme(text):
        return True
    scheme = text.split(":", 1)[0].lower()
    return scheme in SAFE_HREF_SCHEMES


def is_safe_data_media_url(value: str) -> bool:
    return bool(SAFE_DATA_MEDIA_RE.match(value))


def is_safe_asset_path(value: Any) -> bool:
    text = str(value or "").strip()
    if (
        not text
        or has_control_chars(text)
        or text.startswith("/")
        or text.startswith("//")
        or "\\" in text
        or has_explicit_scheme(text)
        or not text.startswith("assets/")
    ):
        return False
    return ".." not in PurePosixPath(text).parts


def is_safe_media_source(value: Any) -> bool:
    text = str(value or "").strip()
    if text.lower().startswith("data:"):
        return is_safe_data_media_url(text)
    return is_safe_asset_path(text)


def media_source(media: Any) -> Any:
    if isinstance(media, str):
        return media
    if isinstance(media, dict):
        return media.get("src") or media.get("url") or media.get("path")
    return None


def validate_node_urls(graph_id: Any, node_id: Any, node: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    for index, file_entry in enumerate(node.get("files") or []):
        if isinstance(file_entry, dict) and file_entry.get("url") and not is_safe_href(file_entry["url"]):
            errors.append(f"{graph_id}/{node_id}: file {index} uses an unsafe URL")
    for index, link in enumerate(node.get("links") or []):
        if isinstance(link, dict) and link.get("url") and not is_safe_href(link["url"]):
            errors.append(f"{graph_id}/{node_id}: link {index} uses an unsafe URL")
    for index, media in enumerate(node.get("media") or []):
        source = media_source(media)
        if source and not is_safe_media_source(source):
            errors.append(f"{graph_id}/{node_id}: media {index} uses an unsafe source URL")
    return errors


def validate_data(data: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    meta = data.get("meta")
    if isinstance(meta, dict) and meta.get("prUrl") and not is_safe_href(meta["prUrl"]):
        errors.append("meta.prUrl uses an unsafe URL")
    graphs = data.get("graphs")
    if not isinstance(graphs, list):
        return ["walkthrough data must include a graphs array"]
    graph_ids = [graph.get("id") for graph in graphs if isinstance(graph, dict)]
    if graph_ids != REQUIRED_GRAPH_IDS:
        errors.append("graphs must appear in exact order: " + ", ".join(REQUIRED_GRAPH_IDS))
    for graph in graphs:
        if not isinstance(graph, dict):
            errors.append("each graph must be an object")
            continue
        graph_id = graph.get("id", "<missing>")
        nodes = graph.get("nodes")
        edges = graph.get("edges")
        tour = graph.get("tour")
        if not isinstance(nodes, list) or not nodes:
            errors.append(f"{graph_id}: nodes must be a non-empty array")
            continue
        if not isinstance(edges, list):
            errors.append(f"{graph_id}: edges must be an array")
            edges = []
        if graph_id != "system-overview" and not edges:
            errors.append(f"{graph_id}: non-overview graph must include directed edges")
        if not isinstance(tour, list) or not tour:
            errors.append(f"{graph_id}: tour must be a non-empty array")
            tour = []
        node_ids: set[Any] = set()
        for node in nodes:
            if not isinstance(node, dict):
                errors.append(f"{graph_id}: every node must be an object")
                continue
            node_id = node.get("id", "<missing>")
            if not node.get("id"):
                errors.append(f"{graph_id}: node missing id")
            elif node_id in node_ids:
                errors.append(f"{graph_id}: duplicate node id {node_id}")
            else:
                node_ids.add(node_id)
            if not node.get("title"):
                errors.append(f"{graph_id}/{node_id}: node missing title")
            if not node_text(node):
                errors.append(f"{graph_id}/{node_id}: node needs explanatory text")
            if not isinstance(node.get("x"), (int, float)) or not isinstance(
                node.get("y"), (int, float)
            ):
                errors.append(f"{graph_id}/{node_id}: node needs numeric x and y coordinates")
            if graph_id == "system-overview":
                for key in ("files", "comments", "media"):
                    if node.get(key):
                        errors.append(f"{graph_id}/{node_id}: overview nodes must not attach {key}")
            errors.extend(validate_node_urls(graph_id, node_id, node))
        for edge in edges:
            if not isinstance(edge, dict):
                errors.append(f"{graph_id}: every edge must be an object")
                continue
            if edge.get("source") not in node_ids:
                errors.append(f"{graph_id}: edge source does not match a node: {edge.get('source')}")
            if edge.get("target") not in node_ids:
                errors.append(f"{graph_id}: edge target does not match a node: {edge.get('target')}")
            if graph_id != "system-overview" and not edge.get("label"):
                errors.append(f"{graph_id}: directed edge needs a relationship label")
        for index, step in enumerate(tour):
            if not isinstance(step, dict):
                errors.append(f"{graph_id}: tour step {index} must be an object")
                continue
            if step.get("nodeId") not in node_ids:
                errors.append(f"{graph_id}: tour step {index} points at missing node {step.get('nodeId')}")
            if not step.get("body") and not step.get("summary"):
                errors.append(f"{graph_id}: tour step {index} needs explanatory text")
    return errors


def validate_html_surface(
    html_text: str, runtime_scripts: list[str], script_srcs: list[str]
) -> list[str]:
    errors = []
    runtime_surface = "\n".join([*runtime_scripts, *script_srcs])
    if re.search(r"\bfetch\s*\(", runtime_surface):
        errors.append("HTML must not use fetch() for local data loading")
    if "@latest" in runtime_surface or "/latest/" in runtime_surface:
        errors.append("HTML must not reference latest package versions")
    for label in REQUIRED_LABELS:
        if label not in html_text:
            errors.append(f"missing required control label: {label}")
    for attr in ("data-graph-id", "data-node-id", "data-edge-id", "data-tour-index"):
        if attr not in html_text:
            errors.append(f"missing stable renderer attribute: {attr}")
    return errors


def main() -> None:
    args = parse_args()
    html_text = load_html(args.html)
    data, errors, runtime_scripts, script_srcs = parse_embedded_data(html_text)
    errors.extend(validate_html_surface(html_text, runtime_scripts, script_srcs))
    if data is not None:
        errors.extend(validate_data(data))
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(1)
    print(f"OK: {args.html}")


if __name__ == "__main__":
    main()
