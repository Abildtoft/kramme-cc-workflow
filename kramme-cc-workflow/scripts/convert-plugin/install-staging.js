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
  prepareTransactionMutation,
  publishStagedFile,
  recordInstalledTargetForRollback,
  withInstallTransaction,
} = require("./install-transaction");
const {
  copyDir,
  ensureDir,
  expectedContentBuffer,
  fileContentEquals,
  filesystemErrorCode,
  lstatIfExists,
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
 * @property {string[]} [previousManagedRoots]
 * @property {boolean} [replace]
 *
 * @typedef {Object} StagedFileInstallOptions
 * @property {ExpectedTargetContent} [expectedTargetContent]
 * @property {string} [label]
 * @property {string[]} [previousManagedFiles]
 * @property {boolean} [replace]
 *
 * @typedef {Object} InstallStagedDirOptions
 * @property {ExpectedTargetEntries} [expectedTargetEntries]
 * @property {string} [label]
 * @property {boolean} [replace]
 *
 * @typedef {Object} InstallStagedFileOptions
 * @property {ExpectedTargetContent} [expectedTargetContent]
 * @property {ExpectedTargetIdentity} [expectedTargetIdentity]
 * @property {string} [label]
 * @property {boolean} [preserveTargetChangesOnRollback]
 * @property {boolean} [replace]
 *
 * @typedef {Object} PruneStaleManagedFilesOptions
 * @property {string} [label]
 *
 * @typedef {Object} CleanupKrammeComponentsOptions
 * @property {string} [label]
 * @property {(entry: import("fs").Dirent) => boolean} [filter]
 * @property {string[]} [prefixes]
 * @property {ConfirmOptions} [confirmOptions]
 *
 * @typedef {Object} CleanupInstalledEntriesOptions
 * @property {string} [label]
 * @property {ConfirmOptions} [confirmOptions]
 *
 * @typedef {Buffer | string | null} ExpectedTargetContent
 * @typedef {{ ctimeMs?: number, device: number, gid?: number, inode: number, links: number, mode?: number, uid?: number }} ExpectedTargetIdentity
 * @typedef {{ kind: "directory" } | { kind: "file", content: Buffer } | { kind: "missing" }} ExpectedTargetEntry
 * @typedef {Map<string, ExpectedTargetEntry>} ExpectedTargetEntries
 * @typedef {{ expectedTargetContent?: ExpectedTargetContent, expectedTargetEntries?: ExpectedTargetEntries, expectedTargetIdentity?: ExpectedTargetIdentity, record: { operation: string, target: string, backup: string | null }, recordIndex: number, target: string, targetExists: boolean }} PreparedTransactionMutation
 * @typedef {{ removed: boolean, hasStaleManagedFile?: boolean }} ManagedPruneInspection
 */

/** @param {string} baseRoot @param {string} pluginName @param {string} label */
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

/** @param {string | null | undefined} stagingRoot */
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
 * @returns {Promise<ExpectedTargetEntries | undefined>}
 */
async function preflightStagedDirInstall(
  stagedDir,
  targetDir,
  {
    currentManagedFiles,
    label = "directory",
    previousManagedFiles,
    previousManagedRoots = [],
    replace = false,
  } = {},
) {
  if (!(await pathExists(stagedDir)) || replace) return undefined;
  /** @type {ExpectedTargetEntries} */
  const expectedTargetEntries = new Map();
  if (!(await pathExists(targetDir))) {
    expectedTargetEntries.set("", { kind: "missing" });
    return expectedTargetEntries;
  }
  const targetStats = await fs.lstat(targetDir);
  if (!targetStats.isDirectory()) {
    throw new Error(
      `Cannot install ${label} because ${targetDir} is not a directory.`,
    );
  }
  expectedTargetEntries.set("", { kind: "directory" });

  await preflightStagedDirMerge(stagedDir, targetDir, "", {
    expectedTargetEntries,
    label,
    previousManagedFiles: new Set(
      sanitizeManagedFileList(previousManagedFiles),
    ),
    previousManagedRoots,
    staleManagedFiles: staleManagedFileSet(
      previousManagedFiles,
      currentManagedFiles,
    ),
  });
  return expectedTargetEntries;
}

/**
 * @param {string} stagedFile
 * @param {string} targetFile
 * @param {StagedFileInstallOptions} [options]
 * @returns {Promise<Buffer | null | undefined>}
 */
async function preflightStagedFileInstall(
  stagedFile,
  targetFile,
  {
    expectedTargetContent,
    label = "file",
    previousManagedFiles = [],
    replace = false,
  } = {},
) {
  if (!(await pathExists(stagedFile))) return undefined;
  if (!(await pathExists(targetFile))) return null;
  const targetStats = await fs.lstat(targetFile);
  if (targetStats.isDirectory()) {
    throw new Error(
      `Cannot install ${label} because ${targetFile} is a directory.`,
    );
  }
  if (!targetStats.isFile()) {
    throw new Error(
      `Cannot install ${label} because ${targetFile} is not a regular file.`,
    );
  }
  const targetContent = await fs.readFile(targetFile);
  if (
    replace ||
    (expectedTargetContent !== undefined &&
      expectedTargetContent !== null &&
      targetContent.equals(expectedContentBuffer(expectedTargetContent))) ||
    (await regularFilesAreIdentical(stagedFile, targetFile)) ||
    (await matchesAnyManagedFile(targetFile, previousManagedFiles))
  ) {
    return targetContent;
  }
  if (expectedTargetContent !== undefined) {
    throw new Error(
      `Cannot install ${label} because ${targetFile} changed during installation.`,
    );
  }
  throw new Error(
    `Cannot install ${label} because ${targetFile} is a non-identical unowned file.`,
  );
}

/**
 * @param {string} stagedDir
 * @param {string} targetDir
 * @param {InstallStagedDirOptions} [options]
 */
async function installStagedDir(
  stagedDir,
  targetDir,
  { expectedTargetEntries, label = "directory", replace = false } = {},
) {
  if (!(await pathExists(stagedDir))) return;
  const transactional = await prepareTransactionMutation(targetDir, {
    expectedTargetEntries,
    label,
    preserveExisting: !replace,
  });
  if (replace && !transactional) {
    await fs.rm(targetDir, { recursive: true, force: true });
  }
  await ensureDir(path.dirname(targetDir));
  if (replace || !(await pathExists(targetDir))) {
    try {
      await fs.rename(stagedDir, targetDir);
      return;
    } catch (error) {
      if (filesystemErrorCode(error) !== "EXDEV") throw error;
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
  await prepareTransactionMutation(targetDir, { preserveExisting: true });
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
      if (filesystemErrorCode(error) === "ENOENT") continue;
      throw error;
    }

    if (!stats.isFile() && !stats.isSymbolicLink()) continue;
    await fs.rm(targetPath, { force: true });
    await removeEmptyAncestorDirs(path.dirname(targetPath), targetDir);
  }
}

/** @param {unknown} previousFiles @param {unknown} currentFiles @returns {Set<string>} */
function staleManagedFileSet(previousFiles, currentFiles) {
  const currentFileSet = new Set(sanitizeManagedFileList(currentFiles));
  return new Set(
    sanitizeManagedFileList(previousFiles).filter(
      (relativeFile) => !currentFileSet.has(relativeFile),
    ),
  );
}

/**
 * @param {string} stagedDir
 * @param {string} targetDir
 * @param {string} prefix
 * @param {{ expectedTargetEntries: ExpectedTargetEntries, label: string, previousManagedFiles: Set<string>, previousManagedRoots: string[], staleManagedFiles: Set<string> }} options
 */
async function preflightStagedDirMerge(
  stagedDir,
  targetDir,
  prefix,
  {
    expectedTargetEntries,
    label,
    previousManagedFiles,
    previousManagedRoots,
    staleManagedFiles,
  },
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
      if (!targetStats) {
        expectedTargetEntries.set(relativePath, { kind: "missing" });
        continue;
      }
      if (!targetStats.isDirectory()) {
        throw new Error(
          `Cannot install ${label} because ${targetPath} conflicts with staged directory ${relativePath}.`,
        );
      }
      expectedTargetEntries.set(relativePath, { kind: "directory" });
      await preflightStagedDirMerge(stagedPath, targetPath, relativePath, {
        expectedTargetEntries,
        label,
        previousManagedFiles,
        previousManagedRoots,
        staleManagedFiles,
      });
      continue;
    }

    if (!entry.isFile()) continue;
    if (!targetStats) {
      expectedTargetEntries.set(relativePath, { kind: "missing" });
      continue;
    }
    if (targetStats.isDirectory()) {
      const removableDirectory = await directoryRemovedByManagedPrune(
        targetPath,
        relativePath,
        staleManagedFiles,
      );
      if (removableDirectory) {
        expectedTargetEntries.set(relativePath, { kind: "missing" });
        continue;
      }
      throw new Error(
        `Cannot install ${label} because ${targetPath} conflicts with staged file ${relativePath}.`,
      );
    }
    const targetContent = targetStats.isFile()
      ? await fs.readFile(targetPath)
      : null;
    if (
      targetContent &&
      (previousManagedFiles.has(relativePath) ||
        (await fileContentEquals(stagedPath, targetContent)) ||
        (await contentMatchesAnyManagedFile(
          targetContent,
          previousManagedRoots.map((root) => path.join(root, relativePath)),
        )))
    ) {
      expectedTargetEntries.set(relativePath, {
        content: targetContent,
        kind: "file",
      });
      continue;
    }
    throw new Error(
      `Cannot install ${label} because ${targetPath} is a non-identical unowned file.`,
    );
  }
}

