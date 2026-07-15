// @ts-check
"use strict";

const fs = require("fs/promises");
const path = require("path");
const { normalizeName, parseFrontmatter } = require("./frontmatter");
const {
  SKILL_FRONTMATTER_BOOLEAN_FIELDS,
  skillContracts,
  skillFrontmatterFieldByLoaderProperty,
} = require("../schemas/skill-contracts");
const {
  isJsonObject,
  pathExists,
  readJsonObject,
  readText,
  requireJsonObject,
  resolveWithinRoot,
} = require("./filesystem");

/**
 * @typedef {import("./contracts").ClaudeAgent} ClaudeAgent
 * @typedef {import("./contracts").ClaudeCommand} ClaudeCommand
 * @typedef {import("./contracts").ClaudePlugin} ClaudePlugin
 * @typedef {import("./contracts").ClaudeSkill} ClaudeSkill
 * @typedef {import("./contracts").CodexMcpServer} CodexMcpServer
 * @typedef {import("./contracts").CodexMcpServers} CodexMcpServers
 * @typedef {import("./contracts").JsonObject} JsonObject
 * @typedef {{ field: string, expectedType: string }} FrontmatterTypeError
 */

const ARGUMENT_HINT_FIELD = skillFrontmatterFieldByLoaderProperty(
  "argumentHint",
  "argument-hint",
);
const DISABLE_MODEL_INVOCATION_FIELD = skillFrontmatterFieldByLoaderProperty(
  "disableModelInvocation",
  "disable-model-invocation",
);
const USER_INVOCABLE_FIELD = skillFrontmatterFieldByLoaderProperty(
  "userInvocable",
  "user-invocable",
);
const PLATFORMS_FIELD = skillFrontmatterFieldByLoaderProperty(
  "platforms",
  "kramme-platforms",
);

/** @param {unknown} value */
function normalizeFrontmatterBoolean(value) {
  if (typeof value === "boolean") return value;
  if (typeof value !== "string") return value;

  const normalized = value.trim().toLowerCase();
  if (normalized === "true") return true;
  if (normalized === "false") return false;
  return value;
}

/** @param {string} field @param {unknown} value */
function normalizeFrontmatterField(field, value) {
  if (!SKILL_FRONTMATTER_BOOLEAN_FIELDS.has(field)) return value;
  return normalizeFrontmatterBoolean(value);
}

/** @param {unknown} type @param {unknown} value */
function frontmatterTypeError(type, value) {
  if (type === "string" && !isNonEmptyString(value)) {
    return "non-empty string";
  }
  if (type === "boolean" && !isFrontmatterBoolean(value)) {
    return 'boolean ("true" or "false")';
  }
  if (type === "string_array" && !isNonEmptyStringArray(value)) {
    return "non-empty array of non-empty strings";
  }
  return undefined;
}

// Collect-all counterpart of the linter's frontmatter_type_errors so both
// engines can be pinned to the same shared fixtures. validateSkillFrontmatter
// throws on the first entry; this returns every mismatch in schema order.
/** @param {Record<string, unknown>} data @returns {FrontmatterTypeError[]} */
function skillFrontmatterTypeErrors(data) {
  const fields = skillContracts.skill_frontmatter?.fields ?? {};
  /** @type {FrontmatterTypeError[]} */
  const errors = [];
  for (const [field, contract] of Object.entries(fields)) {
    if (!Object.hasOwn(data, field)) continue;
    const expectedType = frontmatterTypeError(contract.type, data[field]);
    if (expectedType) errors.push({ field, expectedType });
  }
  return errors;
}

/** @param {Record<string, unknown>} data @param {string} file */
function validateSkillFrontmatter(data, file) {
  const [firstError] = skillFrontmatterTypeErrors(data);
  if (firstError) {
    throw new Error(
      `${file}: frontmatter field "${firstError.field}" must be a ${firstError.expectedType}.`,
    );
  }
}

/** @param {unknown} value @returns {value is string} */
function isNonEmptyString(value) {
  return typeof value === "string" && value.trim().length > 0;
}

/** @param {unknown} value */
function isFrontmatterBoolean(value) {
  if (typeof value === "boolean") return true;
  if (typeof value !== "string") return false;
  return ["true", "false"].includes(value.trim().toLowerCase());
}

