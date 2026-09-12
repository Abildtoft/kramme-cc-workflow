"use strict";

const assert = require("node:assert/strict");
const fs = require("fs/promises");
const os = require("os");
const path = require("path");

const {
  codexPluginRootExpression,
} = require("../../scripts/convert-plugin/codex-shared-scripts");

/**
 * @typedef {import("../../scripts/convert-plugin/contracts").CodexBundle} CodexBundle
 * @typedef {import("../../scripts/convert-plugin/contracts").CodexPluginPackage} CodexPluginPackage
 */

/**
 * @param {Partial<CodexPluginPackage>} [overrides]
 * @returns {CodexPluginPackage}
 */
function fixtureCodexPluginPackage(overrides = {}) {
  const name = overrides.name ?? "fixture-plugin";
  const marketplaceName = overrides.marketplaceName ?? name;
  const version = overrides.version ?? "1.0.0";
  const cacheRelativePath = `plugins/cache/${marketplaceName}/${name}/${version}`;
  return {
    cacheRelativePath,
    hookSourceDir: path.join("/plugin", "hooks"),
    manifest: {
      description: "Fixture plugin.",
      name,
      skills: "./skills/",
      version,
    },
    marketplaceName,
    name,
    rootExpression: codexPluginRootExpression(cacheRelativePath),
    version,
    ...overrides,
  };
}

/**
 * @param {Partial<CodexBundle>} [overrides]
 * @returns {CodexBundle}
 */
function emptyCodexBundle(overrides = {}) {
  return {
    agentSkills: [],
    codexPlugin: fixtureCodexPluginPackage(),
    generatedSkills: [],
    knownAgentSkills: new Map(),
    knownCommands: new Set(),
    mcpServers: {},
    sharedScriptDirs: [],
    sharedScriptFiles: [],
    skillDirs: [],
    ...overrides,
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

/** @template T @param {() => Promise<T>} fn @returns {Promise<T>} */
async function withMutedConsole(fn) {
  const { log, warn } = console;
  console.log = () => {};
  console.warn = () => {};
  try {
    return await fn();
  } finally {
    console.log = log;
    console.warn = warn;
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

/** @param {string} root @returns {Promise<Array<{ file: string, text: string }>>} */
async function readMarkdownTree(root) {
  /** @type {Array<{ file: string, text: string }>} */
  const markdown = [];
  const entries = await fs.readdir(root, { withFileTypes: true });
  for (const entry of entries) {
    const file = path.join(root, entry.name);
    if (entry.isDirectory()) {
      markdown.push(...(await readMarkdownTree(file)));
    } else if (entry.isFile() && path.extname(entry.name) === ".md") {
      markdown.push({ file, text: await readText(file) });
    }
  }
  return markdown;
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
  assertFilesystemError,
  createFixturePlugin,
  emptyCodexBundle,
  fixtureCodexPluginPackage,
  pathExists,
  readMarkdownTree,
  readText,
  withMutedConsole,
  withTempDir,
  writeFile,
  writeJson,
  writeSourceSkill,
};
