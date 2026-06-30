"use strict";

const path = require("path");

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
    ...sharedScriptFiles.map((sharedScriptFile) => ({
      sourceText: `\${CLAUDE_PLUGIN_ROOT}/${sharedScriptFile.targetPath
        .split(path.sep)
        .join("/")}`,
      targetText: shellQuotePath(
        path.join(codexRoot, sharedScriptFile.targetPath),
      ),
    })),
  ];
}

function rewriteCodexSharedScriptReferences(text, replacements = []) {
  let result = text;
  for (const replacement of replacements) {
    if (replacement.sourcePrefix) {
      result = result
        .split(replacement.sourcePrefix)
        .join(replacement.targetPrefix);
    }
    if (replacement.sourceText) {
      result = result.split(replacement.sourceText).join(replacement.targetText);
    }
  }
  return result;
}

function shellQuotePath(filePath) {
  return `'${String(filePath).replace(/'/g, "'\\''")}'`;
}

module.exports = {
  codexSharedScriptReplacements,
  rewriteCodexSharedScriptReferences,
};