/** @param {unknown} value @returns {value is string[]} */
function isNonEmptyStringArray(value) {
  return (
    Array.isArray(value) &&
    value.length > 0 &&
    value.every((item) => isNonEmptyString(item))
  );
}

/**
 * @param {unknown} input
 * @returns {Promise<string>}
 */
async function resolvePluginInput(input) {
  const directPath = path.resolve(String(input));
  if (await pathExists(directPath)) return directPath;

  const slug = String(input ?? "").trim();
  if (!slug) {
    throw new Error("Plugin name or path is required.");
  }

  const scriptRoot = resolveScriptRoot();
  const rootCandidates = [process.cwd(), scriptRoot];
  const parentRoot = path.resolve(scriptRoot, "..");
  const parentMarketplacePath = path.join(
    parentRoot,
    ".claude-plugin",
    "marketplace.json",
  );
  if (parentRoot !== scriptRoot && (await pathExists(parentMarketplacePath))) {
    rootCandidates.push(parentRoot);
  }

  for (const root of rootCandidates) {
    const marketplaceResolved = await resolveMarketplacePlugin(root, slug);
    if (marketplaceResolved) return marketplaceResolved;

    const pluginsDirResolved = path.join(root, "plugins", slug);
    if (await pathExists(pluginsDirResolved)) return pluginsDirResolved;
  }

  throw new Error(`Could not resolve plugin "${slug}".`);
}

function resolveScriptRoot() {
  return path.resolve(__dirname, "..", "..");
}

/** @param {string} root @param {string} slug */
async function resolveMarketplacePlugin(root, slug) {
  const marketplacePath = path.join(root, ".claude-plugin", "marketplace.json");
  if (!(await pathExists(marketplacePath))) return null;
  const marketplace = await readJsonObject(
    marketplacePath,
    "Marketplace manifest",
  );
  const plugins = Array.isArray(marketplace.plugins) ? marketplace.plugins : [];
  const entry = plugins.find(
    (plugin) => isJsonObject(plugin) && plugin.name === slug,
  );
  if (!entry) return null;
  const source = entry.source === undefined ? "." : entry.source;
  if (typeof source !== "string") {
    throw new Error(
      `${marketplacePath}: marketplace plugin "${slug}" source must be a string.`,
    );
  }
  return resolveWithinRoot(root, source, "marketplace plugin source");
}

/**
 * @param {string} inputPath
 * @returns {Promise<ClaudePlugin>}
 */
async function loadClaudePlugin(inputPath) {
  const root = await resolveClaudeRoot(inputPath);
  const manifestPath = path.join(root, ".claude-plugin", "plugin.json");
  const manifest = await readJsonObject(manifestPath, "Plugin manifest");

  const agents = await loadAgents(
    resolveComponentDirs(root, "agents", manifest.agents),
  );
  const legacyCommands = await loadCommands(
    resolveComponentDirs(root, "commands", manifest.commands),
  );
  const skills = await loadSkills(
    resolveComponentDirs(root, "skills", manifest.skills),
  );
  const commands = deriveInvocableCommands(legacyCommands, skills);
  const hooks = await loadHooks(root, manifest.hooks);
  const mcpServers = await loadMcpServers(root, manifest);

  return {
    root,
    manifest,
    agents,
    commands,
    skills,
    hooks,
    mcpServers,
  };
}

/** @param {string} inputPath */
async function resolveClaudeRoot(inputPath) {
  const absolute = path.resolve(inputPath);
  const manifestAtPath = path.join(absolute, ".claude-plugin", "plugin.json");
  if (await pathExists(manifestAtPath)) {
    return absolute;
  }

  if (absolute.endsWith(path.join(".claude-plugin", "plugin.json"))) {
    return path.dirname(path.dirname(absolute));
  }

  if (absolute.endsWith("plugin.json")) {
    return path.dirname(path.dirname(absolute));
  }

  throw new Error(
    `Could not find .claude-plugin/plugin.json under ${inputPath}`,
  );
}

