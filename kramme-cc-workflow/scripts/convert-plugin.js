#!/usr/bin/env node
"use strict";

const fs = require("fs/promises");
const path = require("path");
const os = require("os");
const readline = require("readline");

function resolveManagedChild(root, entry, label) {
  const resolvedRoot = path.resolve(root);
  const resolvedPath = path.resolve(root, entry);
  if (
    resolvedPath === resolvedRoot ||
    !resolvedPath.startsWith(resolvedRoot + path.sep)
  ) {
    throw new Error(`Invalid ${label}: ${entry}`);
  }
  return resolvedPath;
}

const targets = {
  codex: {
    name: "codex",
    convert: convertClaudeToCodex,
    write: writeCodexBundle,
  },
};

const REMOVED_OPENCODE_INSTALL_OPTIONS = [
  {
    keys: ["output", "o"],
    label: "--output/-o",
    hint: "use --codex-home to choose the Codex install root.",
  },
  {
    keys: ["permissions"],
    label: "--permissions",
    hint: "Codex installs preserve allowed-tools in skill frontmatter.",
  },
  {
    keys: ["agent-mode", "agentMode"],
    label: "--agent-mode",
    hint: "Claude agents are now installed as Codex agent skills.",
  },
  {
    keys: ["infer-temperature", "inferTemperature"],
    label: "--infer-temperature",
    hint: "Codex skills do not support converted temperature settings.",
  },
];

async function main() {
  const argv = process.argv.slice(2);
  if (argv.length === 0 || isHelp(argv[0])) {
    printHelp(0);
    return;
  }

  const command = argv[0];
  if (command === "install") {
    const parsed = parseArgs(argv.slice(1));
    await runInstall(parsed);
    return;
  }

  if (command === "stats") {
    const parsed = parseArgs(argv.slice(1));
    await runStats(parsed);
    return;
  }

  if (command !== "install" && command !== "stats") {
    console.error(`Unknown command: ${command}`);
    printHelp(1);
  }
}

async function runInstall(parsed) {
  const pluginInput = parsed._[0] ?? process.cwd();
  const { targetName, target } = resolveTarget(parsed);

  rejectRemovedOpenCodeInstallOptions(parsed);

  if (parsed.also) {
    throw new Error(
      "--also is no longer supported; install the Codex target directly.",
    );
  }

  const resolvedPluginPath = await resolvePluginInput(pluginInput);
  const plugin = await loadClaudePlugin(resolvedPluginPath);
  const codexHome = resolveRoot(
    parsed["codex-home"] ?? parsed.codexHome,
    ".codex",
  );
  const codexRoot = resolveCodexOutputRoot(codexHome);
  const agentsHome = resolveRoot(
    parsed["agents-home"] ?? parsed.agentsHome,
    ".agents",
  );
  const confirmOptions = {
    yes: parseBoolean(parsed.yes ?? parsed.y, false),
    nonInteractive: parseBoolean(
      parsed["non-interactive"] ?? parsed.nonInteractive,
      false,
    ),
  };

  const bundle = target.convert(plugin);
  if (!bundle) {
    throw new Error(`Target ${targetName} did not return a bundle.`);
  }

  const writeOptions = {
    agentsHome,
    pluginName: plugin.manifest.name,
    confirm: {
      yes: confirmOptions.yes,
      nonInteractive: confirmOptions.nonInteractive,
    },
  };

  await target.write(codexRoot, bundle, writeOptions);
  console.log(`Installed ${plugin.manifest.name} to ${codexRoot}`);
  await ensureCodexAgentsFile(codexRoot);
}

function resolveTarget(parsed) {
  const targetName = String(parsed.to ?? "codex");
  const target = targets[targetName];
  if (!target) {
    throw new Error(`Unknown target: ${targetName}`);
  }
  return { targetName, target };
}

function rejectRemovedOpenCodeInstallOptions(parsed) {
  for (const option of REMOVED_OPENCODE_INSTALL_OPTIONS) {
    if (option.keys.some((key) => Object.hasOwn(parsed, key))) {
      throw new Error(`${option.label} is no longer supported; ${option.hint}`);
    }
  }
}

async function runStats(parsed) {
  const pluginInput = parsed._[0] ?? process.cwd();
  const { target } = resolveTarget(parsed);
  const resolvedPluginPath = await resolvePluginInput(pluginInput);
  const plugin = await loadClaudePlugin(resolvedPluginPath);

  const codexBundle = target.convert(plugin);
  const stats = {
    codex_skills:
      codexBundle.skillDirs.length + codexBundle.generatedSkills.length,
    agent_skills: codexBundle.agentSkills?.length ?? 0,
  };

  const outputAsJson = parseBoolean(parsed.json, false);
  if (outputAsJson) {
    console.log(JSON.stringify(stats));
    return;
  }

  for (const [key, value] of Object.entries(stats)) {
    console.log(`${key}=${value}`);
  }
}

