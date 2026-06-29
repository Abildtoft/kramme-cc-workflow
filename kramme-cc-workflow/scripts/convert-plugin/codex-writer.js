"use strict";

const fs = require("fs/promises");
const path = require("path");
const os = require("os");
const { transformContentForCodex } = require("./codex-transformer");
const {
  codexHookMarketplaceEntry,
  codexHookMarketplaceRoot,
  codexHookPluginCacheEntry,
  stageCodexConfig,
} = require("./codex-config");
const { confirm } = require("./confirm");
const {
  getPreviousInstallEntries,
  loadInstallState,
  sanitizeEntryList,
  setInstallEntries,
  unionEntryLists,
  writeInstallManifest,
  writeInstallState,
} = require("./install-state");
const {
  cleanupInstalledEntries,
  cleanupKrammeComponents,
  createInstallStagingRoot,
  installStagedDir,
  installStagedFile,
  preflightStagedDirInstall,
  preflightStagedFileInstall,
  pruneStaleManagedFiles,
  removeInstallStagingRoot,
} = require("./install-staging");
const {
  copyDir,
  copyFile,
  ensureDir,
  listRelativeFiles,
  pathExists,
  readText,
  resolveManagedChild,
  writeText,
  writeJson,
} = require("./filesystem");

function codexSharedScriptReplacements(
  codexRoot,
  sharedScriptDirs = [],
  sharedScriptFiles = [],
) {
  return [
    ...sharedScriptDirs.map((sharedScriptDir) => ({
      sourcePrefix: `\${CLAUDE_PLUGIN_ROOT}/${sharedScriptDir.targetDir
        .split(path.sep)
        .join("/")}/`,
      targetPrefix: `${shellQuotePath(
        path.join(codexRoot, sharedScriptDir.targetDir),
      )}/`,
    })),
    ...sharedScriptFiles.map((sharedScriptFile) => ({
      sourceText: `\${CLAUDE_PLUGIN_ROOT}/${sharedScriptFile.targetPath
        .split(path.sep)
        .join("/")}`,
      targetText: shellQuotePath(
        path.join(codexRoot, sharedScriptFile.targetPath),
      ),
    })),
  ];
}

function rewriteCodexSharedScriptReferences(text, replacements = []) {
  let result = text;
  for (const replacement of replacements) {
    if (replacement.sourcePrefix) {
      result = result
        .split(replacement.sourcePrefix)
        .join(replacement.targetPrefix);
    }
    if (replacement.sourceText) {
      result = result.split(replacement.sourceText).join(replacement.targetText);
    }
  }
  return result;
}

function shellQuotePath(filePath) {
  return `'${String(filePath).replace(/'/g, "'\\''")}'`;
}

function hasOwnEntry(object, entry) {
  return Object.prototype.hasOwnProperty.call(object ?? {}, entry);
}

function buildNextManagedFileMap(
  previousFiles,
  currentFiles,
  nextEntries,
  cleaned,
) {
  const result = {};
  for (const entry of sanitizeEntryList(nextEntries)) {
    if (hasOwnEntry(currentFiles, entry)) {
      result[entry] = currentFiles[entry];
    } else if (!cleaned && hasOwnEntry(previousFiles, entry)) {
      result[entry] = previousFiles[entry];
    }
  }
  return result;
}

