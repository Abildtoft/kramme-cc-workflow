"use strict";

const fs = require("fs/promises");
const path = require("path");
const {
  codexHookMarketplaceEntry,
  codexHookMarketplaceRoot,
  codexHookPluginCacheEntry,
} = require("./codex-config");
const { confirm } = require("./confirm");
const { sanitizeEntryList } = require("./install-state");
const { cleanupInstalledEntries, installStagedDir } = require("./install-staging");
const {
  copyDir,
  copyFile,
  pathExists,
  readText,
  resolveManagedChild,
  writeJson,
  writeText,
} = require("./filesystem");

async function stageCodexHookPluginBundle(
  codexRoot,
  codexStagingRoot,
  codexPlugin,
  previousEntries,
  options = {},
) {
  const confirmOptions = options.confirmOptions ?? {};
  if (!codexPlugin) {
    return {
      pluginCaches: [],
      hookMarketplaces: [],
      targets: {},
    };
  }

  const marketplaceEntry = codexHookMarketplaceEntry(codexPlugin);
  const marketplaceRoot = codexHookMarketplaceRoot(codexRoot, codexPlugin);
  const pluginCacheEntry = codexHookPluginCacheEntry(codexPlugin);
  const pluginCacheRoot = resolveManagedChild(
    path.join(codexRoot, "plugins"),
    pluginCacheEntry,
    "Codex plugin cache entry",
  );
  const stagedMarketplaceRoot = resolveManagedChild(
    codexStagingRoot,
    marketplaceEntry,
    "Codex hook marketplace entry",
  );
  const stagedMarketplacePluginRoot = path.join(
    stagedMarketplaceRoot,
    "plugins",
    codexPlugin.name,
  );
  const stagedPluginCacheRoot = resolveManagedChild(
    path.join(codexStagingRoot, "plugins"),
    pluginCacheEntry,
    "Codex plugin cache entry",
  );

  const marketplaceTarget = await prepareCodexHookPluginTarget(marketplaceRoot, {
    label: "Codex hook marketplace",
    entry: marketplaceEntry,
    previousEntries: previousEntries.hookMarketplaces,
    confirmOptions,
  });
  const pluginCacheTarget = await prepareCodexHookPluginTarget(pluginCacheRoot, {
    label: "Codex plugin cache entry",
    entry: pluginCacheEntry,
    previousEntries: previousEntries.pluginCaches,
    confirmOptions,
  });

  await writeCodexHookPluginTree(stagedMarketplacePluginRoot, codexPlugin);
  await writeCodexHookPluginTree(stagedPluginCacheRoot, codexPlugin);
  await writeCodexHookMarketplace(stagedMarketplaceRoot, codexPlugin);

  return {
    pluginCaches: [pluginCacheEntry],
    hookMarketplaces: [marketplaceEntry],
    targets: {
      marketplace: {
        finalRoot: marketplaceRoot,
        overwriteExisting: marketplaceTarget.overwriteExisting,
        stagedRoot: stagedMarketplaceRoot,
      },
      pluginCache: {
        finalRoot: pluginCacheRoot,
        overwriteExisting: pluginCacheTarget.overwriteExisting,
        stagedRoot: stagedPluginCacheRoot,
      },
    },
  };
}

async function finalizeCodexHookPluginBundle(
  codexRoot,
  codexStagingRoot,
  codexPlugin,
  previousEntries,
  targets = {},
  options = {},
) {
  const confirmOptions = options.confirmOptions ?? {};
  const cleanedPluginCaches = await cleanupInstalledEntries(
    path.join(codexRoot, "plugins"),
    previousEntries.pluginCaches,
    {
      label: "Codex plugin cache",
      recursive: true,
      confirmOptions,
    },
  );
  const cleanedHookMarketplaces = await cleanupInstalledEntries(
    codexRoot,
    previousEntries.hookMarketplaces,
    {
      label: "Codex hook marketplace",
      recursive: true,
      confirmOptions,
    },
  );

  if (!codexPlugin) {
    return {
      cleanedPluginCaches,
      cleanedHookMarketplaces,
    };
  }

  const marketplaceTarget =
    targets.marketplace ??
    {
      finalRoot: codexHookMarketplaceRoot(codexRoot, codexPlugin),
      overwriteExisting: false,
      stagedRoot: resolveManagedChild(
        codexStagingRoot,
        codexHookMarketplaceEntry(codexPlugin),
        "Codex hook marketplace entry",
      ),
    };
  const pluginCacheTarget =
    targets.pluginCache ??
    {
      finalRoot: resolveManagedChild(
        path.join(codexRoot, "plugins"),
        codexHookPluginCacheEntry(codexPlugin),
        "Codex plugin cache entry",
      ),
      overwriteExisting: false,
      stagedRoot: resolveManagedChild(
        path.join(codexStagingRoot, "plugins"),
        codexHookPluginCacheEntry(codexPlugin),
        "Codex plugin cache entry",
      ),
    };

  await installStagedDir(
    marketplaceTarget.stagedRoot,
    marketplaceTarget.finalRoot,
    {
      replace: cleanedHookMarketplaces || marketplaceTarget.overwriteExisting,
    },
  );
  await installStagedDir(
    pluginCacheTarget.stagedRoot,
    pluginCacheTarget.finalRoot,
    {
      replace: cleanedPluginCaches || pluginCacheTarget.overwriteExisting,
    },
  );

  return {
    cleanedPluginCaches,
    cleanedHookMarketplaces,
  };
}

