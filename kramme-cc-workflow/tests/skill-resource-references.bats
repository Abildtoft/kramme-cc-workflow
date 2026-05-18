#!/usr/bin/env bats

@test "skill-local resource references point to existing files" {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for skill resource reference tests"
  fi

  run bash -c '
    cd "'"$BATS_TEST_DIRNAME"'/.."
    node <<'"'"'NODE'"'"'
const fs = require("fs");
const path = require("path");

const skillsDir = path.join(process.cwd(), "skills");
const failures = [];
const resourcePathPattern =
  /(?:references|assets|scripts)\/[A-Za-z0-9._~:/?#\[\]@!$&()+,;=%-]+\.(?:md|sh|js|ts|mjs|cjs|py|json|ya?ml|txt|html|css|png|jpe?g|gif|svg|webp)/.source;
const skillResourcePathPattern =
  /(?:\$\{(?:CLAUDE_)?PLUGIN_ROOT\}\/)?skills\/[A-Za-z0-9:_-]+\/(?:references|assets|scripts)\/[A-Za-z0-9._~:/?#\[\]@!$&()+,;=%-]+\.(?:md|sh|js|ts|mjs|cjs|py|json|ya?ml|txt|html|css|png|jpe?g|gif|svg|webp)/.source;
const referencePattern =
  new RegExp(`(?:^|[^A-Za-z0-9_./-])((?:${skillResourcePathPattern})|(?:${resourcePathPattern}))(?![A-Za-z0-9_./-])`, "g");
const loadInstructionPattern =
  /\b(read|follow|load|open|use|see|run|execute|copy|populate|template|from|consult|resolve|import|extract|compare|audit|check)\b/i;
const resourceListItemPattern =
  /^\s*(?:[-*]|\|)\s*`?(?:(?:\$\{(?:CLAUDE_)?PLUGIN_ROOT\}\/)?skills\/[A-Za-z0-9:_-]+\/)?(?:references|assets|scripts)\//;

function walkMarkdownFiles(dir) {
  const files = [];

  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...walkMarkdownFiles(fullPath));
    } else if (entry.isFile() && entry.name.endsWith(".md")) {
      files.push(fullPath);
    }
  }

  return files;
}

function nonFencedLines(raw) {
  let inFence = false;

  return raw.split(/\r?\n/).map((line) => {
    if (/^ {0,3}(```|~~~)/.test(line)) {
      inFence = !inFence;
      return "";
    }

    return inFence ? "" : line;
  });
}

function resolveResourcePath(skillDir, resourcePath) {
  const normalizedPath = resourcePath
    .replace(/[),.;:]+$/g, "")
    .split("#")[0]
    .split("?")[0]
    .replace(/^\$\{(?:CLAUDE_)?PLUGIN_ROOT\}\//, "");

  if (normalizedPath.startsWith("skills/")) {
    return {
      resourcePath: normalizedPath,
      targetPath: path.join(process.cwd(), normalizedPath),
    };
  }

  return {
    resourcePath: normalizedPath,
    targetPath: path.join(skillDir, normalizedPath),
  };
}

const skillDirs = fs
  .readdirSync(skillsDir, { withFileTypes: true })
  .filter((entry) => entry.isDirectory())
  .sort((a, b) => a.name.localeCompare(b.name));

for (const skill of skillDirs) {
  const skillDir = path.join(skillsDir, skill.name);
  const markdownFiles = walkMarkdownFiles(skillDir).sort();

  for (const file of markdownFiles) {
    const relativeFile = path.relative(process.cwd(), file);
    const lines = nonFencedLines(fs.readFileSync(file, "utf8"));

    lines.forEach((line, index) => {
      const matches = [...line.matchAll(referencePattern)];

      if (matches.length === 0) {
        return;
      }

      if (!loadInstructionPattern.test(line) && !resourceListItemPattern.test(line)) {
        return;
      }

      for (const match of matches) {
        const { resourcePath, targetPath } = resolveResourcePath(skillDir, match[1]);

        if (!fs.existsSync(targetPath)) {
          failures.push(`${relativeFile}:${index + 1}: missing ${resourcePath}`);
        }
      }
    });
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
