// @ts-check
"use strict";

/**
 * Claude Code exposes the installed plugin directory as `CLAUDE_PLUGIN_ROOT`.
 * Codex plugins receive that variable in hook commands only, so converted skill
 * Markdown replaces every reference, including `${CLAUDE_PLUGIN_ROOT:-...}`
 * fallbacks, with the shell expression of the Codex plugin cache directory the
 * plugin installs into.
 */
const CLAUDE_PLUGIN_ROOT_PATTERN =
  /\$\{CLAUDE_PLUGIN_ROOT(?::-[^}]*)?\}|\$CLAUDE_PLUGIN_ROOT\b/g;

/** @param {string} cacheRelativePath */
function codexPluginRootExpression(cacheRelativePath) {
  return `\${CODEX_HOME:-$HOME/.codex}/${cacheRelativePath
    .split("\\")
    .join("/")}`;
}

/** @param {string} text @param {string} pluginRootExpression */
function rewriteCodexPluginRootReferences(text, pluginRootExpression) {
  return text.replace(CLAUDE_PLUGIN_ROOT_PATTERN, () => pluginRootExpression);
}

/** @param {string} text */
function hasClaudePluginRootReference(text) {
  return new RegExp(CLAUDE_PLUGIN_ROOT_PATTERN.source).test(text);
}

module.exports = {
  codexPluginRootExpression,
  hasClaudePluginRootReference,
  rewriteCodexPluginRootReferences,
};
