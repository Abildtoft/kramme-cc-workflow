#!/usr/bin/env bats

setup() {
  ROOT="$BATS_TEST_DIRNAME/.."
  RENDERER="$ROOT/skills/kramme:pr:walkthrough/scripts/render_walkthrough.py"
  VALIDATOR="$ROOT/skills/kramme:pr:walkthrough/scripts/validate_walkthrough.py"
  TMP_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMP_DIR"
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
