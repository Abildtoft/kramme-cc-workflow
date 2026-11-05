// @ts-check
"use strict";

const { createHash } = require("crypto");
const fs = require("fs/promises");
const path = require("path");
const { confirm } = require("./confirm");
const {
  filesystemErrorCode,
  isJsonObject,
  pathExists,
  readJson,
  readText,
  resolveManagedChild,
  writeJson,
  writeText,
} = require("./filesystem");

/**
 * Earlier converter releases copied skills, agent skills, shared helpers, a
 * hook marketplace, and an AGENTS.md tool map straight into the Codex and
 * agents homes and recorded what they owned in `.kramme-install-state.json`.
 * This module removes exactly those recorded entries so a native plugin install
 * does not leave duplicate skills behind.
 *
 * @typedef {import("./contracts").ConfirmOptions} ConfirmOptions
 * @typedef {{ agentSkills: string[], hookMarketplaces: string[], pluginCaches: string[], prompts: string[], sharedHelperFiles: Record<string, string>, skills: string[] }} LegacyInstallEntries
 * @typedef {{ status: "absent" } | { status: "declined" } | { status: "removed", removedPaths: number }} LegacyCleanupResult
 */

const LEGACY_STATE_FILE = ".kramme-install-state.json";
const LEGACY_MANIFESTS_DIR = ".kramme-install-manifests";
const LEGACY_ARTIFACT_DIRS = [
  ".kramme-install-lock",
  LEGACY_MANIFESTS_DIR,
  ".kramme-install-staging",
  ".kramme-install-transactions",
];
const AGENTS_BLOCK_START = "<!-- BEGIN KRAMME CODEX TOOL MAP -->";
const AGENTS_BLOCK_END = "<!-- END KRAMME CODEX TOOL MAP -->";
const UNSAFE_HELPER_PATH = /[\\:\u0000-\u001f\u007f]/;

/** @param {string} codexHome */
function legacyStatePath(codexHome) {
  return path.join(codexHome, LEGACY_STATE_FILE);
}

/** @param {string} codexHome @param {string} pluginName */
function legacyManifestPath(codexHome, pluginName) {
  return path.join(
    codexHome,
    LEGACY_MANIFESTS_DIR,
    `${encodeURIComponent(pluginName)}-codex.json`,
  );
}

/** @param {string} codexHome @param {string} [pluginName] */
async function hasLegacyInstall(codexHome, pluginName) {
  const state = legacyStatePath(codexHome);
  if (
    pluginName &&
    (await pathExists(legacyManifestPath(codexHome, pluginName)))
  ) {
    return true;
  }
  if (!(await pathExists(state))) return false;
  if (!pluginName) return true;
  try {
    const parsed = await readJson(state);
    if (!isJsonObject(parsed)) return true;
    const plugins = isJsonObject(parsed.plugins) ? parsed.plugins : {};
    return isJsonObject(plugins[pluginName]);
  } catch {
    // An unreadable state file is still a legacy install; fail closed below.
    return true;
  }
}

/**
 * Read the entries recorded for one plugin from the state file, unioned with
 * the per-plugin manifest so a damaged state file still yields the manifest.
 *
 * @param {string} codexHome @param {string} pluginName
 * @returns {Promise<LegacyInstallEntries>}
 */
async function readLegacyInstallEntries(codexHome, pluginName) {
  const sources = [
    legacyStatePath(codexHome),
    legacyManifestPath(codexHome, pluginName),
  ];
  const merged = emptyEntries();
  for (const file of sources) {
    const record = await readLegacyRecord(file, pluginName);
    if (!record) continue;
    for (const key of /** @type {const} */ ([
      "agentSkills",
      "hookMarketplaces",
      "pluginCaches",
      "prompts",
      "skills",
    ])) {
      merged[key] = union(merged[key], sanitizeEntryList(record[key]));
    }
    Object.assign(
      merged.sharedHelperFiles,
      sanitizeSharedHelperFiles(record.sharedHelperFiles),
    );
  }
  return merged;
}

/** @param {string} file @param {string} pluginName @returns {Promise<Record<string, unknown> | null>} */
async function readLegacyRecord(file, pluginName) {
  let parsed;
  try {
    parsed = await readJson(file);
  } catch (error) {
    if (filesystemErrorCode(error) === "ENOENT") return null;
    console.warn(`Ignoring unreadable legacy install record ${file}.`);
    return null;
  }
  if (!isJsonObject(parsed)) return null;
  if (path.basename(file) !== LEGACY_STATE_FILE) return parsed;
  const plugins = isJsonObject(parsed.plugins) ? parsed.plugins : {};
  const plugin = isJsonObject(plugins[pluginName]) ? plugins[pluginName] : {};
  return isJsonObject(plugin.codex) ? plugin.codex : null;
}

/**
 * Remove the recorded legacy output after confirmation.
 *
 * @param {{ codexHome: string, agentsHome: string, pluginName: string, confirmOptions: ConfirmOptions, preservePaths?: string[], log?: (message: string) => void }} options
 * @returns {Promise<LegacyCleanupResult>}
 */
