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
    await installStagedDir(stagedDir, targetDir, { replace: false });
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
    await installStagedDir(stagedDir, targetDir, { replace: false });
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
    await installStagedDir(stagedDir, targetDir, { replace: false });
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

module.exports = {
  finalizeCodexBundleOutput,
  stageCodexBundleOutput,
};
