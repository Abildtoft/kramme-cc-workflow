// @ts-check
"use strict";

const fs = require("fs/promises");
const path = require("path");
const {
  rewriteCodexMarkdownResourcesFromSource,
} = require("./codex-markdown-resources");
const { rewriteCodexPluginRootReferences } = require("./codex-shared-scripts");
const {
  copyDir,
  copyFile,
  ensureDir,
  filesystemErrorCode,
  pathExists,
  readText,
  resolveManagedChild,
  writeJson,
  writeText,
} = require("./filesystem");

/**
 * @typedef {import("./contracts").CodexBundle} CodexBundle
 * @typedef {import("./contracts").CodexPluginPackage} CodexPluginPackage
 * @typedef {import("./contracts").CodexSkillFile} CodexSkillFile
 * @typedef {{ marketplaceRoot: string, pluginRoot: string, skillCount: number }} BuiltCodexMarketplace
 */

const EXCLUDED_HOOK_SOURCE_FILES = new Set([
  "context-links.config",
  "hook-state.json",
]);
const SOURCE_SNAPSHOT_DIR = "references/sources-snapshot";
const HOOK_BOOTSTRAP_MARKER = "# kramme hook bundle bootstrap";
const MARKETPLACE_MANIFEST = path.join(
  ".agents",
  "plugins",
  "marketplace.json",
);
const OWNERSHIP_MARKER = ".kramme-plugin-marketplace.json";
const OWNERSHIP_MARKER_VERSION = 1;

/**
 * Write a Codex marketplace containing one native plugin built from the bundle.
 *
 * The output root must be absent or empty. The resulting tree is what
 * `codex plugin marketplace add <root>` consumes:
 *
 * ```text
 * <root>/.agents/plugins/marketplace.json
 * <root>/plugins/<name>/.codex-plugin/plugin.json
 * <root>/plugins/<name>/skills/<skill>/SKILL.md
 * <root>/plugins/<name>/scripts/...       shared runtime helpers
 * <root>/plugins/<name>/hooks/...         when hook packaging is eligible
 * ```
 *
 * @param {string} outputRoot
 * @param {CodexBundle} bundle
 * @returns {Promise<BuiltCodexMarketplace>}
 */
async function buildCodexMarketplace(outputRoot, bundle) {
  await assertEmptyOutputRoot(outputRoot);
  const codexPlugin = bundle.codexPlugin;
  const pluginRoot = resolveManagedChild(
    path.join(outputRoot, "plugins"),
    codexPlugin.name,
    "Codex plugin name",
  );

  await writeJson(
    path.join(pluginRoot, ".codex-plugin", "plugin.json"),
    codexPlugin.manifest,
  );
  const skillCount = await writeSkills(pluginRoot, bundle);
  await writeSharedRuntime(pluginRoot, bundle);
  if (codexPlugin.hooks) {
    await writeHooks(pluginRoot, codexPlugin);
  }
  await writeJson(
    path.join(outputRoot, MARKETPLACE_MANIFEST),
    marketplaceManifest(codexPlugin),
  );
  await writeJson(path.join(outputRoot, OWNERSHIP_MARKER), {
    generatedBy: "kramme-cc-workflow",
    markerVersion: OWNERSHIP_MARKER_VERSION,
    marketplaceName: codexPlugin.marketplaceName,
    pluginName: codexPlugin.name,
    pluginVersion: codexPlugin.version,
  });

  return { marketplaceRoot: outputRoot, pluginRoot, skillCount };
}

/** @param {string} outputRoot */
async function assertEmptyOutputRoot(outputRoot) {
  let entries;
  try {
    entries = await fs.readdir(outputRoot);
  } catch (error) {
    if (filesystemErrorCode(error) === "ENOENT") return;
    throw error;
  }
  if (entries.length > 0) {
    throw new Error(
      `Output directory ${outputRoot} is not empty; remove it or choose another --out directory.`,
    );
  }
}

/** @param {string} pluginRoot @param {CodexBundle} bundle */
async function writeSkills(pluginRoot, bundle) {
  const skillsRoot = path.join(pluginRoot, "skills");
  await ensureDir(skillsRoot);
  const rootExpression = bundle.codexPlugin.rootExpression;
  /** @type {Set<string>} */
  const written = new Set();
  /** @param {CodexSkillFile} skill */
  const targetDirFor = (skill) => {
    if (written.has(skill.name)) {
      throw new Error(`Duplicate Codex skill name: ${skill.name}`);
    }
    written.add(skill.name);
    return resolveManagedChild(skillsRoot, skill.name, "skill name");
  };

  for (const skill of bundle.skillDirs) {
    const targetDir = targetDirFor(skill);
    await copyDir(skill.sourceDir, targetDir, {
      filter: ({ relativePath }) => relativePath !== SOURCE_SNAPSHOT_DIR,
    });
    await writeSkillFile(targetDir, skill, rootExpression);
    await rewriteCodexMarkdownResourcesFromSource(skill.sourceDir, targetDir, {
      knownAgentSkills: bundle.knownAgentSkills,
      knownCommands: bundle.knownCommands,
      pluginRootExpression: rootExpression,
    });
  }
  for (const skill of [...bundle.generatedSkills, ...bundle.agentSkills]) {
    await writeSkillFile(targetDirFor(skill), skill, rootExpression);
  }
  return written.size;
}

