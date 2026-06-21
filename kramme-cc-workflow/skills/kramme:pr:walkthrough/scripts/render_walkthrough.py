#!/usr/bin/env python3
"""Render a PR walkthrough JSON model into a static D3 HTML file."""

from __future__ import annotations

import argparse
import html
import json
from pathlib import Path
from typing import Any

D3_ASSET_PATH = Path(__file__).resolve().parents[1] / "assets" / "d3.v7.9.0.min.js"
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


def validate_minimum(data: dict[str, Any]) -> None:
    graphs = data.get("graphs")
    if not isinstance(graphs, list):
        raise SystemExit("walkthrough data must include a graphs array")
    graph_ids = [graph.get("id") for graph in graphs if isinstance(graph, dict)]
    if graph_ids != REQUIRED_GRAPH_IDS:
        raise SystemExit(
            "graphs must appear in this exact order: " + ", ".join(REQUIRED_GRAPH_IDS)
        )


def html_document(data: dict[str, Any], d3_js: str) -> str:
    meta = data.get("meta") if isinstance(data.get("meta"), dict) else {}
    title = str(meta.get("title") or "PR Walkthrough")
    summary = str(meta.get("summary") or "Interactive pull request walkthrough.")
    data_json = json.dumps(data, ensure_ascii=False).replace("</", "<\\/")
    return HTML_TEMPLATE.replace("__TITLE__", html.escape(title)).replace(
        "__SUMMARY__",
        html.escape(summary),
    ).replace("__D3_JS__", d3_js).replace("__DATA_JSON__", data_json)


