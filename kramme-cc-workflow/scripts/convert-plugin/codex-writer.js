"use strict";

const fs = require("fs/promises");
const path = require("path");
const os = require("os");
const readline = require("readline");
const { normalizeName } = require("./frontmatter");
const { transformContentForCodex } = require("./codex-transformer");
const {
  copyDir,
  copyFile,
  ensureDir,
  pathExists,
  readJson,
  readText,
  resolveManagedChild,
  writeJson,
  writeText,
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
  const sharedScriptDirs = bundle.codexPlugin?.sharedScriptDirs ?? [];
  const sharedScriptFiles = bundle.codexPlugin?.sharedScriptFiles ?? [];
  for (const sharedScriptDir of sharedScriptDirs) {
    if (await pathExists(sharedScriptDir.sourceDir)) {
      await copyDir(
        sharedScriptDir.sourceDir,
        path.join(codexRoot, sharedScriptDir.targetDir),
      );
    }
  }
  for (const sharedScriptFile of sharedScriptFiles) {
    if (await pathExists(sharedScriptFile.sourceFile)) {
      await copyFile(
        sharedScriptFile.sourceFile,
        path.join(codexRoot, sharedScriptFile.targetPath),
      );
    }
  }
  const sharedScriptReplacements = codexSharedScriptReplacements(
    codexRoot,
    sharedScriptDirs,
    sharedScriptFiles,
  );

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
    await writeText(
      path.join(promptsDir, `${prompt.name}.md`),
      prompt.content + "\n",
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

  for (const skill of bundle.skillDirs) {
    const targetDir = resolveManagedChild(skillsRoot, skill.name, "skill name");
    await copyDir(skill.sourceDir, targetDir);
    if (skill.content) {
      const content = rewriteCodexSharedScriptReferences(
        skill.content,
        sharedScriptReplacements,
      );
      await writeText(path.join(targetDir, "SKILL.md"), content + "\n");
    }
    await rewriteCodexMarkdownResourcesFromSource(skill.sourceDir, targetDir, {
      knownCommands: bundle.knownCommands,
      knownAgentSkills: bundle.knownAgentSkills,
      sharedScriptReplacements,
    });
  }

  for (const skill of bundle.generatedSkills) {
    const targetDir = resolveManagedChild(skillsRoot, skill.name, "skill name");
    const content = rewriteCodexSharedScriptReferences(
      skill.content,
      sharedScriptReplacements,
    );
    await writeText(path.join(targetDir, "SKILL.md"), content + "\n");
  }

  let cleanedAgentSkills = true;
  if (
    bundle.agentSkills &&
    (bundle.agentSkills.length > 0 || previousEntries.agentSkills.length > 0)
  ) {
    const agentsHome =
      extraOpts.agentsHome ?? path.join(os.homedir(), ".agents");
    const agentSkillsRoot = path.join(agentsHome, "skills");
    cleanedAgentSkills = await cleanupInstalledEntries(
      agentSkillsRoot,
      previousEntries.agentSkills,
      {
        label: "skill",
        recursive: true,
        confirmOptions: extraOpts.confirm,
      },
    );
    for (const skill of bundle.agentSkills) {
      const targetDir = resolveManagedChild(
        agentSkillsRoot,
        skill.name,
        "agent skill name",
      );
      await writeText(path.join(targetDir, "SKILL.md"), skill.content + "\n");
    }
  }

  const hookPluginResult = await writeCodexHookPluginBundle(
    codexRoot,
    bundle.codexPlugin,
    previousEntries,
    { confirmOptions: extraOpts.confirm },
  );

  const config = renderCodexConfig(bundle.mcpServers);
  if (config) {
    await writeText(path.join(codexRoot, "config.toml"), config);
  }
  if (bundle.codexPlugin) {
    await upsertCodexHookPluginConfig(codexRoot, bundle.codexPlugin);
  } else if (
    previousEntries.pluginCaches.length > 0 ||
    previousEntries.hookMarketplaces.length > 0
  ) {
    await removeCodexHookPluginConfig(
      codexRoot,
      codexHookPluginConfigRef(pluginName),
    );
  }

  const nextEntries = {
    hookMarketplaces: hookPluginResult.cleanedHookMarketplaces
      ? hookPluginResult.hookMarketplaces
      : unionEntryLists(
          previousEntries.hookMarketplaces,
          hookPluginResult.hookMarketplaces,
        ),
    pluginCaches: hookPluginResult.cleanedPluginCaches
      ? hookPluginResult.pluginCaches
      : unionEntryLists(
          previousEntries.pluginCaches,
          hookPluginResult.pluginCaches,
        ),
    prompts: cleanedPrompts
      ? bundle.prompts.map((prompt) => `${prompt.name}.md`)
      : unionEntryLists(
          previousEntries.prompts,
          bundle.prompts.map((prompt) => `${prompt.name}.md`),
        ),
    skills: cleanedCodexSkills
      ? [
          ...bundle.skillDirs.map((skill) => skill.name),
          ...bundle.generatedSkills.map((skill) => skill.name),
        ]
      : unionEntryLists(previousEntries.skills, [
          ...bundle.skillDirs.map((skill) => skill.name),
          ...bundle.generatedSkills.map((skill) => skill.name),
        ]),
    agentSkills: cleanedAgentSkills
      ? (bundle.agentSkills ?? []).map((skill) => skill.name)
      : unionEntryLists(
          previousEntries.agentSkills,
          (bundle.agentSkills ?? []).map((skill) => skill.name),
        ),
    updatedAtMs: Date.now(),
  };
  setInstallEntries(installState, pluginName, "codex", nextEntries);
  await writeInstallState(codexRoot, installState);
  await writeInstallManifest(codexRoot, pluginName, "codex", nextEntries);
}

async function writeCodexHookPluginBundle(
  codexRoot,
  codexPlugin,
  previousEntries,
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
      pluginCaches: [],
      hookMarketplaces: [],
    };
  }

  const marketplaceEntry = codexHookMarketplaceEntry(codexPlugin);
  const marketplaceRoot = codexHookMarketplaceRoot(codexRoot, codexPlugin);
  const marketplacePluginRoot = path.join(
    marketplaceRoot,
    "plugins",
    codexPlugin.name,
  );
  const pluginCacheEntry = codexHookPluginCacheEntry(codexPlugin);
  const pluginCacheRoot = resolveManagedChild(
    path.join(codexRoot, "plugins"),
    pluginCacheEntry,
    "Codex plugin cache entry",
  );

  await prepareCodexHookPluginTarget(marketplaceRoot, {
    label: "Codex hook marketplace",
    entry: marketplaceEntry,
    previousEntries: previousEntries.hookMarketplaces,
    cleaned: cleanedHookMarketplaces,
    confirmOptions,
  });
  await prepareCodexHookPluginTarget(pluginCacheRoot, {
    label: "Codex plugin cache entry",
    entry: pluginCacheEntry,
    previousEntries: previousEntries.pluginCaches,
    cleaned: cleanedPluginCaches,
    confirmOptions,
  });

  await writeCodexHookPluginTree(marketplacePluginRoot, codexPlugin);
  await writeCodexHookPluginTree(pluginCacheRoot, codexPlugin);
  await writeCodexHookMarketplace(marketplaceRoot, codexPlugin);

  return {
    cleanedPluginCaches,
    cleanedHookMarketplaces,
    pluginCaches: [pluginCacheEntry],
    hookMarketplaces: [marketplaceEntry],
  };
}

