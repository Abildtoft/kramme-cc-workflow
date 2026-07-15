"use strict";

const fs = require("fs/promises");
const path = require("path");
const {
  contextualizeFilesystemError,
  filesystemErrorCode,
  isJsonObject,
  pathExists,
  readJson,
  writeJson,
} = require("./filesystem");

/**
 * @typedef {import("./contracts").InstallEntries} InstallEntries
 * @typedef {import("./contracts").InstallState} InstallState
 * @typedef {import("./contracts").ManagedFileMap} ManagedFileMap
 */

/** @returns {InstallState} */
function createInstallState() {
  return {
    version: 1,
    plugins: {},
  };
}

/** @param {unknown} value */
function sanitizeInstallTimestamp(value) {
  const timestamp = Number(value);
  if (!Number.isFinite(timestamp) || timestamp <= 0) return undefined;
  return timestamp;
}

/** @param {unknown} record @returns {InstallEntries} */
function sanitizeInstallRecord(record) {
  const value = isJsonObject(record) ? record : {};
  return {
    hookMarketplaces: sanitizeEntryList(value.hookMarketplaces),
    prompts: sanitizeEntryList(value.prompts),
    pluginCaches: sanitizeEntryList(value.pluginCaches),
    skills: sanitizeEntryList(value.skills),
    skillFiles: sanitizeManagedFileMap(value.skillFiles),
    agentSkills: sanitizeEntryList(value.agentSkills),
    agentSkillFiles: sanitizeManagedFileMap(value.agentSkillFiles),
    updatedAtMs: sanitizeInstallTimestamp(value.updatedAtMs),
  };
}

/** @param {string} filename */
function parseInstallManifestFilename(filename) {
  const match = /^(.*)-codex\.json$/.exec(filename);
  if (!match) return null;

  try {
    return {
      pluginName: decodeURIComponent(match[1]),
      targetName: "codex",
    };
  } catch {
    return null;
  }
}

/** @param {import("fs").Stats} stats */
function getLegacyManifestOrderTimestamp(stats) {
  if (Number.isFinite(stats.birthtimeMs) && stats.birthtimeMs > 0) {
    return stats.birthtimeMs;
  }
  if (Number.isFinite(stats?.mtimeMs) && stats.mtimeMs > 0) {
    return stats.mtimeMs;
  }
  if (Number.isFinite(stats?.ctimeMs) && stats.ctimeMs > 0) {
    return stats.ctimeMs;
  }
  return 0;
}

/** @param {string} root @returns {Promise<InstallState>} */
async function rebuildInstallStateFromManifests(root) {
  const state = createInstallState();
  const manifestsDir = path.join(root, ".kramme-install-manifests");
  if (!(await pathExists(manifestsDir))) return state;

  const entries = await fs.readdir(manifestsDir, { withFileTypes: true });
  /** @type {Array<{ pluginName: string, targetName: string, manifest: InstallEntries, sortKey: number }>} */
  const manifests = [];
  for (const entry of entries) {
    if (!entry.isFile() || path.extname(entry.name) !== ".json") continue;

    const manifestMeta = parseInstallManifestFilename(entry.name);
    if (!manifestMeta) continue;

    const manifest = await loadInstallManifest(
      root,
      manifestMeta.pluginName,
      manifestMeta.targetName,
    );
    if (!manifest) continue;

    let fallbackUpdatedAtMs = 0;
    try {
      const stats = await fs.stat(path.join(manifestsDir, entry.name));
      // Prefer creation time so hand-edited legacy manifests still rebuild in install order.
      fallbackUpdatedAtMs = getLegacyManifestOrderTimestamp(stats);
    } catch {
      // Ignore stat failures and fall back to deterministic filename ordering.
    }

    manifests.push({
      ...manifestMeta,
      manifest,
      sortKey: manifest.updatedAtMs ?? fallbackUpdatedAtMs,
    });
  }

  manifests.sort((left, right) => {
    if (left.sortKey !== right.sortKey) {
      return left.sortKey - right.sortKey;
    }
    if (left.pluginName !== right.pluginName) {
      return left.pluginName.localeCompare(right.pluginName);
    }
    return left.targetName.localeCompare(right.targetName);
  });

  for (const { pluginName, targetName, manifest, sortKey } of manifests) {
    setInstallEntries(
      state,
      pluginName,
      targetName,
      manifest.updatedAtMs === undefined && sortKey > 0
        ? { ...manifest, updatedAtMs: sortKey }
        : manifest,
    );
  }

  return state;
}

/** @param {string} root */
async function loadInstallState(root) {
  const filePath = path.join(root, ".kramme-install-state.json");
  if (!(await pathExists(filePath))) {
    return {
      state: await rebuildInstallStateFromManifests(root),
      fromDisk: false,
      recoveryReason: "missing",
    };
  }

  let state;
  try {
    state = await readJson(filePath);
  } catch (error) {
    if (filesystemErrorCode(error) === "ENOENT") {
      return {
        state: await rebuildInstallStateFromManifests(root),
        fromDisk: false,
        recoveryReason: "missing",
      };
    }
    if (!(error instanceof SyntaxError)) {
      throw contextualizeFilesystemError("read install state", filePath, error);
    }
    return {
      state: await rebuildInstallStateFromManifests(root),
      fromDisk: false,
      recoveryReason: "malformed-json",
    };
  }

  const parsedState = parseInstallState(state);
  if (parsedState) {
    return {
      state: parsedState,
      fromDisk: true,
      recoveryReason: null,
    };
  }

  return {
    state: await rebuildInstallStateFromManifests(root),
    fromDisk: false,
    recoveryReason: "invalid-shape",
  };
}