def main() -> None:
    args = parse_args()
    data = read_data(args.data)
    validate_minimum(data)
    d3_js = read_d3_asset()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(html_document(data, d3_js), encoding="utf-8")
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
    const data = JSON.parse(document.getElementById("pr-walkthrough-data").textContent);
    const requiredGraphIds = ["system-overview", "data-flow", "code-dependency", "user-action"];
    const graphs = data.graphs || [];
    const graphById = new Map(graphs.map((graph) => [graph.id, graph]));
    let activeGraphId = requiredGraphIds.find((id) => graphById.has(id)) || graphs[0]?.id;
    let selectedNodeId = null;
    let tourIndex = 0;
    const svg = d3.select("#canvas");
    const root = svg.append("g").attr("class", "viewport");
    const edgeLayer = root.append("g").attr("class", "edges");
    const nodeLayer = root.append("g").attr("class", "nodes");
    const zoom = d3.zoom().scaleExtent([0.25, 3.5]).on("zoom", (event) => {
      root.attr("transform", event.transform);
    });
    svg.call(zoom);

    svg.append("defs").append("marker")
      .attr("id", "arrow")
      .attr("viewBox", "0 -5 10 10")
      .attr("refX", 10)
      .attr("refY", 0)
      .attr("markerWidth", 8)
      .attr("markerHeight", 8)
      .attr("orient", "auto")
      .append("path")
      .attr("d", "M0,-5L10,0L0,5")
      .attr("fill", "#77736b");

    function esc(value) {
      return String(value ?? "").replace(/[&<>"']/g, (char) => ({
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        '"': "&quot;",
        "'": "&#39;",
      })[char]);
    }

    function hasExplicitScheme(value) {
      return /^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(value);
    }

    function isSafeHref(value) {
      const text = String(value ?? "").trim();
      if (!text || /[\u0000-\u001F\u007F]/.test(text) || text.startsWith("//")) {
        return false;
      }
      if (!hasExplicitScheme(text)) {
        return true;
      }
      try {
        return ["http:", "https:", "mailto:"].includes(new URL(text).protocol);
      } catch {
        return false;
      }
    }

    function isSafeDataMediaUrl(value) {
      return /^data:(image\/(?:avif|gif|jpe?g|png|webp)|video\/(?:mp4|webm));base64,[a-z0-9+/=\s]+$/i.test(value);
    }

    function isSafeAssetPath(value) {
      const text = String(value ?? "").trim();
      if (!text || /[\u0000-\u001F\u007F]/.test(text) || text.startsWith("/") || text.startsWith("//")) {
        return false;
      }
      if (hasExplicitScheme(text) || text.includes("\\") || !text.startsWith("assets/")) {
        return false;
      }
      return !text.split("/").includes("..");
    }

    function isSafeMediaSource(value) {
      const text = String(value ?? "").trim();
      if (text.toLowerCase().startsWith("data:")) {
        return isSafeDataMediaUrl(text);
      }
      return isSafeAssetPath(text);
    }

    function renderHref(url, label) {
      const text = esc(label || url || "link");
      if (!isSafeHref(url)) {
        return `<code>${text}</code>`;
      }
      return `<a href="${esc(String(url).trim())}" rel="noreferrer noopener">${text}</a>`;
    }

    function activeGraph() {
      return graphById.get(activeGraphId) || graphs[0] || { nodes: [], edges: [], tour: [] };
    }

    function nodeMap(graph) {
      return new Map((graph.nodes || []).map((node) => [node.id, node]));
    }

    function nodeSize(node, graph) {
      const overview = graph.id === "system-overview";
      return {
        width: Number(node.width || (overview ? 340 : 230)),
        height: Number(node.height || (overview ? 170 : 120)),
      };
    }

    function clippedEndpoint(source, target, graph) {
      const size = nodeSize(target, graph);
      const dx = target.x - source.x;
      const dy = target.y - source.y;
      const halfWidth = size.width / 2;
      const halfHeight = size.height / 2;
      if (dx === 0 && dy === 0) {
        return { x: target.x, y: target.y };
      }
      const scale = Math.min(Math.abs(halfWidth / dx) || Infinity, Math.abs(halfHeight / dy) || Infinity);
      return { x: target.x - dx * scale, y: target.y - dy * scale };
    }

    function updateMeta() {
      const meta = data.meta || {};
      const parts = [];
      if (meta.baseRef || meta.headRef) {
        parts.push(`<span>${esc(meta.baseRef || "?")}...${esc(meta.headRef || "?")}</span>`);
      }
      if (meta.prUrl) {
        parts.push(renderHref(meta.prUrl, meta.prUrl));
      }
      document.getElementById("meta").innerHTML = parts.join("");
    }

    function renderTabs() {
      const tabs = document.getElementById("tabs");
      tabs.innerHTML = "";
      for (const graph of graphs) {
        const button = document.createElement("button");
        button.type = "button";
        button.textContent = graph.label || graph.id;
        button.dataset.graphId = graph.id;
        button.className = graph.id === activeGraphId ? "active" : "";
        button.addEventListener("click", () => switchGraph(graph.id));
        tabs.appendChild(button);
      }
    }

    function render() {
      const graph = activeGraph();
      const nodes = graph.nodes || [];
      const byId = nodeMap(graph);
      const query = document.getElementById("search").value.trim().toLowerCase();
      const matches = (node) => {
        if (!query) return true;
        const haystack = [
          node.title,
          node.summary,
          ...(node.details || []),
          ...(node.files || []).map((file) => file.path),
          ...(node.comments || []).map((comment) => `${comment.author || ""} ${comment.body || ""}`),
          ...(node.media || []).map((media) => {
            if (typeof media === "string") return media;
            return `${media.label || ""} ${media.title || ""} ${media.alt || ""} ${media.src || media.url || media.path || ""}`;
          }),
        ].join(" ").toLowerCase();
        return haystack.includes(query);
      };

      edgeLayer.selectAll("*").remove();
      nodeLayer.selectAll("*").remove();
      if (!nodes.length) {
        document.getElementById("detail").innerHTML = '<div class="empty">No nodes defined for this view.</div>';
        return;
      }

      const edges = edgeLayer.selectAll("g.edge")
        .data(graph.edges || [], (edge) => `${edge.source}->${edge.target}:${edge.label || ""}`)
        .join("g")
        .attr("class", "edge")
        .attr("data-graph-id", graph.id)
        .attr("data-edge-id", (edge, index) => edge.id || `${edge.source}-${edge.target}-${index}`);

      edges.each(function(edge) {
        const source = byId.get(edge.source);
        const target = byId.get(edge.target);
        if (!source || !target) return;
        const end = clippedEndpoint(source, target, graph);
        const start = clippedEndpoint(target, source, graph);
        const group = d3.select(this);
        group.append("line")
          .attr("x1", start.x)
          .attr("y1", start.y)
          .attr("x2", end.x)
          .attr("y2", end.y)
          .attr("marker-end", "url(#arrow)");
        group.append("text")
          .attr("x", (start.x + end.x) / 2)
          .attr("y", (start.y + end.y) / 2 - 8)
          .attr("text-anchor", "middle")
          .text(edge.label || "");
      });

      const cards = nodeLayer.selectAll("g.node-card")
        .data(nodes, (node) => node.id)
        .join("g")
        .attr("class", (node) => {
          const classes = ["node-card"];
          if (node.id === selectedNodeId) classes.push("active");
          if (!matches(node)) classes.push("dimmed");
          return classes.join(" ");
        })
        .attr("data-graph-id", graph.id)
        .attr("data-node-id", (node) => node.id)
        .attr("transform", (node) => `translate(${node.x || 0},${node.y || 0})`)
        .on("click", (_event, node) => selectNode(node.id));

      cards.each(function(node) {
        const size = nodeSize(node, graph);
        const group = d3.select(this);
        group.append("rect")
          .attr("x", -size.width / 2)
          .attr("y", -size.height / 2)
          .attr("width", size.width)
          .attr("height", size.height)
          .attr("stroke", node.color || graph.color || "#77736b");
        const htmlBlock = group.append("foreignObject")
          .attr("x", -size.width / 2)
          .attr("y", -size.height / 2)
          .attr("width", size.width)
          .attr("height", size.height);
        htmlBlock.append("xhtml:div")
          .attr("class", "node-html")
          .html(`<strong>${esc(node.title || node.id)}</strong><p>${esc(node.summary || "")}</p>`);
      });

      if (!selectedNodeId || !byId.has(selectedNodeId)) {
        const tourNodeId = activeTourStep()?.nodeId;
        selectedNodeId = tourNodeId && byId.has(tourNodeId) ? tourNodeId : nodes[0].id;
      }
      renderDetail();
      renderTourStatus();
    }

    function renderDetail() {
      const graph = activeGraph();
      const node = nodeMap(graph).get(selectedNodeId);
      const detail = document.getElementById("detail");
      if (!node) {
        detail.innerHTML = '<div class="empty">Select a node.</div>';
        return;
      }
      const details = (node.details || []).map((item) => `<li>${esc(item)}</li>`).join("");
      const files = (node.files || []).map((file) => {
        const label = esc(file.path || file.label || "file");
        return file.url ? `<li>${renderHref(file.url, file.path || file.label || "file")}</li>` : `<li><code>${label}</code></li>`;
      }).join("");
      const comments = (node.comments || []).map((comment) => (
        `<li><strong>${esc(comment.author || "comment")}</strong>: ${esc(comment.body || "")}</li>`
      )).join("");
      const links = (node.links || []).map((link) => (
        `<li>${renderHref(link.url, link.label || link.url)}</li>`
      )).join("");
      const media = (node.media || []).map((item) => {
        const entry = typeof item === "string" ? { src: item } : (item || {});
        const source = String(entry.src || entry.url || entry.path || "");
        const rawLabel = String(entry.label || entry.title || entry.alt || source || "media");
        const type = String(entry.type || "").toLowerCase();
        const label = esc(rawLabel);
        const caption = `<span class="media-caption">${label}</span>`;
        if (!source) {
          return `<li>${label}</li>`;
        }
        if (!isSafeMediaSource(source)) {
          return `<li>${label}</li>`;
        }
        const safeSource = esc(source);
        const isImage = type.startsWith("image") || source.startsWith("data:image/") || /\.(avif|gif|jpe?g|png|svg|webp)$/i.test(source);
        const isVideo = type.startsWith("video") || source.startsWith("data:video/") || /\.(mp4|webm|mov|m4v)$/i.test(source);
        if (isImage) {
          return `<li><img src="${safeSource}" alt="${esc(entry.alt || rawLabel)}">${caption}</li>`;
        }
        if (isVideo) {
          return `<li><video controls src="${safeSource}"></video>${caption}</li>`;
        }
        return `<li><a href="${safeSource}">${label}</a></li>`;
      }).join("");
      detail.innerHTML = `
        <h2>${esc(node.title || node.id)}</h2>
        <p>${esc(node.summary || "")}</p>
        ${details ? `<h3>Details</h3><ul>${details}</ul>` : ""}
        ${files ? `<h3>Files</h3><ul>${files}</ul>` : ""}
        ${media ? `<h3>Media</h3><ul class="media-list">${media}</ul>` : ""}
        ${comments ? `<h3>Review discussion</h3><ul>${comments}</ul>` : ""}
        ${links ? `<h3>Links</h3><ul>${links}</ul>` : ""}
      `;
    }

    function renderTourStatus() {
      const graph = activeGraph();
      const total = (graph.tour || []).length;
      const status = document.getElementById("tour-status");
      const copy = document.getElementById("tour-copy");
      const step = activeTourStep();
      status.dataset.tourIndex = String(tourIndex);
      status.textContent = total ? `Step ${tourIndex + 1} / ${total}` : "No tour";
      copy.textContent = total ? (step?.body || step?.summary || "") : "";
    }

    function selectNode(nodeId) {
      selectedNodeId = nodeId;
      const graph = activeGraph();
      const tourHit = (graph.tour || []).findIndex((step) => step.nodeId === nodeId);
      if (tourHit >= 0) {
        tourIndex = tourHit;
      }
      render();
    }

    function switchGraph(graphId) {
      activeGraphId = graphId;
      selectedNodeId = null;
      tourIndex = 0;
      renderTabs();
      render();
      fitToView();
    }

    function activeTourStep() {
      const graph = activeGraph();
      return (graph.tour || [])[tourIndex];
    }

    function goTour(delta) {
      const graph = activeGraph();
      const total = (graph.tour || []).length;
      if (!total) return;
      tourIndex = (tourIndex + delta + total) % total;
      const step = activeTourStep();
      if (step?.nodeId) {
        selectedNodeId = step.nodeId;
      }
      render();
    }

    function restartTour() {
      tourIndex = 0;
      const step = activeTourStep();
      if (step?.nodeId) {
        selectedNodeId = step.nodeId;
      }
      render();
    }

    function fitToView() {
      const graph = activeGraph();
      const nodes = graph.nodes || [];
      if (!nodes.length) return;
      const box = svg.node().getBoundingClientRect();
      const xs = nodes.map((node) => node.x || 0);
      const ys = nodes.map((node) => node.y || 0);
      const minX = Math.min(...xs) - 260;
      const maxX = Math.max(...xs) + 260;
      const minY = Math.min(...ys) - 180;
      const maxY = Math.max(...ys) + 180;
      const scale = Math.min(box.width / (maxX - minX), box.height / (maxY - minY), 1.4);
      const tx = (box.width - scale * (minX + maxX)) / 2;
      const ty = (box.height - scale * (minY + maxY)) / 2;
      svg.transition().duration(220).call(zoom.transform, d3.zoomIdentity.translate(tx, ty).scale(scale));
    }

    function resetZoom() {
      svg.transition().duration(180).call(zoom.transform, d3.zoomIdentity);
    }

    document.getElementById("fit").addEventListener("click", fitToView);
    document.getElementById("reset").addEventListener("click", resetZoom);
    document.getElementById("previous-tour").addEventListener("click", () => goTour(-1));
    document.getElementById("next-tour").addEventListener("click", () => goTour(1));
    document.getElementById("restart-tour").addEventListener("click", restartTour);
    document.getElementById("search").addEventListener("input", render);
    document.addEventListener("keydown", (event) => {
      if (event.target?.tagName === "INPUT" && event.key !== "Escape") return;
      if (event.key === "ArrowRight" || event.key === "n") goTour(1);
      if (event.key === "ArrowLeft" || event.key === "p") goTour(-1);
      if (event.key >= "1" && event.key <= "4") switchGraph(requiredGraphIds[Number(event.key) - 1]);
      if (event.key === "+" || event.key === "=") svg.transition().call(zoom.scaleBy, 1.2);
      if (event.key === "-") svg.transition().call(zoom.scaleBy, 0.8);
      if (event.key === "0") resetZoom();
      if (event.key === "f") fitToView();
      if (event.key === "/") {
        event.preventDefault();
        document.getElementById("search").focus();
      }
      if (event.key === "Escape") {
        document.getElementById("search").value = "";
        render();
      }
    });

    updateMeta();
    renderTabs();
    render();
    requestAnimationFrame(fitToView);
  </script>
</body>
</html>
"""


if __name__ == "__main__":
    main()
