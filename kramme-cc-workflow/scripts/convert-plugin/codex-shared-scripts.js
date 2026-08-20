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
    ...sharedScriptDirs.flatMap((sharedScriptDir) => {
      const targetDir = path.join(codexRoot, sharedScriptDir.targetDir);
      const relativePrefix = `${sharedScriptDir.targetDir
        .split(path.sep)
        .join("/")}/`;
      return ["CLAUDE_PLUGIN_ROOT", "CLAUDE_PLUGIN_ROOT:-"].map(
        (rootExpression) => ({
          sourcePrefix: `\${${rootExpression}}/${relativePrefix}`,
          targetPrefix: `${shellQuotePath(targetDir)}/`,
          doubleQuotedTargetPrefix: `${escapeDoubleQuotedPath(targetDir)}/`,
        }),
      );
    }),
    ...sharedScriptFiles.flatMap((sharedScriptFile) => {
      const relativePath = sharedScriptFile.targetPath
        .split(path.sep)
        .join("/");
      const targetText = shellQuotePath(
        path.join(codexRoot, sharedScriptFile.targetPath),
      );
      return ["CLAUDE_PLUGIN_ROOT", "CLAUDE_PLUGIN_ROOT:-"].flatMap(
        (rootExpression) => {
          const sourceText = `\${${rootExpression}}/${relativePath}`;
          return [
            { sourceText: `"${sourceText}"`, targetText },
            { sourceText, targetText },
          ];
        },
      );
    }),
  ];
}

/**
 * @param {string} codexRoot
 * @param {string} skillName
 * @returns {SharedScriptReplacement[]}
 */
function codexSkillLocalReplacements(codexRoot, skillName) {
  const targetDir = path.join(codexRoot, "skills", skillName);
  return [
    {
      sourcePrefix: `\${CLAUDE_PLUGIN_ROOT}/skills/${skillName}/`,
      targetPrefix: `${shellQuotePath(targetDir)}/`,
      doubleQuotedTargetPrefix: `${escapeDoubleQuotedPath(targetDir)}/`,
    },
    {
      sourceText: `"\${CLAUDE_PLUGIN_ROOT}/skills/${skillName}"`,
      targetText: shellQuotePath(targetDir),
    },
    {
      sourceText: `\${CLAUDE_PLUGIN_ROOT}/skills/${skillName}`,
      targetText: shellQuotePath(targetDir),
    },
  ];
}

/** @param {string} text @param {SharedScriptReplacement[]} [replacements] */
function rewriteCodexSharedScriptReferences(text, replacements = []) {
  let result = text;
  for (const replacement of replacements) {
    if (replacement.sourcePrefix) {
      if (replacement.doubleQuotedTargetPrefix) {
        result = result
          .split(`"${replacement.sourcePrefix}`)
          .join(`"${replacement.doubleQuotedTargetPrefix}`);
      }
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

/** @param {string} filePath */
function escapeDoubleQuotedPath(filePath) {
  return String(filePath).replace(/[\\"$`]/g, "\\$&");
}

module.exports = {
  codexSkillLocalReplacements,
  codexSharedScriptReplacements,
  rewriteCodexSharedScriptReferences,
};
