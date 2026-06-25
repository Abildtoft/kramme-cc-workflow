"use strict";

const fs = require("fs/promises");
const path = require("path");
const { pathExists, readJson, writeJson } = require("./filesystem");

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
    agentSkills: sanitizeEntryList(record?.agentSkills),
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
    };
  }

  try {
    const state = await readJson(filePath);
    if (
      state &&
      typeof state === "object" &&
      state.plugins &&
      typeof state.plugins === "object"
    ) {
      return {
        state,
        fromDisk: true,
      };
    }
  } catch {
    // Ignore invalid state and rebuild from the current install.
  }

  return {
    state: await rebuildInstallStateFromManifests(root),
    fromDisk: false,
  };
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
    return sanitizeInstallRecord(await readJson(filePath));
  } catch {
    // Ignore invalid manifests and rebuild from the current install.
  }

  return null;
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

function unionEntryLists(...lists) {
  return Array.from(
    new Set(lists.flatMap((entries) => sanitizeEntryList(entries))),
  );
}

module.exports = {
  getPreviousInstallEntries,
  loadInstallState,
  sanitizeEntryList,
  setInstallEntries,
  unionEntryLists,
  writeInstallManifest,
  writeInstallState,
};
