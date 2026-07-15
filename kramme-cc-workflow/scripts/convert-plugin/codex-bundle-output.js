"use strict";

const os = require("os");
const path = require("path");
const { stageCodexConfig } = require("./codex-config");
const {
  finalizeCodexHookPluginBundle,
  stageCodexHookPluginBundle,
} = require("./codex-hook-plugin-writer");
const {
  rewriteCodexMarkdownResourcesFromSource,
} = require("./codex-markdown-resources");
const {
  codexSharedScriptReplacements,
  rewriteCodexSharedScriptReferences,
} = require("./codex-shared-scripts");
const { sanitizeEntryList } = require("./install-state");
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
  listRelativeFiles,
  pathExists,
  resolveManagedChild,
  writeText,
} = require("./filesystem");

/**
 * @typedef {import("./contracts").CodexBundle} CodexBundle
 * @typedef {import("./contracts").CodexSkillFile} CodexSkillFile
 * @typedef {import("./contracts").HookTargets} HookTargets
 * @typedef {import("./contracts").InstallEntries} PreviousInstallEntries
 * @typedef {import("./contracts").SharedScriptDir} SharedScriptDir
 * @typedef {import("./contracts").SharedScriptFile} SharedScriptFile
 * @typedef {import("./contracts").WriteCodexOptions} WriteCodexOptions
 * @typedef {Object} StagedBundle
 * @property {string | null} agentSkillsRoot
 * @property {string | null} agentStagingRoot
 * @property {string[]} hookMarketplaces
 * @property {HookTargets} hookTargets
 * @property {string[]} pluginCaches
 * @property {SharedScriptDir[]} sharedScriptDirs
 * @property {SharedScriptFile[]} sharedScriptFiles
 * @property {string | null} stagedAgentSkillsRoot
 * @property {Record<string, string[]>} stagedAgentSkillFiles
 * @property {string | null} stagedConfigPath
 * @property {string} stagedPromptsDir
 * @property {Record<string, string[]>} stagedSkillFiles
 * @property {string} stagedSkillsRoot
 */

/**
 * @template {CodexSkillFile} T
 * @typedef {Object} SkillGroupDescriptor
 * @property {Record<string, string[]>} currentManagedFiles
 * @property {T[]} entries
 * @property {string} label
 * @property {string} nameLabel
 * @property {string[]} previousEntries
 * @property {Record<string, string[]>} previousManagedFiles
 * @property {string | null} stagedRoot
 * @property {((skill: T, targetDir: string) => Promise<void>)} [stageEntry]
 * @property {string | null} targetRoot
 */

/**
 * @typedef {Omit<SkillGroupDescriptor<CodexSkillFile>, "entries" | "stageEntry"> & { entries: CodexSkillFile[] }} SkillGroupView
 */

/**
 * @template {CodexSkillFile} T
 * @param {Partial<SkillGroupDescriptor<T>> & Pick<SkillGroupDescriptor<T>, "currentManagedFiles" | "label" | "nameLabel" | "stagedRoot">} descriptor
 * @returns {SkillGroupDescriptor<T>}
 */
function createSkillGroupDescriptor(descriptor) {
  return {
    ...descriptor,
    entries: descriptor.entries ?? [],
    previousEntries: descriptor.previousEntries ?? [],
    previousManagedFiles: descriptor.previousManagedFiles ?? {},
    targetRoot: descriptor.targetRoot ?? null,
  };
}

/** @template {CodexSkillFile} T @param {SkillGroupDescriptor<T>} group */
async function stageSkillGroup(group) {
  const stageEntry = group.stageEntry;
  if (!stageEntry) {
    if (group.entries.length > 0) {
      throw new Error(`Missing staging callback for ${group.label} group.`);
    }
    return;
  }
  for (const skill of group.entries) {
    const targetDir = resolveManagedChild(
      requireSkillGroupRoot(group.stagedRoot, group, "staging"),
      skill.name,
      group.nameLabel,
    );
    await stageEntry(skill, targetDir);
    group.currentManagedFiles[skill.name] = await listRelativeFiles(targetDir);
  }
}

/**
 * @param {SkillGroupView} group
 * @param {{includeManagedFiles?: boolean}} [options]
 */