/** @param {string[]} agentsDirs @returns {Promise<ClaudeAgent[]>} */
async function loadAgents(agentsDirs) {
  const files = await collectMarkdownFiles(agentsDirs);
  /** @type {ClaudeAgent[]} */
  const agents = [];
  for (const file of files) {
    const raw = await readText(file);
    const { data, body } = parseFrontmatter(raw);
    validateAgentFrontmatter(data, file);
    const name = data.name ?? path.basename(file, ".md");
    agents.push({
      name,
      description:
        typeof data.description === "string" ? data.description : undefined,
      capabilities: Array.isArray(data.capabilities)
        ? /** @type {string[]} */ (data.capabilities)
        : undefined,
      model: data.model,
      body: body.trim(),
      sourcePath: file,
    });
  }
  return agents;
}

/** @param {Record<string, unknown>} data @param {string} file */
function validateAgentFrontmatter(data, file) {
  if (
    Object.hasOwn(data, "description") &&
    typeof data.description !== "string"
  ) {
    throw new Error(
      `${file}: frontmatter field "description" must be a string.`,
    );
  }
  if (
    Object.hasOwn(data, "capabilities") &&
    (!Array.isArray(data.capabilities) ||
      !data.capabilities.every((capability) => typeof capability === "string"))
  ) {
    throw new Error(
      `${file}: frontmatter field "capabilities" must be an array of strings.`,
    );
  }
}

/** @param {string[]} commandsDirs @returns {Promise<ClaudeCommand[]>} */
async function loadCommands(commandsDirs) {
  const files = await collectMarkdownFiles(commandsDirs);
  /** @type {ClaudeCommand[]} */
  const commands = [];
  for (const file of files) {
    const raw = await readText(file);
    const { data, body } = parseFrontmatter(raw);
    const name = data.name ?? path.basename(file, ".md");
    const allowedTools = parseAllowedTools(data["allowed-tools"]);
    commands.push({
      name,
      description: data.description,
      argumentHint: data[ARGUMENT_HINT_FIELD],
      model: data.model,
      allowedTools,
      disableModelInvocation: normalizeFrontmatterField(
        DISABLE_MODEL_INVOCATION_FIELD,
        data[DISABLE_MODEL_INVOCATION_FIELD],
      ),
      body: body.trim(),
      sourcePath: file,
    });
  }
  return commands;
}

/** @param {string[]} skillsDirs @returns {Promise<ClaudeSkill[]>} */
async function loadSkills(skillsDirs) {
  const entries = await collectFiles(skillsDirs);
  const skillFiles = entries.filter(
    (file) => path.basename(file) === "SKILL.md",
  );
  /** @type {ClaudeSkill[]} */
  const skills = [];
  for (const file of skillFiles) {
    const raw = await readText(file);
    const { data, body } = parseFrontmatter(raw);
    validateSkillFrontmatter(data, file);
    const name = String(data.name ?? path.basename(path.dirname(file)));
    const allowedTools = parseAllowedTools(data["allowed-tools"]);
    skills.push({
      name,
      description:
        typeof data.description === "string" ? data.description : undefined,
      argumentHint:
        typeof data[ARGUMENT_HINT_FIELD] === "string"
          ? data[ARGUMENT_HINT_FIELD]
          : undefined,
      model: data.model,
      allowedTools,
      disableModelInvocation: /** @type {boolean | undefined} */ (
        normalizeFrontmatterField(
          DISABLE_MODEL_INVOCATION_FIELD,
          data[DISABLE_MODEL_INVOCATION_FIELD],
        )
      ),
      userInvocable: /** @type {boolean | undefined} */ (
        normalizeFrontmatterField(
          USER_INVOCABLE_FIELD,
          data[USER_INVOCABLE_FIELD],
        )
      ),
      platforms: parsePlatforms(data[PLATFORMS_FIELD]),
      body: body.trim(),
      sourceDir: path.dirname(file),
      skillPath: file,
    });
  }
  return skills;
}

/** @param {ClaudeCommand[]} legacyCommands @param {ClaudeSkill[]} skills @returns {ClaudeCommand[]} */
function deriveInvocableCommands(legacyCommands, skills) {
  /** @type {ClaudeCommand[]} */
  const commands = [];
  const seen = new Set();

  for (const command of legacyCommands) {
    const normalizedName = normalizeName(command.name);
    if (seen.has(normalizedName)) continue;
    commands.push(command);
    seen.add(normalizedName);
  }

  for (const skill of skills) {
    if (skill.userInvocable === false) continue;
    const normalizedName = normalizeName(skill.name);
    if (seen.has(normalizedName)) continue;
    commands.push({
      name: skill.name,
      description: skill.description,
      argumentHint: skill.argumentHint,
      model: skill.model,
      allowedTools: skill.allowedTools,
      disableModelInvocation: skill.disableModelInvocation,
      body: skill.body,
      sourcePath: skill.skillPath,
    });
    seen.add(normalizedName);
  }

  return commands;
}