async function writeCodexBundle(outputRoot, bundle, extraOpts = {}) {
  const codexRoot = resolveCodexOutputRoot(outputRoot);
  const pluginName = extraOpts.pluginName ?? "plugin";
  const { state: installState } = await loadInstallState(codexRoot);
  const previousEntries = await getPreviousInstallEntries(
    codexRoot,
    installState,
    pluginName,
    "codex",
  );
  await ensureDir(codexRoot);
  const codexStagingRoot = await createInstallStagingRoot(
    codexRoot,
    pluginName,
    "codex",
  );
  let agentStagingRoot = null;
  try {
    const stagedBundle = await stageCodexBundleOutput(
      codexRoot,
      codexStagingRoot,
      bundle,
      previousEntries,
      pluginName,
      extraOpts,
    );
    agentStagingRoot = stagedBundle.agentStagingRoot;
    const finalizedBundle = await finalizeCodexBundleOutput(
      codexRoot,
      codexStagingRoot,
      stagedBundle,
      bundle,
      previousEntries,
      extraOpts,
    );

    const currentCodexSkills = [
      ...bundle.skillDirs.map((skill) => skill.name),
      ...bundle.generatedSkills.map((skill) => skill.name),
    ];
    const currentAgentSkills = (bundle.agentSkills ?? []).map(
      (skill) => skill.name,
    );
    const nextSkills = finalizedBundle.cleanedCodexSkills
      ? currentCodexSkills
      : unionEntryLists(previousEntries.skills, currentCodexSkills);
    const nextAgentSkills = finalizedBundle.cleanedAgentSkills
      ? currentAgentSkills
      : unionEntryLists(previousEntries.agentSkills, currentAgentSkills);
    const nextEntries = {
      hookMarketplaces: finalizedBundle.cleanedHookMarketplaces
        ? stagedBundle.hookMarketplaces
        : unionEntryLists(
            previousEntries.hookMarketplaces,
            stagedBundle.hookMarketplaces,
      ),
      pluginCaches: finalizedBundle.cleanedPluginCaches
        ? stagedBundle.pluginCaches
        : unionEntryLists(
            previousEntries.pluginCaches,
            stagedBundle.pluginCaches,
          ),
      prompts: finalizedBundle.cleanedPrompts
        ? bundle.prompts.map((prompt) => `${prompt.name}.md`)
        : unionEntryLists(
            previousEntries.prompts,
            bundle.prompts.map((prompt) => `${prompt.name}.md`),
          ),
      skills: nextSkills,
      skillFiles: buildNextManagedFileMap(
        previousEntries.skillFiles,
        stagedBundle.stagedSkillFiles,
        nextSkills,
        finalizedBundle.cleanedCodexSkills,
      ),
      agentSkills: nextAgentSkills,
      agentSkillFiles: buildNextManagedFileMap(
        previousEntries.agentSkillFiles,
        stagedBundle.stagedAgentSkillFiles,
        nextAgentSkills,
        finalizedBundle.cleanedAgentSkills,
      ),
      updatedAtMs: Date.now(),
    };
    setInstallEntries(installState, pluginName, "codex", nextEntries);
    await writeInstallState(codexRoot, installState);
    await writeInstallManifest(codexRoot, pluginName, "codex", nextEntries);
  } finally {
    await removeInstallStagingRoot(codexStagingRoot);
    await removeInstallStagingRoot(agentStagingRoot);
  }
}