function printHelp(exitCode) {
  const help = `Usage:
  scripts/convert-plugin.js install <plugin-name|path> [options]
  scripts/convert-plugin.js stats <plugin-name|path> [options]

Options:
  --to <target>           Target format: codex (default: codex)
  --codex-home <dir>      Codex root (default: ~/.codex)
  --agents-home <dir>     Agents root (default: ~/.agents)
  --yes, -y               Assume "yes" for all cleanup confirmations
  --non-interactive       Never prompt; use default answers for confirmations
  --json                  (stats only) print a JSON object instead of key=value lines
`;
  console.log(help);
  if (exitCode) process.exit(exitCode);
}

function isHelp(value) {
  return value === "-h" || value === "--help";
}

function parseArgs(argv) {
  const result = { _: [] };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg.startsWith("--")) {
      const [key, inlineValue] = arg.slice(2).split("=");
      if (inlineValue !== undefined) {
        result[key] = inlineValue;
        continue;
      }
      const next = argv[i + 1];
      if (next && !next.startsWith("-")) {
        result[key] = next;
        i += 1;
      } else {
        result[key] = true;
      }
      continue;
    }
    if (arg.startsWith("-")) {
      if (arg === "-o") {
        const next = argv[i + 1];
        if (next && !next.startsWith("-")) {
          result.o = next;
          i += 1;
        } else {
          result.o = true;
        }
        continue;
      }
      result[arg.slice(1)] = true;
      continue;
    }
    result._.push(arg);
  }
  return result;
}

function parseBoolean(value, fallback) {
  if (value === undefined) return fallback;
  if (typeof value === "boolean") return value;
  const normalized = String(value).trim().toLowerCase();
  if (normalized === "true" || normalized === "1" || normalized === "yes")
    return true;
  if (normalized === "false" || normalized === "0" || normalized === "no")
    return false;
  return fallback;
}

function resolveRoot(value, ...defaultSegments) {
  if (value && String(value).trim()) {
    return path.resolve(expandHome(String(value).trim()));
  }
  return path.join(os.homedir(), ...defaultSegments);
}

function expandHome(value) {
  if (value === "~") return os.homedir();
  if (value.startsWith(`~${path.sep}`)) {
    return path.join(os.homedir(), value.slice(2));
  }
  return value;
}

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
  return path.resolve(__dirname, "..");
}

async function resolveMarketplacePlugin(root, slug) {
  const marketplacePath = path.join(root, ".claude-plugin", "marketplace.json");
  if (!(await pathExists(marketplacePath))) return null;
  const marketplace = await readJson(marketplacePath);
  const plugins = Array.isArray(marketplace.plugins) ? marketplace.plugins : [];
  const entry = plugins.find((plugin) => plugin?.name === slug);
  if (!entry) return null;
  const source = entry.source ?? ".";
  return resolveWithinRoot(root, source, "marketplace plugin source");
}