async function prepareCodexHookPluginTarget(
  targetRoot,
  { label, entry, previousEntries, confirmOptions },
) {
  if (!(await pathExists(targetRoot))) {
    return { overwriteExisting: false };
  }

  const wasTracked = sanitizeEntryList(previousEntries).includes(entry);
  if (wasTracked) {
    return { overwriteExisting: false };
  }

  console.log(`\nFound existing untracked ${label} at ${targetRoot}.`);
  const confirmed = await confirm(
    `Delete existing ${label} before installing?`,
    confirmOptions,
  );
  if (!confirmed) {
    throw new Error(`Refusing to overwrite existing untracked ${label}.`);
  }

  return { overwriteExisting: true };
}

async function writeCodexHookPluginTree(targetRoot, codexPlugin) {
  await writeJson(
    path.join(targetRoot, ".codex-plugin", "plugin.json"),
    codexPlugin.manifest,
  );
  const hooksRoot = path.join(targetRoot, "hooks");
  if (await pathExists(codexPlugin.hookSourceDir)) {
    await copyDir(codexPlugin.hookSourceDir, hooksRoot);
  }
  for (const sharedScriptDir of codexPlugin.sharedScriptDirs ?? []) {
    if (await pathExists(sharedScriptDir.sourceDir)) {
      await copyDir(
        sharedScriptDir.sourceDir,
        path.join(targetRoot, sharedScriptDir.targetDir),
      );
    }
  }
  for (const sharedScriptFile of codexPlugin.sharedScriptFiles ?? []) {
    if (await pathExists(sharedScriptFile.sourceFile)) {
      await copyFile(
        sharedScriptFile.sourceFile,
        path.join(targetRoot, sharedScriptFile.targetPath),
      );
    }
  }
  await writeJson(path.join(hooksRoot, "hooks.json"), codexPlugin.hooks);
  await bootstrapHookScripts(hooksRoot, targetRoot);
}

async function writeCodexHookMarketplace(marketplaceRoot, codexPlugin) {
  const marketplace = {
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

  await writeJson(
    path.join(marketplaceRoot, ".agents", "plugins", "marketplace.json"),
    marketplace,
  );
}

async function bootstrapHookScripts(
  rootDir,
  bundleRootDir = path.dirname(rootDir),
) {
  if (!(await pathExists(rootDir))) return;

  const bootstrapMarker = "# kramme hook bundle bootstrap";
  const entries = await fs.readdir(rootDir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(rootDir, entry.name);
    if (entry.isDirectory()) {
      await bootstrapHookScripts(fullPath, bundleRootDir);
      continue;
    }
    if (!entry.isFile() || path.extname(entry.name) !== ".sh") {
      continue;
    }

    const scriptDir = path.dirname(fullPath);
    const relativePluginRoot = (path.relative(scriptDir, bundleRootDir) || ".")
      .split(path.sep)
      .join("/");
    const bootstrapLines = [
      `${bootstrapMarker} start`,
      'if [ -z "${CLAUDE_PLUGIN_ROOT:-}" ]; then',
      '  _claude_hook_source="${BASH_SOURCE:-$0}"',
      '  _claude_hook_dir="$(CDPATH= cd -- "$(dirname -- "$_claude_hook_source")" && pwd)"',
      `  CLAUDE_PLUGIN_ROOT="$(CDPATH= cd -- "$_claude_hook_dir/${relativePluginRoot}" && pwd)"`,
      "fi",
      "export CLAUDE_PLUGIN_ROOT",
      "unset _claude_hook_source _claude_hook_dir",
      `${bootstrapMarker} end`,
    ];
    const source = await readText(fullPath);
    if (source.includes(bootstrapMarker)) continue;

    const lineEnding = source.includes("\r\n") ? "\r\n" : "\n";
    const lines = source.split(/\r?\n/);
    const insertIndex = lines[0]?.startsWith("#!") ? 1 : 0;
    lines.splice(insertIndex, 0, ...bootstrapLines);
    await writeText(fullPath, lines.join(lineEnding));
  }
}

module.exports = {
  finalizeCodexHookPluginBundle,
  stageCodexHookPluginBundle,
};