async function stageCodexBundleOutput(
  codexRoot,
  codexStagingRoot,
  bundle,
  previousEntries,
  pluginName,
  extraOpts,
) {
  let agentStagingRoot = null;
  try {
    const sharedScriptDirs = bundle.codexPlugin?.sharedScriptDirs ?? [];
    const sharedScriptFiles = bundle.codexPlugin?.sharedScriptFiles ?? [];
    for (const sharedScriptDir of sharedScriptDirs) {
      if (await pathExists(sharedScriptDir.sourceDir)) {
        await copyDir(
          sharedScriptDir.sourceDir,
          path.join(codexStagingRoot, sharedScriptDir.targetDir),
        );
      }
    }
    for (const sharedScriptFile of sharedScriptFiles) {
      if (await pathExists(sharedScriptFile.sourceFile)) {
        await copyFile(
          sharedScriptFile.sourceFile,
          path.join(codexStagingRoot, sharedScriptFile.targetPath),
        );
      }
    }
    const sharedScriptReplacements = codexSharedScriptReplacements(
      codexRoot,
      sharedScriptDirs,
      sharedScriptFiles,
    );

    const stagedPromptsDir = path.join(codexStagingRoot, "prompts");
    for (const prompt of bundle.prompts) {
      await writeText(
        path.join(stagedPromptsDir, `${prompt.name}.md`),
        prompt.content + "\n",
      );
    }

    const stagedSkillsRoot = path.join(codexStagingRoot, "skills");
    const stagedSkillFiles = {};
    for (const skill of bundle.skillDirs) {
      const targetDir = resolveManagedChild(
        stagedSkillsRoot,
        skill.name,
        "skill name",
      );
      await copyDir(skill.sourceDir, targetDir);
      if (skill.content) {
        const content = rewriteCodexSharedScriptReferences(
          skill.content,
          sharedScriptReplacements,
        );
        await writeText(path.join(targetDir, "SKILL.md"), content + "\n");
      }
      await rewriteCodexMarkdownResourcesFromSource(
        skill.sourceDir,
        targetDir,
        {
          knownCommands: bundle.knownCommands,
          knownAgentSkills: bundle.knownAgentSkills,
          sharedScriptReplacements,
        },
      );
      stagedSkillFiles[skill.name] = await listRelativeFiles(targetDir);
    }

    for (const skill of bundle.generatedSkills) {
      const targetDir = resolveManagedChild(
        stagedSkillsRoot,
        skill.name,
        "skill name",
      );
      const content = rewriteCodexSharedScriptReferences(
        skill.content,
        sharedScriptReplacements,
      );
      await writeText(path.join(targetDir, "SKILL.md"), content + "\n");
      stagedSkillFiles[skill.name] = await listRelativeFiles(targetDir);
    }

    let agentsHome = null;
    let agentSkillsRoot = null;
    let stagedAgentSkillsRoot = null;
    const stagedAgentSkillFiles = {};
    if (
      bundle.agentSkills &&
      (bundle.agentSkills.length > 0 || previousEntries.agentSkills.length > 0)
    ) {
      agentsHome = extraOpts.agentsHome ?? path.join(os.homedir(), ".agents");
      agentSkillsRoot = path.join(agentsHome, "skills");
    }
    if (bundle.agentSkills && bundle.agentSkills.length > 0) {
      agentsHome = extraOpts.agentsHome ?? path.join(os.homedir(), ".agents");
      agentSkillsRoot = path.join(agentsHome, "skills");
      agentStagingRoot = await createInstallStagingRoot(
        agentsHome,
        pluginName,
        "agents",
      );
      stagedAgentSkillsRoot = path.join(agentStagingRoot, "skills");
      for (const skill of bundle.agentSkills) {
        const targetDir = resolveManagedChild(
          stagedAgentSkillsRoot,
          skill.name,
          "agent skill name",
        );
        await writeText(path.join(targetDir, "SKILL.md"), skill.content + "\n");
        stagedAgentSkillFiles[skill.name] = await listRelativeFiles(targetDir);
      }
    }

    const hookPluginResult = await stageCodexHookPluginBundle(
      codexRoot,
      codexStagingRoot,
      bundle.codexPlugin,
      previousEntries,
      { confirmOptions: extraOpts.confirm },
    );

    const stagedConfigPath = await stageCodexConfig(
      codexRoot,
      codexStagingRoot,
      bundle,
      previousEntries,
      pluginName,
    );

    return {
      agentSkillsRoot,
      agentStagingRoot,
      hookMarketplaces: hookPluginResult.hookMarketplaces,
      hookTargets: hookPluginResult.targets,
      pluginCaches: hookPluginResult.pluginCaches,
      sharedScriptDirs,
      sharedScriptFiles,
      stagedAgentSkillsRoot,
      stagedAgentSkillFiles,
      stagedConfigPath,
      stagedPromptsDir,
      stagedSkillFiles,
      stagedSkillsRoot,
    };
  } catch (error) {
    await removeInstallStagingRoot(agentStagingRoot);
    throw error;
  }
}