async function loadClaudePlugin(inputPath) {
  const root = await resolveClaudeRoot(inputPath);
  const manifestPath = path.join(root, ".claude-plugin", "plugin.json");
  const manifest = await readJson(manifestPath);

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
      argumentHint: data["argument-hint"],
      model: data.model,
      allowedTools,
      disableModelInvocation: data["disable-model-invocation"],
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
    const name = data.name ?? path.basename(path.dirname(file));
    const allowedTools = parseAllowedTools(data["allowed-tools"]);
    skills.push({
      name,
      description: data.description,
      argumentHint: data["argument-hint"],
      model: data.model,
      allowedTools,
      disableModelInvocation: data["disable-model-invocation"],
      userInvocable: data["user-invocable"],
      platforms: parsePlatforms(data["kramme-platforms"]),
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
  const hookConfigs = [];
  const defaultPath = path.join(root, "hooks", "hooks.json");
  if (await pathExists(defaultPath)) {
    hookConfigs.push(await readJson(defaultPath));
  }

  if (hooksField) {
    if (typeof hooksField === "string" || Array.isArray(hooksField)) {
      const hookPaths = toPathList(hooksField);
      for (const hookPath of hookPaths) {
        const resolved = resolveWithinRoot(root, hookPath, "hooks path");
        if (await pathExists(resolved)) {
          hookConfigs.push(await readJson(resolved));
        }
      }
    } else {
      hookConfigs.push(hooksField);
    }
  }

  if (hookConfigs.length === 0) return undefined;
  return mergeHooks(hookConfigs);
}

async function loadMcpServers(root, manifest) {
  const field = manifest.mcpServers;
  if (field) {
    if (typeof field === "string" || Array.isArray(field)) {
      return mergeMcpConfigs(await loadMcpPaths(root, field));
    }
    return field;
  }

  const mcpPath = path.join(root, ".mcp.json");
  if (await pathExists(mcpPath)) {
    return readJson(mcpPath);
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

function mergeHooks(hooksList) {
  const merged = { hooks: {} };
  for (const hooks of hooksList) {
    for (const [event, matchers] of Object.entries(hooks.hooks ?? {})) {
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
      configs.push(await readJson(resolved));
    }
  }
  return configs;
}

function mergeMcpConfigs(configs) {
  return configs.reduce((acc, config) => ({ ...acc, ...config }), {});
}

function resolveWithinRoot(root, entry, label) {
  const resolvedRoot = path.resolve(root);
  const resolvedPath = path.resolve(root, entry);
  if (
    resolvedPath === resolvedRoot ||
    resolvedPath.startsWith(resolvedRoot + path.sep)
  ) {
    return resolvedPath;
  }
  throw new Error(
    `Invalid ${label}: ${entry}. Paths must stay within the plugin root.`,
  );
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
  if (typeof value === "string") {
    return value
      .split(/,/)
      .map((item) => item.trim().toLowerCase())
      .filter(Boolean);
  }
  return undefined;
}

function filterByPlatform(skills, commands, platform) {
  const excluded = new Set();
  for (const skill of skills) {
    if (skill.platforms && !skill.platforms.includes(platform)) {
      excluded.add(normalizeName(skill.name));
    }
  }
  if (excluded.size === 0) return { skills, commands };
  return {
    skills: skills.filter((skill) => !excluded.has(normalizeName(skill.name))),
    commands: commands.filter(
      (command) => !excluded.has(normalizeName(command.name)),
    ),
  };
}

function convertClaudeToCodex(plugin) {
  const { skills, commands } = filterByPlatform(
    plugin.skills,
    plugin.commands,
    "codex",
  );
  const copiedSkillNames = new Set(
    skills.map((skill) => codexName(skill.name)),
  );
  const usedSkillNames = new Set(copiedSkillNames);
  const knownCommandNames = new Set(copiedSkillNames);
  const commandSkillDefinitions = commands
    // Skill-backed commands already exist as copied skill directories.
    .filter((command) => path.basename(command.sourcePath ?? "") !== "SKILL.md")
    .filter((command) => !copiedSkillNames.has(codexName(command.name)))
    .map((command) => {
      const skillName = uniqueName(codexName(command.name), usedSkillNames);
      knownCommandNames.add(skillName);
      return { command, skillName };
    });

  const agentSkills = plugin.agents.map((agent) =>
    convertAgentSkill(agent, usedSkillNames),
  );
  const knownAgentSkills = buildKnownAgentSkillNames(
    plugin.agents,
    agentSkills,
  );
  const commandSkills = commandSkillDefinitions.map(({ command, skillName }) =>
    convertCommandSkill(
      command,
      knownCommandNames,
      skillName,
      knownAgentSkills,
    ),
  );
  const skillDirs = skills.map((skill) =>
    convertExistingSkillForCodex(skill, knownCommandNames, knownAgentSkills),
  );

  return {
    prompts: [],
    skillDirs,
    generatedSkills: commandSkills,
    agentSkills,
    knownCommands: knownCommandNames,
    knownAgentSkills,
    mcpServers: plugin.mcpServers,
    codexPlugin: plugin.hooks ? convertCodexHookPlugin(plugin) : undefined,
  };
}

const CODEX_DESCRIPTION_MAX_LENGTH = 1024;

function convertCodexHookPlugin(plugin) {
  const name = normalizeName(plugin.manifest.name);
  const version = String(plugin.manifest.version ?? "local").trim() || "local";
  const marketplaceName = name;
  const description = sanitizeDescription(
    plugin.manifest.description ??
      `Lifecycle hooks converted from ${plugin.manifest.name}.`,
  );
  const manifest = {
    name,
    version,
    description,
    hooks: "./hooks/hooks.json",
  };

  if (plugin.manifest.author) {
    manifest.author = plugin.manifest.author;
  }

  return {
    name,
    marketplaceName,
    version,
    manifest,
    hooks: cloneJson(plugin.hooks),
    hookSourceDir: path.join(plugin.root, "hooks"),
  };
}

function convertAgentSkill(agent, usedNames) {
  const name = uniqueName(codexName(agent.name), usedNames);
  const description = sanitizeDescription(
    agent.description ?? `Converted from Claude agent ${agent.name}`,
  );
  const frontmatter = { name, description };

  let body = agent.body.trim();
  if (agent.capabilities && agent.capabilities.length > 0) {
    const capabilities = agent.capabilities
      .map((capability) => `- ${capability}`)
      .join("\n");
    body = `## Capabilities\n${capabilities}\n\n${body}`.trim();
  }
  if (body.length === 0) {
    body = `Instructions converted from the ${agent.name} agent.`;
  }

  const content = formatFrontmatter(frontmatter, body);
  return { name, content };
}

function buildKnownAgentSkillNames(agents, agentSkills) {
  const knownAgentSkills = new Map();
  for (let index = 0; index < agents.length; index += 1) {
    const agent = agents[index];
    const skill = agentSkills[index];
    if (!agent || !skill) continue;
    knownAgentSkills.set(codexName(agent.name), skill.name);
    if (agent.sourcePath) {
      knownAgentSkills.set(
        codexName(path.basename(agent.sourcePath, ".md")),
        skill.name,
      );
    }
  }
  return knownAgentSkills;
}

function convertCommandSkill(command, knownCommands, name, knownAgentSkills) {
  const frontmatter = {
    name,
    description: sanitizeDescription(
      command.description ?? `Converted from Claude command ${command.name}`,
    ),
    "argument-hint": command.argumentHint,
    "allowed-tools":
      command.allowedTools && command.allowedTools.length > 0
        ? command.allowedTools
        : undefined,
    "disable-model-invocation": command.disableModelInvocation,
    "user-invocable": true,
  };
  const transformedBody = transformContentForCodex(command.body.trim(), {
    knownCommands,
    knownAgentSkills,
  });
  const body = transformedBody.trim();
  const content = formatFrontmatter(
    frontmatter,
    body.length > 0 ? body : command.body,
  );
  return { name, content };
}

function convertExistingSkillForCodex(skill, knownCommands, knownAgentSkills) {
  const frontmatter = {
    name: skill.name,
    description: sanitizeDescription(
      skill.description ?? `Converted from Claude skill ${skill.name}`,
    ),
    "argument-hint": skill.argumentHint,
    "allowed-tools":
      skill.allowedTools && skill.allowedTools.length > 0
        ? skill.allowedTools
        : undefined,
    "disable-model-invocation": skill.disableModelInvocation,
    "user-invocable": skill.userInvocable,
    "kramme-platforms":
      skill.platforms && skill.platforms.length > 0
        ? skill.platforms
        : undefined,
  };
  const body = transformContentForCodex(skill.body.trim(), {
    knownCommands,
    knownAgentSkills,
  });
  const content = formatFrontmatter(
    frontmatter,
    body.length > 0 ? body : skill.body,
  );
  return { name: skill.name, sourceDir: skill.sourceDir, content };
}

function transformContentForCodex(body, options = {}) {
  let result = body;
  const knownCommands = options.knownCommands;
  const knownAgentSkills = options.knownAgentSkills;

  const taskPattern = /^(\s*-?\s*)Task\s+([a-z][a-z0-9-]*)\(([^)]+)\)/gm;
  result = result.replace(taskPattern, (_match, prefix, agentName, args) => {
    const skillName = codexName(agentName);
    const trimmedArgs = args.trim();
    return `${prefix}Use the $${skillName} skill to: ${trimmedArgs}`;
  });

  const slashCommandPattern =
    /(?<![:\w])\/([a-z][a-z0-9_:-]*?)(?=[\s,.`"')\]}]|$)/gi;
  result = result.replace(slashCommandPattern, (match, commandName) => {
    if (commandName.includes("/")) return match;
    if (
      ["dev", "tmp", "etc", "usr", "var", "bin", "home"].includes(commandName)
    )
      return match;
    const codexified = codexName(commandName);
    if (knownCommands && !knownCommands.has(codexified)) return match;
    return `$${codexified}`;
  });

  const agentRefPattern =
    /@([a-z][a-z0-9-]*-(?:agent|reviewer|researcher|analyst|specialist|oracle|sentinel|guardian|strategist))/gi;
  result = result.replace(agentRefPattern, (_match, agentName) => {
    const skillName = codexName(agentName);
    return `$${skillName} skill`;
  });

  result = rewriteCodexAgentFileReferences(result, knownAgentSkills);

  result = normalizeCodexInstructionText(result);

  return result;
}

function rewriteCodexAgentFileReferences(text, knownAgentSkills) {
  if (!knownAgentSkills || knownAgentSkills.size === 0) return text;
  const linkTargetPattern =
    /(?<!!)\[[^\]\n]+\]\(\s*<?agents\/([a-z][a-z0-9_:-]*)\.md>?(?:\s+(?:"[^"\n]*"|'[^'\n]*'|\([^)\n]*\)))?\s*\)/gi;
  const autolinkPattern = /<agents\/([a-z][a-z0-9_:-]*)\.md>/gi;
  const agentPathPattern =
    /(?<![\w./\\}:$(-])`?agents\/([a-z][a-z0-9_:-]*)\.md`?(?=$|[\s,.:;`"')\]}])/gi;
  const toSkillReference = (match, agentName) => {
    const skillName = knownAgentSkills.get(codexName(agentName));
    if (!skillName) return match;
    return `$${skillName} skill`;
  };
  text = text.replace(linkTargetPattern, toSkillReference);
  text = text.replace(autolinkPattern, toSkillReference);
  return text.replace(agentPathPattern, toSkillReference);
}

const CODEX_INSTRUCTION_REPLACEMENTS = [
  [/### Using AskUserQuestion Correctly\b/g, "### Asking Questions in Codex"],
  [
    /The AskUserQuestion tool requires \*\*2-4 predefined options\*\* per question\.\s*Users can always select "Other" to provide free-text input\./g,
    "When asking directly in chat, offer a small set of concrete options when that helps the user answer quickly. Users can always ignore the suggested options and reply freely in chat.",
  ],
  [
    /The AskUserQuestion tool requires \*\*2-4 predefined options\*\* per question\./g,
    "When asking directly in chat, offer a small set of concrete options when that helps the user answer quickly.",
  ],
  [
    /Users can always select "Other" to provide free-text input\./g,
    "Users can always ignore the suggested options and reply freely in chat.",
  ],
  [/\*\*Tool structure:\*\*/g, "**Suggested structure:**"],
  [/- `header`: Short label\b/g, "- `Label`: Short label"],
  [
    /- `question`: The full question text\b/g,
    "- `Question`: The full question text",
  ],
  [
    /- `options`: 2-4 choices, each with `label` \(short\) and `description` \(explains tradeoff\)\b/g,
    "- `Suggested options`: 2-4 concise choices, each with a short label and a tradeoff explanation",
  ],
  [
    /- `multiSelect`: Set `true` when choices aren't mutually exclusive\b/g,
    "- `Multi-select`: Use this style only when multiple options can apply at once",
  ],
  [
    /- `multiSelect`: Set `true` for non-exclusive choices\b/g,
    "- `Multi-select`: Use this style only when multiple options can apply at once",
  ],
  [
    /\bKeep the total predefined option count within AskUserQuestion's 2-4 option limit\./g,
    "Keep the option set concise; 2-4 concrete options is usually enough.",
  ],
  [
    /\bKeep the total predefined option count between 2 and 4\./g,
    "Keep the option set concise; 2-4 concrete options is usually enough.",
  ],
  [
    /\bUse `?AskUserQuestion`? with multiSelect to\b/g,
    "Ask the user directly in chat and explicitly allow multiple selections to",
  ],
  [
    /\buse `?AskUserQuestion`? with multiSelect to\b/g,
    "ask the user directly in chat and explicitly allow multiple selections to",
  ],
  [/\bUse `?AskUserQuestion`? to ask\b/g, "Ask the user directly in chat"],
  [/\buse `?AskUserQuestion`? to ask\b/g, "ask the user directly in chat"],
  [/\bUse the `?AskUserQuestion`? tool\b/g, "Ask the user directly in chat"],
  [/\buse the `?AskUserQuestion`? tool\b/g, "ask the user directly in chat"],
  [
    /\bUsing the `?AskUserQuestion`? tool\b/g,
    "By asking the user directly in chat",
  ],
  [
    /\busing the `?AskUserQuestion`? tool\b/g,
    "by asking the user directly in chat",
  ],
  [/\bUse `?AskUserQuestion`? to\b/g, "Ask the user directly in chat to"],
  [/\buse `?AskUserQuestion`? to\b/g, "ask the user directly in chat to"],
  [
    /\bwith `?AskUserQuestion`?(?=[:\s.,)]|$)/g,
    "by asking the user directly in chat",
  ],
  [/\bOtherwise AskUserQuestion\b/g, "Otherwise ask the user directly in chat"],
  [/\botherwise AskUserQuestion\b/g, "otherwise ask the user directly in chat"],
  [
    /\bOtherwise use `?AskUserQuestion`?(?=[:\s.,)]|$)/g,
    "Otherwise ask the user directly in chat",
  ],
  [
    /\botherwise use `?AskUserQuestion`?(?=[:\s.,)]|$)/g,
    "otherwise ask the user directly in chat",
  ],
  [/\bUse `?AskUserQuestion`?(?=[:\s.,)]|$)/g, "Ask the user directly in chat"],
  [/\buse `?AskUserQuestion`?(?=[:\s.,)]|$)/g, "ask the user directly in chat"],
  [
    /\busing `?AskUserQuestion`?(?=[:\s.,)]|$)/g,
    "by asking the user directly in chat",
  ],
  [
    /\bvia `?AskUserQuestion`?(?=[:\s.,)]|$)/g,
    "by asking the user directly in chat",
  ],
  [
    /\bAskUserQuestion with (\d+) options\b/g,
    "a direct chat question with $1 concrete options",
  ],
  [
    /\bAskUserQuestion with multiSelect\b/g,
    "a direct chat question that explicitly allows multiple selections",
  ],
  [/\bEvery AskUserQuestion option\b/g, "Every option you present"],
  [/\bAskUserQuestion option\b/g, "option you present"],
  [/\bskip this AskUserQuestion\b/g, "skip this direct chat question"],
  [/\bsend AskUserQuestion\b/g, "send the direct chat question"],
  [
    /\bAfter presenting AskUserQuestion\b/g,
    "After asking the question in chat",
  ],
  [
    /\bfreeform AskUserQuestion\b/g,
    "direct chat follow-up for free-form input",
  ],
  [/\bAskUserQuestion\b/g, "direct chat question"],
  [/\bUse direct chat question\b/g, "Ask the user directly in chat"],
  [/\buse direct chat question\b/g, "ask the user directly in chat"],
  [/\busing direct chat question\b/g, "by asking the user directly in chat"],
  [/\bvia direct chat question\b/g, "by asking the user directly in chat"],
  [
    /\bAsk the user directly in chat to ask\b/g,
    "Ask the user directly in chat",
  ],
  [
    /\bask the user directly in chat to ask\b/g,
    "ask the user directly in chat",
  ],
  [
    /\bAsk the user directly in chat with (\d+) options\b/g,
    "Ask the user directly in chat with $1 concrete options",
  ],
  [/\bTask tool calls\b/g, "subagent calls"],
  [
    /\bvia the Task tool with\b/g,
    "using a subagent when available; otherwise in the main thread, with",
  ],
  [
    /\busing the Task tool with\b/g,
    "using a subagent when available; otherwise in the main thread, with",
  ],
  [
    /\bvia the Task tool\b/g,
    "using a subagent when available; otherwise in the main thread",
  ],
  [
    /\busing the Task tool\b/g,
    "using a subagent when available; otherwise in the main thread",
  ],
  [/\bTask tool\b/g, "subagent workflow"],
  [/\bvia the Skill tool to\b/g, "using the corresponding Codex skill to"],
  [/\busing the Skill tool to\b/g, "using the corresponding Codex skill to"],
  [/\bInvoke via Skill tool\b/g, "Invoke using the corresponding Codex skill"],
  [/\bvia the Skill tool\b/g, "using the corresponding Codex skill"],
  [/\busing the Skill tool\b/g, "using the corresponding Codex skill"],
  [/\bSkill tool\b/g, "skill invocation"],
  [/\bTodoWrite\/TodoRead\b/g, "update_plan"],
  [/\bTodoWrite\b/g, "update_plan"],
  [/\bTodoRead\b/g, "update_plan"],
  [/\bQuestion tool\b/g, "direct chat questions"],
  [/\bRead tool\b/g, "shell reads or rg"],
  [/\bEdit\/MultiEdit\b/g, "apply_patch"],
  [/\bEdit tool\b/g, "apply_patch"],
  [/\bMultiEdit\b/g, "apply_patch"],
  [/\bsubagent_type\s*=\s*Explore\b/g, "agent_type=explorer"],
  [/\bsubagent_type\s*:\s*Explore\b/g, "agent_type: explorer"],
  [/\bExplore agents\b/g, "explorer subagents"],
  [/\bExplore agent\b/g, "explorer subagent"],
];