async function cleanupLegacyInstall({
  codexHome,
  agentsHome,
  pluginName,
  confirmOptions,
  preservePaths = [],
  log = console.log,
}) {
  if (!(await hasLegacyInstall(codexHome, pluginName))) {
    return { status: "absent" };
  }
  const entries = await readLegacyInstallEntries(codexHome, pluginName);

  const records = await inspectLegacyRecords(codexHome, pluginName);
  if (records.unreadable && !hasEntries(entries)) {
    throw new Error(
      `Cannot safely clean legacy Codex output in ${codexHome}: install records are unreadable and no owned paths were recovered.`,
    );
  }

  log(
    `Found a legacy converter install in ${codexHome} (${entries.skills.length} skills, ${entries.agentSkills.length} agent skills, ${Object.keys(entries.sharedHelperFiles).length} shared helpers).`,
  );
  const confirmed = await confirm(
    "Remove the legacy Codex output recorded there?",
    confirmOptions,
  );
  if (!confirmed) {
    console.warn(
      `Keeping legacy Codex output; converted skills under ${codexHome}/skills will duplicate the plugin's skills until removed.`,
    );
    return { status: "declined" };
  }

  let removedPaths = 0;
  /** @param {string} root @param {string[]} names @param {string} label */
  const removeChildren = async (root, names, label) => {
    for (const name of names) {
      const target = tryResolveManagedChild(root, name, label);
      if (target && preservePaths.some((kept) => pathsOverlap(target, kept))) {
        continue;
      }
      if (target && (await removePath(target))) removedPaths += 1;
    }
  };
  await removeChildren(path.join(codexHome, "skills"), entries.skills, "skill");
  await removeChildren(
    path.join(codexHome, "prompts"),
    entries.prompts,
    "prompt",
  );
  await removeChildren(
    path.join(agentsHome, "skills"),
    entries.agentSkills,
    "agent skill",
  );
  await removeChildren(codexHome, entries.hookMarketplaces, "hook marketplace");
  await removeChildren(
    path.join(codexHome, "plugins"),
    entries.pluginCaches,
    "plugin cache entry",
  );
  removedPaths += await removeOwnedHelpers(
    codexHome,
    entries.sharedHelperFiles,
  );
  const otherPlugins =
    isJsonObject(records.state) && isJsonObject(records.state.plugins)
      ? Object.keys(records.state.plugins).filter((name) => name !== pluginName)
      : [];
  if (
    otherPlugins.length === 0 &&
    !records.unreadable &&
    (await removeAgentsToolMap(path.join(codexHome, "AGENTS.md")))
  ) {
    removedPaths += 1;
  }
  removedPaths += await removeLegacyRecords(pluginName, records);
  log(`Removed ${removedPaths} legacy Codex install paths.`);
  return { status: "removed", removedPaths };
}

/** @param {string} left @param {string} right */
function pathsOverlap(left, right) {
  const relative = path.relative(path.resolve(left), path.resolve(right));
  const reverse = path.relative(path.resolve(right), path.resolve(left));
  const contained = (/** @type {string} */ value) =>
    value === "" ||
    (value !== ".." &&
      !value.startsWith(`..${path.sep}`) &&
      !path.isAbsolute(value));
  return contained(relative) || contained(reverse);
}

/** @param {LegacyInstallEntries} entries */
function hasEntries(entries) {
  return (
    entries.agentSkills.length > 0 ||
    entries.hookMarketplaces.length > 0 ||
    entries.pluginCaches.length > 0 ||
    entries.prompts.length > 0 ||
    entries.skills.length > 0 ||
    Object.keys(entries.sharedHelperFiles).length > 0
  );
}

/** @param {string} codexHome @param {string} pluginName */
async function inspectLegacyRecords(codexHome, pluginName) {
  const stateFile = legacyStatePath(codexHome);
  const manifestFile = legacyManifestPath(codexHome, pluginName);
  let state = null;
  let stateUnreadable = false;
  try {
    state = await readJson(stateFile);
    if (
      !isJsonObject(state) ||
      !isJsonObject(state.plugins) ||
      (Object.hasOwn(state.plugins, pluginName) &&
        (!isJsonObject(state.plugins[pluginName]) ||
          !isJsonObject(state.plugins[pluginName].codex)))
    ) {
      stateUnreadable = true;
      state = null;
    }
  } catch (error) {
    if (filesystemErrorCode(error) !== "ENOENT") stateUnreadable = true;
  }
  let manifest = null;
  try {
    manifest = await readJson(manifestFile);
    if (!isJsonObject(manifest)) {
      stateUnreadable = true;
      manifest = null;
    }
  } catch (error) {
    if (filesystemErrorCode(error) !== "ENOENT") stateUnreadable = true;
  }
  return {
    manifest,
    manifestFile,
    state,
    stateFile,
    unreadable: stateUnreadable,
  };
}