async function finalizeCodexBundleOutput(
  codexRoot,
  codexStagingRoot,
  stagedBundle,
  bundle,
  previousEntries,
  extraOpts,
) {
  await preflightCodexBundleFinalization(
    codexRoot,
    codexStagingRoot,
    stagedBundle,
    bundle,
    previousEntries,
  );

  for (const sharedScriptDir of stagedBundle.sharedScriptDirs) {
    await installStagedDir(
      path.join(codexStagingRoot, sharedScriptDir.targetDir),
      path.join(codexRoot, sharedScriptDir.targetDir),
      { replace: false },
    );
  }
  for (const sharedScriptFile of stagedBundle.sharedScriptFiles) {
    await installStagedFile(
      path.join(codexStagingRoot, sharedScriptFile.targetPath),
      path.join(codexRoot, sharedScriptFile.targetPath),
      { replace: false },
    );
  }

  const promptsDir = path.join(codexRoot, "prompts");
  const cleanedPrompts = await cleanupInstalledEntries(
    promptsDir,
    previousEntries.prompts,
    {
      label: "prompt",
      confirmOptions: extraOpts.confirm,
    },
  );
  for (const prompt of bundle.prompts) {
    const entry = `${prompt.name}.md`;
    await installStagedFile(
      path.join(stagedBundle.stagedPromptsDir, entry),
      path.join(promptsDir, entry),
      { replace: cleanedPrompts },
    );
  }

  const skillsRoot = path.join(codexRoot, "skills");
  await cleanupKrammeComponents(skillsRoot, {
    label: "skill",
    filter: (e) => e.isDirectory(),
    recursive: true,
    prefixes: ["impl-"],
    confirmOptions: extraOpts.confirm,
  });
  const cleanedCodexSkills = await cleanupInstalledEntries(
    skillsRoot,
    previousEntries.skills,
    {
      label: "skill",
      recursive: true,
      confirmOptions: extraOpts.confirm,
    },
  );
  if (!cleanedCodexSkills) {
    for (const skill of [...bundle.skillDirs, ...bundle.generatedSkills]) {
      await preflightStagedDirInstall(
        resolveManagedChild(
          stagedBundle.stagedSkillsRoot,
          skill.name,
          "skill name",
        ),
        resolveManagedChild(skillsRoot, skill.name, "skill name"),
        {
          currentManagedFiles: stagedBundle.stagedSkillFiles?.[skill.name],
          label: `skill ${skill.name}`,
          previousManagedFiles: previousEntries.skillFiles?.[skill.name],
        },
      );
    }
  }
  for (const skill of bundle.skillDirs) {
    const stagedDir = resolveManagedChild(
      stagedBundle.stagedSkillsRoot,
      skill.name,
      "skill name",
    );
    const targetDir = resolveManagedChild(skillsRoot, skill.name, "skill name");
    await pruneStaleManagedFiles(
      targetDir,
      previousEntries.skillFiles?.[skill.name],
      stagedBundle.stagedSkillFiles?.[skill.name],
      { label: `skill ${skill.name}` },
    );
    await installStagedDir(
      stagedDir,
      targetDir,
      { replace: false },
    );
  }
  for (const skill of bundle.generatedSkills) {
    const stagedDir = resolveManagedChild(
      stagedBundle.stagedSkillsRoot,
      skill.name,
      "skill name",
    );
    const targetDir = resolveManagedChild(skillsRoot, skill.name, "skill name");
    await pruneStaleManagedFiles(
      targetDir,
      previousEntries.skillFiles?.[skill.name],
      stagedBundle.stagedSkillFiles?.[skill.name],
      { label: `skill ${skill.name}` },
    );
    await installStagedDir(
      stagedDir,
      targetDir,
      { replace: false },
    );
  }

  let cleanedAgentSkills = true;
  if (stagedBundle.agentSkillsRoot) {
    cleanedAgentSkills = await cleanupInstalledEntries(
      stagedBundle.agentSkillsRoot,
      previousEntries.agentSkills,
      {
        label: "skill",
        recursive: true,
        confirmOptions: extraOpts.confirm,
      },
    );
  }
  if (!cleanedAgentSkills) {
    for (const skill of bundle.agentSkills ?? []) {
      await preflightStagedDirInstall(
        resolveManagedChild(
          stagedBundle.stagedAgentSkillsRoot,
          skill.name,
          "agent skill name",
        ),
        resolveManagedChild(
          stagedBundle.agentSkillsRoot,
          skill.name,
          "agent skill name",
        ),
        {
          currentManagedFiles: stagedBundle.stagedAgentSkillFiles?.[skill.name],
          label: `agent skill ${skill.name}`,
          previousManagedFiles: previousEntries.agentSkillFiles?.[skill.name],
        },
      );
    }
  }
  for (const skill of bundle.agentSkills ?? []) {
    const stagedDir = resolveManagedChild(
      stagedBundle.stagedAgentSkillsRoot,
      skill.name,
      "agent skill name",
    );
    const targetDir = resolveManagedChild(
      stagedBundle.agentSkillsRoot,
      skill.name,
      "agent skill name",
    );
    await pruneStaleManagedFiles(
      targetDir,
      previousEntries.agentSkillFiles?.[skill.name],
      stagedBundle.stagedAgentSkillFiles?.[skill.name],
      { label: `agent skill ${skill.name}` },
    );
    await installStagedDir(
      stagedDir,
      targetDir,
      { replace: false },
    );
  }

  const hookPluginResult = await finalizeCodexHookPluginBundle(
    codexRoot,
    codexStagingRoot,
    bundle.codexPlugin,
    previousEntries,
    stagedBundle.hookTargets,
    { confirmOptions: extraOpts.confirm },
  );

  if (stagedBundle.stagedConfigPath) {
    await installStagedFile(
      stagedBundle.stagedConfigPath,
      path.join(codexRoot, "config.toml"),
      { replace: false },
    );
  }

  return {
    cleanedAgentSkills,
    cleanedCodexSkills,
    cleanedHookMarketplaces: hookPluginResult.cleanedHookMarketplaces,
    cleanedPluginCaches: hookPluginResult.cleanedPluginCaches,
    cleanedPrompts,
  };
}