async function prepareCodexHookPluginTarget(
  targetRoot,
  { label, entry, previousEntries, cleaned, confirmOptions },
) {
  if (!(await pathExists(targetRoot))) return;

  const wasTracked = sanitizeEntryList(previousEntries).includes(entry);
  if (wasTracked) {
    if (cleaned) {
      await fs.rm(targetRoot, { recursive: true, force: true });
    }
    return;
  }

  console.log(`\nFound existing untracked ${label} at ${targetRoot}.`);
  const confirmed = await confirm(
    `Delete existing ${label} before installing?`,
    confirmOptions,
  );
  if (!confirmed) {
    throw new Error(`Refusing to overwrite existing untracked ${label}.`);
  }

  await fs.rm(targetRoot, { recursive: true, force: true });
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

function codexHookPluginConfigRef(pluginName) {
  const name = normalizeName(pluginName);
  return { name, marketplaceName: name };
}

function codexHookMarketplaceEntry(codexPlugin) {
  return path.join(".kramme-plugin-marketplaces", codexPlugin.marketplaceName);
}

function codexHookMarketplaceRoot(codexRoot, codexPlugin) {
  return resolveManagedChild(
    codexRoot,
    codexHookMarketplaceEntry(codexPlugin),
    "Codex hook marketplace entry",
  );
}

function codexHookPluginCacheEntry(codexPlugin) {
  return path.join(
    "cache",
    codexPlugin.marketplaceName,
    codexPlugin.name,
    codexPlugin.version,
  );
}

async function upsertCodexHookPluginConfig(codexRoot, codexPlugin) {
  const configPath = path.join(codexRoot, "config.toml");
  const existing = (await pathExists(configPath))
    ? await readText(configPath)
    : "";
  const tables = renderCodexHookPluginConfigTables(codexRoot, codexPlugin);
  const updated = upsertTomlTables(existing, tables);
  if (updated !== existing) {
    await writeText(configPath, updated);
  }
}

async function removeCodexHookPluginConfig(codexRoot, codexPlugin) {
  const configPath = path.join(codexRoot, "config.toml");
  if (!(await pathExists(configPath))) return;
  const existing = await readText(configPath);
  const updated = removeTomlTables(existing, [
    codexMarketplaceTableHeader(codexPlugin),
    codexPluginTableHeader(codexPlugin),
  ]);
  if (updated !== existing) {
    await writeText(configPath, updated);
  }
}

function renderCodexHookPluginConfigTables(codexRoot, codexPlugin) {
  const source = codexHookMarketplaceRoot(codexRoot, codexPlugin);
  const lastUpdated = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
  return [
    {
      header: codexMarketplaceTableHeader(codexPlugin),
      content: [
        codexMarketplaceTableHeader(codexPlugin),
        `last_updated = ${formatTomlString(lastUpdated)}`,
        'source_type = "local"',
        `source = ${formatTomlString(source)}`,
      ].join("\n"),
    },
    {
      header: codexPluginTableHeader(codexPlugin),
      content: [codexPluginTableHeader(codexPlugin), "enabled = true"].join(
        "\n",
      ),
    },
  ];
}

function codexMarketplaceTableHeader(codexPlugin) {
  return `[marketplaces.${formatTomlKey(codexPlugin.marketplaceName)}]`;
}

function codexPluginTableHeader(codexPlugin) {
  return `[plugins.${formatTomlKey(`${codexPlugin.name}@${codexPlugin.marketplaceName}`)}]`;
}

function upsertTomlTables(existing, tables) {
  const headers = tables.map((table) => table.header);
  const withoutExisting = removeTomlTables(existing, headers).trimEnd();
  const renderedTables = tables.map((table) => table.content.trimEnd());
  return (
    [withoutExisting, ...renderedTables].filter(Boolean).join("\n\n") + "\n"
  );
}

function removeTomlTables(existing, headers) {
  let result = existing;
  for (const header of headers) {
    result = removeTomlTable(result, header);
  }
  return (
    result.replace(/\n{3,}/g, "\n\n").trimEnd() + (result.trim() ? "\n" : "")
  );
}

function removeTomlTable(existing, header) {
  const lines = String(existing ?? "").split(/\r?\n/);
  const kept = [];
  let skipping = false;
  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed === header) {
      skipping = true;
      continue;
    }
    if (skipping && /^\[/.test(trimmed)) {
      skipping = false;
    }
    if (!skipping) {
      kept.push(line);
    }
  }
  return kept.join("\n");
}

