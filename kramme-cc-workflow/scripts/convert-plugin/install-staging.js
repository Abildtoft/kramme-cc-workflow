"use strict";

const fs = require("fs/promises");
const path = require("path");
const { normalizeName } = require("./frontmatter");
const { confirm } = require("./confirm");
const {
  sanitizeEntryList,
  sanitizeManagedFileList,
} = require("./install-state");
const {
  copyDir,
  copyFile,
  ensureDir,
  pathExists,
  resolveManagedChild,
} = require("./filesystem");

/**
 * @typedef {Object} ConfirmOptions
 * @property {boolean} [yes]
 * @property {boolean} [nonInteractive]
 *
 * @typedef {Object} StagedDirInstallOptions
 * @property {string[]} [currentManagedFiles]
 * @property {string} [label]
 * @property {string[]} [previousManagedFiles]
 * @property {boolean} [replace]
 *
 * @typedef {Object} StagedFileInstallOptions
 * @property {string} [label]
 * @property {boolean} [replace]
 *
 * @typedef {Object} PruneStaleManagedFilesOptions
 * @property {string} [label]
 *
 * @typedef {Object} CleanupKrammeComponentsOptions
 * @property {string} [label]
 * @property {(entry: import("fs").Dirent) => boolean} [filter]
 * @property {boolean} [recursive]
 * @property {string[]} [prefixes]
 * @property {ConfirmOptions} [confirmOptions]
 *
 * @typedef {Object} CleanupInstalledEntriesOptions
 * @property {string} [label]
 * @property {boolean} [recursive]
 * @property {ConfirmOptions} [confirmOptions]
 */

async function createInstallStagingRoot(baseRoot, pluginName, label) {
  await ensureDir(baseRoot);
  const nonce = Math.random().toString(16).slice(2);
  const stagingRoot = path.join(
    baseRoot,
    ".kramme-install-staging",
    `${normalizeName(pluginName)}-${label}-${Date.now()}-${process.pid}-${nonce}`,
  );
  await ensureDir(stagingRoot);
  return stagingRoot;
}

async function removeInstallStagingRoot(stagingRoot) {
  if (!stagingRoot) return;
  await fs.rm(stagingRoot, { recursive: true, force: true });
  try {
    await fs.rmdir(path.dirname(stagingRoot));
  } catch {
    // Another concurrent install may still have a sibling staging directory.
  }
}

/**
 * @param {string} stagedDir
 * @param {string} targetDir
 * @param {StagedDirInstallOptions} [options]
 */
async function preflightStagedDirInstall(
  stagedDir,
  targetDir,
  {
    currentManagedFiles,
    label = "directory",
    previousManagedFiles,
    replace = false,
  } = {},
) {
  if (
    !(await pathExists(stagedDir)) ||
    replace ||
    !(await pathExists(targetDir))
  ) {
    return;
  }
  const targetStats = await fs.lstat(targetDir);
  if (!targetStats.isDirectory()) {
    throw new Error(
      `Cannot install ${label} because ${targetDir} is not a directory.`,
    );
  }

  await preflightStagedDirMerge(stagedDir, targetDir, "", {
    label,
    staleManagedFiles: staleManagedFileSet(
      previousManagedFiles,
      currentManagedFiles,
    ),
  });
}

/**
 * @param {string} stagedFile
 * @param {string} targetFile
 * @param {StagedFileInstallOptions} [options]
 */
async function preflightStagedFileInstall(
  stagedFile,
  targetFile,
  { label = "file", replace = false } = {},
) {
  if (
    !(await pathExists(stagedFile)) ||
    replace ||
    !(await pathExists(targetFile))
  ) {
    return;
  }
  const targetStats = await fs.lstat(targetFile);
  if (targetStats.isDirectory()) {
    throw new Error(
      `Cannot install ${label} because ${targetFile} is a directory.`,
    );
  }
}

async function installStagedDir(stagedDir, targetDir, { replace = false } = {}) {
  if (!(await pathExists(stagedDir))) return;
  if (replace) {
    await fs.rm(targetDir, { recursive: true, force: true });
  }
  await ensureDir(path.dirname(targetDir));
  if (replace || !(await pathExists(targetDir))) {
    try {
      await fs.rename(stagedDir, targetDir);
      return;
    } catch (error) {
      if (error.code !== "EXDEV") throw error;
    }
  }
  await copyDir(stagedDir, targetDir);
  await fs.rm(stagedDir, { recursive: true, force: true });
}