async function preflightCodexBundleFinalization(
  codexRoot,
  codexStagingRoot,
  stagedBundle,
  bundle,
  previousEntries,
) {
  for (const sharedScriptDir of stagedBundle.sharedScriptDirs) {
    await preflightStagedDirInstall(
      path.join(codexStagingRoot, sharedScriptDir.targetDir),
      path.join(codexRoot, sharedScriptDir.targetDir),
      {
        label: `shared script directory ${sharedScriptDir.targetDir}`,
      },
    );
  }
  for (const sharedScriptFile of stagedBundle.sharedScriptFiles) {
    await preflightStagedFileInstall(
      path.join(codexStagingRoot, sharedScriptFile.targetPath),
      path.join(codexRoot, sharedScriptFile.targetPath),
      {
        label: `shared script file ${sharedScriptFile.targetPath}`,
      },
    );
  }

  const previousPrompts = new Set(sanitizeEntryList(previousEntries.prompts));
  for (const prompt of bundle.prompts) {
    const entry = `${prompt.name}.md`;
    await preflightStagedFileInstall(
      path.join(stagedBundle.stagedPromptsDir, entry),
      path.join(codexRoot, "prompts", entry),
      {
        label: `prompt ${entry}`,
        replace: previousPrompts.has(entry),
      },
    );
  }

  const previousSkills = new Set(sanitizeEntryList(previousEntries.skills));
  for (const skill of [...bundle.skillDirs, ...bundle.generatedSkills]) {
    await preflightStagedDirInstall(
      resolveManagedChild(
        stagedBundle.stagedSkillsRoot,
        skill.name,
        "skill name",
      ),
      resolveManagedChild(
        path.join(codexRoot, "skills"),
        skill.name,
        "skill name",
      ),
      {
        label: `skill ${skill.name}`,
        replace: previousSkills.has(skill.name),
      },
    );
  }

  const previousAgentSkills = new Set(
    sanitizeEntryList(previousEntries.agentSkills),
  );
  for (const skill of bundle.agentSkills ?? []) {
    await preflightStagedDirInstall(
      resolveManagedChild(
        stagedBundle.stagedAgentSkillsRoot,
        skill.name,
        "agent skill name",
      ),
      resolveManagedChild(
        stagedBundle.agentSkillsRoot,
        skill.name,
        "agent skill name",
      ),
      {
        label: `agent skill ${skill.name}`,
        replace: previousAgentSkills.has(skill.name),
      },
    );
  }

  if (stagedBundle.stagedConfigPath) {
    await preflightStagedFileInstall(
      stagedBundle.stagedConfigPath,
      path.join(codexRoot, "config.toml"),
      {
        label: "Codex config",
      },
    );
  }
}

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

