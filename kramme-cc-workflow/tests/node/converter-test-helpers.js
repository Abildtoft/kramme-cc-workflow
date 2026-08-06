"use strict";

const assert = require("node:assert/strict");
const fs = require("fs/promises");
const os = require("os");
const path = require("path");

/**
 * @param {Partial<import("../../scripts/convert-plugin/contracts").CodexBundle>} [overrides]
 * @returns {import("../../scripts/convert-plugin/contracts").CodexBundle}
 */
function emptyCodexBundle(overrides = {}) {
  return {
    agentSkills: [],
    codexPlugin: undefined,
    generatedSkills: [],
    knownAgentSkills: new Map(),
    knownCommands: new Set(),
    mcpServers: {},
    prompts: [],
    skillDirs: [],
    ...overrides,
  };
}

/** @returns {{ agentSkillFiles: Record<string, string[]>, agentSkills: string[], hookMarketplaces: string[], pluginCaches: string[], prompts: string[], skillFiles: Record<string, string[]>, skills: string[] }} */
function emptyPreviousEntries() {
  return {
    agentSkillFiles: {},
    agentSkills: [],
    hookMarketplaces: [],
    pluginCaches: [],
    prompts: [],
    skillFiles: {},
    skills: [],
  };
}

/** @template T @param {(root: string) => Promise<T>} fn @returns {Promise<T>} */
async function withTempDir(fn) {
  const createdRoot = await fs.mkdtemp(
    path.join(os.tmpdir(), "converter-contracts-"),
  );
  const root = await fs.realpath(createdRoot);
  try {
    return await fn(root);
  } finally {
    await fs.rm(root, { force: true, recursive: true });
  }
}

/** @param {string} file @param {unknown} data */
async function writeJson(file, data) {
  await writeFile(file, JSON.stringify(data, null, 2) + "\n");
}

/** @param {string} pluginRoot @param {string} [pluginName] */
async function createFixturePlugin(pluginRoot, pluginName = "fixture-plugin") {
  await writeJson(path.join(pluginRoot, ".claude-plugin", "plugin.json"), {
    agents: [],
    commands: [],
    name: pluginName,
    skills: [],
    version: "1.0.0",
  });
}

/** @param {string} sourceDir @param {Record<string, string>} files */
async function writeSourceSkill(sourceDir, files) {
  await fs.rm(sourceDir, { force: true, recursive: true });
  for (const [relativePath, content] of Object.entries(files)) {
    await writeFile(path.join(sourceDir, relativePath), content);
  }
}

/** @param {string} file @param {string} content */
async function writeFile(file, content) {
  await fs.mkdir(path.dirname(file), { recursive: true });
  await fs.writeFile(file, content, "utf8");
}

/** @param {string} file */
async function readText(file) {
  return fs.readFile(file, "utf8");
}

/** @param {string} file */
async function pathExists(file) {
  try {
    await fs.access(file);
    return true;
  } catch {
    return false;
  }
}

/** @param {unknown} error @param {{ cause: unknown, code: string, message: RegExp, path: string }} expected */
function assertFilesystemError(error, { cause, code, message, path: file }) {
  assert.ok(error instanceof Error);
  const filesystemError = /** @type {NodeJS.ErrnoException} */ (error);
  assert.equal(filesystemError.code, code);
  assert.equal(filesystemError.path, file);
  assert.equal(filesystemError.cause, cause);
  assert.match(filesystemError.message, message);
}

module.exports = {
  emptyCodexBundle,
  emptyPreviousEntries,
  withTempDir,
  writeJson,
  createFixturePlugin,
  writeSourceSkill,
  writeFile,
  readText,
  pathExists,
  assertFilesystemError,
};