function normalizeCodexInstructionText(text) {
  let result = rewriteAskUserQuestionCodeBlocks(text);
  for (const [pattern, replacement] of CODEX_INSTRUCTION_REPLACEMENTS) {
    result = result.replace(pattern, replacement);
  }
  result = result.replace(
    /(^[ \t]*)Ask the user directly in chat:\n\s*\n\1Ask the user directly in chat:\n/gm,
    "$1Ask the user directly in chat:\n",
  );
  return result;
}

function rewriteAskUserQuestionCodeBlocks(text) {
  const openFencePattern = /(^[ \t]*)(`{3,})([^\n]*)\r?\n/gm;
  let result = "";
  let cursor = 0;
  let match;

  while ((match = openFencePattern.exec(text))) {
    const [openingLine, indent, openingFence] = match;
    const bodyStart = match.index + openingLine.length;
    const closingFence = findAskUserQuestionClosingFence(
      text,
      bodyStart,
      indent,
      openingFence.length,
    );
    if (!closingFence) continue;

    const body = text.slice(bodyStart, closingFence.index);
    const parsed = parseAskUserQuestionBlock(body);
    if (!parsed) {
      openFencePattern.lastIndex = closingFence.afterIndex;
      continue;
    }

    result += text.slice(cursor, match.index);
    result += renderDirectChatQuestion(parsed, { indent });
    cursor = closingFence.afterIndex;
    openFencePattern.lastIndex = closingFence.afterIndex;
  }

  result += text.slice(cursor);
  return result;
}

function findAskUserQuestionClosingFence(
  text,
  fromIndex,
  openingIndent,
  minimumFenceLength,
) {
  const closingFencePattern = /(^[ \t]*)(`{3,})[ \t]*(?:\r?\n|$)/gm;
  closingFencePattern.lastIndex = fromIndex;

  let match;
  while ((match = closingFencePattern.exec(text))) {
    if (
      match[1].length <= openingIndent.length &&
      match[2].length >= minimumFenceLength
    ) {
      return { index: match.index, afterIndex: closingFencePattern.lastIndex };
    }
  }

  return null;
}

