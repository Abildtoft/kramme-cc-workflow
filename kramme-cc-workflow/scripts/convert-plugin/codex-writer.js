"use strict";

const path = require("path");
const {
  finalizeCodexBundleOutput,
  stageCodexBundleOutput,
} = require("./codex-bundle-output");
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
  createInstallStagingRoot,
  removeInstallStagingRoot,
} = require("./install-staging");
const {
  ensureDir,
  pathExists,
  readText,
  writeText,
} = require("./filesystem");

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

module.exports = {
  ensureCodexAgentsFile,
  resolveCodexOutputRoot,
  writeCodexBundle,
};
