// @ts-check
"use strict";

const fs = require("fs/promises");
const path = require("path");
const { transformContentForCodex } = require("./codex-transformer");
const { rewriteCodexPluginRootReferences } = require("./codex-shared-scripts");
const { pathExists, readText, writeText } = require("./filesystem");

/**
 * @typedef {import("./contracts").CodexTransformOptions} CodexTransformOptions
 * @typedef {CodexTransformOptions & { pluginRootExpression: string }} MarkdownRewriteOptions
 */

/**
 * Rewrite the Markdown resources copied beside a converted `SKILL.md` so they
 * carry Codex instruction text and the installed plugin root.
 *
 * @param {string} sourceDir @param {string} targetDir @param {MarkdownRewriteOptions} options
 */
async function rewriteCodexMarkdownResourcesFromSource(
  sourceDir,
  targetDir,
  options,
) {
  const entries = await fs.readdir(sourceDir, { withFileTypes: true });
  for (const entry of entries) {
    const sourcePath = path.join(sourceDir, entry.name);
    const targetPath = path.join(targetDir, entry.name);
    if (entry.isDirectory()) {
      if (!(await pathExists(targetPath))) {
        continue;
      }
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
    const transformed = rewriteCodexPluginRootReferences(
      transformContentForCodex(source, options),
      options.pluginRootExpression,
    );
    if (transformed !== source) {
      await writeText(targetPath, transformed);
    }
  }
}

module.exports = {
  rewriteCodexMarkdownResourcesFromSource,
};
