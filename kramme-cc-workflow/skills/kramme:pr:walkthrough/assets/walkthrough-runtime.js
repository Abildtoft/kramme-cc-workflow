/** @typedef {import("./walkthrough-types").Graph} Graph */
/** @typedef {import("./walkthrough-types").GraphNode} GraphNode */

/**
 * @template {Element} E
 * @param {string} id
 * @param {{new (...args: never[]): E}} elementType
 * @returns {E}
 */
function requiredElement(id, elementType) {
  const element = document.getElementById(id);
  if (!(element instanceof elementType)) {
    throw new Error(`Missing or invalid walkthrough element: ${id}`);
  }
  return element;
}

/** @param {unknown} value @returns {value is Record<string, unknown>} */
function isRecord(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/** @param {unknown} value @param {(entry: unknown) => boolean} check */
function optionalArray(value, check) {
  return value === undefined || (Array.isArray(value) && value.every(check));
}

/** @param {unknown} value @returns {value is GraphNode} */
function isGraphNode(value) {
  return (
    isRecord(value) &&
    typeof value.id === "string" &&
    ["x", "y"].every(
      (key) => value[key] === undefined || typeof value[key] === "number",
    ) &&
    (value.details === undefined || Array.isArray(value.details)) &&
    optionalArray(value.files, isRecord) &&
    optionalArray(value.comments, isRecord) &&
    optionalArray(value.links, isRecord) &&
    optionalArray(
      value.media,
      (item) => typeof item === "string" || isRecord(item),
    )
  );
}

/** @param {unknown} value @returns {value is Graph} */
function isGraph(value) {
  return (
    isRecord(value) &&
    typeof value.id === "string" &&
    optionalArray(value.nodes, isGraphNode) &&
    optionalArray(
      value.edges,
      (edge) =>
        isRecord(edge) &&
        typeof edge.source === "string" &&
        typeof edge.target === "string",
    ) &&
    optionalArray(
      value.tour,
      (step) =>
        isRecord(step) &&
        (step.nodeId === undefined || typeof step.nodeId === "string"),
    )
  );
}

/** @param {unknown} value @returns {value is import("./walkthrough-types").WalkthroughData} */
function isWalkthroughData(value) {
  return (
    isRecord(value) &&
    (value.meta === undefined || value.meta === null || isRecord(value.meta)) &&
    optionalArray(value.graphs, isGraph)
  );
}

/** @type {unknown} */
const parsedData = JSON.parse(
  requiredElement("pr-walkthrough-data", HTMLScriptElement).textContent || "",
);
if (!isWalkthroughData(parsedData)) {
  throw new Error("Invalid walkthrough data");
}
const data = parsedData;
const search = requiredElement("search", HTMLInputElement);
const canvas = requiredElement("canvas", SVGSVGElement);
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
/** @type {string | null} */
let selectedNodeId = null;
let tourIndex = 0;
const svg = d3.select(canvas);
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

/** @param {unknown} value */
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
      })[char] || char,
  );
}

/** @param {string} value */
function hasExplicitScheme(value) {
  return /^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(value);
}

/** @param {unknown} value */
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

/** @param {string} value */
function isSafeDataMediaUrl(value) {
  return /^data:(image\/(?:avif|gif|jpe?g|png|webp)|video\/(?:mp4|webm));base64,[a-z0-9+/=\s]+$/i.test(
    value,
  );
}

/** @param {unknown} value */
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

/** @param {unknown} value */
function isSafeMediaSource(value) {
  const text = String(value ?? "").trim();
  if (text.toLowerCase().startsWith("data:")) {
    return isSafeDataMediaUrl(text);
  }
  return isSafeAssetPath(text);
}

/** @param {unknown} url @param {unknown} label */
function renderHref(url, label) {
  const text = esc(label || url || "link");
  if (!isSafeHref(url)) {
    return `<code>${text}</code>`;
  }
  return `<a href="${esc(String(url).trim())}" rel="noreferrer noopener">${text}</a>`;
}

/** @returns {Graph} */
function activeGraph() {
  return (
    graphById.get(activeGraphId || "") ||
    graphs[0] || { id: "", nodes: [], edges: [], tour: [] }
  );
}

/** @param {Graph} graph */
function nodeMap(graph) {
  return new Map((graph.nodes || []).map((node) => [node.id, node]));
}

/** @param {GraphNode} node @param {Graph} graph */
function nodeSize(node, graph) {
  const overview = graph.id === "system-overview";
  return {
    width: Number(node.width || (overview ? 340 : 230)),
    height: Number(node.height || (overview ? 170 : 120)),
  };
}

/** @param {GraphNode} source @param {GraphNode} target @param {Graph} graph */
function clippedEndpoint(source, target, graph) {
  const size = nodeSize(target, graph);
  const dx = (target.x || 0) - (source.x || 0);
  const dy = (target.y || 0) - (source.y || 0);
  const halfWidth = size.width / 2;
  const halfHeight = size.height / 2;
  if (dx === 0 && dy === 0) {
    return { x: target.x || 0, y: target.y || 0 };
  }
  const scale = Math.min(
    Math.abs(halfWidth / dx) || Infinity,
    Math.abs(halfHeight / dy) || Infinity,
  );
  return { x: (target.x || 0) - dx * scale, y: (target.y || 0) - dy * scale };
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
  requiredElement("meta", HTMLElement).innerHTML = parts.join("");
}

function renderTabs() {
  const tabs = requiredElement("tabs", HTMLElement);
  tabs.innerHTML = "";
  for (const graph of graphs) {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = String(graph.label || graph.id);
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
  const query = search.value.trim().toLowerCase();
  /** @param {GraphNode} node */
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
    requiredElement("detail", HTMLElement).innerHTML =
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
    .attr("data-edge-id", (edge, index) =>
      String(edge.id || `${edge.source}-${edge.target}-${index}`),
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
      .text(String(edge.label || ""));
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
      .attr("stroke", String(node.color || graph.color || "#77736b"));
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
  const node = nodeMap(graph).get(selectedNodeId || "");
  const detail = requiredElement("detail", HTMLElement);
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
  const status = requiredElement("tour-status", HTMLElement);
  const copy = requiredElement("tour-copy", HTMLElement);
  const step = activeTourStep();
  status.dataset.tourIndex = String(tourIndex);
  status.textContent = total ? `Step ${tourIndex + 1} / ${total}` : "No tour";
  copy.textContent = String(total ? step?.body || step?.summary || "" : "");
}

/** @param {string} nodeId */
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

/** @param {string} graphId */
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

/** @param {number} delta */
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
  const box = canvas.getBoundingClientRect();
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

requiredElement("fit", HTMLElement).addEventListener("click", fitToView);
requiredElement("reset", HTMLElement).addEventListener("click", resetZoom);
requiredElement("previous-tour", HTMLButtonElement).addEventListener(
  "click",
  () => goTour(-1),
);
requiredElement("next-tour", HTMLElement).addEventListener("click", () =>
  goTour(1),
);
requiredElement("restart-tour", HTMLElement).addEventListener(
  "click",
  restartTour,
);
search.addEventListener("input", render);
document.addEventListener("keydown", (event) => {
  if (event.target instanceof HTMLInputElement && event.key !== "Escape")
    return;
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
    search.focus();
  }
  if (event.key === "Escape") {
    search.value = "";
    render();
  }
});

updateMeta();
renderTabs();
render();
requestAnimationFrame(fitToView);
