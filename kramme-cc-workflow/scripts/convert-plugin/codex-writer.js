// @ts-check
"use strict";

const fs = require("fs/promises");
const os = require("os");
const path = require("path");
const {
  finalizeCodexBundleOutput,
  stageCodexBundleOutput,
} = require("./codex-bundle-output");
const {
  getInstallManifestPath,
  getPreviousInstallEntries,
  loadInstallState,
  sanitizeEntryList,
  setInstallEntries,
  unionEntryLists,
  writeInstallManifest,
  writeInstallState,
} = require("./install-state");
const {
  createInstallStagingRoot,
  installStagedFile,
  preflightStagedFileInstall,
  removeInstallStagingRoot,
  withInstallTransaction,
} = require("./install-staging");
const {
  copyFilePreservingMetadata,
  filesystemErrorCode,
  pathExists,
  readText,
  writeText,
} = require("./filesystem");

/**
 * @typedef {import("./contracts").CodexBundle} CodexBundle
 * @typedef {import("./contracts").InstallEntries} InstallEntries
 * @typedef {import("./contracts").InstallEntries} PreviousInstallEntries
 * @typedef {import("./contracts").InstallState} InstallState
 * @typedef {import("./codex-bundle-output").StagedBundle} StagedCodexBundle
 * @typedef {import("./contracts").WriteCodexOptions} WriteCodexOptions
 * @typedef {WriteCodexOptions & {
 *   lockTimeoutMs?: number,
 *   onInstallPhase?: (phase: string) => (void | Promise<void>)
 * }} TransactionalWriteCodexOptions
 * @typedef {Record<string, string[]>} ManagedFileMap
 * @typedef {{ device: number, inode: number, target: string }} SymbolicLinkIdentity
 * @typedef {{ filePath: string, symbolicLink: SymbolicLinkIdentity | null, targetFile: string }} CodexAgentsDestination
 * @typedef {{ expectedTargetContent: string | null, expectedTargetIdentity?: { ctimeMs: number, device: number, gid: number, inode: number, links: number, mode: number, uid: number }, stagedFile: string, targetFile: string }} StagedCodexAgentsFile
 * @typedef {{ cleanedAgentSkills: boolean, cleanedCodexSkills: boolean, cleanedHookMarketplaces: boolean, cleanedPluginCaches: boolean, cleanedPrompts: boolean }} FinalizedCodexBundle
 *
 * One locked installation attempt either completed or discovered that it must
 * be retried with wider locks or a moved AGENTS.md destination. The retried
 * destination travels with its own case so the caller cannot lose it.
 *
 * @typedef {{ status: "installed" }
 *   | { status: "agent-home-lock-required" }
 *   | { status: "agents-destination-lock-required", agentsDestination: CodexAgentsDestination }} CodexInstallAttempt
 */

/** @param {Record<string, unknown>} object @param {string} entry */
function hasOwnEntry(object, entry) {
  return Object.prototype.hasOwnProperty.call(object ?? {}, entry);
}

/**
 * @param {ManagedFileMap} previousFiles
 * @param {ManagedFileMap} currentFiles
 * @param {unknown} nextEntries
 * @param {boolean} cleaned
 * @returns {ManagedFileMap}
 */