function resolveCodexOutputRoot(outputRoot) {
  return path.basename(outputRoot) === ".codex"
    ? outputRoot
    : path.join(outputRoot, ".codex");
}

const CODEX_AGENTS_BLOCK_START = "<!-- BEGIN KRAMME CODEX TOOL MAP -->";
const CODEX_AGENTS_BLOCK_END = "<!-- END KRAMME CODEX TOOL MAP -->";

const CODEX_AGENTS_BLOCK_BODY = `## Kramme Codex Tool Mapping (Claude Compatibility)

This section maps Claude Code plugin tool references to Codex behavior.
Only this block is managed automatically.

Tool mapping:
- Read: use shell reads (cat/sed) or rg
- Write: create files via shell redirection or apply_patch
- Edit/MultiEdit: use apply_patch
- Bash: use shell_command
- Grep: use rg (fallback: grep)
- Glob: use rg --files or find
- LS: use ls via shell_command
- WebFetch/WebSearch: use curl or Context7 for library docs
- AskUserQuestion/Question: ask the user in chat
- Task/Subagent/Parallel: use multi-agent execution when available; otherwise run sequentially in main thread. Use multi_tool_use.parallel for parallel tool calls.
- TodoWrite/TodoRead: use update_plan for short-lived task tracking; use a markdown file only when durable repo artifacts are explicitly needed
- Skill: open the referenced SKILL.md and follow it
- ExitPlanMode: ignore
`;

async function ensureCodexAgentsFile(codexHome) {
  await ensureDir(codexHome);
  const filePath = path.join(codexHome, "AGENTS.md");
  const block = buildCodexAgentsBlock();

  if (!(await pathExists(filePath))) {
    await writeText(filePath, block + "\n");
    return;
  }

  const existing = await readText(filePath);
  const updated = upsertBlock(existing, block);
  if (updated !== existing) {
    await writeText(filePath, updated);
  }
}

function buildCodexAgentsBlock() {
  return [
    CODEX_AGENTS_BLOCK_START,
    CODEX_AGENTS_BLOCK_BODY.trim(),
    CODEX_AGENTS_BLOCK_END,
  ].join("\n");
}

function upsertBlock(existing, block) {
  const startIndex = existing.indexOf(CODEX_AGENTS_BLOCK_START);
  const endIndex = existing.indexOf(CODEX_AGENTS_BLOCK_END);

  if (startIndex !== -1 && endIndex !== -1 && endIndex > startIndex) {
    const before = existing.slice(0, startIndex).trimEnd();
    const after = existing
      .slice(endIndex + CODEX_AGENTS_BLOCK_END.length)
      .trimStart();
    return [before, block, after].filter(Boolean).join("\n\n") + "\n";
  }

  if (existing.trim().length === 0) {
    return block + "\n";
  }

  return existing.trimEnd() + "\n\n" + block + "\n";
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

async function rewriteCodexMarkdownResourcesFromSource(
  sourceDir,
  targetDir,
  options = {},
) {
  const entries = await fs.readdir(sourceDir, { withFileTypes: true });
  for (const entry of entries) {
    const sourcePath = path.join(sourceDir, entry.name);
    const targetPath = path.join(targetDir, entry.name);
    if (entry.isDirectory()) {
      await rewriteCodexMarkdownResourcesFromSource(
        sourcePath,
        targetPath,
        options,
      );
      continue;
    }
    if (
      !entry.isFile() ||
      path.extname(entry.name) !== ".md" ||
      entry.name === "SKILL.md"
    ) {
      continue;
    }
    const source = await readText(targetPath);
    const transformed = rewriteCodexSharedScriptReferences(
      transformContentForCodex(source, options),
      options.sharedScriptReplacements,
    );
    if (transformed !== source) {
      await writeText(targetPath, transformed);
    }
  }
}

module.exports = {
  ensureCodexAgentsFile,
  resolveCodexOutputRoot,
  writeCodexBundle,
};