async function preflightSkillGroup(
  group,
  { includeManagedFiles = false } = {},
) {
  const previousEntries = new Set(sanitizeEntryList(group.previousEntries));
  for (const skill of group.entries) {
    const options =
      /** @type {{currentManagedFiles?: string[], label: string, previousManagedFiles?: string[], replace?: boolean}} */ ({
        label: `${group.label} ${skill.name}`,
      });
    if (includeManagedFiles) {
      options.currentManagedFiles = group.currentManagedFiles?.[skill.name];
      options.previousManagedFiles = group.previousManagedFiles?.[skill.name];
    } else {
      options.replace = previousEntries.has(skill.name);
    }
    await preflightStagedDirInstall(
      resolveManagedChild(
        requireSkillGroupRoot(group.stagedRoot, group, "staging"),
        skill.name,
        group.nameLabel,
      ),
      resolveManagedChild(
        requireSkillGroupRoot(group.targetRoot, group, "target"),
        skill.name,
        group.nameLabel,
      ),
      options,
    );
  }
}

/** @param {SkillGroupView} group */
async function finalizeSkillGroup(group) {
  for (const skill of group.entries) {
    const stagedDir = resolveManagedChild(
      requireSkillGroupRoot(group.stagedRoot, group, "staging"),
      skill.name,
      group.nameLabel,
    );
    const targetDir = resolveManagedChild(
      requireSkillGroupRoot(group.targetRoot, group, "target"),
      skill.name,
      group.nameLabel,
    );
    await pruneStaleManagedFiles(
      targetDir,
      group.previousManagedFiles?.[skill.name],
      group.currentManagedFiles?.[skill.name],
      { label: `${group.label} ${skill.name}` },
    );
    await installStagedDir(stagedDir, targetDir, { replace: false });
  }
}

/**
 * @param {string | null} root
 * @param {SkillGroupView} group
 * @param {string} kind
 * @returns {string}
 */
function requireSkillGroupRoot(root, group, kind) {
  if (!root) throw new Error(`Missing ${kind} root for ${group.label} group.`);
  return root;
}

/**
 * @param {string} codexRoot
 * @param {StagedBundle} stagedBundle
 * @param {CodexBundle} bundle
 * @param {PreviousInstallEntries} previousEntries
 */
function createFinalizationSkillGroups(
  codexRoot,
  stagedBundle,
  bundle,
  previousEntries,
) {
  const codexGroupFields = {
    currentManagedFiles: stagedBundle.stagedSkillFiles,
    label: "skill",
    nameLabel: "skill name",
    previousEntries: previousEntries.skills,
    previousManagedFiles: previousEntries.skillFiles,
    stagedRoot: stagedBundle.stagedSkillsRoot,
    targetRoot: path.join(codexRoot, "skills"),
  };
  return {
    agentSkillGroup: createSkillGroupDescriptor({
      currentManagedFiles: stagedBundle.stagedAgentSkillFiles,
      entries: bundle.agentSkills,
      label: "agent skill",
      nameLabel: "agent skill name",
      previousEntries: previousEntries.agentSkills,
      previousManagedFiles: previousEntries.agentSkillFiles,
      stagedRoot: stagedBundle.stagedAgentSkillsRoot,
      targetRoot: stagedBundle.agentSkillsRoot,
    }),
    codexSkillGroups: [
      createSkillGroupDescriptor({
        ...codexGroupFields,
        entries: bundle.skillDirs,
      }),
      createSkillGroupDescriptor({
        ...codexGroupFields,
        entries: bundle.generatedSkills,
      }),
    ],
  };
}