function buildNextManagedFileMap(
  previousFiles,
  currentFiles,
  nextEntries,
  cleaned,
) {
  /** @type {ManagedFileMap} */
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

/**
 * @param {string} outputRoot
 * @param {CodexBundle} bundle
 * @param {TransactionalWriteCodexOptions} [extraOpts]
 * @returns {Promise<void>}
 */
async function writeCodexBundle(outputRoot, bundle, extraOpts = {}) {
  const codexRoot = resolveCodexOutputRoot(outputRoot);
  const agentsHome = extraOpts.agentsHome ?? path.join(os.homedir(), ".agents");
  const pluginName = extraOpts.pluginName ?? "plugin";
  let lockAgentHome = (bundle.agentSkills?.length ?? 0) > 0;
  let agentsDestination = await resolveCodexAgentsDestination(codexRoot);

  while (true) {
    const attempt = await runCodexInstallAttempt(codexRoot, bundle, extraOpts, {
      agentsDestination,
      agentsHome,
      lockAgentHome,
      pluginName,
    });
    if (attempt.status === "installed") return;
    if (attempt.status === "agent-home-lock-required") {
      lockAgentHome = true;
      continue;
    }
    agentsDestination = attempt.agentsDestination;
  }
}

/**
 * Perform one locked installation attempt against the expected destination.
 *
 * @param {string} codexRoot
 * @param {CodexBundle} bundle
 * @param {TransactionalWriteCodexOptions} extraOpts
 * @param {{ agentsDestination: CodexAgentsDestination, agentsHome: string, lockAgentHome: boolean, pluginName: string }} attemptState
 * @returns {Promise<CodexInstallAttempt>}
 */
async function runCodexInstallAttempt(
  codexRoot,
  bundle,
  extraOpts,
  { agentsDestination, agentsHome, lockAgentHome, pluginName },
) {
  const lockRoots = lockAgentHome ? [agentsHome] : [];
  const preserveInvalidLockRoots = [];
  if (agentsDestination.targetFile !== agentsDestination.filePath) {
    const targetRoot = path.dirname(agentsDestination.targetFile);
    lockRoots.push(targetRoot);
    preserveInvalidLockRoots.push(targetRoot);
  }
  return withInstallTransaction(
    codexRoot,
    {
      lockRoots,
      lockTimeoutMs: extraOpts.lockTimeoutMs,
      preserveInvalidLockRoots,
      pluginName,
    },
    async () => {
      const currentAgentsDestination =
        await resolveCodexAgentsDestination(codexRoot);
      if (
        !codexAgentsDestinationsMatch(
          currentAgentsDestination,
          agentsDestination,
        )
      ) {
        return {
          status: "agents-destination-lock-required",
          agentsDestination: currentAgentsDestination,
        };
      }
      const { state: installState } = await loadInstallState(codexRoot);
      const previousEntries = await getPreviousInstallEntries(
        codexRoot,
        installState,
        pluginName,
        "codex",
      );
      if (!lockAgentHome && previousEntries.agentSkills.length > 0) {
        return { status: "agent-home-lock-required" };
      }
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
        await stageCodexAgentsFile(
          codexRoot,
          codexStagingRoot,
          agentsDestination,
        );
        const finalizedBundle = await finalizeCodexBundleOutput(
          codexRoot,
          codexStagingRoot,
          stagedBundle,
          bundle,
          previousEntries,
          extraOpts,
        );
        await publishCodexAgentsFile(
          codexRoot,
          codexStagingRoot,
          agentsDestination,
          extraOpts,
        );
        const nextEntries = buildNextInstallEntries(
          bundle,
          stagedBundle,
          finalizedBundle,
          previousEntries,
        );
        await publishInstallState(
          codexRoot,
          codexStagingRoot,
          pluginName,
          installState,
          nextEntries,
          extraOpts,
        );
        return { status: "installed" };
      } finally {
        await removeInstallStagingRoot(codexStagingRoot);
        await removeInstallStagingRoot(agentStagingRoot);
      }
    },
  );
}

/**
 * Stage the AGENTS.md tool map once more and publish it, then confirm the
 * destination still resolves where the attempt locked it.
 *
 * @param {string} codexRoot
 * @param {string} codexStagingRoot
 * @param {CodexAgentsDestination} agentsDestination
 * @param {TransactionalWriteCodexOptions} extraOpts
 */
async function publishCodexAgentsFile(
  codexRoot,
  codexStagingRoot,
  agentsDestination,
  extraOpts,
) {
  const stagedAgentsFile = await stageCodexAgentsFile(
    codexRoot,
    codexStagingRoot,
    agentsDestination,
  );
  if (stagedAgentsFile) {
    await installStagedFile(
      stagedAgentsFile.stagedFile,
      stagedAgentsFile.targetFile,
      {
        expectedTargetContent: stagedAgentsFile.expectedTargetContent,
        expectedTargetIdentity: stagedAgentsFile.expectedTargetIdentity,
        label: "Codex AGENTS.md tool map",
        preserveTargetChangesOnRollback: true,
      },
    );
  }
  await assertCodexAgentsDestinationUnchanged(codexRoot, agentsDestination);
  await notifyInstallPhase(extraOpts, "agents");
}