/** @param {string} targetDir @param {CodexSkillFile} skill @param {string} rootExpression */
async function writeSkillFile(targetDir, skill, rootExpression) {
  await writeText(
    path.join(targetDir, "SKILL.md"),
    rewriteCodexPluginRootReferences(skill.content, rootExpression) + "\n",
  );
}

/** @param {string} pluginRoot @param {CodexBundle} bundle */
async function writeSharedRuntime(pluginRoot, bundle) {
  for (const sharedScriptDir of bundle.sharedScriptDirs) {
    if (await pathExists(sharedScriptDir.sourceDir)) {
      await copyDir(
        sharedScriptDir.sourceDir,
        resolveManagedChild(
          pluginRoot,
          sharedScriptDir.targetDir,
          "shared script directory",
        ),
        { executableFiles: sharedScriptDir.executableFiles },
      );
    }
  }
  for (const sharedScriptFile of bundle.sharedScriptFiles) {
    if (await pathExists(sharedScriptFile.sourceFile)) {
      await copyFile(
        sharedScriptFile.sourceFile,
        resolveManagedChild(
          pluginRoot,
          sharedScriptFile.targetPath,
          "shared script file",
        ),
        { mode: sharedScriptFile.executable ? 0o755 : undefined },
      );
    }
  }
}

/** @param {string} pluginRoot @param {CodexPluginPackage} codexPlugin */
async function writeHooks(pluginRoot, codexPlugin) {
  const hooksRoot = path.join(pluginRoot, "hooks");
  if (await pathExists(codexPlugin.hookSourceDir)) {
    await copyDir(codexPlugin.hookSourceDir, hooksRoot, {
      filter: ({ entry, relativePath }) =>
        !entry.isFile() || !EXCLUDED_HOOK_SOURCE_FILES.has(relativePath),
    });
  }
  await writeJson(path.join(hooksRoot, "hooks.json"), codexPlugin.hooks);
  await bootstrapHookScripts(hooksRoot, pluginRoot);
}

/**
 * Prepend a plugin-root bootstrap to every hook shell script so the scripts
 * also run when the host does not export `CLAUDE_PLUGIN_ROOT` (Codex sets it
 * for plugin hooks, but subagent shells have been observed without it).
 *
 * @param {string} rootDir @param {string} pluginRoot
 */
async function bootstrapHookScripts(rootDir, pluginRoot) {
  if (!(await pathExists(rootDir))) return;

  const entries = await fs.readdir(rootDir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(rootDir, entry.name);
    if (entry.isDirectory()) {
      await bootstrapHookScripts(fullPath, pluginRoot);
      continue;
    }
    if (!entry.isFile() || path.extname(entry.name) !== ".sh") {
      continue;
    }

    const relativePluginRoot = (
      path.relative(path.dirname(fullPath), pluginRoot) || "."
    )
      .split(path.sep)
      .join("/");
    const bootstrapLines = [
      `${HOOK_BOOTSTRAP_MARKER} start`,
      'if [ -z "${CLAUDE_PLUGIN_ROOT:-}" ]; then',
      '  _claude_hook_source="${BASH_SOURCE:-$0}"',
      '  _claude_hook_dir="$(CDPATH= cd -- "$(dirname -- "$_claude_hook_source")" && pwd)"',
      `  CLAUDE_PLUGIN_ROOT="$(CDPATH= cd -- "$_claude_hook_dir/${relativePluginRoot}" && pwd)"`,
      "fi",
      "export CLAUDE_PLUGIN_ROOT",
      "unset _claude_hook_source _claude_hook_dir",
      `${HOOK_BOOTSTRAP_MARKER} end`,
    ];
    const source = await readText(fullPath);
    if (source.includes(HOOK_BOOTSTRAP_MARKER)) continue;

    const lineEnding = source.includes("\r\n") ? "\r\n" : "\n";
    const lines = source.split(/\r?\n/);
    const insertIndex = lines[0]?.startsWith("#!") ? 1 : 0;
    lines.splice(insertIndex, 0, ...bootstrapLines);
    await writeText(fullPath, lines.join(lineEnding));
  }
}

/** @param {CodexPluginPackage} codexPlugin */
function marketplaceManifest(codexPlugin) {
  return {
    name: codexPlugin.marketplaceName,
    interface: {
      displayName: codexPlugin.manifest.name,
    },
    plugins: [
      {
        name: codexPlugin.name,
        source: {
          source: "local",
          path: `./plugins/${codexPlugin.name}`,
        },
        policy: {
          installation: "AVAILABLE",
          authentication: "ON_INSTALL",
        },
        category: "Productivity",
      },
    ],
  };
}

module.exports = {
  MARKETPLACE_MANIFEST,
  OWNERSHIP_MARKER,
  buildCodexMarketplace,
};