/**
 * @param {string} codexRoot
 * @param {string} codexStagingRoot
 * @param {CodexBundle} bundle
 * @param {PreviousInstallEntries} previousEntries
 * @param {string} pluginName
 * @param {WriteCodexOptions} extraOpts
 * @returns {Promise<StagedBundle>}
 */
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
    const stagedSkillFiles = /** @type {Record<string, string[]>} */ ({});
    await stageSkillGroup(
      createSkillGroupDescriptor({
        currentManagedFiles: stagedSkillFiles,
        entries: bundle.skillDirs,
        label: "skill",
        nameLabel: "skill name",
        stagedRoot: stagedSkillsRoot,
        stageEntry: async (skill, targetDir) => {
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
        },
      }),
    );
    await stageSkillGroup(
      createSkillGroupDescriptor({
        currentManagedFiles: stagedSkillFiles,
        entries: bundle.generatedSkills,
        label: "skill",
        nameLabel: "skill name",
        stagedRoot: stagedSkillsRoot,
        stageEntry: async (skill, targetDir) => {
          const content = rewriteCodexSharedScriptReferences(
            skill.content,
            sharedScriptReplacements,
          );
          await writeText(path.join(targetDir, "SKILL.md"), content + "\n");
        },
      }),
    );

    let agentsHome = null;
    let agentSkillsRoot = null;
    let stagedAgentSkillsRoot = null;
    const stagedAgentSkillFiles = /** @type {Record<string, string[]>} */ ({});
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
      await stageSkillGroup(
        createSkillGroupDescriptor({
          currentManagedFiles: stagedAgentSkillFiles,
          entries: bundle.agentSkills,
          label: "agent skill",
          nameLabel: "agent skill name",
          stagedRoot: stagedAgentSkillsRoot,
          stageEntry: async (skill, targetDir) => {
            await writeText(
              path.join(targetDir, "SKILL.md"),
              skill.content + "\n",
            );
          },
        }),
      );
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

/**
 * @param {string} codexRoot
 * @param {string} codexStagingRoot
 * @param {StagedBundle} stagedBundle
 * @param {CodexBundle} bundle
 * @param {PreviousInstallEntries} previousEntries
 * @param {WriteCodexOptions} extraOpts
 */
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
  const { agentSkillGroup, codexSkillGroups } = createFinalizationSkillGroups(
    codexRoot,
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
  await notifyInstallPhase(extraOpts, "shared-scripts");

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
  await notifyInstallPhase(extraOpts, "prompts");

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
    for (const skillGroup of codexSkillGroups) {
      await preflightSkillGroup(skillGroup, { includeManagedFiles: true });
    }
  }
  for (const skillGroup of codexSkillGroups) {
    await finalizeSkillGroup(skillGroup);
  }
  await notifyInstallPhase(extraOpts, "codex-skills");

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
    await preflightSkillGroup(agentSkillGroup, {
      includeManagedFiles: true,
    });
  }
  await finalizeSkillGroup(agentSkillGroup);
  await notifyInstallPhase(extraOpts, "agent-skills");

  const hookPluginResult = await finalizeCodexHookPluginBundle(
    codexRoot,
    codexStagingRoot,
    bundle.codexPlugin,
    previousEntries,
    stagedBundle.hookTargets,
    { confirmOptions: extraOpts.confirm },
  );
  await notifyInstallPhase(extraOpts, "hooks");

  if (stagedBundle.stagedConfigPath) {
    await installStagedFile(
      stagedBundle.stagedConfigPath,
      path.join(codexRoot, "config.toml"),
      { replace: false },
    );
  }
  await notifyInstallPhase(extraOpts, "config");

  return {
    cleanedAgentSkills,
    cleanedCodexSkills,
    cleanedHookMarketplaces: hookPluginResult.cleanedHookMarketplaces,
    cleanedPluginCaches: hookPluginResult.cleanedPluginCaches,
    cleanedPrompts,
  };
}

async function notifyInstallPhase(options, phase) {
  if (typeof options.onInstallPhase === "function") {
    await options.onInstallPhase(phase);
  }
}

/**
 * @param {string} codexRoot
 * @param {string} codexStagingRoot
 * @param {StagedBundle} stagedBundle
 * @param {CodexBundle} bundle
 * @param {PreviousInstallEntries} previousEntries
 */
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

  const { agentSkillGroup, codexSkillGroups } = createFinalizationSkillGroups(
    codexRoot,
    stagedBundle,
    bundle,
    previousEntries,
  );
  for (const skillGroup of [...codexSkillGroups, agentSkillGroup]) {
    await preflightSkillGroup(skillGroup);
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

module.exports = {
  finalizeCodexBundleOutput,
  stageCodexBundleOutput,
};
