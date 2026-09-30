#!/usr/bin/env python3
"""Render a PR walkthrough JSON model into a static D3 HTML file."""

from __future__ import annotations

import argparse
import html
import json
import textwrap
from pathlib import Path
from typing import Any

D3_ASSET_PATH = Path(__file__).resolve().parents[1] / "assets" / "d3.v7.9.0.min.js"
RUNTIME_ASSET_PATH = (
    Path(__file__).resolve().parents[1] / "assets" / "walkthrough-runtime.js"
)
REQUIRED_GRAPH_IDS = ["system-overview", "data-flow", "code-dependency", "user-action"]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", required=True, type=Path, help="Path to walkthrough graph JSON.")
    parser.add_argument(
        "--output",
        default=Path(".context/pr-walkthrough/index.html"),
        type=Path,
        help="Output HTML path.",
    )
    return parser.parse_args()


def read_data(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"{path}: invalid JSON: {exc}") from exc
    if not isinstance(data, dict):
        raise SystemExit(f"{path}: top-level value must be an object")
    return data


def read_d3_asset() -> str:
    try:
        return D3_ASSET_PATH.read_text(encoding="utf-8").replace("</", "<\\/")
    except OSError as exc:
        raise SystemExit(f"{D3_ASSET_PATH}: cannot read vendored D3 asset: {exc}") from exc


def read_runtime_asset() -> str:
    try:
        source = RUNTIME_ASSET_PATH.read_text(encoding="utf-8").rstrip("\n")
    except OSError as exc:
        raise SystemExit(
            f"{RUNTIME_ASSET_PATH}: cannot read walkthrough runtime: {exc}"
        ) from exc
    return textwrap.indent(source, "    ").replace("</script", "<\\/script")


def validate_minimum(data: dict[str, Any]) -> None:
    graphs = data.get("graphs")
    if not isinstance(graphs, list):
        raise SystemExit("walkthrough data must include a graphs array")
    graph_ids = [graph.get("id") for graph in graphs if isinstance(graph, dict)]
    if graph_ids != REQUIRED_GRAPH_IDS:
        raise SystemExit(
            "graphs must appear in this exact order: " + ", ".join(REQUIRED_GRAPH_IDS)
        )


def html_document(data: dict[str, Any], d3_js: str, runtime_js: str) -> str:
    meta_value = data.get("meta")
    meta: dict[str, Any] = meta_value if isinstance(meta_value, dict) else {}
    title = str(meta.get("title") or "PR Walkthrough")
    summary = str(meta.get("summary") or "Interactive pull request walkthrough.")
    data_json = json.dumps(data, ensure_ascii=False).replace("</", "<\\/")
    return (
        HTML_TEMPLATE.replace("__RUNTIME_JS__", runtime_js)
        .replace("__TITLE__", html.escape(title))
        .replace(
            "__SUMMARY__",
            html.escape(summary),
        )
        .replace("__D3_JS__", d3_js)
        .replace("__DATA_JSON__", data_json)
    )


def main() -> None:
    args = parse_args()
    data = read_data(args.data)
    validate_minimum(data)
    d3_js = read_d3_asset()
    runtime_js = read_runtime_asset()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(html_document(data, d3_js, runtime_js), encoding="utf-8")
    print(args.output.resolve())


