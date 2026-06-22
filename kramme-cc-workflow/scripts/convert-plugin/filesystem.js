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
  } catch {
    return false;
  }
}

async function copyDir(sourceDir, targetDir) {
  await ensureDir(targetDir);
  const entries = await fs.readdir(sourceDir, { withFileTypes: true });
  for (const entry of entries) {
    const sourcePath = path.join(sourceDir, entry.name);
    const targetPath = path.join(targetDir, entry.name);
    if (entry.isDirectory()) {
      await copyDir(sourcePath, targetPath);
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

module.exports = {
  copyDir,
  copyFile,
  ensureDir,
  pathExists,
  readJson,
  readText,
  resolveManagedChild,
  resolveWithinRoot,
  writeJson,
  writeText,
};
