"use strict";

const path = require("path");

/**
 * @typedef {import("./contracts").SharedScriptDir} SharedScriptDir
 * @typedef {import("./contracts").SharedScriptFile} SharedScriptFile
 * @typedef {import("./contracts").SharedScriptReplacement} SharedScriptReplacement
 */

/**
 * @param {string} codexRoot
 * @param {SharedScriptDir[]} [sharedScriptDirs]
 * @param {Array<Pick<SharedScriptFile, "targetPath">>} [sharedScriptFiles]
 * @returns {SharedScriptReplacement[]}
 */
function codexSharedScriptReplacements(
  codexRoot,
  sharedScriptDirs = [],
  sharedScriptFiles = [],
) {
  return [
    ...sharedScriptDirs.map((sharedScriptDir) => ({
      sourcePrefix: `\${CLAUDE_PLUGIN_ROOT}/${sharedScriptDir.targetDir
        .split(path.sep)
        .join("/")}/`,
      targetPrefix: `${shellQuotePath(
        path.join(codexRoot, sharedScriptDir.targetDir),
      )}/`,
    })),
    ...sharedScriptFiles.flatMap((sharedScriptFile) => {
      const sourceText = `\${CLAUDE_PLUGIN_ROOT}/${sharedScriptFile.targetPath
        .split(path.sep)
        .join("/")}`;
      const targetText = shellQuotePath(
        path.join(codexRoot, sharedScriptFile.targetPath),
      );
      return [
        { sourceText: `"${sourceText}"`, targetText },
        { sourceText, targetText },
      ];
    }),
  ];
}

/** @param {string} text @param {SharedScriptReplacement[]} [replacements] */
function rewriteCodexSharedScriptReferences(text, replacements = []) {
  let result = text;
  for (const replacement of replacements) {
    if (replacement.sourcePrefix) {
      result = result
        .split(replacement.sourcePrefix)
        .join(replacement.targetPrefix);
    }
    if (replacement.sourceText) {
      result = result
        .split(replacement.sourceText)
        .join(replacement.targetText);
    }
  }
  return result;
}

/** @param {string} filePath */
function shellQuotePath(filePath) {
  return `'${String(filePath).replace(/'/g, "'\\''")}'`;
}

module.exports = {
  codexSharedScriptReplacements,
  rewriteCodexSharedScriptReferences,
};
