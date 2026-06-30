"use strict";

const fs = require("fs/promises");
const path = require("path");
const { transformContentForCodex } = require("./codex-transformer");
const {
  rewriteCodexSharedScriptReferences,
} = require("./codex-shared-scripts");
const { readText, writeText } = require("./filesystem");

async function rewriteCodexMarkdownResourcesFromSource(
  sourceDir,
  targetDir,
  options = {},
) {
  const entries = await fs.readdir(sourceDir, { withFileTypes: true });
  for (const entry of entries) {
    const sourcePath = path.join(sourceDir, entry.name);
    const targetPath = path.join(targetDir, entry.name);
    if (entry.isDirectory()) {
      await rewriteCodexMarkdownResourcesFromSource(
        sourcePath,
        targetPath,
        options,
      );
      continue;
    }
    if (
      !entry.isFile() ||
      path.extname(entry.name) !== ".md" ||
      entry.name === "SKILL.md"
    ) {
      continue;
    }
    const source = await readText(targetPath);
    const transformed = rewriteCodexSharedScriptReferences(
      transformContentForCodex(source, options),
      options.sharedScriptReplacements,
    );
    if (transformed !== source) {
      await writeText(targetPath, transformed);
    }
  }
}

module.exports = {
  rewriteCodexMarkdownResourcesFromSource,
};
