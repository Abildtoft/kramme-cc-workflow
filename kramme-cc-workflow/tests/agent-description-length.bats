#!/usr/bin/env bats

@test "agent descriptions fit Codex skill metadata limits" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for agent metadata tests"
  fi

  run bash -c '
    cd "'"$BATS_TEST_DIRNAME"'/.."
    node <<'"'"'NODE'"'"'
const fs = require("fs");
const path = require("path");

const MAX_LENGTH = 1024;
const agentsDir = path.join(process.cwd(), "agents");
const failures = [];

for (const entry of fs.readdirSync(agentsDir).filter((name) => name.endsWith(".md")).sort()) {
  const raw = fs.readFileSync(path.join(agentsDir, entry), "utf8");
  const match = raw.match(/^---\n([\s\S]*?)\n---/);
  if (!match) {
    failures.push(`${entry}: missing frontmatter`);
    continue;
  }

  const descriptionMatch =
    match[1].match(/^description:\s*"([\s\S]*?)"\n/m) ??
    match[1].match(/^description:\s*(.+)$/m);
  if (!descriptionMatch) {
    failures.push(`${entry}: missing description`);
    continue;
  }

  const description = descriptionMatch[1].replace(/\s+/g, " ").trim();
  if (description.length > MAX_LENGTH) {
    failures.push(`${entry}: ${description.length} chars`);
  }
}

if (failures.length > 0) {
  console.error(failures.join("\n"));
  process.exit(1);
}
NODE
  '

  [ "$status" -eq 0 ]
}
