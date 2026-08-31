"use strict";

const fs = require("fs/promises");
const path = require("path");
const { filesystemErrorCode } = require("./filesystem");

const DIAGNOSTIC_SCHEMA_VERSION = 1;

/**
 * @typedef {{
 *   agentsRoot: string,
 *   codexHome: string,
 *   pluginInput: string,
 * }} DiagnosticOptions
 * @typedef {{
 *   inspectInstallTransactions?: (root: string, options?: { lockRoots?: string[] }) => Promise<import("./install-transaction").TransactionHealthSummary>,
 *   loadClaudePlugin?: (inputPath: string) => Promise<import("./contracts").ClaudePlugin>,
 *   loadInstallState?: (root: string) => Promise<{ fromDisk: boolean, recoveryReason: string | null }>,
 *   resolvePluginInput?: (input: unknown) => Promise<string>,
 * }} DiagnosticDependencies
 */

/**
 * Collect the converter's resolved local context without mutating it.
 *
 * @param {DiagnosticOptions} options
 * @param {DiagnosticDependencies} [dependencies]
 */
async function collectConverterDiagnostics(options, dependencies = {}) {
  const resolvePluginInput =
    dependencies.resolvePluginInput ?? require("./loader").resolvePluginInput;
  const loadClaudePlugin =
    dependencies.loadClaudePlugin ?? require("./loader").loadClaudePlugin;
  const loadInstallState =
    dependencies.loadInstallState ??
    require("./install-state").loadInstallState;
  const inspectInstallTransactions =
    dependencies.inspectInstallTransactions ??
    require("./install-transaction").inspectInstallTransactions;

  const resolvedPluginPath = await resolvePluginInput(options.pluginInput);
  const plugin = await loadClaudePlugin(resolvedPluginPath);
  const codexRoot = resolveCodexRoot(options.codexHome);
  const agentsRoot = path.resolve(options.agentsRoot);
  const installStatePath = path.join(codexRoot, ".kramme-install-state.json");
  const { fromDisk, recoveryReason } = await loadInstallState(codexRoot);
  const transactionHealth = await inspectInstallTransactions(codexRoot, {
    lockRoots: await resolveDiagnosticLockRoots(codexRoot, agentsRoot),
  });

  return {
    schema_version: DIAGNOSTIC_SCHEMA_VERSION,
    plugin_name: normalizeLabel(plugin.manifest.name, "plugin"),
    plugin_version: normalizeLabel(plugin.manifest.version, "local"),
    plugin_source: path.resolve(plugin.root),
    codex_root: codexRoot,
    agents_root: agentsRoot,
    install_state_path: installStatePath,
    install_state_status: fromDisk ? "loaded" : "reconstructed",
    install_state_from_disk: fromDisk,
    install_state_recovery_reason: recoveryReason,
    transaction_health: transactionHealth,
  };
}

/** @param {string} codexRoot @param {string} agentsRoot */
async function resolveDiagnosticLockRoots(codexRoot, agentsRoot) {
  const roots = [agentsRoot];
  const agentsFile = path.join(codexRoot, "AGENTS.md");
  try {
    const stats = await fs.lstat(agentsFile);
    if (stats.isSymbolicLink()) {
      const linkTarget = await fs.readlink(agentsFile);
      roots.push(
        path.dirname(path.resolve(path.dirname(agentsFile), linkTarget)),
      );
    }
  } catch (error) {
    if (filesystemErrorCode(error) !== "ENOENT") throw error;
  }
  return roots;
}

/** @param {string} codexHome */
function resolveCodexRoot(codexHome) {
  const resolved = path.resolve(codexHome);
  return path.basename(resolved) === ".codex"
    ? resolved
    : path.join(resolved, ".codex");
}

/** @param {unknown} value @param {string} fallback */
function normalizeLabel(value, fallback) {
  const normalized = String(value ?? fallback)
    .replace(/\s+/g, " ")
    .trim();
  return normalized || fallback;
}

module.exports = {
  collectConverterDiagnostics,
};