function parseAskUserQuestionBlock(body) {
  const lines = String(body).split(/\r?\n/);
  let index = 0;
  while (index < lines.length && lines[index].trim() === "") {
    index += 1;
  }

  if (/^AskUserQuestion\b/.test(lines[index]?.trim() ?? "")) {
    index += 1;
  }

  let header = "";
  let question = "";
  let multiSelect = false;
  const options = [];
  let currentOption = null;
  let sawStructuredPrompt = false;

  const pushCurrentOption = () => {
    if (!currentOption) return;
    options.push(currentOption);
    currentOption = null;
  };

  for (; index < lines.length; index += 1) {
    const trimmed = lines[index].trim();
    if (!trimmed) continue;

    let match = trimmed.match(/^header:\s*(.+)$/i);
    if (match) {
      header = stripWrappingQuotes(match[1]);
      sawStructuredPrompt = true;
      continue;
    }

    match = trimmed.match(/^question:\s*(.+)$/i);
    if (match) {
      const value = stripWrappingQuotes(match[1]);
      if (/^[|>][-+]?$/i.test(value)) {
        const block = readIndentedBlock(
          lines,
          index + 1,
          leadingWhitespaceLength(lines[index]),
        );
        question = value.startsWith(">")
          ? foldBlockScalar(block.value)
          : block.value;
        index = block.nextIndex - 1;
      } else {
        question = value;
      }
      sawStructuredPrompt = true;
      continue;
    }

    match = trimmed.match(/^multiSelect:\s*(.+)$/i);
    if (match) {
      multiSelect = /^true$/i.test(stripWrappingQuotes(match[1]));
      sawStructuredPrompt = true;
      continue;
    }

    if (/^options:\s*$/i.test(trimmed)) {
      sawStructuredPrompt = true;
      continue;
    }

    match = trimmed.match(/^-+\s*label:\s*(.+)$/i);
    if (match) {
      pushCurrentOption();
      currentOption = { label: stripWrappingQuotes(match[1]), description: "" };
      sawStructuredPrompt = true;
      continue;
    }

    match = trimmed.match(/^description:\s*(.+)$/i);
    if (match) {
      if (currentOption) {
        currentOption.description = stripWrappingQuotes(match[1]);
      }
      sawStructuredPrompt = true;
      continue;
    }

    match = trimmed.match(/^-+\s*\(freeform\)\s*(.+)$/i);
    if (match) {
      pushCurrentOption();
      options.push({ label: stripWrappingQuotes(match[1]), description: "" });
      sawStructuredPrompt = true;
      continue;
    }

    match = trimmed.match(/^-+\s*(.+)$/);
    if (match) {
      pushCurrentOption();
      options.push({ label: stripWrappingQuotes(match[1]), description: "" });
      sawStructuredPrompt = true;
      continue;
    }
  }

  pushCurrentOption();

  if (!sawStructuredPrompt || !question) {
    return null;
  }

  return { header, question, multiSelect, options };
}

