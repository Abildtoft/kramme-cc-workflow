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
  pathExists,
  readJsonObject,
  readText,
  requireJsonObject,
  resolveWithinRoot,
} = require("./filesystem");

/** @typedef {import("./contracts").ClaudePlugin} ClaudePlugin */

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

function normalizeFrontmatterBoolean(value) {
  if (typeof value === "boolean") return value;
  if (typeof value !== "string") return value;

  const normalized = value.trim().toLowerCase();
  if (normalized === "true") return true;
  if (normalized === "false") return false;
  return value;
}

function normalizeFrontmatterField(field, value) {
  if (!SKILL_FRONTMATTER_BOOLEAN_FIELDS.has(field)) return value;
  return normalizeFrontmatterBoolean(value);
}

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
function skillFrontmatterTypeErrors(data) {
  const fields = skillContracts.skill_frontmatter?.fields ?? {};
  const errors = [];
  for (const [field, contract] of Object.entries(fields)) {
    if (!Object.hasOwn(data, field)) continue;
    const expectedType = frontmatterTypeError(contract.type, data[field]);
    if (expectedType) errors.push({ field, expectedType });
  }
  return errors;
}

function validateSkillFrontmatter(data, file) {
  const [firstError] = skillFrontmatterTypeErrors(data);
  if (firstError) {
    throw new Error(
      `${file}: frontmatter field "${firstError.field}" must be a ${firstError.expectedType}.`,
    );
  }
}

function isNonEmptyString(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function isFrontmatterBoolean(value) {
  if (typeof value === "boolean") return true;
  if (typeof value !== "string") return false;
  return ["true", "false"].includes(value.trim().toLowerCase());
}

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

async function resolveMarketplacePlugin(root, slug) {
  const marketplacePath = path.join(root, ".claude-plugin", "marketplace.json");
  if (!(await pathExists(marketplacePath))) return null;
  const marketplace = await readJsonObject(
    marketplacePath,
    "Marketplace manifest",
  );
  const plugins = Array.isArray(marketplace.plugins) ? marketplace.plugins : [];
  const entry = plugins.find((plugin) => plugin?.name === slug);
  if (!entry) return null;
  const source = entry.source ?? ".";
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

async function loadAgents(agentsDirs) {
  const files = await collectMarkdownFiles(agentsDirs);
  const agents = [];
  for (const file of files) {
    const raw = await readText(file);
    const { data, body } = parseFrontmatter(raw);
    validateAgentFrontmatter(data, file);
    const name = data.name ?? path.basename(file, ".md");
    agents.push({
      name,
      description: data.description,
      capabilities: data.capabilities,
      model: data.model,
      body: body.trim(),
      sourcePath: file,
    });
  }
  return agents;
}

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

async function loadCommands(commandsDirs) {
  const files = await collectMarkdownFiles(commandsDirs);
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

async function loadSkills(skillsDirs) {
  const entries = await collectFiles(skillsDirs);
  const skillFiles = entries.filter(
    (file) => path.basename(file) === "SKILL.md",
  );
  const skills = [];
  for (const file of skillFiles) {
    const raw = await readText(file);
    const { data, body } = parseFrontmatter(raw);
    validateSkillFrontmatter(data, file);
    const name = data.name ?? path.basename(path.dirname(file));
    const allowedTools = parseAllowedTools(data["allowed-tools"]);
    skills.push({
      name,
      description: data.description,
      argumentHint: data[ARGUMENT_HINT_FIELD],
      model: data.model,
      allowedTools,
      disableModelInvocation: normalizeFrontmatterField(
        DISABLE_MODEL_INVOCATION_FIELD,
        data[DISABLE_MODEL_INVOCATION_FIELD],
      ),
      userInvocable: normalizeFrontmatterField(
        USER_INVOCABLE_FIELD,
        data[USER_INVOCABLE_FIELD],
      ),
      platforms: parsePlatforms(data[PLATFORMS_FIELD]),
      body: body.trim(),
      sourceDir: path.dirname(file),
      skillPath: file,
    });
  }
  return skills;
}

function deriveInvocableCommands(legacyCommands, skills) {
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

async function loadHooks(root, hooksField) {
  const hookEventMaps = [];
  const defaultPath = path.join(root, "hooks", "hooks.json");
  if (await pathExists(defaultPath)) {
    hookEventMaps.push(await readHookEvents(defaultPath));
  }

  if (hooksField) {
    if (typeof hooksField === "string" || Array.isArray(hooksField)) {
      const hookPaths = toPathList(hooksField);
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

async function readHookEvents(file) {
  return extractHookEvents(
    await readJsonObject(file, "Hooks config"),
    `${file}: Hooks config`,
  );
}

function extractHookEvents(config, label) {
  if (!Object.hasOwn(config, "hooks")) return {};
  return requireJsonObject(config.hooks, `${label} field "hooks"`);
}

async function loadMcpServers(root, manifest) {
  const field = manifest.mcpServers;
  if (field) {
    if (typeof field === "string" || Array.isArray(field)) {
      return mergeMcpConfigs(await loadMcpPaths(root, field));
    }
    return requireJsonObject(
      field,
      `${path.join(root, ".claude-plugin", "plugin.json")}: Plugin manifest mcpServers field`,
    );
  }

  const mcpPath = path.join(root, ".mcp.json");
  if (await pathExists(mcpPath)) {
    return readJsonObject(mcpPath, "MCP config");
  }

  return undefined;
}

function resolveComponentDirs(root, defaultDir, custom) {
  const dirs = [path.join(root, defaultDir)];
  for (const entry of toPathList(custom)) {
    dirs.push(resolveWithinRoot(root, entry, `${defaultDir} path`));
  }
  return dirs;
}

function toPathList(value) {
  if (!value) return [];
  if (Array.isArray(value)) return value;
  return [value];
}

async function collectMarkdownFiles(dirs) {
  const entries = await collectFiles(dirs);
  return entries.filter((file) => file.endsWith(".md"));
}

async function collectFiles(dirs) {
  const files = [];
  for (const dir of dirs) {
    if (!(await pathExists(dir))) continue;
    const entries = await walkFiles(dir);
    files.push(...entries);
  }
  return files;
}

async function walkFiles(dir) {
  const entries = await fs.readdir(dir, { withFileTypes: true });
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

function mergeHooks(hookEventMaps) {
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

async function loadMcpPaths(root, value) {
  const configs = [];
  for (const entry of toPathList(value)) {
    const resolved = resolveWithinRoot(root, entry, "mcpServers path");
    if (await pathExists(resolved)) {
      configs.push(await readJsonObject(resolved, "MCP config"));
    }
  }
  return configs;
}

function mergeMcpConfigs(configs) {
  return configs.reduce((acc, config) => ({ ...acc, ...config }), {});
}

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
