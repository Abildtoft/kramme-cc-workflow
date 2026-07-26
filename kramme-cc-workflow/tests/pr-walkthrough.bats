#!/usr/bin/env bats

setup() {
  ROOT="$BATS_TEST_DIRNAME/.."
  RENDERER="$ROOT/skills/kramme:pr:walkthrough/scripts/render_walkthrough.py"
  VALIDATOR="$ROOT/skills/kramme:pr:walkthrough/scripts/validate_walkthrough.py"
  RUNTIME="$ROOT/skills/kramme:pr:walkthrough/assets/walkthrough-runtime.js"
  TMP_DIR="$(mktemp -d)"
  WALKTHROUGH_CHROME_PID=""
}

stop_walkthrough_chrome() {
  local pid="${WALKTHROUGH_CHROME_PID:-}"
  local attempt
  [[ -n "$pid" ]] || return 0

  kill "$pid" 2>/dev/null || true
  for attempt in $(seq 1 20); do
    if ! kill -0 "$pid" 2>/dev/null; then
      wait "$pid" 2>/dev/null || true
      WALKTHROUGH_CHROME_PID=""
      return 0
    fi
    sleep 0.05
  done

  kill -KILL "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  WALKTHROUGH_CHROME_PID=""
}

remove_walkthrough_tmp_dir() {
  local attempt
  for attempt in $(seq 1 100); do
    rm -rf "$TMP_DIR" 2>/dev/null && return 0
    sleep 0.05
  done
  rm -rf "$TMP_DIR"
}

teardown() {
  stop_walkthrough_chrome
  remove_walkthrough_tmp_dir
}

write_valid_graph() {
  local graph="$1"
  cat >"$graph" <<'JSON'
{
  "meta": {
    "title": "Walkthrough regression fixture",
    "summary": "Exercises validation and browser interactions."
  },
  "graphs": [
    {
      "id": "system-overview",
      "label": "System overview",
      "nodes": [{"id": "system", "title": "System", "summary": "Overview.", "x": 0, "y": 0}],
      "edges": [],
      "tour": [{"nodeId": "system", "body": "Start here."}]
    },
    {
      "id": "data-flow",
      "label": "Data flow",
      "nodes": [
        {
          "id": "input",
          "title": "Input",
          "summary": "Model input.",
          "x": 0,
          "y": 0,
          "files": [{"path": "input.json"}],
          "links": [{"label": "Review", "url": "https://example.com/review"}],
          "media": [{"label": "Diagram", "src": "assets/diagram.png"}]
        },
        {"id": "output", "title": "Output", "summary": "Rendered artifact.", "x": 300, "y": 0}
      ],
      "edges": [{"source": "input", "target": "output", "label": "renders"}],
      "tour": [
        {"nodeId": "input", "body": "Inspect the input."},
        {"nodeId": "output", "body": "Inspect the output."}
      ]
    },
    {
      "id": "code-dependency",
      "label": "Code dependency",
      "nodes": [
        {"id": "model", "title": "Model", "summary": "Graph data.", "x": 0, "y": 0},
        {"id": "validator", "title": "Validator", "summary": "Checks graph data.", "x": 300, "y": 0}
      ],
      "edges": [{"source": "model", "target": "validator", "label": "checked by"}],
      "tour": [{"nodeId": "model", "body": "Model is validated."}]
    },
    {
      "id": "user-action",
      "label": "User action",
      "nodes": [
        {"id": "open", "title": "Open", "summary": "Open artifact.", "x": 0, "y": 0},
        {"id": "click", "title": "Click", "summary": "Click details.", "x": 300, "y": 0}
      ],
      "edges": [{"source": "open", "target": "click", "label": "then"}],
      "tour": [{"nodeId": "open", "body": "Open the artifact."}]
    }
  ]
}
JSON
}