/**
 * Record the new entries and publish them.
 *
 * The recovery manifest is published first and the authoritative state last, so
 * a reader resolves either the old state or the complete new installation while
 * both files remain backward-compatible.
 *
 * @param {string} codexRoot
 * @param {string} codexStagingRoot
 * @param {string} pluginName
 * @param {InstallState} installState
 * @param {InstallEntries} nextEntries
 * @param {TransactionalWriteCodexOptions} extraOpts
 */
async function publishInstallState(
  codexRoot,
  codexStagingRoot,
  pluginName,
  installState,
  nextEntries,
  extraOpts,
) {
  setInstallEntries(installState, pluginName, "codex", nextEntries);
  await writeInstallManifest(
    codexStagingRoot,
    pluginName,
    "codex",
    nextEntries,
  );
  await writeInstallState(codexStagingRoot, installState);
  await installStagedFile(
    getInstallManifestPath(codexStagingRoot, pluginName, "codex"),
    getInstallManifestPath(codexRoot, pluginName, "codex"),
    { replace: true },
  );
  await notifyInstallPhase(extraOpts, "manifest");
  await installStagedFile(
    path.join(codexStagingRoot, ".kramme-install-state.json"),
    path.join(codexRoot, ".kramme-install-state.json"),
    { replace: true },
  );
  await notifyInstallPhase(extraOpts, "state");
}

/**
 * Merge the staged bundle into the entries this installation should record.
 *
 * A cleaned group replaces its previous entries; an uncleaned one unions with
 * them so entries this plugin no longer ships stay managed.
 *
 * @param {CodexBundle} bundle
 * @param {StagedCodexBundle} stagedBundle
 * @param {FinalizedCodexBundle} finalizedBundle
 * @param {PreviousInstallEntries} previousEntries
 * @returns {InstallEntries}
 */