function renderDirectChatQuestion(prompt, options = {}) {
  const indent = options.indent ?? "";
  const lines = ["Ask the user directly in chat:"];
  if (prompt.header) {
    lines.push(`Question label: ${prompt.header}`);
  }
  appendPrefixedMultiline(lines, "Question: ", prompt.question);
  if (prompt.multiSelect) {
    lines.push("Allow multiple selections if more than one option can apply.");
  }
  if (prompt.options.length > 0) {
    lines.push("Suggested options:");
    for (const option of prompt.options) {
      lines.push(
        option.description
          ? `- ${option.label} — ${option.description}`
          : `- ${option.label}`,
      );
    }
  }
  return lines.map((line) => `${indent}${line}`).join("\n");
}

function readIndentedBlock(lines, startIndex, parentIndent) {
  const blockLines = [];
  let index = startIndex;

  for (; index < lines.length; index += 1) {
    const line = lines[index];
    if (line.trim() !== "" && leadingWhitespaceLength(line) <= parentIndent)
      break;
    blockLines.push(line);
  }

  const contentIndent = blockLines
    .filter((line) => line.trim() !== "")
    .reduce(
      (minimum, line) => Math.min(minimum, leadingWhitespaceLength(line)),
      Infinity,
    );

  if (contentIndent === Infinity) {
    return { value: "", nextIndex: index };
  }

  const value = blockLines
    .map((line) => (line.trim() === "" ? "" : line.slice(contentIndent)))
    .join("\n")
    .replace(/\n+$/g, "");

  return { value, nextIndex: index };
}