/** @param {string} pluginName @param {{ manifest: unknown, manifestFile: string, state: unknown, stateFile: string, unreadable: boolean }} records */
async function removeLegacyRecords(pluginName, records) {
  let removed = 0;
  if (isJsonObject(records.state) && isJsonObject(records.state.plugins)) {
    const plugins = { ...records.state.plugins };
    delete plugins[pluginName];
    if (Object.keys(plugins).length === 0) {
      if (await removePath(records.stateFile)) removed += 1;
    } else {
      await writeJson(records.stateFile, { ...records.state, plugins });
    }
  }
  if (
    isJsonObject(records.manifest) &&
    (await removePath(records.manifestFile))
  ) {
    removed += 1;
  }
  const manifestsDir = path.dirname(records.manifestFile);
  try {
    await fs.rmdir(manifestsDir);
  } catch (error) {
    if (
      filesystemErrorCode(error) !== "ENOENT" &&
      filesystemErrorCode(error) !== "ENOTEMPTY"
    ) {
      throw error;
    }
  }
  return removed;
}

/**
 * Delete shared helper files whose bytes still match the recorded digest, then
 * drop the directories they leave empty.
 *
 * @param {string} codexHome @param {Record<string, string>} sharedHelperFiles
 */
async function removeOwnedHelpers(codexHome, sharedHelperFiles) {
  let removed = 0;
  /** @type {Set<string>} */
  const parents = new Set();
  for (const [relativePath, digest] of Object.entries(sharedHelperFiles)) {
    const target = tryResolveManagedChild(codexHome, relativePath, "helper");
    if (!target) continue;
    let content;
    try {
      content = await fs.readFile(target);
    } catch (error) {
      if (filesystemErrorCode(error) === "ENOENT") continue;
      throw error;
    }
    if (createHash("sha256").update(content).digest("hex") !== digest) continue;
    await fs.rm(target, { force: true });
    removed += 1;
    parents.add(path.dirname(target));
  }
  for (const parent of parents) {
    await removeEmptyAncestors(parent, codexHome);
  }
  return removed;
}

/** @param {string} directory @param {string} stopAt */
async function removeEmptyAncestors(directory, stopAt) {
  let current = directory;
  while (current !== stopAt && current.startsWith(stopAt + path.sep)) {
    try {
      await fs.rmdir(current);
    } catch {
      return;
    }
    current = path.dirname(current);
  }
}

/** @param {string} file */
async function removeAgentsToolMap(file) {
  let existing;
  try {
    existing = await readText(file);
  } catch (error) {
    if (filesystemErrorCode(error) === "ENOENT") return false;
    throw error;
  }
  const start = existing.indexOf(AGENTS_BLOCK_START);
  const end = existing.indexOf(AGENTS_BLOCK_END);
  if (start === -1 || end === -1 || end < start) return false;
  const before = existing.slice(0, start).trim();
  const after = existing.slice(end + AGENTS_BLOCK_END.length).trim();
  const remaining = [before, after].filter(Boolean).join("\n\n");
  if (remaining.length === 0) {
    await fs.rm(file, { force: true });
  } else {
    await writeText(file, remaining + "\n");
  }
  return true;
}

/** @param {string} target */
async function removePath(target) {
  if (!(await pathExists(target))) return false;
  await fs.rm(target, { force: true, recursive: true });
  return true;
}

/** @param {string} root @param {string} entry @param {string} label */
function tryResolveManagedChild(root, entry, label) {
  try {
    return resolveManagedChild(root, entry, label);
  } catch {
    console.warn(`Ignoring unsafe legacy ${label} entry: ${entry}`);
    return null;
  }
}

/** @returns {LegacyInstallEntries} */
function emptyEntries() {
  return {
    agentSkills: [],
    hookMarketplaces: [],
    pluginCaches: [],
    prompts: [],
    sharedHelperFiles: {},
    skills: [],
  };
}

/** @param {unknown} entries @returns {string[]} */
function sanitizeEntryList(entries) {
  if (!Array.isArray(entries)) return [];
  return entries
    .map((entry) => String(entry ?? "").trim())
    .filter((entry) => entry && !entry.includes("\0"));
}

/** @param {unknown} value @returns {Record<string, string>} */
function sanitizeSharedHelperFiles(value) {
  if (!isJsonObject(value)) return {};
  /** @type {Record<string, string>} */
  const result = {};
  for (const [relativePath, digest] of Object.entries(value)) {
    if (typeof digest !== "string" || !/^[a-f0-9]{64}$/.test(digest)) continue;
    if (
      UNSAFE_HELPER_PATH.test(relativePath) ||
      relativePath
        .split("/")
        .some((part) => !part || part === "." || part === "..")
    )
      continue;
    result[relativePath] = digest;
  }
  return result;
}

/** @param {string[]} left @param {string[]} right */
function union(left, right) {
  return Array.from(new Set([...left, ...right]));
}

module.exports = {
  cleanupLegacyInstall,
  hasLegacyInstall,
  readLegacyInstallEntries,
};