/** @param {string} root @param {unknown} hooksField */
async function loadHooks(root, hooksField) {
  /** @type {JsonObject[]} */
  const hookEventMaps = [];
  const defaultPath = path.join(root, "hooks", "hooks.json");
  if (await pathExists(defaultPath)) {
    hookEventMaps.push(await readHookEvents(defaultPath));
  }

  if (hooksField) {
    if (typeof hooksField === "string" || Array.isArray(hooksField)) {
      const hookPaths = toPathList(hooksField, "Plugin manifest hooks field");
      for (const hookPath of hookPaths) {
        const resolved = resolveWithinRoot(root, hookPath, "hooks path");
        if (await pathExists(resolved)) {
          hookEventMaps.push(await readHookEvents(resolved));
        }
      }
    } else {
      const manifestPath = path.join(root, ".claude-plugin", "plugin.json");
      hookEventMaps.push(
        extractHookEvents(
          requireJsonObject(
            hooksField,
            `${manifestPath}: Plugin manifest hooks field`,
          ),
          `${manifestPath}: Plugin manifest hooks`,
        ),
      );
    }
  }

  if (hookEventMaps.length === 0) return undefined;
  return mergeHooks(hookEventMaps);
}

/** @param {string} file */
async function readHookEvents(file) {
  return extractHookEvents(
    await readJsonObject(file, "Hooks config"),
    `${file}: Hooks config`,
  );
}

/** @param {JsonObject} config @param {string} label @returns {JsonObject} */
function extractHookEvents(config, label) {
  if (!Object.hasOwn(config, "hooks")) return {};
  return requireJsonObject(config.hooks, `${label} field "hooks"`);
}

/** @param {string} root @param {JsonObject} manifest */
async function loadMcpServers(root, manifest) {
  const field = manifest.mcpServers;
  const manifestPath = path.join(root, ".claude-plugin", "plugin.json");
  if (field) {
    if (typeof field === "string" || Array.isArray(field)) {
      return validateMcpServers(
        mergeMcpConfigs(await loadMcpPaths(root, field)),
        `${manifestPath}: Plugin manifest mcpServers field`,
      );
    }
    const label = `${manifestPath}: Plugin manifest mcpServers field`;
    return validateMcpServers(requireJsonObject(field, label), label);
  }

  const mcpPath = path.join(root, ".mcp.json");
  if (await pathExists(mcpPath)) {
    return validateMcpServers(
      await readJsonObject(mcpPath, "MCP config"),
      `${mcpPath}: MCP config`,
    );
  }

  return undefined;
}

/** @param {string} root @param {string} defaultDir @param {unknown} custom */
function resolveComponentDirs(root, defaultDir, custom) {
  const dirs = [path.join(root, defaultDir)];
  for (const entry of toPathList(
    custom,
    `Plugin manifest ${defaultDir} field`,
  )) {
    dirs.push(resolveWithinRoot(root, entry, `${defaultDir} path`));
  }
  return dirs;
}

/** @param {unknown} value @param {string} label @returns {string[]} */
function toPathList(value, label) {
  if (value === undefined || value === null || value === "") return [];
  if (typeof value === "string") return [value];
  if (
    Array.isArray(value) &&
    value.every((entry) => typeof entry === "string")
  ) {
    return value;
  }
  throw new Error(`${label} must be a string or an array of strings.`);
}

/** @param {string[]} dirs @returns {Promise<string[]>} */
async function collectMarkdownFiles(dirs) {
  const entries = await collectFiles(dirs);
  return entries.filter((file) => file.endsWith(".md"));
}

/** @param {string[]} dirs @returns {Promise<string[]>} */
async function collectFiles(dirs) {
  /** @type {string[]} */
  const files = [];
  for (const dir of dirs) {
    if (!(await pathExists(dir))) continue;
    const entries = await walkFiles(dir);
    files.push(...entries);
  }
  return files;
}