function leadingWhitespaceLength(value) {
  return String(value ?? "").match(/^[ \t]*/)[0].length;
}

function foldBlockScalar(value) {
  return String(value)
    .split(/\n{2,}/)
    .map((paragraph) => paragraph.replace(/\n/g, " "))
    .join("\n\n");
}

function appendPrefixedMultiline(lines, prefix, value) {
  const valueLines = String(value ?? "").split(/\r?\n/);
  lines.push(`${prefix}${valueLines[0] ?? ""}`);
  for (const line of valueLines.slice(1)) {
    lines.push(line ? `  ${line}` : "");
  }
}

function stripWrappingQuotes(value) {
  const trimmed = String(value ?? "").trim();
  if (!trimmed) return "";
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'")) ||
    (trimmed.startsWith("`") && trimmed.endsWith("`"))
  ) {
    return trimmed.slice(1, -1);
  }
  return trimmed;
}

function normalizeName(value) {
  const trimmed = String(value ?? "").trim();
  if (!trimmed) return "item";
  const normalized = trimmed
    .toLowerCase()
    .replace(/[\\/]+/g, "-")
    .replace(/[:\s]+/g, "-")
    .replace(/[^a-z0-9_-]+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-+|-+$/g, "");
  return normalized || "item";
}

function codexName(value) {
  const trimmed = String(value ?? "").trim();
  if (!trimmed) return "item";
  const normalized = trimmed
    .toLowerCase()
    .replace(/[\\/]+/g, "-")
    .replace(/\s+/g, "-")
    .replace(/[^a-z0-9_:-]+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-+|-+$/g, "");
  return normalized || "item";
}

function sanitizeDescription(value, maxLength = CODEX_DESCRIPTION_MAX_LENGTH) {
  const normalized = String(value ?? "")
    .replace(/\s+/g, " ")
    .trim();
  if (normalized.length <= maxLength) return normalized;
  const ellipsis = "...";
  return (
    normalized.slice(0, Math.max(0, maxLength - ellipsis.length)).trimEnd() +
    ellipsis
  );
}