/**
 * @param {string} targetDir
 * @param {string[] | undefined} previousFiles
 * @param {string[] | undefined} currentFiles
 * @param {PruneStaleManagedFilesOptions} [options]
 */
async function pruneStaleManagedFiles(
  targetDir,
  previousFiles,
  currentFiles,
  { label = "directory" } = {},
) {
  for (const relativeFile of staleManagedFileSet(previousFiles, currentFiles)) {
    const targetPath = resolveManagedChild(
      targetDir,
      relativeFile,
      `${label} managed file`,
    );
    if (!(await hasSafeManagedAncestorDirs(targetDir, targetPath))) continue;

    let stats;
    try {
      stats = await fs.lstat(targetPath);
    } catch (error) {
      if (error.code === "ENOENT") continue;
      throw error;
    }

    if (!stats.isFile() && !stats.isSymbolicLink()) continue;
    await fs.rm(targetPath, { force: true });
    await removeEmptyAncestorDirs(path.dirname(targetPath), targetDir);
  }
}

function staleManagedFileSet(previousFiles, currentFiles) {
  const currentFileSet = new Set(sanitizeManagedFileList(currentFiles));
  return new Set(
    sanitizeManagedFileList(previousFiles).filter(
      (relativeFile) => !currentFileSet.has(relativeFile),
    ),
  );
}

async function preflightStagedDirMerge(
  stagedDir,
  targetDir,
  prefix,
  { label, staleManagedFiles },
) {
  const entries = await fs.readdir(stagedDir, { withFileTypes: true });
  for (const entry of entries) {
    const relativePath = prefix ? `${prefix}/${entry.name}` : entry.name;
    const stagedPath = path.join(stagedDir, entry.name);
    const targetPath = path.join(targetDir, entry.name);
    const targetStats = await lstatAfterManagedPrune(
      targetPath,
      relativePath,
      staleManagedFiles,
    );

    if (entry.isDirectory()) {
      if (!targetStats) continue;
      if (!targetStats.isDirectory()) {
        throw new Error(
          `Cannot install ${label} because ${targetPath} conflicts with staged directory ${relativePath}.`,
        );
      }
      await preflightStagedDirMerge(stagedPath, targetPath, relativePath, {
        label,
        staleManagedFiles,
      });
      continue;
    }

    if (!entry.isFile() || !targetStats?.isDirectory()) continue;

    const removableDirectory = await directoryRemovedByManagedPrune(
      targetPath,
      relativePath,
      staleManagedFiles,
    );
    if (!removableDirectory) {
      throw new Error(
        `Cannot install ${label} because ${targetPath} conflicts with staged file ${relativePath}.`,
      );
    }
  }
}

async function lstatAfterManagedPrune(
  targetPath,
  relativePath,
  staleManagedFiles,
) {
  let stats;
  try {
    stats = await fs.lstat(targetPath);
  } catch (error) {
    if (error.code === "ENOENT") return null;
    throw error;
  }
  if (
    staleManagedFiles.has(relativePath) &&
    (stats.isFile() || stats.isSymbolicLink())
  ) {
    return null;
  }
  return stats;
}

async function directoryRemovedByManagedPrune(
  dirPath,
  relativeDir,
  staleManagedFiles,
) {
  const result = await inspectDirectoryForManagedPrune(
    dirPath,
    relativeDir,
    staleManagedFiles,
  );
  return result.removed;
}

async function inspectDirectoryForManagedPrune(
  dirPath,
  relativeDir,
  staleManagedFiles,
) {
  const entries = await fs.readdir(dirPath, { withFileTypes: true });
  let hasStaleManagedFile = false;
  for (const entry of entries) {
    const relativePath = `${relativeDir}/${entry.name}`;
    const fullPath = path.join(dirPath, entry.name);
    if (entry.isDirectory()) {
      const child = await inspectDirectoryForManagedPrune(
        fullPath,
        relativePath,
        staleManagedFiles,
      );
      if (!child.removed) return { removed: false };
      hasStaleManagedFile = hasStaleManagedFile || child.hasStaleManagedFile;
      continue;
    }

    if (
      (entry.isFile() || entry.isSymbolicLink()) &&
      staleManagedFiles.has(relativePath)
    ) {
      hasStaleManagedFile = true;
      continue;
    }

    return { removed: false };
  }

  return {
    hasStaleManagedFile,
    removed: hasStaleManagedFile,
  };
}