/** @param {Buffer} targetContent @param {string[]} managedFiles */
async function contentMatchesAnyManagedFile(targetContent, managedFiles) {
  for (const managedFile of managedFiles) {
    const stats = await lstatIfExists(managedFile);
    if (
      stats?.isFile() &&
      (await fileContentEquals(managedFile, targetContent))
    ) {
      return true;
    }
  }
  return false;
}

/** @param {string} targetFile @param {string[]} managedFiles */
async function matchesAnyManagedFile(targetFile, managedFiles) {
  for (const managedFile of managedFiles) {
    if (await regularFilesAreIdentical(targetFile, managedFile)) return true;
  }
  return false;
}

/** @param {string} leftFile @param {string} rightFile */
async function regularFilesAreIdentical(leftFile, rightFile) {
  const [leftStats, rightStats] = await Promise.all([
    lstatIfExists(leftFile),
    lstatIfExists(rightFile),
  ]);
  if (!leftStats?.isFile() || !rightStats?.isFile()) return false;
  const [left, right] = await Promise.all([
    fs.readFile(leftFile),
    fs.readFile(rightFile),
  ]);
  return left.equals(right);
}

/** @param {string} targetPath @param {string} relativePath @param {Set<string>} staleManagedFiles */
async function lstatAfterManagedPrune(
  targetPath,
  relativePath,
  staleManagedFiles,
) {
  let stats;
  try {
    stats = await fs.lstat(targetPath);
  } catch (error) {
    if (filesystemErrorCode(error) === "ENOENT") return null;
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

/** @param {string} dirPath @param {string} relativeDir @param {Set<string>} staleManagedFiles */
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

/**
 * @param {string} dirPath
 * @param {string} relativeDir
 * @param {Set<string>} staleManagedFiles
 * @returns {Promise<ManagedPruneInspection>}
 */
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
      hasStaleManagedFile =
        hasStaleManagedFile || Boolean(child.hasStaleManagedFile);
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

/** @param {string} rootDir @param {string} targetPath */
async function hasSafeManagedAncestorDirs(rootDir, targetPath) {
  const resolvedRoot = path.resolve(rootDir);
  const targetDir = path.dirname(path.resolve(targetPath));
  const dirs = [];

  try {
    const rootStats = await fs.lstat(resolvedRoot);
    if (!rootStats.isDirectory()) return false;
  } catch (error) {
    if (filesystemErrorCode(error) === "ENOENT") return false;
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
      if (filesystemErrorCode(error) === "ENOENT") return false;
      throw error;
    }
    if (!stats.isDirectory()) return false;
  }

  return true;
}

/** @param {string} startDir @param {string} rootDir */
async function removeEmptyAncestorDirs(startDir, rootDir) {
  const resolvedRoot = path.resolve(rootDir);
  let current = path.resolve(startDir);

  while (
    current !== resolvedRoot &&
    current.startsWith(resolvedRoot + path.sep)
  ) {
    try {
      await fs.rmdir(current);
    } catch {
      return;
    }
    current = path.dirname(current);
  }
}

/**
 * @param {string} stagedFile
 * @param {string} targetFile
 * @param {InstallStagedFileOptions} [options]
 */
async function installStagedFile(
  stagedFile,
  targetFile,
  {
    expectedTargetContent,
    expectedTargetIdentity,
    label = "file",
    preserveTargetChangesOnRollback = false,
    replace = false,
  } = {},
) {
  if (!(await pathExists(stagedFile))) return;
  const installedContent = preserveTargetChangesOnRollback
    ? await fs.readFile(stagedFile)
    : null;
  const transactional = await prepareTransactionMutation(targetFile, {
    expectedTargetContent,
    expectedTargetIdentity,
    label,
  });
  if (replace && !transactional) {
    await fs.rm(targetFile, { force: true });
  }
  await ensureDir(path.dirname(targetFile));
  const mutation =
    transactional ||
    /** @type {PreparedTransactionMutation} */ ({
      record: {
        operation: "create",
        target: path.resolve(targetFile),
        backup: null,
      },
      recordIndex: 0,
      target: path.resolve(targetFile),
      targetExists: false,
    });
  await publishStagedFile(stagedFile, mutation, label);
  if (installedContent !== null) {
    await recordInstalledTargetForRollback(
      targetFile,
      installedContent,
      mutation,
    );
  }
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
    const targetPath = path.join(dir, name);
    if (!(await prepareTransactionMutation(targetPath))) {
      await fs.rm(targetPath, { recursive: true, force: true });
    }
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
  { label, confirmOptions = {} } = {},
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
    if (!(await prepareTransactionMutation(targetPath))) {
      await fs.rm(targetPath, { recursive: true, force: true });
    }
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
  withInstallTransaction,
};