function uniqueName(base, used) {
  if (!used.has(base)) {
    used.add(base);
    return base;
  }
  let index = 2;
  while (used.has(`${base}-${index}`)) {
    index += 1;
  }
  const name = `${base}-${index}`;
  used.add(name);
  return name;
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
      await writeText(path.join(targetDir, "SKILL.md"), skill.content + "\n");
    }
    await rewriteCodexMarkdownResourcesFromSource(skill.sourceDir, targetDir, {
      knownCommands: bundle.knownCommands,
      knownAgentSkills: bundle.knownAgentSkills,
    });
  }

  for (const skill of bundle.generatedSkills) {
    const targetDir = resolveManagedChild(skillsRoot, skill.name, "skill name");
    await writeText(path.join(targetDir, "SKILL.md"), skill.content + "\n");
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

function parseFrontmatter(raw) {
  const lines = raw.split(/\r?\n/);
  if (lines.length === 0 || lines[0].trim() !== "---") {
    return { data: {}, body: raw };
  }

  let endIndex = -1;
  for (let i = 1; i < lines.length; i += 1) {
    if (lines[i].trim() === "---") {
      endIndex = i;
      break;
    }
  }

  if (endIndex === -1) {
    return { data: {}, body: raw };
  }

  const yamlLines = lines.slice(1, endIndex);
  const body = lines.slice(endIndex + 1).join("\n");
  const data = parseYamlLines(yamlLines);
  return { data, body };
}

function parseYamlLines(lines) {
  const data = {};
  let currentKey = null;
  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i];
    if (!line.trim()) continue;

    if (line.trim().startsWith("- ")) {
      if (!currentKey) continue;
      if (!Array.isArray(data[currentKey])) {
        data[currentKey] = [];
      }
      data[currentKey].push(parseYamlValue(line.trim().slice(2)));
      continue;
    }

    const idx = line.indexOf(":");
    if (idx === -1) continue;
    const key = line.slice(0, idx).trim();
    let value = line.slice(idx + 1).trim();
    currentKey = key;
    if (!value) {
      data[key] = [];
      continue;
    }
    if (value === "|" || value === ">") {
      const blockLines = [];
      let j = i + 1;
      while (j < lines.length && /^[ \\t]+/.test(lines[j])) {
        blockLines.push(lines[j].replace(/^[ \\t]{1,2}/, ""));
        j += 1;
      }
      i = j - 1;
      const joiner = value === "|" ? "\n" : " ";
      data[key] = blockLines.join(joiner).trimEnd();
      currentKey = null;
      continue;
    }
    data[key] = parseYamlValue(value);
  }
  return data;
}

function parseYamlValue(value) {
  if (
    (value.startsWith('"') && value.endsWith('"')) ||
    (value.startsWith("'") && value.endsWith("'"))
  ) {
    return value.slice(1, -1);
  }
  if (value.startsWith("[") && value.endsWith("]")) {
    const inner = value.slice(1, -1).trim();
    if (!inner) return [];
    return inner.split(",").map((item) => parseYamlValue(item.trim()));
  }
  if (value === "true") return true;
  if (value === "false") return false;
  if (value === "null" || value === "~") return null;
  if (/^-?\d+(\.\d+)?$/.test(value)) return Number(value);
  return value;
}

function formatFrontmatter(data, body) {
  const yaml = Object.entries(data)
    .filter(([, value]) => value !== undefined)
    .map(([key, value]) => formatYamlLine(key, value))
    .join("\n");

  if (yaml.trim().length === 0) {
    return body;
  }

  return ["---", yaml, "---", "", body].join("\n");
}

function formatYamlLine(key, value) {
  if (Array.isArray(value)) {
    const items = value.map((item) => `  - ${formatYamlValue(item)}`);
    return [key + ":", ...items].join("\n");
  }
  return `${key}: ${formatYamlValue(value)}`;
}

function formatYamlValue(value) {
  if (value === null || value === undefined) return "";
  if (typeof value === "number" || typeof value === "boolean")
    return String(value);
  const raw = String(value);
  if (raw.includes("\n")) {
    return `|\n${raw
      .split("\n")
      .map((line) => `  ${line}`)
      .join("\n")}`;
  }
  if (raw.includes(":") || raw.startsWith("[") || raw.startsWith("{")) {
    return JSON.stringify(raw);
  }
  return raw;
}

async function readText(file) {
  return fs.readFile(file, "utf8");
}

async function writeText(file, content) {
  await ensureDir(path.dirname(file));
  await fs.writeFile(file, content, "utf8");
}

async function readJson(file) {
  const raw = await readText(file);
  return JSON.parse(raw);
}

function cloneJson(value) {
  return JSON.parse(JSON.stringify(value));
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

async function writeJson(file, data) {
  const content = JSON.stringify(data, null, 2) + "\n";
  await writeText(file, content);
}

async function ensureDir(dir) {
  await fs.mkdir(dir, { recursive: true });
}

async function pathExists(filePath) {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

async function copyDir(sourceDir, targetDir) {
  await ensureDir(targetDir);
  const entries = await fs.readdir(sourceDir, { withFileTypes: true });
  for (const entry of entries) {
    const sourcePath = path.join(sourceDir, entry.name);
    const targetPath = path.join(targetDir, entry.name);
    if (entry.isDirectory()) {
      await copyDir(sourcePath, targetPath);
    } else if (entry.isFile()) {
      await ensureDir(path.dirname(targetPath));
      await fs.copyFile(sourcePath, targetPath);
    }
  }
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
    const transformed = transformContentForCodex(source, options);
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

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
