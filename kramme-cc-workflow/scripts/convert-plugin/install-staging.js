"use strict";

const fs = require("fs/promises");
const path = require("path");
const { normalizeName } = require("./frontmatter");
const { confirm } = require("./confirm");
const { sanitizeEntryList } = require("./install-state");
const {
  copyDir,
  copyFile,
  ensureDir,
  pathExists,
  resolveManagedChild,
} = require("./filesystem");

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

async function preflightStagedDirInstall(
  stagedDir,
  targetDir,
  { label = "directory", replace = false } = {},
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
}

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
    .filter(filter)
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
  removeInstallStagingRoot,
};
