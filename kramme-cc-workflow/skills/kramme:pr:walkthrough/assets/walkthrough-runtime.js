const data = JSON.parse(
  document.getElementById("pr-walkthrough-data").textContent,
);
const requiredGraphIds = [
  "system-overview",
  "data-flow",
  "code-dependency",
  "user-action",
];
const graphs = data.graphs || [];
const graphById = new Map(graphs.map((graph) => [graph.id, graph]));
let activeGraphId =
  requiredGraphIds.find((id) => graphById.has(id)) || graphs[0]?.id;
let selectedNodeId = null;
let tourIndex = 0;
const svg = d3.select("#canvas");
const root = svg.append("g").attr("class", "viewport");
const edgeLayer = root.append("g").attr("class", "edges");
const nodeLayer = root.append("g").attr("class", "nodes");
const zoom = d3
  .zoom()
  .scaleExtent([0.25, 3.5])
  .on("zoom", (event) => {
    root.attr("transform", event.transform);
  });
svg.call(zoom);

svg
  .append("defs")
  .append("marker")
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
  return String(value ?? "").replace(
    /[&<>"']/g,
    (char) =>
      ({
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        '"': "&quot;",
        "'": "&#39;",
      })[char],
  );
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
  return /^data:(image\/(?:avif|gif|jpe?g|png|webp)|video\/(?:mp4|webm));base64,[a-z0-9+/=\s]+$/i.test(
    value,
  );
}