find_chrome() {
  local candidate
  for candidate in \
    chromium \
    chromium-browser \
    google-chrome \
    google-chrome-stable \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "/Applications/Chromium.app/Contents/MacOS/Chromium"; do
    if command -v "$candidate" >/dev/null 2>&1 || [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

@test "PR walkthrough validator rejects unsafe URL schemes" {
  if ! command -v python3 >/dev/null 2>&1; then
    skip "python3 is required for PR walkthrough tests"
  fi

  graph="$TMP_DIR/graph.json"
  html="$TMP_DIR/index.html"
  cat >"$graph" <<'JSON'
{
  "meta": {
    "title": "Unsafe URL test",
    "summary": "Exercises URL validation.",
    "prUrl": "javascript:alert(1)"
  },
  "graphs": [
    {
      "id": "system-overview",
      "label": "System overview",
      "nodes": [{"id": "system", "title": "System", "summary": "Overview.", "x": 0, "y": 0}],
      "edges": [],
      "tour": [{"nodeId": "system", "body": "Start here."}]
    },
    {
      "id": "data-flow",
      "label": "Data flow",
      "nodes": [
        {
          "id": "input",
          "title": "Input",
          "summary": "Untrusted metadata.",
          "x": 0,
          "y": 0,
          "files": [{"path": "file.md", "url": "javascript:alert(2)"}],
          "links": [{"label": "bad", "url": "vbscript:alert(3)"}],
          "media": [
            {"label": "bad remote", "src": "https://example.com/screenshot.png"},
            {"label": "bad svg", "src": "data:image/svg+xml;base64,PHN2Zz48L3N2Zz4="}
          ]
        },
        {"id": "output", "title": "Output", "summary": "Rendered detail.", "x": 300, "y": 0}
      ],
      "edges": [{"source": "input", "target": "output", "label": "renders"}],
      "tour": [{"nodeId": "input", "body": "Inspect unsafe sources."}]
    },
    {
      "id": "code-dependency",
      "label": "Code dependency",
      "nodes": [
        {"id": "model", "title": "Model", "summary": "Graph data.", "x": 0, "y": 0},
        {"id": "validator", "title": "Validator", "summary": "Checks graph data.", "x": 300, "y": 0}
      ],
      "edges": [{"source": "model", "target": "validator", "label": "checked by"}],
      "tour": [{"nodeId": "model", "body": "Model is validated."}]
    },
    {
      "id": "user-action",
      "label": "User action",
      "nodes": [
        {"id": "open", "title": "Open", "summary": "Open artifact.", "x": 0, "y": 0},
        {"id": "click", "title": "Click", "summary": "Click details.", "x": 300, "y": 0}
      ],
      "edges": [{"source": "open", "target": "click", "label": "then"}],
      "tour": [{"nodeId": "open", "body": "Open the artifact."}]
    }
  ]
}
JSON

  python3 "$RENDERER" --data "$graph" --output "$html"

  run python3 "$VALIDATOR" --html "$html"

  [ "$status" -eq 1 ]
  [[ "$output" == *"meta.prUrl uses an unsafe URL"* ]]
  [[ "$output" == *"file 0 uses an unsafe URL"* ]]
  [[ "$output" == *"link 0 uses an unsafe URL"* ]]
  [[ "$output" == *"media 0 uses an unsafe source URL"* ]]
}

@test "PR walkthrough renderer inlines vendored D3 and accepts local media assets" {
  if ! command -v python3 >/dev/null 2>&1; then
    skip "python3 is required for PR walkthrough tests"
  fi

  graph="$TMP_DIR/graph.json"
  html="$TMP_DIR/custom-output.html"
  cat >"$graph" <<'JSON'
{
  "meta": {
    "title": "Valid asset test",
    "summary": "Exercises local media assets.",
    "prUrl": "https://github.com/example/repo/pull/1"
  },
  "graphs": [
    {
      "id": "system-overview",
      "label": "System overview",
      "nodes": [{"id": "system", "title": "System", "summary": "Overview.", "x": 0, "y": 0}],
      "edges": [],
      "tour": [{"nodeId": "system", "body": "Start here."}]
    },
    {
      "id": "data-flow",
      "label": "Data flow",
      "nodes": [
        {
          "id": "input",
          "title": "Input",
          "summary": "Local screenshot.",
          "x": 0,
          "y": 0,
          "media": [{"label": "screenshot", "src": "assets/screenshot.png"}]
        },
        {"id": "output", "title": "Output", "summary": "Rendered detail.", "x": 300, "y": 0}
      ],
      "edges": [{"source": "input", "target": "output", "label": "renders"}],
      "tour": [{"nodeId": "input", "body": "Inspect local media."}]
    },
    {
      "id": "code-dependency",
      "label": "Code dependency",
      "nodes": [
        {"id": "model", "title": "Model", "summary": "Graph data.", "x": 0, "y": 0},
        {"id": "validator", "title": "Validator", "summary": "Checks graph data.", "x": 300, "y": 0}
      ],
      "edges": [{"source": "model", "target": "validator", "label": "checked by"}],
      "tour": [{"nodeId": "model", "body": "Model is validated."}]
    },
    {
      "id": "user-action",
      "label": "User action",
      "nodes": [
        {"id": "open", "title": "Open", "summary": "Open artifact.", "x": 0, "y": 0},
        {"id": "click", "title": "Click", "summary": "Click details.", "x": 300, "y": 0}
      ],
      "edges": [{"source": "open", "target": "click", "label": "then"}],
      "tour": [{"nodeId": "open", "body": "Open the artifact."}]
    }
  ]
}
JSON

  python3 "$RENDERER" --data "$graph" --output "$html"

  run python3 "$VALIDATOR" --html "$html"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK: $html"* ]]
  grep -qF 'id="d3-vendor" data-vendor="d3"' "$html"
  run grep -qF "cdn.jsdelivr.net" "$html"
  [ "$status" -eq 1 ]
}

@test "PR walkthrough validator rejects duplicate node IDs" {
  if ! command -v python3 >/dev/null 2>&1; then
    skip "python3 is required for PR walkthrough tests"
  fi

  graph="$TMP_DIR/graph.json"
  html="$TMP_DIR/index.html"
  cat >"$graph" <<'JSON'
{
  "meta": {
    "title": "Duplicate node test",
    "summary": "Exercises node identity validation."
  },
  "graphs": [
    {
      "id": "system-overview",
      "label": "System overview",
      "nodes": [{"id": "system", "title": "System", "summary": "Overview.", "x": 0, "y": 0}],
      "edges": [],
      "tour": [{"nodeId": "system", "body": "Start here."}]
    },
    {
      "id": "data-flow",
      "label": "Data flow",
      "nodes": [
        {"id": "duplicate", "title": "First", "summary": "First node.", "x": 0, "y": 0},
        {"id": "duplicate", "title": "Second", "summary": "Second node.", "x": 300, "y": 0}
      ],
      "edges": [{"source": "duplicate", "target": "duplicate", "label": "ambiguous"}],
      "tour": [{"nodeId": "duplicate", "body": "Ambiguous target."}]
    },
    {
      "id": "code-dependency",
      "label": "Code dependency",
      "nodes": [
        {"id": "model", "title": "Model", "summary": "Graph data.", "x": 0, "y": 0},
        {"id": "validator", "title": "Validator", "summary": "Checks graph data.", "x": 300, "y": 0}
      ],
      "edges": [{"source": "model", "target": "validator", "label": "checked by"}],
      "tour": [{"nodeId": "model", "body": "Model is validated."}]
    },
    {
      "id": "user-action",
      "label": "User action",
      "nodes": [
        {"id": "open", "title": "Open", "summary": "Open artifact.", "x": 0, "y": 0},
        {"id": "click", "title": "Click", "summary": "Click details.", "x": 300, "y": 0}
      ],
      "edges": [{"source": "open", "target": "click", "label": "then"}],
      "tour": [{"nodeId": "open", "body": "Open the artifact."}]
    }
  ]
}
JSON

  python3 "$RENDERER" --data "$graph" --output "$html"

  run python3 "$VALIDATOR" --html "$html"

  [ "$status" -eq 1 ]
  [[ "$output" == *"data-flow: duplicate node id duplicate"* ]]
}

@test "PR walkthrough validator rejects malformed identifiers without an internal exception" {
  if ! command -v python3 >/dev/null 2>&1; then
    skip "python3 is required for PR walkthrough tests"
  fi

  graph="$TMP_DIR/graph.json"
  html="$TMP_DIR/index.html"
  write_valid_graph "$graph"
  python3 "$RENDERER" --data "$graph" --output "$html"
  python3 - "$html" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
html = path.read_text(encoding="utf-8")
start_marker = '<script id="pr-walkthrough-data" type="application/json">'
prefix, remainder = html.split(start_marker, 1)
data_json, suffix = remainder.split("</script>", 1)
data = json.loads(data_json)
data["graphs"][0]["id"] = []
data["graphs"][1]["nodes"][0]["id"] = []
data["graphs"][1]["nodes"][1]["id"] = {}
data["graphs"][1]["edges"][0]["source"] = {}
data["graphs"][1]["edges"][0]["target"] = ""
data["graphs"][1]["tour"][0]["nodeId"] = []
data["graphs"][2]["nodes"][0]["id"] = ""
path.write_text(
    prefix + start_marker + json.dumps(data) + "</script>" + suffix,
    encoding="utf-8",
)
PY

  run python3 "$VALIDATOR" --html "$html"

  [ "$status" -eq 1 ]
  [[ "$output" == *"graph 0 id must be a non-empty string"* ]]
  [[ "$output" == *"data-flow: node 0 id must be a non-empty string"* ]]
  [[ "$output" == *"data-flow: node 1 id must be a non-empty string"* ]]
  [[ "$output" == *"data-flow: edge 0 source must be a non-empty string"* ]]
  [[ "$output" == *"data-flow: edge 0 target must be a non-empty string"* ]]
  [[ "$output" == *"data-flow: tour step 0 nodeId must be a non-empty string"* ]]
  [[ "$output" == *"code-dependency: node 0 id must be a non-empty string"* ]]
  [[ "$output" != *"Traceback"* ]]
  [[ "$output" != *"TypeError"* ]]
}

@test "PR walkthrough validator rejects malformed collection fields" {
  if ! command -v python3 >/dev/null 2>&1; then
    skip "python3 is required for PR walkthrough tests"
  fi

  graph="$TMP_DIR/graph.json"
  html="$TMP_DIR/index.html"
  write_valid_graph "$graph"
  python3 - "$graph" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
node = data["graphs"][1]["nodes"][0]
node["details"] = {}
node["files"] = {}
node["comments"] = "not-an-array"
node["links"] = 42
node["media"] = "not-an-array"
data["graphs"][1]["tour"] = {}
path.write_text(json.dumps(data), encoding="utf-8")
PY

  python3 "$RENDERER" --data "$graph" --output "$html"
  run python3 "$VALIDATOR" --html "$html"

  [ "$status" -eq 1 ]
  [[ "$output" == *"data-flow: tour must be a non-empty array"* ]]
  [[ "$output" == *"data-flow/input: details must be an array"* ]]
  [[ "$output" == *"data-flow/input: files must be an array"* ]]
  [[ "$output" == *"data-flow/input: comments must be an array"* ]]
  [[ "$output" == *"data-flow/input: links must be an array"* ]]
  [[ "$output" == *"data-flow/input: media must be an array"* ]]
  [[ "$output" != *"Traceback"* ]]
  [[ "$output" != *"TypeError"* ]]
}

@test "PR walkthrough validator rejects invalid embedded runtime JavaScript" {
  if ! command -v python3 >/dev/null 2>&1 || ! command -v node >/dev/null 2>&1; then
    skip "python3 and node are required for runtime syntax validation"
  fi

  graph="$TMP_DIR/graph.json"
  html="$TMP_DIR/index.html"
  write_valid_graph "$graph"
  python3 "$RENDERER" --data "$graph" --output "$html"
  python3 - "$html" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
html = path.read_text(encoding="utf-8")
html = html.replace(
    '<script id="pr-walkthrough-runtime">',
    '<script id="pr-walkthrough-runtime">const invalid = ;',
    1,
)
path.write_text(html, encoding="utf-8")
PY

  run python3 "$VALIDATOR" --html "$html"

  [ "$status" -eq 1 ]
  [[ "$output" == *"runtime JavaScript syntax check failed"* ]]
}

@test "PR walkthrough runtime asset parses as JavaScript" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for runtime syntax validation"
  fi

  run node --check "$RUNTIME"

  [ "$status" -eq 0 ]
}

@test "PR walkthrough renderer preserves runtime placeholder text in graph data" {
  if ! command -v python3 >/dev/null 2>&1; then
    skip "python3 is required for PR walkthrough tests"
  fi

  graph="$TMP_DIR/graph.json"
  html="$TMP_DIR/index.html"
  write_valid_graph "$graph"
  python3 - "$graph" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
token = "__RUNTIME_JS__"
data["meta"]["title"] = f"Review {token}"
data["meta"]["summary"] = f"Summary {token}"
data["graphs"][1]["nodes"][0]["summary"] = f"Node {token}"
path.write_text(json.dumps(data), encoding="utf-8")
PY

  python3 "$RENDERER" --data "$graph" --output "$html"
  run python3 - "$html" <<'PY'
import json
import sys
from pathlib import Path

html = Path(sys.argv[1]).read_text(encoding="utf-8")
marker = '<script id="pr-walkthrough-data" type="application/json">'
data_json = html.split(marker, 1)[1].split("</script>", 1)[0]
data = json.loads(data_json)
token = "__RUNTIME_JS__"
assert data["meta"]["title"] == f"Review {token}"
assert data["meta"]["summary"] == f"Summary {token}"
assert data["graphs"][1]["nodes"][0]["summary"] == f"Node {token}"
print("runtime placeholder preserved")
PY

  [ "$status" -eq 0 ]
  [[ "$output" == *"runtime placeholder preserved"* ]]
}

@test "PR walkthrough tests do not kill an inherited CHROME_PID" {
  if ! command -v bats >/dev/null 2>&1; then
    skip "bats is required for the inherited PID regression"
  fi

  sleep 30 >/dev/null 2>&1 3>&- &
  dummy_pid=$!
  run env CHROME_PID="$dummy_pid" bats \
    --filter "^PR walkthrough validator rejects unsafe URL schemes$" \
    "$BATS_TEST_FILENAME"
  nested_status="$status"

  process_survived=0
  if kill -0 "$dummy_pid" 2>/dev/null; then
    process_survived=1
    kill "$dummy_pid" 2>/dev/null || true
    wait "$dummy_pid" 2>/dev/null || true
  fi

  [ "$nested_status" -eq 0 ]
  [ "$process_survived" -eq 1 ]
}

@test "PR walkthrough supports initial render, tab switch, search, and tour navigation" {
  if ! command -v python3 >/dev/null 2>&1 || ! command -v node >/dev/null 2>&1; then
    skip "python3 and node are required for the browser smoke"
  fi
  if [[ "$(node -p 'typeof WebSocket')" != "function" ]]; then
    skip "Node.js WebSocket support is required for the browser smoke"
  fi
  chrome="$(find_chrome)" || skip "Chrome or Chromium is required for the browser smoke"

  graph="$TMP_DIR/graph.json"
  html="$TMP_DIR/index.html"
  chrome_log="$TMP_DIR/chrome.log"
  write_valid_graph "$graph"
  python3 "$RENDERER" --data "$graph" --output "$html"

  "$chrome" \
    --headless=new \
    --disable-background-networking \
    --disable-component-update \
    --disable-default-apps \
    --disable-sync \
    --metrics-recording-only \
    --mute-audio \
    --no-default-browser-check \
    --no-first-run \
    --remote-debugging-port=0 \
    --user-data-dir="$TMP_DIR/chrome-profile" \
    about:blank >"$TMP_DIR/chrome.out" 2>"$chrome_log" 3>&- &
  WALKTHROUGH_CHROME_PID=$!

  devtools_url=""
  for _ in $(seq 1 200); do
    devtools_url="$(grep -m1 -o 'ws://[^ ]*' "$chrome_log" || true)"
    [[ -n "$devtools_url" ]] && break
    sleep 0.05
  done
  if [[ -z "$devtools_url" ]]; then
    cat "$chrome_log" >&2
    false
  fi

  run node - "$devtools_url" "$html" <<'NODE'
const { pathToFileURL } = require("node:url");
const SMOKE_TIMEOUT_MS = 15000;

async function main() {
  const browserUrl = process.argv[2];
  const pageUrl = pathToFileURL(process.argv[3]).href;
  const socket = new WebSocket(browserUrl);
  let nextId = 0;
  const pending = new Map();
  const eventWaiters = [];

  await new Promise((resolve, reject) => {
    socket.addEventListener("open", resolve, { once: true });
    socket.addEventListener("error", reject, { once: true });
  });

  socket.addEventListener("message", (event) => {
    const message = JSON.parse(event.data);
    if (message.id) {
      const waiter = pending.get(message.id);
      if (!waiter) return;
      pending.delete(message.id);
      if (message.error) {
        waiter.reject(new Error(message.error.message));
      } else {
        waiter.resolve(message.result);
      }
      return;
    }
    for (const waiter of [...eventWaiters]) {
      if (waiter.method === message.method && waiter.sessionId === message.sessionId) {
        eventWaiters.splice(eventWaiters.indexOf(waiter), 1);
        clearTimeout(waiter.timer);
        waiter.resolve(message.params);
      }
    }
  });

  function send(method, params = {}, sessionId) {
    return new Promise((resolve, reject) => {
      const id = ++nextId;
      pending.set(id, { resolve, reject });
      socket.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
    });
  }

  function waitForEvent(method, sessionId) {
    return new Promise((resolve, reject) => {
      const waiter = {
        method,
        sessionId,
        resolve,
        reject,
        timer: setTimeout(() => {
          eventWaiters.splice(eventWaiters.indexOf(waiter), 1);
          reject(new Error(`Timed out waiting for ${method}`));
        }, 5000),
      };
      eventWaiters.push(waiter);
    });
  }

  async function evaluate(expression) {
    const response = await send(
      "Runtime.evaluate",
      { expression, returnByValue: true, awaitPromise: true },
      sessionId,
    );
    if (response.exceptionDetails) {
      throw new Error(response.exceptionDetails.text || "Runtime evaluation failed");
    }
    return response.result.value;
  }

  async function waitFor(expression) {
    for (let attempt = 0; attempt < 100; attempt += 1) {
      if (await evaluate(expression)) return;
      await new Promise((resolve) => setTimeout(resolve, 50));
    }
    throw new Error(`Timed out waiting for: ${expression}`);
  }

  const { targetId } = await send("Target.createTarget", { url: "about:blank" });
  const attached = await send("Target.attachToTarget", { targetId, flatten: true });
  const sessionId = attached.sessionId;
  await send("Page.enable", {}, sessionId);
  await send("Runtime.enable", {}, sessionId);
  const loaded = waitForEvent("Page.loadEventFired", sessionId);
  await send("Page.navigate", { url: pageUrl }, sessionId);
  await loaded;

  await waitFor('document.querySelectorAll("#tabs button").length === 4');
  const initial = await evaluate(`({
    activeGraph: document.querySelector("#tabs button.active")?.dataset.graphId,
    nodes: document.querySelectorAll('.node-card[data-graph-id="system-overview"]').length,
    tour: document.getElementById("tour-status").textContent
  })`);
  if (initial.activeGraph !== "system-overview" || initial.nodes !== 1 || initial.tour !== "Step 1 / 1") {
    throw new Error(`Initial render failed: ${JSON.stringify(initial)}`);
  }

  const switched = await evaluate(`(() => {
    document.querySelector('button[data-graph-id="data-flow"]').click();
    return {
      activeGraph: document.querySelector("#tabs button.active")?.dataset.graphId,
      nodes: document.querySelectorAll('.node-card[data-graph-id="data-flow"]').length
    };
  })()`);
  if (switched.activeGraph !== "data-flow" || switched.nodes !== 2) {
    throw new Error(`Tab switch failed: ${JSON.stringify(switched)}`);
  }

  const searched = await evaluate(`(() => {
    const search = document.getElementById("search");
    search.value = "Output";
    search.dispatchEvent(new Event("input", { bubbles: true }));
    return {
      value: search.value,
      dimmed: document.querySelectorAll(".node-card.dimmed").length
    };
  })()`);
  if (searched.value !== "Output" || searched.dimmed !== 1) {
    throw new Error(`Search failed: ${JSON.stringify(searched)}`);
  }

  const toured = await evaluate(`(() => {
    document.getElementById("next-tour").click();
    return {
      index: document.getElementById("tour-status").dataset.tourIndex,
      activeNode: document.querySelector(".node-card.active")?.dataset.nodeId,
      copy: document.getElementById("tour-copy").textContent
    };
  })()`);
  if (toured.index !== "1" || toured.activeNode !== "output" || toured.copy !== "Inspect the output.") {
    throw new Error(`Tour navigation failed: ${JSON.stringify(toured)}`);
  }

  await send("Browser.close");
  socket.close();
  console.log("browser smoke passed");
}

async function runWithTimeout(task, timeoutMs) {
  let timer;
  const timeout = new Promise((_resolve, reject) => {
    timer = setTimeout(
      () => reject(new Error(`Browser smoke timed out after ${timeoutMs}ms`)),
      timeoutMs,
    );
  });
  try {
    return await Promise.race([task, timeout]);
  } finally {
    clearTimeout(timer);
  }
}

runWithTimeout(main(), SMOKE_TIMEOUT_MS).catch((error) => {
  console.error(error.stack || error);
  process.exit(1);
});
NODE

  [ "$status" -eq 0 ]
  [[ "$output" == *"browser smoke passed"* ]]
}
