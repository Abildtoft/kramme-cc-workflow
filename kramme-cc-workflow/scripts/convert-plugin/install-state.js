"use strict";

const fs = require("fs/promises");
const path = require("path");
const {
  contextualizeFilesystemError,
  pathExists,
  readJson,
  writeJson,
} = require("./filesystem");

function createInstallState() {
  return {
    version: 1,
    plugins: {},
  };
}

function sanitizeInstallTimestamp(value) {
  const timestamp = Number(value);
  if (!Number.isFinite(timestamp) || timestamp <= 0) return undefined;
  return timestamp;
}

function sanitizeInstallRecord(record) {
  return {
    hookMarketplaces: sanitizeEntryList(record?.hookMarketplaces),
    prompts: sanitizeEntryList(record?.prompts),
    pluginCaches: sanitizeEntryList(record?.pluginCaches),
    skills: sanitizeEntryList(record?.skills),
    skillFiles: sanitizeManagedFileMap(record?.skillFiles),
    agentSkills: sanitizeEntryList(record?.agentSkills),
    agentSkillFiles: sanitizeManagedFileMap(record?.agentSkillFiles),
    updatedAtMs: sanitizeInstallTimestamp(record?.updatedAtMs),
  };
}

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

function getLegacyManifestOrderTimestamp(stats) {
  if (Number.isFinite(stats?.birthtimeMs) && stats.birthtimeMs > 0) {
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

async function rebuildInstallStateFromManifests(root) {
  const state = createInstallState();
  const manifestsDir = path.join(root, ".kramme-install-manifests");
  if (!(await pathExists(manifestsDir))) return state;

  const entries = await fs.readdir(manifestsDir, { withFileTypes: true });
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
    if (error?.code === "ENOENT") {
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

  if (isInstallState(state)) {
    return {
      state,
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

function isInstallState(state) {
  return isRecord(state) && isRecord(state.plugins);
}

function isRecord(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function getInstallManifestPath(root, pluginName, targetName) {
  return path.join(
    root,
    ".kramme-install-manifests",
    `${encodeURIComponent(pluginName)}-${targetName}.json`,
  );
}

async function loadInstallManifest(root, pluginName, targetName) {
  const filePath = getInstallManifestPath(root, pluginName, targetName);
  if (!(await pathExists(filePath))) return null;

  try {
    const manifest = await readJson(filePath);
    return isRecord(manifest) ? sanitizeInstallRecord(manifest) : null;
  } catch (error) {
    if (error?.code === "ENOENT" || error instanceof SyntaxError) return null;
    throw contextualizeFilesystemError(
      "read install manifest",
      filePath,
      error,
    );
  }
}

async function writeInstallManifest(root, pluginName, targetName, entries) {
  await writeJson(
    getInstallManifestPath(root, pluginName, targetName),
    sanitizeInstallRecord(entries),
  );
}

async function writeInstallState(root, state) {
  await writeJson(path.join(root, ".kramme-install-state.json"), state);
}

function getInstallEntries(state, pluginName, targetName) {
  const targetState = state.plugins?.[pluginName]?.[targetName];
  return sanitizeInstallRecord(targetState);
}

async function getPreviousInstallEntries(root, state, pluginName, targetName) {
  if (state.plugins?.[pluginName]?.[targetName]) {
    return getInstallEntries(state, pluginName, targetName);
  }
  const manifest = await loadInstallManifest(root, pluginName, targetName);
  return manifest ?? getInstallEntries(state, pluginName, targetName);
}

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

function sanitizeEntryList(entries) {
  if (!Array.isArray(entries)) return [];
  return entries.map((entry) => String(entry ?? "").trim()).filter(Boolean);
}

function sanitizeManagedFileMap(filesByEntry) {
  if (
    !filesByEntry ||
    typeof filesByEntry !== "object" ||
    Array.isArray(filesByEntry)
  ) {
    return {};
  }

  const result = {};
  for (const [entry, files] of Object.entries(filesByEntry)) {
    const normalizedEntry = String(entry ?? "").trim();
    if (!normalizedEntry) continue;
    result[normalizedEntry] = sanitizeManagedFileList(files);
  }
  return result;
}

function sanitizeManagedFileList(files) {
  if (!Array.isArray(files)) return [];
  return Array.from(
    new Set(files.map((file) => normalizeManagedFilePath(file)).filter(Boolean)),
  ).sort();
}

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

function unionEntryLists(...lists) {
  return Array.from(
    new Set(lists.flatMap((entries) => sanitizeEntryList(entries))),
  );
}

module.exports = {
  getPreviousInstallEntries,
  loadInstallState,
  sanitizeEntryList,
  sanitizeManagedFileList,
  setInstallEntries,
  unionEntryLists,
  writeInstallManifest,
  writeInstallState,
};
