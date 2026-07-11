"use strict";

const fs = require("fs/promises");
const path = require("path");

function resolveManagedChild(root, entry, label) {
  const resolvedRoot = path.resolve(root);
  const resolvedPath = path.resolve(root, entry);
  if (
    resolvedPath === resolvedRoot ||
    !resolvedPath.startsWith(resolvedRoot + path.sep)
  ) {
    throw new Error(`Invalid ${label}: ${entry}`);
  }
  return resolvedPath;
}

function resolveWithinRoot(root, entry, label) {
  const resolvedRoot = path.resolve(root);
  const resolvedPath = path.resolve(root, entry);
  if (
    resolvedPath === resolvedRoot ||
    resolvedPath.startsWith(resolvedRoot + path.sep)
  ) {
    return resolvedPath;
  }
  throw new Error(
    `Invalid ${label}: ${entry}. Paths must stay within the plugin root.`,
  );
}

async function readText(file) {
  return fs.readFile(file, "utf8");
}

async function writeText(file, content) {
  await ensureDir(path.dirname(file));
  await fs.writeFile(file, content, "utf8");
}

async function readJson(file) {
  const raw = await readText(file);
  return JSON.parse(raw);
}

async function writeJson(file, data) {
  const content = JSON.stringify(data, null, 2) + "\n";
  await writeText(file, content);
}

async function ensureDir(dir) {
  await fs.mkdir(dir, { recursive: true });
}

async function pathExists(filePath) {
  try {
    await fs.access(filePath);
    return true;
  } catch (error) {
    if (error?.code === "ENOENT") return false;
    throw contextualizeFilesystemError("check path", filePath, error);
  }
}

function contextualizeFilesystemError(operation, filePath, error) {
  const detail = error instanceof Error ? error.message : String(error);
  const contextualError = Object.assign(
    new Error(`Failed to ${operation} ${filePath}: ${detail}`, {
      cause: error,
    }),
    {
      code: typeof error?.code === "string" ? error.code : undefined,
      path: filePath,
    },
  );
  return contextualError;
}

async function copyDir(sourceDir, targetDir, options = {}) {
  const filter = options.filter ?? (() => true);
  await copyDirEntries(sourceDir, targetDir, "", filter);
}

async function copyDirEntries(sourceDir, targetDir, prefix, filter) {
  await ensureDir(targetDir);
  const entries = await fs.readdir(sourceDir, { withFileTypes: true });
  for (const entry of entries) {
    const sourcePath = path.join(sourceDir, entry.name);
    const targetPath = path.join(targetDir, entry.name);
    const relativePath = prefix ? `${prefix}/${entry.name}` : entry.name;
    if (!(await filter({ entry, relativePath, sourcePath, targetPath }))) {
      continue;
    }
    if (entry.isDirectory()) {
      await copyDirEntries(sourcePath, targetPath, relativePath, filter);
    } else if (entry.isFile()) {
      await ensureDir(path.dirname(targetPath));
      await fs.copyFile(sourcePath, targetPath);
    }
  }
}

async function copyFile(sourcePath, targetPath) {
  await ensureDir(path.dirname(targetPath));
  await fs.copyFile(sourcePath, targetPath);
}

async function listRelativeFiles(rootDir) {
  if (!(await pathExists(rootDir))) return [];
  return walkRelativeFiles(rootDir);
}

async function walkRelativeFiles(rootDir, prefix = "") {
  const entries = await fs.readdir(rootDir, { withFileTypes: true });
  entries.sort((left, right) => left.name.localeCompare(right.name));

  const files = [];
  for (const entry of entries) {
    const fullPath = path.join(rootDir, entry.name);
    const relativePath = prefix ? `${prefix}/${entry.name}` : entry.name;
    if (entry.isDirectory()) {
      files.push(...(await walkRelativeFiles(fullPath, relativePath)));
    } else if (entry.isFile()) {
      files.push(relativePath);
    }
  }
  return files;
}

module.exports = {
  copyDir,
  copyFile,
  contextualizeFilesystemError,
  ensureDir,
  listRelativeFiles,
  pathExists,
  readJson,
  readText,
  resolveManagedChild,
  resolveWithinRoot,
  writeJson,
  writeText,
};