/** @param {string} dir @returns {Promise<string[]>} */
async function walkFiles(dir) {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  /** @type {string[]} */
  const files = [];
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await walkFiles(full)));
    } else if (entry.isFile()) {
      files.push(full);
    }
  }
  return files;
}

/** @param {JsonObject[]} hookEventMaps @returns {JsonObject} */
function mergeHooks(hookEventMaps) {
  /** @type {{ hooks: Record<string, unknown[]> }} */
  const merged = { hooks: {} };
  for (const events of hookEventMaps) {
    for (const [event, matchers] of Object.entries(events)) {
      if (!Array.isArray(matchers)) {
        throw new Error(`Hooks config event "${event}" must be an array.`);
      }
      if (!merged.hooks[event]) {
        merged.hooks[event] = [];
      }
      merged.hooks[event].push(...matchers);
    }
  }
  return merged;
}

/** @param {string} root @param {unknown} value @returns {Promise<JsonObject[]>} */
async function loadMcpPaths(root, value) {
  /** @type {JsonObject[]} */
  const configs = [];
  for (const entry of toPathList(value, "Plugin manifest mcpServers field")) {
    const resolved = resolveWithinRoot(root, entry, "mcpServers path");
    if (await pathExists(resolved)) {
      configs.push(await readJsonObject(resolved, "MCP config"));
    }
  }
  return configs;
}

/** @param {JsonObject[]} configs @returns {JsonObject} */
function mergeMcpConfigs(configs) {
  return configs.reduce(
    (acc, config) => ({ ...acc, ...config }),
    /** @type {JsonObject} */ ({}),
  );
}

/** @param {JsonObject} config @param {string} label @returns {CodexMcpServers} */
function validateMcpServers(config, label) {
  /** @type {Array<[string, CodexMcpServer]>} */
  const servers = [];
  for (const [name, value] of Object.entries(config)) {
    const serverLabel = `${label} server "${name}"`;
    const server = requireJsonObject(value, serverLabel);
    servers.push([
      name,
      {
        ...server,
        command: optionalStringField(server, "command", serverLabel),
        args: optionalStringArrayField(server, "args", serverLabel),
        env: optionalStringMapField(server, "env", serverLabel),
        url: optionalStringField(server, "url", serverLabel),
        headers: optionalStringMapField(server, "headers", serverLabel),
      },
    ]);
  }
  return Object.fromEntries(servers);
}

/** @param {JsonObject} value @param {string} field @param {string} label */
function optionalStringField(value, field, label) {
  const entry = value[field];
  if (entry === undefined) return undefined;
  if (typeof entry !== "string") {
    throw new Error(`${label} field "${field}" must be a string.`);
  }
  return entry;
}

/** @param {JsonObject} value @param {string} field @param {string} label */
function optionalStringArrayField(value, field, label) {
  const entry = value[field];
  if (entry === undefined) return undefined;
  if (
    !Array.isArray(entry) ||
    !entry.every((item) => typeof item === "string")
  ) {
    throw new Error(`${label} field "${field}" must be an array of strings.`);
  }
  return entry;
}

/** @param {JsonObject} value @param {string} field @param {string} label */
function optionalStringMapField(value, field, label) {
  const entry = value[field];
  if (entry === undefined) return undefined;
  const record = requireJsonObject(entry, `${label} field "${field}"`);
  /** @type {Array<[string, string]>} */
  const strings = [];
  for (const [key, item] of Object.entries(record)) {
    if (typeof item !== "string") {
      throw new Error(`${label} field "${field}.${key}" must be a string.`);
    }
    strings.push([key, item]);
  }
  return Object.fromEntries(strings);
}

/** @param {unknown} value */
function parseAllowedTools(value) {
  if (!value) return undefined;
  if (Array.isArray(value)) {
    return value.map((item) => String(item));
  }
  if (typeof value === "string") {
    return value
      .split(/,/)
      .map((item) => item.trim())
      .filter(Boolean);
  }
  return undefined;
}

/** @param {unknown} value */
function parsePlatforms(value) {
  if (!value) return undefined;
  if (Array.isArray(value))
    return value.map((item) => String(item).toLowerCase());
  return undefined;
}

module.exports = {
  loadClaudePlugin,
  normalizeFrontmatterField,
  resolvePluginInput,
  skillFrontmatterTypeErrors,
};
