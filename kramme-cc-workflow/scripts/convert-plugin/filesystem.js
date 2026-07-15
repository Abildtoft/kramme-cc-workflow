"use strict";

const fs = require("fs/promises");
const path = require("path");

/** @typedef {import("./contracts").JsonObject} JsonObject */
/**
 * @typedef {{ entry: import("fs").Dirent, relativePath: string, sourcePath: string, targetPath: string }} CopyFilterContext
 * @typedef {(context: CopyFilterContext) => boolean | Promise<boolean>} CopyFilter
 */

/** @param {string} root @param {string} entry @param {string} label */
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

/** @param {string} root @param {string} entry @param {string} label */
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

/** @param {string} file */
async function readText(file) {
  return fs.readFile(file, "utf8");
}

/** @param {string} file @param {string} content */
async function writeText(file, content) {
  await ensureDir(path.dirname(file));
  await fs.writeFile(file, content, "utf8");
}

/**
 * @param {string} file
 * @returns {Promise<unknown>}
 */
async function readJson(file) {
  const raw = await readText(file);
  return JSON.parse(raw);
}

/**
 * @param {unknown} value
 * @returns {value is JsonObject}
 */
function isJsonObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

/**
 * @param {unknown} value
 * @param {string} label
 * @returns {JsonObject}
 */
function requireJsonObject(value, label) {
  if (isJsonObject(value)) return value;
  throw new Error(
    `${label} must be a JSON object; received ${jsonValueKind(value)}.`,
  );
}

/**
 * @param {string} file
 * @param {string} [label]
 * @returns {Promise<JsonObject>}
 */
async function readJsonObject(file, label = "JSON document") {
  return requireJsonObject(await readJson(file), `${file}: ${label}`);
}

/** @param {unknown} value */
function jsonValueKind(value) {
  if (value === null) return "null";
  if (Array.isArray(value)) return "array";
  return typeof value;
}

/** @param {string} file @param {unknown} data */
async function writeJson(file, data) {
  const content = JSON.stringify(data, null, 2) + "\n";
  await writeText(file, content);
}

/** @param {string} dir */
async function ensureDir(dir) {
  await fs.mkdir(dir, { recursive: true });
}

/** @param {string} filePath */
async function pathExists(filePath) {
  try {
    await fs.access(filePath);
    return true;
  } catch (error) {
    if (filesystemErrorCode(error) === "ENOENT") return false;
    throw contextualizeFilesystemError("check path", filePath, error);
  }
}

/** @param {string} operation @param {string} filePath @param {unknown} error */
function contextualizeFilesystemError(operation, filePath, error) {
  const detail = error instanceof Error ? error.message : String(error);
  const contextualError = Object.assign(
    new Error(`Failed to ${operation} ${filePath}: ${detail}`, {
      cause: error,
    }),
    {
      code: filesystemErrorCode(error),
      path: filePath,
    },
  );
  return contextualError;
}

/** @param {unknown} error */
function filesystemErrorCode(error) {
  if (error && typeof error === "object" && "code" in error) {
    const code = /** @type {{ code?: unknown }} */ (error).code;
    return typeof code === "string" ? code : undefined;
  }
  return undefined;
}

/**
 * @param {string} sourceDir
 * @param {string} targetDir
 * @param {{ filter?: CopyFilter }} [options]
 */
async function copyDir(sourceDir, targetDir, options = {}) {
  const filter = options.filter ?? (() => true);
  await copyDirEntries(sourceDir, targetDir, "", filter);
}

/**
 * @param {string} sourceDir
 * @param {string} targetDir
 * @param {string} prefix
 * @param {CopyFilter} filter
 */
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

/** @param {string} sourcePath @param {string} targetPath */
async function copyFile(sourcePath, targetPath) {
  await ensureDir(path.dirname(targetPath));
  await fs.copyFile(sourcePath, targetPath);
}

/** @param {string} rootDir @returns {Promise<string[]>} */
async function listRelativeFiles(rootDir) {
  if (!(await pathExists(rootDir))) return [];
  return walkRelativeFiles(rootDir);
}

/** @param {string} rootDir @param {string} [prefix] @returns {Promise<string[]>} */
async function walkRelativeFiles(rootDir, prefix = "") {
  const entries = await fs.readdir(rootDir, { withFileTypes: true });
  entries.sort((left, right) => left.name.localeCompare(right.name));

  /** @type {string[]} */
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
  filesystemErrorCode,
  isJsonObject,
  listRelativeFiles,
  pathExists,
  readJson,
  readJsonObject,
  readText,
  requireJsonObject,
  resolveManagedChild,
  resolveWithinRoot,
  writeJson,
  writeText,
};