async function hasSafeManagedAncestorDirs(rootDir, targetPath) {
  const resolvedRoot = path.resolve(rootDir);
  const targetDir = path.dirname(path.resolve(targetPath));
  const dirs = [];

  try {
    const rootStats = await fs.lstat(resolvedRoot);
    if (!rootStats.isDirectory()) return false;
  } catch (error) {
    if (error.code === "ENOENT") return false;
    throw error;
  }

  let current = targetDir;
  while (current !== resolvedRoot) {
    if (!current.startsWith(resolvedRoot + path.sep)) return false;
    dirs.push(current);
    current = path.dirname(current);
  }

  for (const dir of dirs.reverse()) {
    let stats;
    try {
      stats = await fs.lstat(dir);
    } catch (error) {
      if (error.code === "ENOENT") return false;
      throw error;
    }
    if (!stats.isDirectory()) return false;
  }

  return true;
}

async function removeEmptyAncestorDirs(startDir, rootDir) {
  const resolvedRoot = path.resolve(rootDir);
  let current = path.resolve(startDir);

  while (current !== resolvedRoot && current.startsWith(resolvedRoot + path.sep)) {
    try {
      await fs.rmdir(current);
    } catch {
      return;
    }
    current = path.dirname(current);
  }
}

async function installStagedFile(
  stagedFile,
  targetFile,
  { replace = false } = {},
) {
  if (!(await pathExists(stagedFile))) return;
  if (replace) {
    await fs.rm(targetFile, { force: true });
  }
  await ensureDir(path.dirname(targetFile));
  try {
    await fs.rename(stagedFile, targetFile);
    return;
  } catch (error) {
    if (error.code !== "EXDEV") throw error;
  }
  await copyFile(stagedFile, targetFile);
  await fs.rm(stagedFile, { force: true });
}

/**
 * @param {string} dir
 * @param {CleanupKrammeComponentsOptions} [options]
 */
async function cleanupKrammeComponents(
  dir,
  {
    label,
    filter,
    recursive = false,
    prefixes = ["kramme:", "kramme-"],
    confirmOptions = {},
  } = {},
) {
  if (!(await pathExists(dir))) return;
  const entries = await fs.readdir(dir, { withFileTypes: true });
  const matched = entries
    .filter(/** @type {(entry: import("fs").Dirent) => boolean} */ (filter))
    .filter((entry) => prefixes.some((prefix) => entry.name.startsWith(prefix)))
    .map((entry) => entry.name);

  if (matched.length === 0) return;

  console.log(
    `\nFound ${matched.length} existing kramme ${label}(s) in ${dir}:`,
  );
  for (const name of matched) {
    console.log(`  - ${name}`);
  }

  const confirmed = await confirm(
    `Delete these ${label}s before installing?`,
    confirmOptions,
  );
  if (!confirmed) {
    console.log(`Skipping ${label} cleanup.`);
    return;
  }

  for (const name of matched) {
    await fs.rm(path.join(dir, name), { recursive, force: true });
  }
  console.log(`Deleted ${matched.length} ${label}(s).`);
}

/**
 * @param {string} dir
 * @param {string[] | undefined} entries
 * @param {CleanupInstalledEntriesOptions} [options]
 */
async function cleanupInstalledEntries(
  dir,
  entries,
  { label, recursive = false, confirmOptions = {} } = {},
) {
  const matched = [];
  for (const entry of sanitizeEntryList(entries)) {
    const targetPath = resolveManagedChild(dir, entry, `${label} entry`);
    if (await pathExists(targetPath)) {
      matched.push({ name: entry, path: targetPath });
    }
  }

  if (matched.length === 0) return true;

  console.log(
    `\nFound ${matched.length} existing ${label}(s) from this plugin in ${dir}:`,
  );
  for (const { name } of matched) {
    console.log(`  - ${name}`);
  }

  const confirmed = await confirm(
    `Delete these ${label}s before installing?`,
    confirmOptions,
  );
  if (!confirmed) {
    console.log(`Skipping ${label} cleanup.`);
    return false;
  }

  for (const { path: targetPath } of matched) {
    await fs.rm(targetPath, { recursive, force: true });
  }
  console.log(`Deleted ${matched.length} ${label}(s).`);
  return true;
}

module.exports = {
  cleanupInstalledEntries,
  cleanupKrammeComponents,
  createInstallStagingRoot,
  installStagedDir,
  installStagedFile,
  preflightStagedDirInstall,
  preflightStagedFileInstall,
  pruneStaleManagedFiles,
  removeInstallStagingRoot,
};