function resolveCodexOutputRoot(outputRoot) {
  return path.basename(outputRoot) === ".codex"
    ? outputRoot
    : path.join(outputRoot, ".codex");
}

function renderCodexConfig(mcpServers) {
  if (!mcpServers || Object.keys(mcpServers).length === 0) return null;

  const lines = ["# Generated by kramme-cc-workflow", ""];

  for (const [name, server] of Object.entries(mcpServers)) {
    const key = formatTomlKey(name);
    lines.push(`[mcp_servers.${key}]`);

    if (server.command) {
      lines.push(`command = ${formatTomlString(server.command)}`);
      if (server.args && server.args.length > 0) {
        const args = server.args.map((arg) => formatTomlString(arg)).join(", ");
        lines.push(`args = [${args}]`);
      }

      if (server.env && Object.keys(server.env).length > 0) {
        lines.push("");
        lines.push(`[mcp_servers.${key}.env]`);
        for (const [envKey, value] of Object.entries(server.env)) {
          lines.push(`${formatTomlKey(envKey)} = ${formatTomlString(value)}`);
        }
      }
    } else if (server.url) {
      lines.push(`url = ${formatTomlString(server.url)}`);
      if (server.headers && Object.keys(server.headers).length > 0) {
        lines.push(`http_headers = ${formatTomlInlineTable(server.headers)}`);
      }
    }

    lines.push("");
  }

  return lines.join("\n");
}

