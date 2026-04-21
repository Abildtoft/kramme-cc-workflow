#!/usr/bin/env bats

@test "agent and skill descriptions fit Codex metadata limits" {
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
const skillsDir = path.join(process.cwd(), "skills");
const failures = [];
const files = [
  ...fs
    .readdirSync(agentsDir, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith(".md"))
    .map((entry) => path.join("agents", entry.name)),
  ...fs
    .readdirSync(skillsDir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => path.join("skills", entry.name, "SKILL.md"))
    .filter((entry) => fs.existsSync(path.join(process.cwd(), entry))),
].sort();

for (const entry of files) {
  const raw = fs.readFileSync(path.join(process.cwd(), entry), "utf8");
  const match = raw.match(/^---\n([\s\S]*?)\n---/);
  if (!match) {
    failures.push(`${entry}: missing frontmatter`);
    continue;
  }

  const descriptionMatch =
    match[1].match(/^description:\s*"([\s\S]*?)"(?:\n|$)/m) ??
    match[1].match(/^description:\s*\x27([\s\S]*?)\x27(?:\n|$)/m) ??
    match[1].match(/^description:\s*(.+)$/m);
  if (!descriptionMatch) {
    failures.push(`${entry}: missing description`);
    continue;
  }

  const description = descriptionMatch[1]
    .trim()
    .replace(/^[\x27"]|[\x27"]$/g, "")
    .replace(/\s+/g, " ");
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

@test "feature spec template preserves raw marker prefixes" {
  run bash -c '
    cd "'"$BATS_TEST_DIRNAME"'/.."
    template="skills/kramme:docs:feature-spec/assets/feature-spec-template.md"

    grep -q -- "^- POTENTIAL CONCERNS:" "$template" ||
      { echo "missing raw POTENTIAL CONCERNS marker"; exit 1; }

    if grep -q -- "^- \`POTENTIAL CONCERNS:\`" "$template"; then
      echo "template backticks the POTENTIAL CONCERNS marker"
      exit 1
    fi
  '

  [ "$status" -eq 0 ]
}