HTML_TEMPLATE = r"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>__TITLE__</title>
  <style>
    :root {
      --bg: #121212;
      --panel: #1e1e1d;
      --panel-2: #292929;
      --border: #3a3a38;
      --text: #faf9f6;
      --muted: #b7b2aa;
      --pink: #a43787;
      --yellow: #c0872a;
      --green: #34895c;
      --blue: #2e5d9e;
      --purple: #754dac;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      min-height: 100vh;
      background: var(--bg);
      color: var(--text);
      font-family: "DM Sans", Matter, system-ui, sans-serif;
      letter-spacing: 0;
    }
    button, input {
      font: inherit;
    }
    button {
      border: 1px solid var(--border);
      background: var(--panel-2);
      color: var(--text);
      border-radius: 6px;
      padding: 8px 10px;
      cursor: pointer;
    }
    button:hover, button:focus-visible {
      border-color: var(--pink);
      outline: none;
    }
    button.active {
      background: var(--pink);
      border-color: var(--pink);
    }
    .shell {
      display: grid;
      grid-template-columns: minmax(0, 1fr) 360px;
      min-height: 100vh;
    }
    header {
      padding: 20px 24px 14px;
      border-bottom: 1px solid var(--border);
      background: #171716;
    }
    h1 {
      margin: 0;
      font-size: 24px;
      line-height: 1.2;
    }
    .summary {
      margin: 8px 0 0;
      max-width: 900px;
      color: var(--muted);
      line-height: 1.45;
    }
    .meta {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      margin-top: 14px;
      color: var(--muted);
      font-family: "Roboto Mono", ui-monospace, monospace;
      font-size: 12px;
    }
    .meta a { color: var(--text); }
    .tabs, .toolbar, .tourbar {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 8px;
      padding: 10px 24px;
      border-bottom: 1px solid var(--border);
      background: var(--panel);
    }
    .tour-copy {
      flex: 1;
      min-width: 260px;
      color: var(--muted);
      line-height: 1.4;
    }
    .toolbar input {
      min-width: 260px;
      flex: 1;
      border: 1px solid var(--border);
      background: #121212;
      color: var(--text);
      border-radius: 6px;
      padding: 8px 10px;
    }
    .stage {
      display: grid;
      grid-template-rows: auto auto auto minmax(0, 1fr);
      min-width: 0;
      min-height: 100vh;
    }
    .canvas-wrap {
      min-height: 520px;
      height: calc(100vh - 210px);
      background: #141413;
      overflow: hidden;
    }
    svg {
      width: 100%;
      height: 100%;
      display: block;
    }
    .detail {
      border-left: 1px solid var(--border);
      background: var(--panel);
      padding: 20px;
      overflow: auto;
    }
    .detail h2 { margin: 0 0 10px; font-size: 18px; }
    .detail p, .detail li { color: var(--muted); line-height: 1.45; }
    .detail a { color: #f2b3de; }
    .detail code {
      font-family: "Roboto Mono", ui-monospace, monospace;
      font-size: 12px;
      color: var(--text);
    }
    .media-list {
      display: flex;
      flex-direction: column;
      gap: 12px;
      padding: 0;
      list-style: none;
    }
    .media-list img,
    .media-list video {
      display: block;
      width: 100%;
      max-height: 280px;
      object-fit: contain;
      border: 1px solid var(--border);
      border-radius: 6px;
      background: #121212;
    }
    .media-caption {
      display: block;
      margin-top: 6px;
      color: var(--muted);
      font-size: 12px;
      line-height: 1.35;
    }
    .node-card rect {
      fill: #20201f;
      stroke: var(--border);
      stroke-width: 1.25;
      rx: 8;
    }
    .node-card.active rect {
      stroke: var(--pink);
      stroke-width: 3;
    }
    .node-card.dimmed {
      opacity: 0.24;
    }
    .node-html {
      color: var(--text);
      overflow: hidden;
      padding: 12px;
      font-size: 13px;
      line-height: 1.35;
    }
    .node-html strong {
      display: block;
      margin-bottom: 6px;
      font-size: 14px;
      line-height: 1.2;
    }
    .node-html p {
      margin: 0;
      color: var(--muted);
    }
    .edge line {
      stroke: #77736b;
      stroke-width: 1.6;
    }
    .edge text {
      fill: var(--muted);
      font-size: 12px;
      font-family: "Roboto Mono", ui-monospace, monospace;
    }
    .edge.dimmed {
      opacity: 0.2;
    }
    .empty {
      padding: 32px;
      color: var(--muted);
    }
    @media (max-width: 960px) {
      .shell {
        grid-template-columns: 1fr;
      }
      .detail {
        border-left: 0;
        border-top: 1px solid var(--border);
        max-height: 42vh;
      }
      .canvas-wrap {
        height: 62vh;
      }
    }
  </style>
</head>
<body>
  <script id="pr-walkthrough-data" type="application/json">__DATA_JSON__</script>
  <div class="shell">
    <main class="stage">
      <header>
        <h1 id="page-title">__TITLE__</h1>
        <p class="summary" id="page-summary">__SUMMARY__</p>
        <div class="meta" id="meta"></div>
      </header>
      <nav class="tabs" id="tabs" aria-label="Walkthrough views"></nav>
      <div class="toolbar">
        <button type="button" id="fit">Fit to view</button>
        <button type="button" id="reset">Reset zoom</button>
        <input id="search" type="search" placeholder="Search nodes, files, comments">
      </div>
      <div class="tourbar">
        <button type="button" id="previous-tour">Previous tour step</button>
        <button type="button" id="next-tour">Next tour step</button>
        <button type="button" id="restart-tour">Restart tour</button>
        <span id="tour-status" data-tour-index="0"></span>
        <span id="tour-copy" class="tour-copy"></span>
      </div>
      <section class="canvas-wrap" aria-label="D3 walkthrough canvas">
        <svg id="canvas" role="img"></svg>
      </section>
    </main>
    <aside class="detail" id="detail" aria-live="polite"></aside>
  </div>
  <script id="d3-vendor" data-vendor="d3">__D3_JS__</script>
  <script id="pr-walkthrough-runtime">
__RUNTIME_JS__
  </script>
</body>
</html>
"""


if __name__ == "__main__":
    main()