function formatTomlString(value) {
  return JSON.stringify(value);
}

function formatTomlKey(value) {
  if (/^[A-Za-z0-9_-]+$/.test(value)) return value;
  return JSON.stringify(value);
}

function formatTomlInlineTable(entries) {
  const parts = Object.entries(entries).map(
    ([key, value]) => `${formatTomlKey(key)} = ${formatTomlString(value)}`,
  );
  return `{ ${parts.join(", ")} }`;
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

function createInstallState() {
  return {
    version: 1,
    plugins: {},
  };
}

function sanitizeInstallTimestamp(value) {
  const timestamp = Number(value);
  if (!Number.isFinite(timestamp) || timestamp <= 0) return undefined;
  return timestamp;
}

function sanitizeInstallRecord(record) {
  return {
    hookMarketplaces: sanitizeEntryList(record?.hookMarketplaces),
    prompts: sanitizeEntryList(record?.prompts),
    pluginCaches: sanitizeEntryList(record?.pluginCaches),
    skills: sanitizeEntryList(record?.skills),
    agentSkills: sanitizeEntryList(record?.agentSkills),
    updatedAtMs: sanitizeInstallTimestamp(record?.updatedAtMs),
  };
}

function parseInstallManifestFilename(filename) {
  const match = /^(.*)-codex\.json$/.exec(filename);
  if (!match) return null;

  try {
    return {
      pluginName: decodeURIComponent(match[1]),
      targetName: "codex",
    };
  } catch {
    return null;
  }
}

function getLegacyManifestOrderTimestamp(stats) {
  if (Number.isFinite(stats?.birthtimeMs) && stats.birthtimeMs > 0) {
    return stats.birthtimeMs;
  }
  if (Number.isFinite(stats?.mtimeMs) && stats.mtimeMs > 0) {
    return stats.mtimeMs;
  }
  if (Number.isFinite(stats?.ctimeMs) && stats.ctimeMs > 0) {
    return stats.ctimeMs;
  }
  return 0;
}

async function rebuildInstallStateFromManifests(root) {
  const state = createInstallState();
  const manifestsDir = path.join(root, ".kramme-install-manifests");
  if (!(await pathExists(manifestsDir))) return state;

  const entries = await fs.readdir(manifestsDir, { withFileTypes: true });
  const manifests = [];
  for (const entry of entries) {
    if (!entry.isFile() || path.extname(entry.name) !== ".json") continue;

    const manifestMeta = parseInstallManifestFilename(entry.name);
    if (!manifestMeta) continue;

    const manifest = await loadInstallManifest(
      root,
      manifestMeta.pluginName,
      manifestMeta.targetName,
    );
    if (!manifest) continue;

    let fallbackUpdatedAtMs = 0;
    try {
      const stats = await fs.stat(path.join(manifestsDir, entry.name));
      // Prefer creation time so hand-edited legacy manifests still rebuild in install order.
      fallbackUpdatedAtMs = getLegacyManifestOrderTimestamp(stats);
    } catch {
      // Ignore stat failures and fall back to deterministic filename ordering.
    }

    manifests.push({
      ...manifestMeta,
      manifest,
      sortKey: manifest.updatedAtMs ?? fallbackUpdatedAtMs,
    });
  }

  manifests.sort((left, right) => {
    if (left.sortKey !== right.sortKey) {
      return left.sortKey - right.sortKey;
    }
    if (left.pluginName !== right.pluginName) {
      return left.pluginName.localeCompare(right.pluginName);
    }
    return left.targetName.localeCompare(right.targetName);
  });

  for (const { pluginName, targetName, manifest, sortKey } of manifests) {
    setInstallEntries(
      state,
      pluginName,
      targetName,
      manifest.updatedAtMs === undefined && sortKey > 0
        ? { ...manifest, updatedAtMs: sortKey }
        : manifest,
    );
  }

  return state;
}

async function loadInstallState(root) {
  const filePath = path.join(root, ".kramme-install-state.json");
  if (!(await pathExists(filePath))) {
    return {
      state: await rebuildInstallStateFromManifests(root),
      fromDisk: false,
    };
  }

  try {
    const state = await readJson(filePath);
    if (
      state &&
      typeof state === "object" &&
      state.plugins &&
      typeof state.plugins === "object"
    ) {
      return {
        state,
        fromDisk: true,
      };
    }
  } catch {
    // Ignore invalid state and rebuild from the current install.
  }

  return {
    state: await rebuildInstallStateFromManifests(root),
    fromDisk: false,
  };
}

function getInstallManifestPath(root, pluginName, targetName) {
  return path.join(
    root,
    ".kramme-install-manifests",
    `${encodeURIComponent(pluginName)}-${targetName}.json`,
  );
}

async function loadInstallManifest(root, pluginName, targetName) {
  const filePath = getInstallManifestPath(root, pluginName, targetName);
  if (!(await pathExists(filePath))) return null;

  try {
    return sanitizeInstallRecord(await readJson(filePath));
  } catch {
    // Ignore invalid manifests and rebuild from the current install.
  }

  return null;
}

async function writeInstallManifest(root, pluginName, targetName, entries) {
  await writeJson(
    getInstallManifestPath(root, pluginName, targetName),
    sanitizeInstallRecord(entries),
  );
}

async function writeInstallState(root, state) {
  await writeJson(path.join(root, ".kramme-install-state.json"), state);
}

function getInstallEntries(state, pluginName, targetName) {
  const targetState = state.plugins?.[pluginName]?.[targetName];
  return sanitizeInstallRecord(targetState);
}

async function getPreviousInstallEntries(root, state, pluginName, targetName) {
  if (state.plugins?.[pluginName]?.[targetName]) {
    return getInstallEntries(state, pluginName, targetName);
  }
  const manifest = await loadInstallManifest(root, pluginName, targetName);
  return manifest ?? getInstallEntries(state, pluginName, targetName);
}

function setInstallEntries(state, pluginName, targetName, entries) {
  if (!state.plugins || typeof state.plugins !== "object") {
    state.plugins = {};
  }
  if (
    !state.plugins[pluginName] ||
    typeof state.plugins[pluginName] !== "object"
  ) {
    state.plugins[pluginName] = {};
  }
  state.plugins[pluginName][targetName] = sanitizeInstallRecord(entries);
}

function sanitizeEntryList(entries) {
  if (!Array.isArray(entries)) return [];
  return entries.map((entry) => String(entry ?? "").trim()).filter(Boolean);
}

function unionEntryLists(...lists) {
  return Array.from(
    new Set(lists.flatMap((entries) => sanitizeEntryList(entries))),
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

async function cleanupKrammeComponents(
  dir,
  {
    label,
    filter,
    recursive = false,
    prefixes = ["kramme:", "kramme-"],
    confirmOptions = {},
  } = {},
) {
  if (!(await pathExists(dir))) return;
  const entries = await fs.readdir(dir, { withFileTypes: true });
  const matched = entries
    .filter(filter)
    .filter((entry) => prefixes.some((prefix) => entry.name.startsWith(prefix)))
    .map((entry) => entry.name);

  if (matched.length === 0) return;

  console.log(
    `\nFound ${matched.length} existing kramme ${label}(s) in ${dir}:`,
  );
  for (const name of matched) {
    console.log(`  - ${name}`);
  }

  const confirmed = await confirm(
    `Delete these ${label}s before installing?`,
    confirmOptions,
  );
  if (!confirmed) {
    console.log(`Skipping ${label} cleanup.`);
    return;
  }

  for (const name of matched) {
    await fs.rm(path.join(dir, name), { recursive, force: true });
  }
  console.log(`Deleted ${matched.length} ${label}(s).`);
}

async function cleanupInstalledEntries(
  dir,
  entries,
  { label, recursive = false, confirmOptions = {} } = {},
) {
  const matched = [];
  for (const entry of sanitizeEntryList(entries)) {
    const targetPath = resolveManagedChild(dir, entry, `${label} entry`);
    if (await pathExists(targetPath)) {
      matched.push({ name: entry, path: targetPath });
    }
  }

  if (matched.length === 0) return true;

  console.log(
    `\nFound ${matched.length} existing ${label}(s) from this plugin in ${dir}:`,
  );
  for (const { name } of matched) {
    console.log(`  - ${name}`);
  }

  const confirmed = await confirm(
    `Delete these ${label}s before installing?`,
    confirmOptions,
  );
  if (!confirmed) {
    console.log(`Skipping ${label} cleanup.`);
    return false;
  }

  for (const { path: targetPath } of matched) {
    await fs.rm(targetPath, { recursive, force: true });
  }
  console.log(`Deleted ${matched.length} ${label}(s).`);
  return true;
}

let nonInteractiveReaderInitialized = false;
let nonInteractiveInputBuffer = "";
let nonInteractiveStreamEnded = false;
let nonInteractiveAnswerWaiter = null;
let nonInteractiveFallbackAnswer;

function parseConfirmationAnswer(answer) {
  const normalized = String(answer ?? "")
    .trim()
    .toLowerCase();
  return normalized === "y" || normalized === "yes";
}

function readLineFromNonInteractiveBuffer() {
  const newlineIndex = nonInteractiveInputBuffer.indexOf("\n");
  if (newlineIndex < 0) return null;
  const rawLine = nonInteractiveInputBuffer.slice(0, newlineIndex);
  nonInteractiveInputBuffer = nonInteractiveInputBuffer.slice(newlineIndex + 1);
  return rawLine.endsWith("\r") ? rawLine.slice(0, -1) : rawLine;
}

function setupNonInteractiveReader() {
  if (nonInteractiveReaderInitialized) return;
  nonInteractiveReaderInitialized = true;
  process.stdin.setEncoding("utf8");
  process.stdin.on("data", (chunk) => {
    nonInteractiveInputBuffer += chunk;

    if (!nonInteractiveAnswerWaiter) {
      if (nonInteractiveInputBuffer.includes("\n")) {
        process.stdin.pause();
      }
      return;
    }

    const line = readLineFromNonInteractiveBuffer();
    if (line === null) return;

    const resolve = nonInteractiveAnswerWaiter;
    nonInteractiveAnswerWaiter = null;
    process.stdin.pause();
    resolve(line);
  });

  process.stdin.on("end", () => {
    nonInteractiveStreamEnded = true;
    if (!nonInteractiveAnswerWaiter) return;
    const resolve = nonInteractiveAnswerWaiter;
    nonInteractiveAnswerWaiter = null;
    const line = readLineFromNonInteractiveBuffer();
    if (line !== null) {
      resolve(line);
      return;
    }
    const trailing = nonInteractiveInputBuffer;
    nonInteractiveInputBuffer = "";
    if (trailing.length > 0) {
      resolve(trailing);
      return;
    }
    resolve(undefined);
  });

  process.stdin.pause();
}

function readNonInteractiveConfirmationAnswer() {
  setupNonInteractiveReader();
  const queued = readLineFromNonInteractiveBuffer();
  if (queued !== null) {
    return Promise.resolve(queued);
  }
  if (nonInteractiveStreamEnded) {
    const trailing = nonInteractiveInputBuffer;
    nonInteractiveInputBuffer = "";
    if (trailing.length > 0) {
      return Promise.resolve(trailing);
    }
    return Promise.resolve(undefined);
  }
  if (nonInteractiveAnswerWaiter) {
    throw new Error(
      "Concurrent non-interactive confirmations are not supported.",
    );
  }
  return new Promise((resolve) => {
    nonInteractiveAnswerWaiter = resolve;
    process.stdin.resume();
  });
}

async function confirm(message, options = {}) {
  if (options.yes) {
    return true;
  }

  if (options.nonInteractive) {
    console.log(`${message} [y/N] (non-interactive mode: defaulting to No)`);
    return false;
  }

  if (!process.stdin.isTTY) {
    process.stdout.write(`${message} [y/N] `);
    const answer = await readNonInteractiveConfirmationAnswer();
    if (answer !== undefined) {
      nonInteractiveFallbackAnswer = answer;
      return parseConfirmationAnswer(answer);
    }
    return parseConfirmationAnswer(nonInteractiveFallbackAnswer);
  }

  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
  return new Promise((resolve) => {
    rl.question(`${message} [y/N] `, (answer) => {
      rl.close();
      resolve(parseConfirmationAnswer(answer));
    });
  });
}

module.exports = {
  ensureCodexAgentsFile,
  resolveCodexOutputRoot,
  writeCodexBundle,
};