/** @param {unknown} value @returns {InstallState | null} */
function parseInstallState(value) {
  if (
    !isJsonObject(value) ||
    value.version !== 1 ||
    !isJsonObject(value.plugins)
  ) {
    return null;
  }

  /** @type {Array<[string, Record<string, InstallEntries>]>} */
  const plugins = [];
  for (const [pluginName, targets] of Object.entries(value.plugins)) {
    if (!isJsonObject(targets)) return null;
    /** @type {Array<[string, InstallEntries]>} */
    const parsedTargets = [];
    for (const [targetName, entries] of Object.entries(targets)) {
      if (!isJsonObject(entries)) return null;
      parsedTargets.push([targetName, sanitizeInstallRecord(entries)]);
    }
    plugins.push([pluginName, Object.fromEntries(parsedTargets)]);
  }
  return { version: 1, plugins: Object.fromEntries(plugins) };
}

/** @param {string} root @param {string} pluginName @param {string} targetName */
function getInstallManifestPath(root, pluginName, targetName) {
  return path.join(
    root,
    ".kramme-install-manifests",
    `${encodeURIComponent(pluginName)}-${targetName}.json`,
  );
}

/** @param {string} root @param {string} pluginName @param {string} targetName @returns {Promise<InstallEntries | null>} */
async function loadInstallManifest(root, pluginName, targetName) {
  const filePath = getInstallManifestPath(root, pluginName, targetName);
  if (!(await pathExists(filePath))) return null;

  try {
    const manifest = await readJson(filePath);
    return isJsonObject(manifest) ? sanitizeInstallRecord(manifest) : null;
  } catch (error) {
    if (filesystemErrorCode(error) === "ENOENT" || error instanceof SyntaxError)
      return null;
    throw contextualizeFilesystemError(
      "read install manifest",
      filePath,
      error,
    );
  }
}

/** @param {string} root @param {string} pluginName @param {string} targetName @param {unknown} entries */
async function writeInstallManifest(root, pluginName, targetName, entries) {
  await writeJson(
    getInstallManifestPath(root, pluginName, targetName),
    sanitizeInstallRecord(entries),
  );
}

/** @param {string} root @param {InstallState} state */
async function writeInstallState(root, state) {
  await writeJson(path.join(root, ".kramme-install-state.json"), state);
}

/** @param {InstallState} state @param {string} pluginName @param {string} targetName */
function getInstallEntries(state, pluginName, targetName) {
  const targetState = state.plugins?.[pluginName]?.[targetName];
  return sanitizeInstallRecord(targetState);
}

/** @param {string} root @param {InstallState} state @param {string} pluginName @param {string} targetName */
async function getPreviousInstallEntries(root, state, pluginName, targetName) {
  if (state.plugins?.[pluginName]?.[targetName]) {
    return getInstallEntries(state, pluginName, targetName);
  }
  const manifest = await loadInstallManifest(root, pluginName, targetName);
  return manifest ?? getInstallEntries(state, pluginName, targetName);
}

/** @param {InstallState} state @param {string} pluginName @param {string} targetName @param {unknown} entries */
function setInstallEntries(state, pluginName, targetName, entries) {
  if (!state.plugins || typeof state.plugins !== "object") {
    state.plugins = {};
  }
  if (
    !state.plugins[pluginName] ||
    typeof state.plugins[pluginName] !== "object"
  ) {
    state.plugins[pluginName] = {};
  }
  state.plugins[pluginName][targetName] = sanitizeInstallRecord(entries);
}

/** @param {unknown} entries @returns {string[]} */
function sanitizeEntryList(entries) {
  if (!Array.isArray(entries)) return [];
  return entries.map((entry) => String(entry ?? "").trim()).filter(Boolean);
}

/** @param {unknown} filesByEntry @returns {ManagedFileMap} */
function sanitizeManagedFileMap(filesByEntry) {
  if (
    !filesByEntry ||
    typeof filesByEntry !== "object" ||
    Array.isArray(filesByEntry)
  ) {
    return {};
  }

  /** @type {ManagedFileMap} */
  const result = {};
  for (const [entry, files] of Object.entries(filesByEntry)) {
    const normalizedEntry = String(entry ?? "").trim();
    if (!normalizedEntry) continue;
    result[normalizedEntry] = sanitizeManagedFileList(files);
  }
  return result;
}

/** @param {unknown} files @returns {string[]} */
function sanitizeManagedFileList(files) {
  if (!Array.isArray(files)) return [];
  return Array.from(
    new Set(
      files
        .map((file) => normalizeManagedFilePath(file))
        .filter((file) => file !== null),
    ),
  ).sort();
}

/** @param {unknown} file */
function normalizeManagedFilePath(file) {
  const normalized = String(file ?? "")
    .trim()
    .replace(/\\/g, "/");
  if (!normalized || path.posix.isAbsolute(normalized)) return null;

  const parts = normalized.split("/");
  if (parts.some((part) => !part || part === "." || part === "..")) {
    return null;
  }
  return parts.join("/");
}

/** @param {...unknown} lists @returns {string[]} */
function unionEntryLists(...lists) {
  return Array.from(
    new Set(lists.flatMap((entries) => sanitizeEntryList(entries))),
  );
}

module.exports = {
  getInstallManifestPath,
  getPreviousInstallEntries,
  loadInstallState,
  sanitizeEntryList,
  sanitizeManagedFileList,
  setInstallEntries,
  unionEntryLists,
  writeInstallManifest,
  writeInstallState,
};