function buildNextInstallEntries(
  bundle,
  stagedBundle,
  finalizedBundle,
  previousEntries,
) {
  const currentCodexSkills = [
    ...bundle.skillDirs.map((skill) => skill.name),
    ...bundle.generatedSkills.map((skill) => skill.name),
  ];
  const currentAgentSkills = (bundle.agentSkills ?? []).map(
    (skill) => skill.name,
  );
  const currentPrompts = bundle.prompts.map((prompt) => `${prompt.name}.md`);
  const nextSkills = finalizedBundle.cleanedCodexSkills
    ? currentCodexSkills
    : unionEntryLists(previousEntries.skills, currentCodexSkills);
  const nextAgentSkills = finalizedBundle.cleanedAgentSkills
    ? currentAgentSkills
    : unionEntryLists(previousEntries.agentSkills, currentAgentSkills);
  return {
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
      ? currentPrompts
      : unionEntryLists(previousEntries.prompts, currentPrompts),
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
}

/** @param {TransactionalWriteCodexOptions} options @param {string} phase */
async function notifyInstallPhase(options, phase) {
  if (typeof options.onInstallPhase === "function") {
    await options.onInstallPhase(phase);
  }
}

/** @param {string} outputRoot */
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

/**
 * @param {string} codexHome
 * @param {string} stagingRoot
 * @param {CodexAgentsDestination} lockedDestination
 * @returns {Promise<StagedCodexAgentsFile | null>}
 */
async function stageCodexAgentsFile(codexHome, stagingRoot, lockedDestination) {
  const destination = await resolveCodexAgentsDestination(codexHome);
  assertMatchingCodexAgentsDestination(destination, lockedDestination);

  const targetExists = await pathExists(destination.targetFile);
  const existing = targetExists ? await readText(destination.targetFile) : "";
  const updated = upsertBlock(existing, buildCodexAgentsBlock());
  if (updated === existing) return null;

  const stagedFile = path.join(stagingRoot, "AGENTS.md");
  await fs.rm(stagedFile, { force: true });
  let expectedTargetIdentity;
  if (targetExists) {
    const existingStats = await fs.lstat(destination.targetFile);
    if (!existingStats.isFile()) {
      throw new Error(
        "Codex AGENTS.md destination changed during installation; retry the install.",
      );
    }
    assertCodexAgentsFileHasSingleLink(destination.filePath, existingStats);
    await copyFilePreservingMetadata(destination.targetFile, stagedFile);
    await writeText(stagedFile, updated);
    expectedTargetIdentity = {
      ctimeMs: existingStats.ctimeMs,
      device: existingStats.dev,
      gid: existingStats.gid,
      inode: existingStats.ino,
      links: existingStats.nlink,
      mode: existingStats.mode,
      uid: existingStats.uid,
    };
  } else {
    await writeText(stagedFile, updated);
  }
  const expectedTargetContent = targetExists ? existing : null;
  await preflightStagedFileInstall(stagedFile, destination.targetFile, {
    expectedTargetContent,
    label: "Codex AGENTS.md tool map",
  });
  return {
    expectedTargetContent,
    expectedTargetIdentity,
    stagedFile,
    targetFile: destination.targetFile,
  };
}

/**
 * @param {string} codexHome
 * @returns {Promise<CodexAgentsDestination>}
 */
async function resolveCodexAgentsDestination(codexHome) {
  const filePath = path.join(codexHome, "AGENTS.md");
  let stats;
  try {
    stats = await fs.lstat(filePath);
  } catch (error) {
    if (filesystemErrorCode(error) === "ENOENT") {
      return { filePath, symbolicLink: null, targetFile: filePath };
    }
    throw error;
  }
  if (!stats.isSymbolicLink()) {
    assertCodexAgentsFileHasSingleLink(filePath, stats);
    return { filePath, symbolicLink: null, targetFile: filePath };
  }

  const linkTarget = await fs.readlink(filePath);
  let targetFile;
  try {
    targetFile = await fs.realpath(filePath);
  } catch (error) {
    if (filesystemErrorCode(error) === "ENOENT") {
      throw new Error(
        `Cannot install Codex AGENTS.md tool map because ${filePath} is a dangling symbolic link.`,
        { cause: error },
      );
    }
    throw error;
  }
  const targetStats = await fs.lstat(targetFile);
  if (!targetStats.isFile()) {
    throw new Error(
      `Cannot install Codex AGENTS.md tool map because ${filePath} does not point to a regular file.`,
    );
  }
  assertCodexAgentsFileHasSingleLink(filePath, targetStats);
  return {
    filePath,
    symbolicLink: {
      device: stats.dev,
      inode: stats.ino,
      target: linkTarget,
    },
    targetFile,
  };
}

/**
 * @param {string} codexHome
 * @param {CodexAgentsDestination} expected
 */
async function assertCodexAgentsDestinationUnchanged(codexHome, expected) {
  const current = await resolveCodexAgentsDestination(codexHome);
  assertMatchingCodexAgentsDestination(current, expected);
}

/**
 * @param {CodexAgentsDestination} current
 * @param {CodexAgentsDestination} expected
 */
function assertMatchingCodexAgentsDestination(current, expected) {
  if (!codexAgentsDestinationsMatch(current, expected)) {
    throw new Error(
      "Codex AGENTS.md destination changed during installation; retry the install.",
    );
  }
}

/**
 * @param {CodexAgentsDestination} left
 * @param {CodexAgentsDestination} right
 */
function codexAgentsDestinationsMatch(left, right) {
  if (
    left.filePath !== right.filePath ||
    left.targetFile !== right.targetFile
  ) {
    return false;
  }
  if (left.symbolicLink === null || right.symbolicLink === null) {
    return left.symbolicLink === right.symbolicLink;
  }
  return (
    left.symbolicLink.device === right.symbolicLink.device &&
    left.symbolicLink.inode === right.symbolicLink.inode &&
    left.symbolicLink.target === right.symbolicLink.target
  );
}

/**
 * @param {string} filePath
 * @param {import("fs").Stats} stats
 */
function assertCodexAgentsFileHasSingleLink(filePath, stats) {
  if (stats.isFile() && stats.nlink > 1) {
    throw new Error(
      `Cannot install Codex AGENTS.md tool map because ${filePath} is hard-linked to another file.`,
    );
  }
}

function buildCodexAgentsBlock() {
  return [
    CODEX_AGENTS_BLOCK_START,
    CODEX_AGENTS_BLOCK_BODY.trim(),
    CODEX_AGENTS_BLOCK_END,
  ].join("\n");
}

/** @param {string} existing @param {string} block */
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

module.exports = {
  resolveCodexOutputRoot,
  writeCodexBundle,
};