function isSafeAssetPath(value) {
  const text = String(value ?? "").trim();
  if (
    !text ||
    /[\u0000-\u001F\u007F]/.test(text) ||
    text.startsWith("/") ||
    text.startsWith("//")
  ) {
    return false;
  }
  if (
    hasExplicitScheme(text) ||
    text.includes("\\") ||
    !text.startsWith("assets/")
  ) {
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
  return (
    graphById.get(activeGraphId) ||
    graphs[0] || { nodes: [], edges: [], tour: [] }
  );
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
  const scale = Math.min(
    Math.abs(halfWidth / dx) || Infinity,
    Math.abs(halfHeight / dy) || Infinity,
  );
  return { x: target.x - dx * scale, y: target.y - dy * scale };
}

function updateMeta() {
  const meta = data.meta || {};
  const parts = [];
  if (meta.baseRef || meta.headRef) {
    parts.push(
      `<span>${esc(meta.baseRef || "?")}...${esc(meta.headRef || "?")}</span>`,
    );
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
      ...(node.comments || []).map(
        (comment) => `${comment.author || ""} ${comment.body || ""}`,
      ),
      ...(node.media || []).map((media) => {
        if (typeof media === "string") return media;
        return `${media.label || ""} ${media.title || ""} ${media.alt || ""} ${media.src || media.url || media.path || ""}`;
      }),
    ]
      .join(" ")
      .toLowerCase();
    return haystack.includes(query);
  };

  edgeLayer.selectAll("*").remove();
  nodeLayer.selectAll("*").remove();
  if (!nodes.length) {
    document.getElementById("detail").innerHTML =
      '<div class="empty">No nodes defined for this view.</div>';
    return;
  }

  const edges = edgeLayer
    .selectAll("g.edge")
    .data(
      graph.edges || [],
      (edge) => `${edge.source}->${edge.target}:${edge.label || ""}`,
    )
    .join("g")
    .attr("class", "edge")
    .attr("data-graph-id", graph.id)
    .attr(
      "data-edge-id",
      (edge, index) => edge.id || `${edge.source}-${edge.target}-${index}`,
    );

  edges.each(function (edge) {
    const source = byId.get(edge.source);
    const target = byId.get(edge.target);
    if (!source || !target) return;
    const end = clippedEndpoint(source, target, graph);
    const start = clippedEndpoint(target, source, graph);
    const group = d3.select(this);
    group
      .append("line")
      .attr("x1", start.x)
      .attr("y1", start.y)
      .attr("x2", end.x)
      .attr("y2", end.y)
      .attr("marker-end", "url(#arrow)");
    group
      .append("text")
      .attr("x", (start.x + end.x) / 2)
      .attr("y", (start.y + end.y) / 2 - 8)
      .attr("text-anchor", "middle")
      .text(edge.label || "");
  });

  const cards = nodeLayer
    .selectAll("g.node-card")
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

  cards.each(function (node) {
    const size = nodeSize(node, graph);
    const group = d3.select(this);
    group
      .append("rect")
      .attr("x", -size.width / 2)
      .attr("y", -size.height / 2)
      .attr("width", size.width)
      .attr("height", size.height)
      .attr("stroke", node.color || graph.color || "#77736b");
    const htmlBlock = group
      .append("foreignObject")
      .attr("x", -size.width / 2)
      .attr("y", -size.height / 2)
      .attr("width", size.width)
      .attr("height", size.height);
    htmlBlock
      .append("xhtml:div")
      .attr("class", "node-html")
      .html(
        `<strong>${esc(node.title || node.id)}</strong><p>${esc(node.summary || "")}</p>`,
      );
  });

  if (!selectedNodeId || !byId.has(selectedNodeId)) {
    const tourNodeId = activeTourStep()?.nodeId;
    selectedNodeId =
      tourNodeId && byId.has(tourNodeId) ? tourNodeId : nodes[0].id;
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
  const details = (node.details || [])
    .map((item) => `<li>${esc(item)}</li>`)
    .join("");
  const files = (node.files || [])
    .map((file) => {
      const label = esc(file.path || file.label || "file");
      return file.url
        ? `<li>${renderHref(file.url, file.path || file.label || "file")}</li>`
        : `<li><code>${label}</code></li>`;
    })
    .join("");
  const comments = (node.comments || [])
    .map(
      (comment) =>
        `<li><strong>${esc(comment.author || "comment")}</strong>: ${esc(comment.body || "")}</li>`,
    )
    .join("");
  const links = (node.links || [])
    .map((link) => `<li>${renderHref(link.url, link.label || link.url)}</li>`)
    .join("");
  const media = (node.media || [])
    .map((item) => {
      const entry = typeof item === "string" ? { src: item } : item || {};
      const source = String(entry.src || entry.url || entry.path || "");
      const rawLabel = String(
        entry.label || entry.title || entry.alt || source || "media",
      );
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
      const isImage =
        type.startsWith("image") ||
        source.startsWith("data:image/") ||
        /\.(avif|gif|jpe?g|png|svg|webp)$/i.test(source);
      const isVideo =
        type.startsWith("video") ||
        source.startsWith("data:video/") ||
        /\.(mp4|webm|mov|m4v)$/i.test(source);
      if (isImage) {
        return `<li><img src="${safeSource}" alt="${esc(entry.alt || rawLabel)}">${caption}</li>`;
      }
      if (isVideo) {
        return `<li><video controls src="${safeSource}"></video>${caption}</li>`;
      }
      return `<li><a href="${safeSource}">${label}</a></li>`;
    })
    .join("");
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
  copy.textContent = total ? step?.body || step?.summary || "" : "";
}

function selectNode(nodeId) {
  selectedNodeId = nodeId;
  const graph = activeGraph();
  const tourHit = (graph.tour || []).findIndex(
    (step) => step.nodeId === nodeId,
  );
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
  const scale = Math.min(
    box.width / (maxX - minX),
    box.height / (maxY - minY),
    1.4,
  );
  const tx = (box.width - scale * (minX + maxX)) / 2;
  const ty = (box.height - scale * (minY + maxY)) / 2;
  svg
    .transition()
    .duration(220)
    .call(zoom.transform, d3.zoomIdentity.translate(tx, ty).scale(scale));
}

function resetZoom() {
  svg.transition().duration(180).call(zoom.transform, d3.zoomIdentity);
}

document.getElementById("fit").addEventListener("click", fitToView);
document.getElementById("reset").addEventListener("click", resetZoom);
document
  .getElementById("previous-tour")
  .addEventListener("click", () => goTour(-1));
document.getElementById("next-tour").addEventListener("click", () => goTour(1));
document.getElementById("restart-tour").addEventListener("click", restartTour);
document.getElementById("search").addEventListener("input", render);
document.addEventListener("keydown", (event) => {
  if (event.target?.tagName === "INPUT" && event.key !== "Escape") return;
  if (event.key === "ArrowRight" || event.key === "n") goTour(1);
  if (event.key === "ArrowLeft" || event.key === "p") goTour(-1);
  if (event.key >= "1" && event.key <= "4")
    switchGraph(requiredGraphIds[Number(event.key) - 1]);
  if (event.key === "+" || event.key === "=")
    svg.transition().call(zoom.scaleBy, 1.2);
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
