#!/usr/bin/env node
"use strict"

const fs = require("fs/promises")
const path = require("path")
const os = require("os")
const readline = require("readline")

const PERMISSION_MODES = ["none", "broad", "from-commands"]
const SOURCE_TOOLS = [
  "read",
  "write",
  "edit",
  "bash",
  "grep",
  "glob",
  "list",
  "webfetch",
  "skill",
  "patch",
  "task",
  "question",
  "todowrite",
  "todoread",
]

function resolveManagedChild(root, entry, label) {
  const resolvedRoot = path.resolve(root)
  const resolvedPath = path.resolve(root, entry)
  if (resolvedPath === resolvedRoot || !resolvedPath.startsWith(resolvedRoot + path.sep)) {
    throw new Error(`Invalid ${label}: ${entry}`)
  }
  return resolvedPath
}

const TOOL_MAP = {
  bash: "bash",
  read: "read",
  write: "write",
  edit: "edit",
  grep: "grep",
  glob: "glob",
  list: "list",
  webfetch: "webfetch",
  skill: "skill",
  patch: "patch",
  task: "task",
  question: "question",
  todowrite: "todowrite",
  todoread: "todoread",
}

const HOOK_EVENT_MAP = {
  PreToolUse: { events: ["tool.execute.before"], type: "tool" },
  PostToolUse: { events: ["tool.execute.after"], type: "tool" },
  PostToolUseFailure: { events: ["tool.execute.after"], type: "tool", requireError: true, note: "Claude PostToolUseFailure" },
  SessionStart: { events: ["session.created"], type: "session" },
  SessionEnd: { events: ["session.deleted"], type: "session" },
  Stop: { events: ["session.idle"], type: "session" },
  PreCompact: { events: ["experimental.session.compacting"], type: "session" },
  PermissionRequest: { events: ["permission.requested", "permission.replied"], type: "permission", note: "Claude PermissionRequest" },
  UserPromptSubmit: { events: ["message.created", "message.updated"], type: "message", note: "Claude UserPromptSubmit" },
  Notification: { events: ["message.updated"], type: "message", note: "Claude Notification" },
  Setup: { events: ["session.created"], type: "session", note: "Claude Setup" },
  SubagentStart: { events: ["message.updated"], type: "message", note: "Claude SubagentStart" },
  SubagentStop: { events: ["message.updated"], type: "message", note: "Claude SubagentStop" },
}

const targets = {
  opencode: {
    name: "opencode",
    convert: convertClaudeToOpenCode,
    write: writeOpenCodeBundle,
  },
  codex: {
    name: "codex",
    convert: convertClaudeToCodex,
    write: writeCodexBundle,
  },
}

async function main() {
  const argv = process.argv.slice(2)
  if (argv.length === 0 || isHelp(argv[0])) {
    printHelp(0)
    return
  }

  const command = argv[0]
  if (command === "install") {
    const parsed = parseArgs(argv.slice(1))
    await runInstall(parsed)
    return
  }

  if (command === "stats") {
    const parsed = parseArgs(argv.slice(1))
    await runStats(parsed)
    return
  }

  if (command !== "install" && command !== "stats") {
    console.error(`Unknown command: ${command}`)
    printHelp(1)
  }
}

async function runInstall(parsed) {
  const pluginInput = parsed._[0] ?? process.cwd()
  const targetName = String(parsed.to ?? "opencode")
  const target = targets[targetName]
  if (!target) {
    throw new Error(`Unknown target: ${targetName}`)
  }

  const permissions = String(parsed.permissions ?? "broad")
  if (!PERMISSION_MODES.includes(permissions)) {
    throw new Error(`Unknown permissions mode: ${permissions}`)
  }

  const resolvedPluginPath = await resolvePluginInput(pluginInput)
  const plugin = await loadClaudePlugin(resolvedPluginPath)
  const outputRoot = resolveRoot(parsed.output ?? parsed.o, ".config", "opencode")
  const codexHome = resolveRoot(parsed["codex-home"] ?? parsed.codexHome, ".codex")
  const codexRoot = resolveCodexOutputRoot(codexHome)
  const agentsHome = resolveRoot(parsed["agents-home"] ?? parsed.agentsHome, ".agents")
  const options = {
    agentMode: String(parsed["agent-mode"] ?? parsed.agentMode ?? "subagent") === "primary" ? "primary" : "subagent",
    inferTemperature: parseBoolean(parsed["infer-temperature"] ?? parsed.inferTemperature, true),
    permissions,
    yes: parseBoolean(parsed.yes ?? parsed.y, false),
    nonInteractive: parseBoolean(parsed["non-interactive"] ?? parsed.nonInteractive, false),
  }

  const bundle = target.convert(plugin, options)
  if (!bundle) {
    throw new Error(`Target ${targetName} did not return a bundle.`)
  }

  const primaryOutput = targetName === "codex" ? codexRoot : outputRoot
  const writeOptions = {
    agentsHome,
    pluginName: plugin.manifest.name,
    confirm: {
      yes: options.yes,
      nonInteractive: options.nonInteractive,
    },
  }

  await target.write(primaryOutput, bundle, writeOptions)
  console.log(`Installed ${plugin.manifest.name} to ${primaryOutput}`)

  const extraTargets = parseExtraTargets(parsed.also)
  const allTargets = [targetName, ...extraTargets]
  for (const extra of extraTargets) {
    const handler = targets[extra]
    if (!handler) {
      console.warn(`Skipping unknown target: ${extra}`)
      continue
    }
    const extraBundle = handler.convert(plugin, options)
    if (!extraBundle) {
      console.warn(`Skipping ${extra}: no output returned.`)
      continue
    }
    const extraRoot = extra === "codex" ? codexRoot : outputRoot
    await handler.write(extraRoot, extraBundle, writeOptions)
    console.log(`Installed ${plugin.manifest.name} to ${extraRoot}`)
  }

  if (allTargets.includes("codex")) {
    await ensureCodexAgentsFile(codexRoot)
  }
}

async function runStats(parsed) {
  const pluginInput = parsed._[0] ?? process.cwd()
  const resolvedPluginPath = await resolvePluginInput(pluginInput)
  const plugin = await loadClaudePlugin(resolvedPluginPath)

  const options = {
    agentMode: "subagent",
    inferTemperature: true,
    permissions: "broad",
    yes: true,
    nonInteractive: true,
  }

  const opencodeBundle = convertClaudeToOpenCode(plugin, options)
  const codexBundle = convertClaudeToCodex(plugin, options)
  const stats = {
    opencode_skills: opencodeBundle.skillDirs.length,
    codex_skills: codexBundle.skillDirs.length + codexBundle.generatedSkills.length,
    agent_skills: codexBundle.agentSkills?.length ?? 0,
  }

  const outputAsJson = parseBoolean(parsed.json, false)
  if (outputAsJson) {
    console.log(JSON.stringify(stats))
    return
  }

  for (const [key, value] of Object.entries(stats)) {
    console.log(`${key}=${value}`)
  }
}

function printHelp(exitCode) {
  const help = `Usage:
  scripts/convert-plugin.js install <plugin-name|path> [options]
  scripts/convert-plugin.js stats <plugin-name|path> [options]

Options:
  --to <target>           Target format: opencode | codex (default: opencode)
  --output, -o <dir>      Output directory (OpenCode root; default: ~/.config/opencode)
  --codex-home <dir>      Codex root (default: ~/.codex)
  --agents-home <dir>     Agents root (default: ~/.agents)
  --also <targets>        Comma-separated extra targets to generate
  --permissions <mode>    none | broad | from-commands (default: broad)
  --agent-mode <mode>     primary | subagent (default: subagent)
  --infer-temperature     true | false (default: true)
  --yes, -y               Assume "yes" for all cleanup confirmations
  --non-interactive       Never prompt; use default answers for confirmations
  --json                  (stats only) print a JSON object instead of key=value lines
`
  console.log(help)
  if (exitCode) process.exit(exitCode)
}

function isHelp(value) {
  return value === "-h" || value === "--help"
}

function parseArgs(argv) {
  const result = { _: [] }
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i]
    if (arg.startsWith("--")) {
      const [key, inlineValue] = arg.slice(2).split("=")
      if (inlineValue !== undefined) {
        result[key] = inlineValue
        continue
      }
      const next = argv[i + 1]
      if (next && !next.startsWith("-")) {
        result[key] = next
        i += 1
      } else {
        result[key] = true
      }
      continue
    }
    if (arg.startsWith("-")) {
      if (arg === "-o") {
        const next = argv[i + 1]
        if (next && !next.startsWith("-")) {
          result.o = next
          i += 1
        } else {
          result.o = true
        }
        continue
      }
      result[arg.slice(1)] = true
      continue
    }
    result._.push(arg)
  }
  return result
}

function parseBoolean(value, fallback) {
  if (value === undefined) return fallback
  if (typeof value === "boolean") return value
  const normalized = String(value).trim().toLowerCase()
  if (normalized === "true" || normalized === "1" || normalized === "yes") return true
  if (normalized === "false" || normalized === "0" || normalized === "no") return false
  return fallback
}

function parseExtraTargets(value) {
  if (!value) return []
  return String(value)
    .split(",")
    .map((entry) => entry.trim())
    .filter(Boolean)
}

function resolveRoot(value, ...defaultSegments) {
  if (value && String(value).trim()) {
    return path.resolve(expandHome(String(value).trim()))
  }
  return path.join(os.homedir(), ...defaultSegments)
}

function expandHome(value) {
  if (value === "~") return os.homedir()
  if (value.startsWith(`~${path.sep}`)) {
    return path.join(os.homedir(), value.slice(2))
  }
  return value
}

async function resolvePluginInput(input) {
  const directPath = path.resolve(String(input))
  if (await pathExists(directPath)) return directPath

  const slug = String(input ?? "").trim()
  if (!slug) {
    throw new Error("Plugin name or path is required.")
  }

  const scriptRoot = resolveScriptRoot()
  const rootCandidates = [process.cwd(), scriptRoot]
  const parentRoot = path.resolve(scriptRoot, "..")
  const parentMarketplacePath = path.join(parentRoot, ".claude-plugin", "marketplace.json")
  if (parentRoot !== scriptRoot && (await pathExists(parentMarketplacePath))) {
    rootCandidates.push(parentRoot)
  }

  for (const root of rootCandidates) {
    const marketplaceResolved = await resolveMarketplacePlugin(root, slug)
    if (marketplaceResolved) return marketplaceResolved

    const pluginsDirResolved = path.join(root, "plugins", slug)
    if (await pathExists(pluginsDirResolved)) return pluginsDirResolved
  }

  throw new Error(`Could not resolve plugin "${slug}".`)
}

function resolveScriptRoot() {
  return path.resolve(__dirname, "..")
}

async function resolveMarketplacePlugin(root, slug) {
  const marketplacePath = path.join(root, ".claude-plugin", "marketplace.json")
  if (!(await pathExists(marketplacePath))) return null
  const marketplace = await readJson(marketplacePath)
  const plugins = Array.isArray(marketplace.plugins) ? marketplace.plugins : []
  const entry = plugins.find((plugin) => plugin?.name === slug)
  if (!entry) return null
  const source = entry.source ?? "."
  return resolveWithinRoot(root, source, "marketplace plugin source")
}

async function loadClaudePlugin(inputPath) {
  const root = await resolveClaudeRoot(inputPath)
  const manifestPath = path.join(root, ".claude-plugin", "plugin.json")
  const manifest = await readJson(manifestPath)

  const agents = await loadAgents(resolveComponentDirs(root, "agents", manifest.agents))
  const legacyCommands = await loadCommands(resolveComponentDirs(root, "commands", manifest.commands))
  const skills = await loadSkills(resolveComponentDirs(root, "skills", manifest.skills))
  const commands = deriveInvocableCommands(legacyCommands, skills)
  const hooks = await loadHooks(root, manifest.hooks)
  const mcpServers = await loadMcpServers(root, manifest)

  return {
    root,
    manifest,
    agents,
    commands,
    skills,
    hooks,
    mcpServers,
  }
}

async function resolveClaudeRoot(inputPath) {
  const absolute = path.resolve(inputPath)
  const manifestAtPath = path.join(absolute, ".claude-plugin", "plugin.json")
  if (await pathExists(manifestAtPath)) {
    return absolute
  }

  if (absolute.endsWith(path.join(".claude-plugin", "plugin.json"))) {
    return path.dirname(path.dirname(absolute))
  }

  if (absolute.endsWith("plugin.json")) {
    return path.dirname(path.dirname(absolute))
  }

  throw new Error(`Could not find .claude-plugin/plugin.json under ${inputPath}`)
}

async function loadAgents(agentsDirs) {
  const files = await collectMarkdownFiles(agentsDirs)
  const agents = []
  for (const file of files) {
    const raw = await readText(file)
    const { data, body } = parseFrontmatter(raw)
    const name = data.name ?? path.basename(file, ".md")
    agents.push({
      name,
      description: data.description,
      capabilities: data.capabilities,
      model: data.model,
      body: body.trim(),
      sourcePath: file,
    })
  }
  return agents
}

async function loadCommands(commandsDirs) {
  const files = await collectMarkdownFiles(commandsDirs)
  const commands = []
  for (const file of files) {
    const raw = await readText(file)
    const { data, body } = parseFrontmatter(raw)
    const name = data.name ?? path.basename(file, ".md")
    const allowedTools = parseAllowedTools(data["allowed-tools"])
    commands.push({
      name,
      description: data.description,
      argumentHint: data["argument-hint"],
      model: data.model,
      allowedTools,
      disableModelInvocation: data["disable-model-invocation"],
      body: body.trim(),
      sourcePath: file,
    })
  }
  return commands
}

async function loadSkills(skillsDirs) {
  const entries = await collectFiles(skillsDirs)
  const skillFiles = entries.filter((file) => path.basename(file) === "SKILL.md")
  const skills = []
  for (const file of skillFiles) {
    const raw = await readText(file)
    const { data, body } = parseFrontmatter(raw)
    const name = data.name ?? path.basename(path.dirname(file))
    const allowedTools = parseAllowedTools(data["allowed-tools"])
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
    })
  }
  return skills
}

function deriveInvocableCommands(legacyCommands, skills) {
  const commands = []
  const seen = new Set()

  for (const command of legacyCommands) {
    const normalizedName = normalizeName(command.name)
    if (seen.has(normalizedName)) continue
    commands.push(command)
    seen.add(normalizedName)
  }

  for (const skill of skills) {
    if (skill.userInvocable === false) continue
    const normalizedName = normalizeName(skill.name)
    if (seen.has(normalizedName)) continue
    commands.push({
      name: skill.name,
      description: skill.description,
      argumentHint: skill.argumentHint,
      model: skill.model,
      allowedTools: skill.allowedTools,
      disableModelInvocation: skill.disableModelInvocation,
      body: skill.body,
      sourcePath: skill.skillPath,
    })
    seen.add(normalizedName)
  }

  return commands
}

async function loadHooks(root, hooksField) {
  const hookConfigs = []
  const defaultPath = path.join(root, "hooks", "hooks.json")
  if (await pathExists(defaultPath)) {
    hookConfigs.push(await readJson(defaultPath))
  }

  if (hooksField) {
    if (typeof hooksField === "string" || Array.isArray(hooksField)) {
      const hookPaths = toPathList(hooksField)
      for (const hookPath of hookPaths) {
        const resolved = resolveWithinRoot(root, hookPath, "hooks path")
        if (await pathExists(resolved)) {
          hookConfigs.push(await readJson(resolved))
        }
      }
    } else {
      hookConfigs.push(hooksField)
    }
  }

  if (hookConfigs.length === 0) return undefined
  return mergeHooks(hookConfigs)
}

async function loadMcpServers(root, manifest) {
  const field = manifest.mcpServers
  if (field) {
    if (typeof field === "string" || Array.isArray(field)) {
      return mergeMcpConfigs(await loadMcpPaths(root, field))
    }
    return field
  }

  const mcpPath = path.join(root, ".mcp.json")
  if (await pathExists(mcpPath)) {
    return readJson(mcpPath)
  }

  return undefined
}

function resolveComponentDirs(root, defaultDir, custom) {
  const dirs = [path.join(root, defaultDir)]
  for (const entry of toPathList(custom)) {
    dirs.push(resolveWithinRoot(root, entry, `${defaultDir} path`))
  }
  return dirs
}

function toPathList(value) {
  if (!value) return []
  if (Array.isArray(value)) return value
  return [value]
}

async function collectMarkdownFiles(dirs) {
  const entries = await collectFiles(dirs)
  return entries.filter((file) => file.endsWith(".md"))
}

async function collectFiles(dirs) {
  const files = []
  for (const dir of dirs) {
    if (!(await pathExists(dir))) continue
    const entries = await walkFiles(dir)
    files.push(...entries)
  }
  return files
}

async function walkFiles(dir) {
  const entries = await fs.readdir(dir, { withFileTypes: true })
  const files = []
  for (const entry of entries) {
    const full = path.join(dir, entry.name)
    if (entry.isDirectory()) {
      files.push(...(await walkFiles(full)))
    } else if (entry.isFile()) {
      files.push(full)
    }
  }
  return files
}

function mergeHooks(hooksList) {
  const merged = { hooks: {} }
  for (const hooks of hooksList) {
    for (const [event, matchers] of Object.entries(hooks.hooks ?? {})) {
      if (!merged.hooks[event]) {
        merged.hooks[event] = []
      }
      merged.hooks[event].push(...matchers)
    }
  }
  return merged
}

async function loadMcpPaths(root, value) {
  const configs = []
  for (const entry of toPathList(value)) {
    const resolved = resolveWithinRoot(root, entry, "mcpServers path")
    if (await pathExists(resolved)) {
      configs.push(await readJson(resolved))
    }
  }
  return configs
}

function mergeMcpConfigs(configs) {
  return configs.reduce((acc, config) => ({ ...acc, ...config }), {})
}

function resolveWithinRoot(root, entry, label) {
  const resolvedRoot = path.resolve(root)
  const resolvedPath = path.resolve(root, entry)
  if (resolvedPath === resolvedRoot || resolvedPath.startsWith(resolvedRoot + path.sep)) {
    return resolvedPath
  }
  throw new Error(`Invalid ${label}: ${entry}. Paths must stay within the plugin root.`)
}

function parseAllowedTools(value) {
  if (!value) return undefined
  if (Array.isArray(value)) {
    return value.map((item) => String(item))
  }
  if (typeof value === "string") {
    return value
      .split(/,/)
      .map((item) => item.trim())
      .filter(Boolean)
  }
  return undefined
}

function parsePlatforms(value) {
  if (!value) return undefined
  if (Array.isArray(value)) return value.map((item) => String(item).toLowerCase())
  if (typeof value === "string") {
    return value
      .split(/,/)
      .map((item) => item.trim().toLowerCase())
      .filter(Boolean)
  }
  return undefined
}

function filterByPlatform(skills, commands, platform) {
  const excluded = new Set()
  for (const skill of skills) {
    if (skill.platforms && !skill.platforms.includes(platform)) {
      excluded.add(normalizeName(skill.name))
    }
  }
  if (excluded.size === 0) return { skills, commands }
  return {
    skills: skills.filter((skill) => !excluded.has(normalizeName(skill.name))),
    commands: commands.filter((command) => !excluded.has(normalizeName(command.name))),
  }
}

function convertClaudeToOpenCode(plugin, options) {
  const { skills, commands } = filterByPlatform(plugin.skills, plugin.commands, "opencode")
  const agentFiles = plugin.agents.map((agent) => convertAgent(agent, options))
  const commandMap = convertCommands(commands)
  const mcp = plugin.mcpServers ? convertMcp(plugin.mcpServers) : undefined
  const hookRootDir = plugin.hooks ? normalizeName(plugin.manifest.name) : undefined
  const plugins = plugin.hooks ? [convertHooks(plugin.hooks, plugin.manifest.name, hookRootDir)] : []

  const config = {
    $schema: "https://opencode.ai/config.json",
    command: Object.keys(commandMap).length > 0 ? commandMap : undefined,
    mcp: mcp && Object.keys(mcp).length > 0 ? mcp : undefined,
  }

  applyPermissions(config, commands, options.permissions)

  return {
    config,
    agents: agentFiles,
    commands,
    plugins,
    hookRootDir,
    hookSourceDir: path.join(plugin.root, "hooks"),
    permissionsMode: options.permissions,
    skillDirs: skills.map((skill) => ({ sourceDir: skill.sourceDir, name: skill.name })),
  }
}

function convertAgent(agent, options) {
  const frontmatter = {
    description: agent.description,
    mode: options.agentMode,
  }

  if (agent.model && agent.model !== "inherit") {
    frontmatter.model = normalizeModel(agent.model)
  }

  if (options.inferTemperature) {
    const temperature = inferTemperature(agent)
    if (temperature !== undefined) {
      frontmatter.temperature = temperature
    }
  }

  const content = formatFrontmatter(frontmatter, agent.body)
  return {
    name: agent.name,
    content,
  }
}

function convertCommands(commands) {
  const result = {}
  for (const command of commands) {
    const entry = {
      description: command.description,
      template: command.body,
    }
    if (command.model && command.model !== "inherit") {
      entry.model = normalizeModel(command.model)
    }
    result[command.name] = entry
  }
  return result
}

function convertMcp(servers) {
  const result = {}
  for (const [name, server] of Object.entries(servers)) {
    if (server.command) {
      result[name] = {
        type: "local",
        command: [server.command, ...(server.args ?? [])],
        environment: server.env,
        enabled: true,
      }
      continue
    }

    if (server.url) {
      result[name] = {
        type: "remote",
        url: server.url,
        headers: server.headers,
        enabled: true,
      }
    }
  }
  return result
}

function convertHooks(hooks, pluginName, hookRootDir) {
  const handlerBlocks = []
  const hookMap = hooks.hooks ?? {}
  const unmappedEvents = []

  for (const [eventName, matchers] of Object.entries(hookMap)) {
    const mapping = HOOK_EVENT_MAP[eventName]
    if (!mapping) {
      unmappedEvents.push(eventName)
      continue
    }
    if (matchers.length === 0) continue
    for (const event of mapping.events) {
      handlerBlocks.push(
        renderHookHandlers(event, matchers, {
          useToolMatcher: mapping.type === "tool" || mapping.type === "permission",
          requireError: Boolean(mapping.requireError),
          note: mapping.note,
        }),
      )
    }
  }

  const unmappedComment = unmappedEvents.length > 0
    ? `// Unmapped Claude hook events: ${unmappedEvents.join(", ")}\n`
    : ""

  const content = `${unmappedComment}import path from "node:path"\nimport { fileURLToPath } from "node:url"\nimport type { Plugin } from "@opencode-ai/plugin"\n\nconst claudePluginRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "hook-bundles", ${JSON.stringify(hookRootDir)})\n\nexport const ConvertedHooks: Plugin = async ({ $ }) => {\n  return {\n${handlerBlocks.join(",\n")}\n  }\n}\n\nexport default ConvertedHooks\n`

  return {
    name: `converted-hooks-${normalizeName(pluginName)}.ts`,
    content,
  }
}

function renderHookHandlers(event, matchers, options) {
  const statements = []
  for (const matcher of matchers) {
    statements.push(...renderHookStatements(matcher, options.useToolMatcher))
  }
  const rendered = statements.map((line) => `    ${line}`).join("\n")
  const wrapped = options.requireError
    ? `    if (input?.error) {\n${statements.map((line) => `      ${line}`).join("\n")}\n    }`
    : rendered
  const note = options.note ? `    // ${options.note}\n` : ""
  return `    "${event}": async (input) => {\n${note}${wrapped}\n    }`
}

function renderHookStatements(matcher, useToolMatcher) {
  if (!matcher.hooks || matcher.hooks.length === 0) return []
  const tools = String(matcher.matcher ?? "")
    .split("|")
    .map((tool) => tool.trim().toLowerCase())
    .filter(Boolean)

  const useMatcher = useToolMatcher && tools.length > 0 && !tools.includes("*")
  const condition = useMatcher
    ? tools.map((tool) => `input.tool === "${tool}"`).join(" || ")
    : null
  const statements = []

  for (const hook of matcher.hooks) {
    if (hook.type === "command") {
      const renderedHookCommand = renderHookCommand(hook.command)
      const renderedCommand = `CLAUDE_PLUGIN_ROOT="\${claudePluginRoot}" ${renderedHookCommand}`
      if (condition) {
        statements.push(`if (${condition}) { await $\`${renderedCommand}\` }`)
      } else {
        statements.push(`await $\`${renderedCommand}\``)
      }
      if (hook.timeout) {
        statements.push(`// timeout: ${hook.timeout}s (not enforced)`)
      }
      continue
    }
    if (hook.type === "prompt") {
      statements.push(`// Prompt hook for ${matcher.matcher}: ${String(hook.prompt ?? "").replace(/\n/g, " ")}`)
      continue
    }
    if (hook.type === "agent") {
      statements.push(`// Agent hook for ${matcher.matcher}: ${hook.agent}`)
      continue
    }
    statements.push(`// Unsupported hook for ${matcher.matcher}: ${hook.type}`)
  }

  return statements
}

function normalizeModel(model) {
  if (model.includes("/")) return model
  if (/^claude-/.test(model)) return `anthropic/${model}`
  if (/^(gpt-|o1-|o3-)/.test(model)) return `openai/${model}`
  if (/^gemini-/.test(model)) return `google/${model}`
  return `anthropic/${model}`
}

function inferTemperature(agent) {
  const sample = `${agent.name} ${agent.description ?? ""}`.toLowerCase()
  if (/(review|audit|security|sentinel|oracle|lint|verification|guardian)/.test(sample)) {
    return 0.1
  }
  if (/(plan|planning|architecture|strategist|analysis|research)/.test(sample)) {
    return 0.2
  }
  if (/(doc|readme|changelog|editor|writer)/.test(sample)) {
    return 0.3
  }
  if (/(brainstorm|creative|ideate|design|concept)/.test(sample)) {
    return 0.6
  }
  return 0.3
}

function applyPermissions(config, commands, mode) {
  if (mode === "none") return

  let enabled = new Set()
  const patterns = {}
  let hasAllowedToolsDeclaration = false

  if (mode === "broad") {
    enabled = new Set(SOURCE_TOOLS)
  } else {
    for (const command of commands) {
      if (!command.allowedTools) continue
      hasAllowedToolsDeclaration = true
      for (const tool of command.allowedTools) {
        const parsed = parseToolSpec(tool)
        if (!parsed.tool) continue
        enabled.add(parsed.tool)
        if (parsed.pattern) {
          const normalizedPattern = normalizePattern(parsed.tool, parsed.pattern)
          if (!patterns[parsed.tool]) patterns[parsed.tool] = new Set()
          patterns[parsed.tool].add(normalizedPattern)
        }
      }
    }

    // Keep the legacy behavior usable for repos that define no per-command tool metadata.
    if (!hasAllowedToolsDeclaration) {
      enabled = new Set(SOURCE_TOOLS)
    }
  }

  const permission = {}
  const tools = {}

  for (const tool of SOURCE_TOOLS) {
    tools[tool] = mode === "broad" ? true : enabled.has(tool)
  }

  if (mode === "broad") {
    for (const tool of SOURCE_TOOLS) {
      permission[tool] = "allow"
    }
  } else {
    for (const tool of SOURCE_TOOLS) {
      const toolPatterns = patterns[tool]
      if (toolPatterns && toolPatterns.size > 0) {
        const patternPermission = { "*": "deny" }
        for (const pattern of toolPatterns) {
          patternPermission[pattern] = "allow"
        }
        permission[tool] = patternPermission
      } else {
        permission[tool] = enabled.has(tool) ? "allow" : "deny"
      }
    }
  }

  if (enabled.has("write") || enabled.has("edit")) {
    if (typeof permission.edit === "string") permission.edit = "allow"
    if (typeof permission.write === "string") permission.write = "allow"
  }
  if (patterns.write || patterns.edit) {
    const combined = new Set()
    for (const pattern of patterns.write ?? []) combined.add(pattern)
    for (const pattern of patterns.edit ?? []) combined.add(pattern)
    const combinedPermission = { "*": "deny" }
    for (const pattern of combined) {
      combinedPermission[pattern] = "allow"
    }
    permission.edit = combinedPermission
    permission.write = combinedPermission
  }

  config.permission = permission
  config.tools = tools
}

function parseToolSpec(raw) {
  const trimmed = String(raw ?? "").trim()
  if (!trimmed) return { tool: null }
  const [namePart, patternPart] = trimmed.split("(", 2)
  const name = namePart.trim().toLowerCase()
  const tool = TOOL_MAP[name] ?? null
  if (!patternPart) return { tool }
  const normalizedPattern = patternPart.endsWith(")")
    ? patternPart.slice(0, -1).trim()
    : patternPart.trim()
  return { tool, pattern: normalizedPattern }
}

function normalizePattern(tool, pattern) {
  if (tool === "bash") {
    return pattern.replace(/:/g, " ").trim()
  }
  return pattern
}

function escapeTemplateLiteral(value) {
  return String(value).replace(/[`\\]/g, "\\$&").replace(/\$\{/g, "\\${")
}

function normalizeSingleQuotedRootPlaceholders(value) {
  const input = String(value ?? "")
  const containsPlaceholderPattern = /\$\{CLAUDE_PLUGIN_ROOT\}|\$CLAUDE_PLUGIN_ROOT\b/
  const placeholderPattern = /\$\{CLAUDE_PLUGIN_ROOT\}|\$CLAUDE_PLUGIN_ROOT\b/g
  let result = ""
  let inDouble = false
  let escaped = false

  const rewriteSingleQuotedSpan = (inner) => {
    if (!containsPlaceholderPattern.test(inner)) {
      return `'${inner}'`
    }

    const segments = []
    let lastIndex = 0
    let placeholderMatch

    placeholderPattern.lastIndex = 0
    while ((placeholderMatch = placeholderPattern.exec(inner)) !== null) {
      const prefix = inner.slice(lastIndex, placeholderMatch.index)
      if (prefix) {
        segments.push(`'${prefix}'`)
      }
      segments.push(`"${placeholderMatch[0]}"`)
      lastIndex = placeholderMatch.index + placeholderMatch[0].length
    }

    const suffix = inner.slice(lastIndex)
    if (suffix) {
      segments.push(`'${suffix}'`)
    }

    return segments.join("")
  }

  for (let index = 0; index < input.length; index += 1) {
    const char = input[index]

    if (escaped) {
      result += char
      escaped = false
      continue
    }

    if (char === "\\") {
      result += char
      escaped = true
      continue
    }

    if (char === "\"") {
      inDouble = !inDouble
      result += char
      continue
    }

    if (char === "'" && !inDouble) {
      const endIndex = input.indexOf("'", index + 1)
      if (endIndex === -1) {
        result += input.slice(index)
        break
      }

      result += rewriteSingleQuotedSpan(input.slice(index + 1, endIndex))
      index = endIndex
      continue
    }

    result += char
  }

  return result
}

function renderHookRootReference(value, placeholder) {
  // Scan the ORIGINAL (un-template-escaped) string so quote/backslash
  // state tracks real shell semantics. Template-literal escaping is
  // applied only to the literal spans between placeholder sites, never
  // to the ${claudePluginRoot} interpolation itself.
  const parts = []
  let literal = ""
  let inSingle = false
  let inDouble = false
  let escaped = false

  const flushLiteral = () => {
    if (literal) {
      parts.push({ type: "literal", value: literal })
      literal = ""
    }
  }

  for (let i = 0; i < value.length; i += 1) {
    const char = value[i]

    if (escaped) {
      literal += char
      escaped = false
      continue
    }

    if (char === "\\" && !inSingle) {
      literal += char
      escaped = true
      continue
    }

    if (char === "'" && !inDouble) {
      inSingle = !inSingle
      literal += char
      continue
    }

    if (char === "\"" && !inSingle) {
      inDouble = !inDouble
      literal += char
      continue
    }

    if (value.startsWith(placeholder, i)) {
      flushLiteral()
      parts.push({ type: "placeholder", quoted: inSingle || inDouble })
      i += placeholder.length - 1
      continue
    }

    literal += char
  }
  flushLiteral()

  return parts
    .map((part) => {
      if (part.type === "literal") return escapeTemplateLiteral(part.value)
      return part.quoted ? "${claudePluginRoot}" : "\"${claudePluginRoot}\""
    })
    .join("")
}

function renderHookCommand(value) {
  // Bun shell drops template interpolations inside single-quoted spans, so
  // rewrite any single-quoted root placeholder into concatenated quoted
  // fragments that keep the interpolation live without changing the
  // surrounding literal shell text.
  const normalizedValue = normalizeSingleQuotedRootPlaceholders(value)
  const placeholder = "__CLAUDE_PLUGIN_ROOT__"
  const withPlaceholder = normalizedValue
    .replace(/\$\{CLAUDE_PLUGIN_ROOT\}/g, placeholder)
    .replace(/\$CLAUDE_PLUGIN_ROOT\b/g, placeholder)
  return renderHookRootReference(withPlaceholder, placeholder)
}

function convertClaudeToCodex(plugin, options) {
  const { skills, commands } = filterByPlatform(plugin.skills, plugin.commands, "codex")
  const copiedSkillNames = new Set(skills.map((skill) => codexName(skill.name)))
  const usedSkillNames = new Set(copiedSkillNames)
  const knownCommandNames = new Set(copiedSkillNames)
  const commandSkills = commands
    // Skill-backed commands already exist as copied skill directories.
    .filter((command) => path.basename(command.sourcePath ?? "") !== "SKILL.md")
    .filter((command) => !copiedSkillNames.has(codexName(command.name)))
    .map((command) => {
      const skillName = uniqueName(codexName(command.name), usedSkillNames)
      knownCommandNames.add(skillName)
      return convertCommandSkill(command, knownCommandNames, skillName)
    })
  const skillDirs = skills.map((skill) => convertExistingSkillForCodex(skill, knownCommandNames))

  const agentSkills = plugin.agents.map((agent) => convertAgentSkill(agent, usedSkillNames))

  return {
    prompts: [],
    skillDirs,
    generatedSkills: commandSkills,
    agentSkills,
    knownCommands: knownCommandNames,
    mcpServers: plugin.mcpServers,
  }
}

const CODEX_DESCRIPTION_MAX_LENGTH = 1024

function convertAgentSkill(agent, usedNames) {
  const name = uniqueName(codexName(agent.name), usedNames)
  const description = sanitizeDescription(
    agent.description ?? `Converted from Claude agent ${agent.name}`,
  )
  const frontmatter = { name, description }

  let body = agent.body.trim()
  if (agent.capabilities && agent.capabilities.length > 0) {
    const capabilities = agent.capabilities.map((capability) => `- ${capability}`).join("\n")
    body = `## Capabilities\n${capabilities}\n\n${body}`.trim()
  }
  if (body.length === 0) {
    body = `Instructions converted from the ${agent.name} agent.`
  }

  const content = formatFrontmatter(frontmatter, body)
  return { name, content }
}

function convertCommandSkill(command, knownCommands, name) {
  const frontmatter = {
    name,
    description: sanitizeDescription(
      command.description ?? `Converted from Claude command ${command.name}`,
    ),
    "argument-hint": command.argumentHint,
    "allowed-tools": command.allowedTools && command.allowedTools.length > 0 ? command.allowedTools : undefined,
    "disable-model-invocation": command.disableModelInvocation,
    "user-invocable": true,
  }
  const transformedBody = transformContentForCodex(command.body.trim(), { knownCommands })
  const body = transformedBody.trim()
  const content = formatFrontmatter(frontmatter, body.length > 0 ? body : command.body)
  return { name, content }
}

function convertExistingSkillForCodex(skill, knownCommands) {
  const frontmatter = {
    name: skill.name,
    description: sanitizeDescription(
      skill.description ?? `Converted from Claude skill ${skill.name}`,
    ),
    "argument-hint": skill.argumentHint,
    "allowed-tools": skill.allowedTools && skill.allowedTools.length > 0 ? skill.allowedTools : undefined,
    "disable-model-invocation": skill.disableModelInvocation,
    "user-invocable": skill.userInvocable,
    "kramme-platforms": skill.platforms && skill.platforms.length > 0 ? skill.platforms : undefined,
  }
  const body = transformContentForCodex(skill.body.trim(), { knownCommands })
  const content = formatFrontmatter(frontmatter, body.length > 0 ? body : skill.body)
  return { name: skill.name, sourceDir: skill.sourceDir, content }
}

function transformContentForCodex(body, options = {}) {
  let result = body
  const knownCommands = options.knownCommands

  const taskPattern = /^(\s*-?\s*)Task\s+([a-z][a-z0-9-]*)\(([^)]+)\)/gm
  result = result.replace(taskPattern, (_match, prefix, agentName, args) => {
    const skillName = codexName(agentName)
    const trimmedArgs = args.trim()
    return `${prefix}Use the $${skillName} skill to: ${trimmedArgs}`
  })

  const slashCommandPattern = /(?<![:\w])\/([a-z][a-z0-9_:-]*?)(?=[\s,.`"')\]}]|$)/gi
  result = result.replace(slashCommandPattern, (match, commandName) => {
    if (commandName.includes("/")) return match
    if (["dev", "tmp", "etc", "usr", "var", "bin", "home"].includes(commandName)) return match
    const codexified = codexName(commandName)
    if (knownCommands && !knownCommands.has(codexified)) return match
    return `$${codexified}`
  })

  const agentRefPattern = /@([a-z][a-z0-9-]*-(?:agent|reviewer|researcher|analyst|specialist|oracle|sentinel|guardian|strategist))/gi
  result = result.replace(agentRefPattern, (_match, agentName) => {
    const skillName = codexName(agentName)
    return `$${skillName} skill`
  })

  result = normalizeCodexInstructionText(result)

  return result
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
  [/Users can always select "Other" to provide free-text input\./g, "Users can always ignore the suggested options and reply freely in chat."],
  [/\*\*Tool structure:\*\*/g, "**Suggested structure:**"],
  [/- `header`: Short label\b/g, "- `Label`: Short label"],
  [/- `question`: The full question text\b/g, "- `Question`: The full question text"],
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
  [/\bKeep the total predefined option count within AskUserQuestion's 2-4 option limit\./g, "Keep the option set concise; 2-4 concrete options is usually enough."],
  [/\bKeep the total predefined option count between 2 and 4\./g, "Keep the option set concise; 2-4 concrete options is usually enough."],
  [/\bUse `?AskUserQuestion`? with multiSelect to\b/g, "Ask the user directly in chat and explicitly allow multiple selections to"],
  [/\buse `?AskUserQuestion`? with multiSelect to\b/g, "ask the user directly in chat and explicitly allow multiple selections to"],
  [/\bUse `?AskUserQuestion`? to ask\b/g, "Ask the user directly in chat"],
  [/\buse `?AskUserQuestion`? to ask\b/g, "ask the user directly in chat"],
  [/\bUse the `?AskUserQuestion`? tool\b/g, "Ask the user directly in chat"],
  [/\buse the `?AskUserQuestion`? tool\b/g, "ask the user directly in chat"],
  [/\bUsing the `?AskUserQuestion`? tool\b/g, "By asking the user directly in chat"],
  [/\busing the `?AskUserQuestion`? tool\b/g, "by asking the user directly in chat"],
  [/\bUse `?AskUserQuestion`? to\b/g, "Ask the user directly in chat to"],
  [/\buse `?AskUserQuestion`? to\b/g, "ask the user directly in chat to"],
  [/\bOtherwise AskUserQuestion\b/g, "Otherwise ask the user directly in chat"],
  [/\botherwise AskUserQuestion\b/g, "otherwise ask the user directly in chat"],
  [/\bOtherwise use `?AskUserQuestion`?(?=[:\s.,)]|$)/g, "Otherwise ask the user directly in chat"],
  [/\botherwise use `?AskUserQuestion`?(?=[:\s.,)]|$)/g, "otherwise ask the user directly in chat"],
  [/\bUse `?AskUserQuestion`?(?=[:\s.,)]|$)/g, "Ask the user directly in chat"],
  [/\buse `?AskUserQuestion`?(?=[:\s.,)]|$)/g, "ask the user directly in chat"],
  [/\busing `?AskUserQuestion`?(?=[:\s.,)]|$)/g, "by asking the user directly in chat"],
  [/\bvia `?AskUserQuestion`?(?=[:\s.,)]|$)/g, "by asking the user directly in chat"],
  [/\bAskUserQuestion with (\d+) options\b/g, "a direct chat question with $1 concrete options"],
  [/\bAskUserQuestion with multiSelect\b/g, "a direct chat question that explicitly allows multiple selections"],
  [/\bEvery AskUserQuestion option\b/g, "Every option you present"],
  [/\bAskUserQuestion option\b/g, "option you present"],
  [/\bskip this AskUserQuestion\b/g, "skip this direct chat question"],
  [/\bsend AskUserQuestion\b/g, "send the direct chat question"],
  [/\bAfter presenting AskUserQuestion\b/g, "After asking the question in chat"],
  [/\bfreeform AskUserQuestion\b/g, "direct chat follow-up for free-form input"],
  [/\bAskUserQuestion\b/g, "direct chat question"],
  [/\bUse direct chat question\b/g, "Ask the user directly in chat"],
  [/\buse direct chat question\b/g, "ask the user directly in chat"],
  [/\busing direct chat question\b/g, "by asking the user directly in chat"],
  [/\bvia direct chat question\b/g, "by asking the user directly in chat"],
  [/\bAsk the user directly in chat to ask\b/g, "Ask the user directly in chat"],
  [/\bask the user directly in chat to ask\b/g, "ask the user directly in chat"],
  [/\bAsk the user directly in chat with (\d+) options\b/g, "Ask the user directly in chat with $1 concrete options"],
  [/\bTask tool calls\b/g, "subagent calls"],
  [/\bvia the Task tool with\b/g, "using a subagent when available; otherwise in the main thread, with"],
  [/\busing the Task tool with\b/g, "using a subagent when available; otherwise in the main thread, with"],
  [/\bvia the Task tool\b/g, "using a subagent when available; otherwise in the main thread"],
  [/\busing the Task tool\b/g, "using a subagent when available; otherwise in the main thread"],
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
]

function normalizeCodexInstructionText(text) {
  let result = rewriteAskUserQuestionCodeBlocks(text)
  for (const [pattern, replacement] of CODEX_INSTRUCTION_REPLACEMENTS) {
    result = result.replace(pattern, replacement)
  }
  result = result.replace(
    /(^[ \t]*)Ask the user directly in chat:\n\s*\n\1Ask the user directly in chat:\n/gm,
    "$1Ask the user directly in chat:\n",
  )
  return result
}

function rewriteAskUserQuestionCodeBlocks(text) {
  const openFencePattern = /(^[ \t]*)(`{3,})([^\n]*)\r?\n/gm
  let result = ""
  let cursor = 0
  let match

  while ((match = openFencePattern.exec(text))) {
    const [openingLine, indent, openingFence] = match
    const bodyStart = match.index + openingLine.length
    const closingFence = findAskUserQuestionClosingFence(text, bodyStart, indent, openingFence.length)
    if (!closingFence) continue

    const body = text.slice(bodyStart, closingFence.index)
    const parsed = parseAskUserQuestionBlock(body)
    if (!parsed) {
      openFencePattern.lastIndex = closingFence.afterIndex
      continue
    }

    result += text.slice(cursor, match.index)
    result += renderDirectChatQuestion(parsed, { indent })
    cursor = closingFence.afterIndex
    openFencePattern.lastIndex = closingFence.afterIndex
  }

  result += text.slice(cursor)
  return result
}

function findAskUserQuestionClosingFence(text, fromIndex, openingIndent, minimumFenceLength) {
  const closingFencePattern = /(^[ \t]*)(`{3,})[ \t]*(?:\r?\n|$)/gm
  closingFencePattern.lastIndex = fromIndex

  let match
  while ((match = closingFencePattern.exec(text))) {
    if (match[1].length <= openingIndent.length && match[2].length >= minimumFenceLength) {
      return { index: match.index, afterIndex: closingFencePattern.lastIndex }
    }
  }

  return null
}

function parseAskUserQuestionBlock(body) {
  const lines = String(body).split(/\r?\n/)
  let index = 0
  while (index < lines.length && lines[index].trim() === "") {
    index += 1
  }

  if (/^AskUserQuestion\b/.test(lines[index]?.trim() ?? "")) {
    index += 1
  }

  let header = ""
  let question = ""
  let multiSelect = false
  const options = []
  let currentOption = null
  let sawStructuredPrompt = false

  const pushCurrentOption = () => {
    if (!currentOption) return
    options.push(currentOption)
    currentOption = null
  }

  for (; index < lines.length; index += 1) {
    const trimmed = lines[index].trim()
    if (!trimmed) continue

    let match = trimmed.match(/^header:\s*(.+)$/i)
    if (match) {
      header = stripWrappingQuotes(match[1])
      sawStructuredPrompt = true
      continue
    }

    match = trimmed.match(/^question:\s*(.+)$/i)
    if (match) {
      question = stripWrappingQuotes(match[1])
      sawStructuredPrompt = true
      continue
    }

    match = trimmed.match(/^multiSelect:\s*(.+)$/i)
    if (match) {
      multiSelect = /^true$/i.test(stripWrappingQuotes(match[1]))
      sawStructuredPrompt = true
      continue
    }

    if (/^options:\s*$/i.test(trimmed)) {
      sawStructuredPrompt = true
      continue
    }

    match = trimmed.match(/^-+\s*label:\s*(.+)$/i)
    if (match) {
      pushCurrentOption()
      currentOption = { label: stripWrappingQuotes(match[1]), description: "" }
      sawStructuredPrompt = true
      continue
    }

    match = trimmed.match(/^description:\s*(.+)$/i)
    if (match) {
      if (currentOption) {
        currentOption.description = stripWrappingQuotes(match[1])
      }
      sawStructuredPrompt = true
      continue
    }

    match = trimmed.match(/^-+\s*\(freeform\)\s*(.+)$/i)
    if (match) {
      pushCurrentOption()
      options.push({ label: stripWrappingQuotes(match[1]), description: "" })
      sawStructuredPrompt = true
      continue
    }

    match = trimmed.match(/^-+\s*(.+)$/)
    if (match) {
      pushCurrentOption()
      options.push({ label: stripWrappingQuotes(match[1]), description: "" })
      sawStructuredPrompt = true
      continue
    }
  }

  pushCurrentOption()

  if (!sawStructuredPrompt || !question) {
    return null
  }

  return { header, question, multiSelect, options }
}

function renderDirectChatQuestion(prompt, options = {}) {
  const indent = options.indent ?? ""
  const lines = ["Ask the user directly in chat:"]
  if (prompt.header) {
    lines.push(`Question label: ${prompt.header}`)
  }
  lines.push(`Question: ${prompt.question}`)
  if (prompt.multiSelect) {
    lines.push("Allow multiple selections if more than one option can apply.")
  }
  if (prompt.options.length > 0) {
    lines.push("Suggested options:")
    for (const option of prompt.options) {
      lines.push(option.description ? `- ${option.label} — ${option.description}` : `- ${option.label}`)
    }
  }
  return lines.map((line) => `${indent}${line}`).join("\n")
}

function stripWrappingQuotes(value) {
  const trimmed = String(value ?? "").trim()
  if (!trimmed) return ""
  if (
    (trimmed.startsWith("\"") && trimmed.endsWith("\"")) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'")) ||
    (trimmed.startsWith("`") && trimmed.endsWith("`"))
  ) {
    return trimmed.slice(1, -1)
  }
  return trimmed
}

function normalizeName(value) {
  const trimmed = String(value ?? "").trim()
  if (!trimmed) return "item"
  const normalized = trimmed
    .toLowerCase()
    .replace(/[\\/]+/g, "-")
    .replace(/[:\s]+/g, "-")
    .replace(/[^a-z0-9_-]+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-+|-+$/g, "")
  return normalized || "item"
}

function codexName(value) {
  const trimmed = String(value ?? "").trim()
  if (!trimmed) return "item"
  const normalized = trimmed
    .toLowerCase()
    .replace(/[\\/]+/g, "-")
    .replace(/\s+/g, "-")
    .replace(/[^a-z0-9_:-]+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-+|-+$/g, "")
  return normalized || "item"
}

function sanitizeDescription(value, maxLength = CODEX_DESCRIPTION_MAX_LENGTH) {
  const normalized = String(value ?? "").replace(/\s+/g, " ").trim()
  if (normalized.length <= maxLength) return normalized
  const ellipsis = "..."
  return normalized.slice(0, Math.max(0, maxLength - ellipsis.length)).trimEnd() + ellipsis
}

function uniqueName(base, used) {
  if (!used.has(base)) {
    used.add(base)
    return base
  }
  let index = 2
  while (used.has(`${base}-${index}`)) {
    index += 1
  }
  const name = `${base}-${index}`
  used.add(name)
  return name
}

function legacyOpenCodeHookRootDirs(bundle, pluginName) {
  return Array.from(new Set([
    normalizeName(pluginName),
    bundle.hookRootDir,
  ].filter(Boolean)))
}

async function findInstalledLegacyOpenCodeHookRootDirs(paths, bundle, pluginName) {
  const installed = []
  for (const hookRootDir of legacyOpenCodeHookRootDirs(bundle, pluginName)) {
    if (await pathExists(path.join(paths.hookBundlesDir, hookRootDir))) {
      installed.push(hookRootDir)
    }
  }
  return installed
}

async function currentPluginHasInstalledOpenCodeEntries(paths, bundle, pluginName) {
  const targets = [
    ...bundle.agents.map((agent) => path.join(paths.agentsDir, `${agent.name}.md`)),
    ...bundle.plugins.map((plugin) => path.join(paths.pluginsDir, plugin.name)),
    ...bundle.skillDirs.map((skill) => resolveManagedChild(paths.skillsDir, skill.name, "skill name")),
  ]

  for (const hookRootDir of legacyOpenCodeHookRootDirs(bundle, pluginName)) {
    targets.push(path.join(paths.hookBundlesDir, hookRootDir))
  }

  for (const targetPath of targets) {
    if (await pathExists(targetPath)) {
      return true
    }
  }

  return false
}

function extractHookScriptFragments(content) {
  return Array.from(new Set(
    String(content ?? "").match(
      /hooks\/(?:[^/"'`\s)]+\/)*[^/"'`\s)]+\.[A-Za-z0-9]+(?=(?:["'`\s)])|$|\/hooks\/)/g,
    ) ?? [],
  ))
}

function setsMatchExactly(left, right) {
  if (left.size !== right.size) return false
  for (const entry of left) {
    if (!right.has(entry)) return false
  }
  return true
}

function legacyHookPluginLikelyBelongsToBundle(legacyContent, bundle) {
  if (!bundle.hookRootDir) return false

  if (legacyContent.includes(`hook-bundles/${bundle.hookRootDir}`)) {
    return true
  }

  const hookScriptFragments = new Set(
    bundle.plugins.flatMap((plugin) => extractHookScriptFragments(plugin.content)),
  )
  if (hookScriptFragments.size === 0) return false

  const legacyHookScriptFragments = new Set(extractHookScriptFragments(legacyContent))
  if (legacyHookScriptFragments.size === 0) return false

  return setsMatchExactly(hookScriptFragments, legacyHookScriptFragments)
}

async function includeLegacyOpenCodeHookPlugin(paths, previousEntries, bundle, options = {}) {
  const { hasTrackedInstall = false, pluginName = "plugin" } = options
  const legacyPluginPath = path.join(paths.pluginsDir, "converted-hooks.ts")
  if (!(await pathExists(legacyPluginPath))) {
    return previousEntries
  }

  const legacyPluginContent = await readText(legacyPluginPath)
  const legacyHookRootDirs = await findInstalledLegacyOpenCodeHookRootDirs(paths, bundle, pluginName)
  const ownsLegacyHooks = (
    legacyHookPluginLikelyBelongsToBundle(legacyPluginContent, bundle)
    || (!hasTrackedInstall && (
      legacyHookRootDirs.length > 0
      || await currentPluginHasInstalledOpenCodeEntries(paths, bundle, pluginName)
    ))
  )

  if (!ownsLegacyHooks) {
    return previousEntries
  }

  // Older Opencode installs used a shared converted-hooks.ts filename and had
  // no per-plugin state, so first upgrade needs to treat it as a cleanup target.
  return {
    ...previousEntries,
    hooks: unionEntryLists(previousEntries.hooks, legacyHookRootDirs),
    plugins: unionEntryLists(previousEntries.plugins, ["converted-hooks.ts"]),
  }
}

async function writeOpenCodeBundle(outputRoot, bundle, extraOpts = {}) {
  const paths = resolveOpenCodePaths(outputRoot)
  const pluginName = extraOpts.pluginName ?? "plugin"
  const installRoots = [paths.stateRoot, ...(paths.legacyStateRoots ?? [])]
  const { state: installState } = await loadInstallStateWithFallback(installRoots)
  const { entries: trackedPreviousEntries, hasTrackedInstall } = await loadPreviousInstallEntries(
    installRoots,
    installState,
    pluginName,
    "opencode",
  )
  const previousEntries = await includeLegacyOpenCodeHookPlugin(
    paths,
    trackedPreviousEntries,
    bundle,
    { hasTrackedInstall, pluginName },
  )
  const legacyBaseConfig = needsLegacyOpenCodeBase(installState, pluginName)
    ? await loadExistingOpenCodeConfig([...(paths.legacyConfigPaths ?? []), paths.configPath])
    : {}
  await ensureDir(paths.root)

  const agentsDir = paths.agentsDir
  const cleanedAgents = await cleanupInstalledEntries(agentsDir, previousEntries.agents, {
    label: "agent",
    confirmOptions: extraOpts.confirm,
  })
  for (const agent of bundle.agents) {
    await writeText(path.join(agentsDir, `${agent.name}.md`), agent.content + "\n")
  }

  const pluginsDir = paths.pluginsDir
  // Only clean legacy shared hook plugins when previous-entry resolution tied
  // them to this install; otherwise preserve them rather than deleting another
  // plugin's still-untracked legacy hooks.
  const cleanedPlugins = await cleanupInstalledEntries(
    pluginsDir,
    previousEntries.plugins,
    {
      label: "plugin",
      confirmOptions: extraOpts.confirm,
    },
  )
  for (const plugin of bundle.plugins) {
    await writeText(path.join(pluginsDir, plugin.name), plugin.content + "\n")
  }

  const cleanedHooks = await cleanupInstalledEntries(paths.hookBundlesDir, previousEntries.hooks, {
    label: "hook bundle",
    recursive: true,
    confirmOptions: extraOpts.confirm,
  })
  if (bundle.hookRootDir && bundle.hookSourceDir && await pathExists(bundle.hookSourceDir)) {
    const hookRootPath = path.join(paths.hookBundlesDir, bundle.hookRootDir)
    if (cleanedHooks) {
      await fs.rm(hookRootPath, { recursive: true, force: true })
    }
    await copyDir(bundle.hookSourceDir, path.join(hookRootPath, "hooks"))
    await bootstrapHookScripts(path.join(hookRootPath, "hooks"))
  }

  const skillsRoot = paths.skillsDir
  const cleanedSkills = await cleanupInstalledEntries(skillsRoot, previousEntries.skills, {
    label: "skill",
    recursive: true,
    confirmOptions: extraOpts.confirm,
  })
  for (const skill of bundle.skillDirs) {
    const targetDir = resolveManagedChild(skillsRoot, skill.name, "skill name")
    await copyDir(skill.sourceDir, targetDir)
    if (skill.content) {
      await writeText(path.join(targetDir, "SKILL.md"), skill.content + "\n")
    }
  }

  const nextEntries = {
    agents: cleanedAgents
      ? bundle.agents.map((agent) => `${agent.name}.md`)
      : unionEntryLists(previousEntries.agents, bundle.agents.map((agent) => `${agent.name}.md`)),
    hooks: cleanedHooks
      ? (bundle.hookRootDir ? [bundle.hookRootDir] : [])
      : unionEntryLists(previousEntries.hooks, bundle.hookRootDir ? [bundle.hookRootDir] : []),
    plugins: cleanedPlugins
      ? bundle.plugins.map((plugin) => plugin.name)
      : unionEntryLists(previousEntries.plugins, bundle.plugins.map((plugin) => plugin.name)),
    skills: cleanedSkills
      ? bundle.skillDirs.map((skill) => skill.name)
      : unionEntryLists(previousEntries.skills, bundle.skillDirs.map((skill) => skill.name)),
    commands: bundle.commands ?? [],
    config: buildOpenCodePluginConfig(bundle.commands ?? [], bundle.config, bundle.permissionsMode ?? "broad"),
    permissionsMode: bundle.permissionsMode ?? "broad",
    updatedAtMs: Date.now(),
  }
  setInstallEntries(installState, pluginName, "opencode", nextEntries)
  await writeJson(paths.configPath, buildCombinedOpenCodeConfigFromState(installState, {
    preferredPluginName: pluginName,
    legacyBaseConfig,
    previousPreferredConfig: previousEntries.config,
    previousPreferredEntries: trackedPreviousEntries,
    currentPreferredCommands: bundle.commands ?? [],
  }))
  await writeInstallState(paths.stateRoot, installState)
  await writeInstallManifest(paths.stateRoot, pluginName, "opencode", nextEntries)
}

function resolveOpenCodePaths(outputRoot) {
  const resolvedOutputRoot = path.resolve(outputRoot)
  const base = path.basename(resolvedOutputRoot)
  if (base === "opencode" || base === ".opencode") {
    const parentRoot = path.dirname(resolvedOutputRoot)
    const legacyStateRoots = base === ".opencode"
      ? [parentRoot]
      : []
    return {
      root: resolvedOutputRoot,
      stateRoot: resolvedOutputRoot,
      legacyStateRoots,
      legacyConfigPaths: base === ".opencode"
        ? [path.join(parentRoot, "opencode.json")]
        : [],
      configPath: path.join(resolvedOutputRoot, "opencode.json"),
      agentsDir: path.join(resolvedOutputRoot, "agents"),
      hookBundlesDir: path.join(resolvedOutputRoot, "hook-bundles"),
      pluginsDir: path.join(resolvedOutputRoot, "plugins"),
      skillsDir: path.join(resolvedOutputRoot, "skills"),
    }
  }

  const hiddenRoot = path.join(resolvedOutputRoot, ".opencode")
  return {
    root: resolvedOutputRoot,
    stateRoot: hiddenRoot,
    legacyStateRoots: [resolvedOutputRoot],
    legacyConfigPaths: [path.join(hiddenRoot, "opencode.json")],
    configPath: path.join(resolvedOutputRoot, "opencode.json"),
    agentsDir: path.join(hiddenRoot, "agents"),
    hookBundlesDir: path.join(hiddenRoot, "hook-bundles"),
    pluginsDir: path.join(hiddenRoot, "plugins"),
    skillsDir: path.join(hiddenRoot, "skills"),
  }
}

async function writeCodexBundle(outputRoot, bundle, extraOpts = {}) {
  const codexRoot = resolveCodexOutputRoot(outputRoot)
  const pluginName = extraOpts.pluginName ?? "plugin"
  const { state: installState } = await loadInstallState(codexRoot)
  const previousEntries = await getPreviousInstallEntries(codexRoot, installState, pluginName, "codex")
  await ensureDir(codexRoot)

  const promptsDir = path.join(codexRoot, "prompts")
  const cleanedPrompts = await cleanupInstalledEntries(promptsDir, previousEntries.prompts, {
    label: "prompt",
    confirmOptions: extraOpts.confirm,
  })
  for (const prompt of bundle.prompts) {
    await writeText(path.join(promptsDir, `${prompt.name}.md`), prompt.content + "\n")
  }

  const skillsRoot = path.join(codexRoot, "skills")
  await cleanupKrammeComponents(skillsRoot, {
    label: "skill",
    filter: (e) => e.isDirectory(),
    recursive: true,
    prefixes: ["impl-"],
    confirmOptions: extraOpts.confirm,
  })
  const cleanedCodexSkills = await cleanupInstalledEntries(skillsRoot, previousEntries.skills, {
    label: "skill",
    recursive: true,
    confirmOptions: extraOpts.confirm,
  })

  for (const skill of bundle.skillDirs) {
    const targetDir = resolveManagedChild(skillsRoot, skill.name, "skill name")
    await copyDir(skill.sourceDir, targetDir)
    if (skill.content) {
      await writeText(path.join(targetDir, "SKILL.md"), skill.content + "\n")
    }
    await rewriteCodexMarkdownResourcesFromSource(skill.sourceDir, targetDir, bundle.knownCommands)
  }

  for (const skill of bundle.generatedSkills) {
    const targetDir = resolveManagedChild(skillsRoot, skill.name, "skill name")
    await writeText(path.join(targetDir, "SKILL.md"), skill.content + "\n")
  }

  let cleanedAgentSkills = true
  if (bundle.agentSkills && (bundle.agentSkills.length > 0 || previousEntries.agentSkills.length > 0)) {
    const agentsHome = extraOpts.agentsHome ?? path.join(os.homedir(), ".agents")
    const agentSkillsRoot = path.join(agentsHome, "skills")
    cleanedAgentSkills = await cleanupInstalledEntries(agentSkillsRoot, previousEntries.agentSkills, {
      label: "skill",
      recursive: true,
      confirmOptions: extraOpts.confirm,
    })
    for (const skill of bundle.agentSkills) {
      const targetDir = resolveManagedChild(agentSkillsRoot, skill.name, "agent skill name")
      await writeText(path.join(targetDir, "SKILL.md"), skill.content + "\n")
    }
  }

  const config = renderCodexConfig(bundle.mcpServers)
  if (config) {
    await writeText(path.join(codexRoot, "config.toml"), config)
  }

  const nextEntries = {
    prompts: cleanedPrompts
      ? bundle.prompts.map((prompt) => `${prompt.name}.md`)
      : unionEntryLists(previousEntries.prompts, bundle.prompts.map((prompt) => `${prompt.name}.md`)),
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
      : unionEntryLists(previousEntries.agentSkills, (bundle.agentSkills ?? []).map((skill) => skill.name)),
    updatedAtMs: Date.now(),
  }
  setInstallEntries(installState, pluginName, "codex", nextEntries)
  await writeInstallState(codexRoot, installState)
  await writeInstallManifest(codexRoot, pluginName, "codex", nextEntries)
}

function resolveCodexOutputRoot(outputRoot) {
  return path.basename(outputRoot) === ".codex" ? outputRoot : path.join(outputRoot, ".codex")
}

function renderCodexConfig(mcpServers) {
  if (!mcpServers || Object.keys(mcpServers).length === 0) return null

  const lines = ["# Generated by kramme-cc-workflow", ""]

  for (const [name, server] of Object.entries(mcpServers)) {
    const key = formatTomlKey(name)
    lines.push(`[mcp_servers.${key}]`)

    if (server.command) {
      lines.push(`command = ${formatTomlString(server.command)}`)
      if (server.args && server.args.length > 0) {
        const args = server.args.map((arg) => formatTomlString(arg)).join(", ")
        lines.push(`args = [${args}]`)
      }

      if (server.env && Object.keys(server.env).length > 0) {
        lines.push("")
        lines.push(`[mcp_servers.${key}.env]`)
        for (const [envKey, value] of Object.entries(server.env)) {
          lines.push(`${formatTomlKey(envKey)} = ${formatTomlString(value)}`)
        }
      }
    } else if (server.url) {
      lines.push(`url = ${formatTomlString(server.url)}`)
      if (server.headers && Object.keys(server.headers).length > 0) {
        lines.push(`http_headers = ${formatTomlInlineTable(server.headers)}`)
      }
    }

    lines.push("")
  }

  return lines.join("\n")
}

function formatTomlString(value) {
  return JSON.stringify(value)
}

function formatTomlKey(value) {
  if (/^[A-Za-z0-9_-]+$/.test(value)) return value
  return JSON.stringify(value)
}

function formatTomlInlineTable(entries) {
  const parts = Object.entries(entries).map(
    ([key, value]) => `${formatTomlKey(key)} = ${formatTomlString(value)}`,
  )
  return `{ ${parts.join(", ")} }`
}

const CODEX_AGENTS_BLOCK_START = "<!-- BEGIN KRAMME CODEX TOOL MAP -->"
const CODEX_AGENTS_BLOCK_END = "<!-- END KRAMME CODEX TOOL MAP -->"

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
`

async function ensureCodexAgentsFile(codexHome) {
  await ensureDir(codexHome)
  const filePath = path.join(codexHome, "AGENTS.md")
  const block = buildCodexAgentsBlock()

  if (!(await pathExists(filePath))) {
    await writeText(filePath, block + "\n")
    return
  }

  const existing = await readText(filePath)
  const updated = upsertBlock(existing, block)
  if (updated !== existing) {
    await writeText(filePath, updated)
  }
}

function buildCodexAgentsBlock() {
  return [CODEX_AGENTS_BLOCK_START, CODEX_AGENTS_BLOCK_BODY.trim(), CODEX_AGENTS_BLOCK_END].join("\n")
}

function upsertBlock(existing, block) {
  const startIndex = existing.indexOf(CODEX_AGENTS_BLOCK_START)
  const endIndex = existing.indexOf(CODEX_AGENTS_BLOCK_END)

  if (startIndex !== -1 && endIndex !== -1 && endIndex > startIndex) {
    const before = existing.slice(0, startIndex).trimEnd()
    const after = existing.slice(endIndex + CODEX_AGENTS_BLOCK_END.length).trimStart()
    return [before, block, after].filter(Boolean).join("\n\n") + "\n"
  }

  if (existing.trim().length === 0) {
    return block + "\n"
  }

  return existing.trimEnd() + "\n\n" + block + "\n"
}

function parseFrontmatter(raw) {
  const lines = raw.split(/\r?\n/)
  if (lines.length === 0 || lines[0].trim() !== "---") {
    return { data: {}, body: raw }
  }

  let endIndex = -1
  for (let i = 1; i < lines.length; i += 1) {
    if (lines[i].trim() === "---") {
      endIndex = i
      break
    }
  }

  if (endIndex === -1) {
    return { data: {}, body: raw }
  }

  const yamlLines = lines.slice(1, endIndex)
  const body = lines.slice(endIndex + 1).join("\n")
  const data = parseYamlLines(yamlLines)
  return { data, body }
}

function parseYamlLines(lines) {
  const data = {}
  let currentKey = null
  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i]
    if (!line.trim()) continue

    if (line.trim().startsWith("- ")) {
      if (!currentKey) continue
      if (!Array.isArray(data[currentKey])) {
        data[currentKey] = []
      }
      data[currentKey].push(parseYamlValue(line.trim().slice(2)))
      continue
    }

    const idx = line.indexOf(":")
    if (idx === -1) continue
    const key = line.slice(0, idx).trim()
    let value = line.slice(idx + 1).trim()
    currentKey = key
    if (!value) {
      data[key] = []
      continue
    }
    if (value === "|" || value === ">") {
      const blockLines = []
      let j = i + 1
      while (j < lines.length && /^[ \\t]+/.test(lines[j])) {
        blockLines.push(lines[j].replace(/^[ \\t]{1,2}/, ""))
        j += 1
      }
      i = j - 1
      const joiner = value === "|" ? "\n" : " "
      data[key] = blockLines.join(joiner).trimEnd()
      currentKey = null
      continue
    }
    data[key] = parseYamlValue(value)
  }
  return data
}

function parseYamlValue(value) {
  if ((value.startsWith("\"") && value.endsWith("\"")) || (value.startsWith("'") && value.endsWith("'"))) {
    return value.slice(1, -1)
  }
  if (value.startsWith("[") && value.endsWith("]")) {
    const inner = value.slice(1, -1).trim()
    if (!inner) return []
    return inner.split(",").map((item) => parseYamlValue(item.trim()))
  }
  if (value === "true") return true
  if (value === "false") return false
  if (value === "null" || value === "~") return null
  if (/^-?\d+(\.\d+)?$/.test(value)) return Number(value)
  return value
}

function formatFrontmatter(data, body) {
  const yaml = Object.entries(data)
    .filter(([, value]) => value !== undefined)
    .map(([key, value]) => formatYamlLine(key, value))
    .join("\n")

  if (yaml.trim().length === 0) {
    return body
  }

  return ["---", yaml, "---", "", body].join("\n")
}

function formatYamlLine(key, value) {
  if (Array.isArray(value)) {
    const items = value.map((item) => `  - ${formatYamlValue(item)}`)
    return [key + ":", ...items].join("\n")
  }
  return `${key}: ${formatYamlValue(value)}`
}

function formatYamlValue(value) {
  if (value === null || value === undefined) return ""
  if (typeof value === "number" || typeof value === "boolean") return String(value)
  const raw = String(value)
  if (raw.includes("\n")) {
    return `|\n${raw.split("\n").map((line) => `  ${line}`).join("\n")}`
  }
  if (raw.includes(":") || raw.startsWith("[") || raw.startsWith("{")) {
    return JSON.stringify(raw)
  }
  return raw
}

async function readText(file) {
  return fs.readFile(file, "utf8")
}

async function writeText(file, content) {
  await ensureDir(path.dirname(file))
  await fs.writeFile(file, content, "utf8")
}

async function readJson(file) {
  const raw = await readText(file)
  return JSON.parse(raw)
}

function isPlainObject(value) {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value)
}

function cloneJson(value) {
  return JSON.parse(JSON.stringify(value))
}

function sanitizeInstallPermissionsMode(value) {
  return PERMISSION_MODES.includes(value) ? value : undefined
}

function sanitizeStoredCommand(command) {
  if (!isPlainObject(command)) return null

  const name = String(command.name ?? "").trim()
  if (!name) return null

  const sanitized = {
    name,
    description: command.description === undefined ? undefined : String(command.description),
    model: command.model === undefined ? undefined : String(command.model),
    body: String(command.body ?? ""),
  }

  const allowedTools = sanitizeEntryList(command.allowedTools)
  if (allowedTools.length > 0) {
    sanitized.allowedTools = allowedTools
  }

  return sanitized
}

function sanitizeStoredCommands(commands) {
  if (!Array.isArray(commands)) return []
  return commands
    .map((command) => sanitizeStoredCommand(command))
    .filter(Boolean)
}

function createInstallState() {
  return {
    version: 1,
    plugins: {},
  }
}

function sanitizeInstallTimestamp(value) {
  const timestamp = Number(value)
  if (!Number.isFinite(timestamp) || timestamp <= 0) return undefined
  return timestamp
}

function sanitizeInstallConfig(config) {
  if (!isPlainObject(config)) return {}

  const sanitized = {}
  if (isPlainObject(config.command) && Object.keys(config.command).length > 0) {
    sanitized.command = cloneJson(config.command)
  }
  if (isPlainObject(config.mcp) && Object.keys(config.mcp).length > 0) {
    sanitized.mcp = cloneJson(config.mcp)
  }
  if (isPlainObject(config.tools) && Object.keys(config.tools).length > 0) {
    sanitized.tools = cloneJson(config.tools)
  }
  if (isPlainObject(config.permission) && Object.keys(config.permission).length > 0) {
    sanitized.permission = cloneJson(config.permission)
  }

  return sanitized
}

function hasStoredOpenCodeConfig(targetState) {
  return Object.keys(sanitizeInstallConfig(targetState?.config)).length > 0
}

function sanitizeInstallRecord(record) {
  return {
    agents: sanitizeEntryList(record?.agents),
    hooks: sanitizeEntryList(record?.hooks),
    plugins: sanitizeEntryList(record?.plugins),
    prompts: sanitizeEntryList(record?.prompts),
    skills: sanitizeEntryList(record?.skills),
    agentSkills: sanitizeEntryList(record?.agentSkills),
    commands: sanitizeStoredCommands(record?.commands),
    config: sanitizeInstallConfig(record?.config),
    permissionsMode: sanitizeInstallPermissionsMode(record?.permissionsMode),
    updatedAtMs: sanitizeInstallTimestamp(record?.updatedAtMs),
  }
}

function parseInstallManifestFilename(filename) {
  const match = /^(.*)-(opencode|codex)\.json$/.exec(filename)
  if (!match) return null

  try {
    return {
      pluginName: decodeURIComponent(match[1]),
      targetName: match[2],
    }
  } catch {
    return null
  }
}

function getLegacyManifestOrderTimestamp(stats) {
  if (Number.isFinite(stats?.birthtimeMs) && stats.birthtimeMs > 0) {
    return stats.birthtimeMs
  }
  if (Number.isFinite(stats?.mtimeMs) && stats.mtimeMs > 0) {
    return stats.mtimeMs
  }
  if (Number.isFinite(stats?.ctimeMs) && stats.ctimeMs > 0) {
    return stats.ctimeMs
  }
  return 0
}

async function rebuildInstallStateFromManifests(root) {
  const state = createInstallState()
  const manifestsDir = path.join(root, ".kramme-install-manifests")
  if (!(await pathExists(manifestsDir))) return state

  const entries = await fs.readdir(manifestsDir, { withFileTypes: true })
  const manifests = []
  for (const entry of entries) {
    if (!entry.isFile() || path.extname(entry.name) !== ".json") continue

    const manifestMeta = parseInstallManifestFilename(entry.name)
    if (!manifestMeta) continue

    const manifest = await loadInstallManifest(root, manifestMeta.pluginName, manifestMeta.targetName)
    if (!manifest) continue

    let fallbackUpdatedAtMs = 0
    try {
      const stats = await fs.stat(path.join(manifestsDir, entry.name))
      // Prefer creation time so hand-edited legacy manifests still rebuild in install order.
      fallbackUpdatedAtMs = getLegacyManifestOrderTimestamp(stats)
    } catch {
      // Ignore stat failures and fall back to deterministic filename ordering.
    }

    manifests.push({
      ...manifestMeta,
      manifest,
      sortKey: manifest.updatedAtMs ?? fallbackUpdatedAtMs,
    })
  }

  manifests.sort((left, right) => {
    if (left.sortKey !== right.sortKey) {
      return left.sortKey - right.sortKey
    }
    if (left.pluginName !== right.pluginName) {
      return left.pluginName.localeCompare(right.pluginName)
    }
    return left.targetName.localeCompare(right.targetName)
  })

  for (const { pluginName, targetName, manifest, sortKey } of manifests) {
    setInstallEntries(
      state,
      pluginName,
      targetName,
      manifest.updatedAtMs === undefined && sortKey > 0
        ? { ...manifest, updatedAtMs: sortKey }
        : manifest,
    )
  }

  return state
}

async function loadInstallState(root) {
  const filePath = path.join(root, ".kramme-install-state.json")
  if (!(await pathExists(filePath))) {
    return {
      state: await rebuildInstallStateFromManifests(root),
      fromDisk: false,
    }
  }

  try {
    const state = await readJson(filePath)
    if (state && typeof state === "object" && state.plugins && typeof state.plugins === "object") {
      return {
        state,
        fromDisk: true,
      }
    }
  } catch {
    // Ignore invalid state and rebuild from the current install.
  }

  return {
    state: await rebuildInstallStateFromManifests(root),
    fromDisk: false,
  }
}

function hasInstallStateEntries(state) {
  if (!isPlainObject(state?.plugins)) return false
  return Object.values(state.plugins)
    .some((pluginTargets) => isPlainObject(pluginTargets) && Object.keys(pluginTargets).length > 0)
}

function hasTrackedInstallRecord(record) {
  const sanitized = sanitizeInstallRecord(record)
  return Boolean(sanitized.permissionsMode)
    || sanitized.commands.length > 0
    || Object.keys(sanitized.config).length > 0
}

function shouldReplaceInstallRecord(existingRecord, incomingRecord) {
  const existingTracked = hasTrackedInstallRecord(existingRecord)
  const incomingTracked = hasTrackedInstallRecord(incomingRecord)

  // Records for the same plugin/target belong to a specific output root. Keep
  // the active root's tracked record and only let legacy roots backfill when
  // the active root lost its tracked install metadata.
  if (existingTracked) {
    return false
  }
  if (incomingTracked) {
    return true
  }

  const existingTimestamp = sanitizeInstallTimestamp(existingRecord?.updatedAtMs) ?? 0
  const incomingTimestamp = sanitizeInstallTimestamp(incomingRecord?.updatedAtMs) ?? 0
  return incomingTimestamp > existingTimestamp
}

function mergeInstallStates(results) {
  const merged = createInstallState()
  let fromDisk = false

  for (const result of results) {
    if (!result) continue
    fromDisk = fromDisk || Boolean(result.fromDisk)

    for (const [pluginName, pluginTargets] of Object.entries(result.state?.plugins ?? {})) {
      if (!isPlainObject(pluginTargets)) continue

      for (const [targetName, targetRecord] of Object.entries(pluginTargets)) {
        if (!isPlainObject(targetRecord)) continue

        const existingRecord = merged.plugins?.[pluginName]?.[targetName]
        if (!existingRecord || shouldReplaceInstallRecord(existingRecord, targetRecord)) {
          setInstallEntries(merged, pluginName, targetName, targetRecord)
        }
      }
    }
  }

  return {
    state: merged,
    fromDisk,
  }
}

async function loadInstallStateWithFallback(roots) {
  const normalizedRoots = uniqueRoots(roots)
  if (normalizedRoots.length === 0) {
    return {
      state: createInstallState(),
      fromDisk: false,
    }
  }

  const results = []
  for (let index = 0; index < normalizedRoots.length; index += 1) {
    const loaded = await loadInstallState(normalizedRoots[index])
    results.push(loaded)
  }

  const merged = mergeInstallStates(results)
  if (hasInstallStateEntries(merged.state) || merged.fromDisk) {
    return merged
  }

  return {
    state: createInstallState(),
    fromDisk: false,
  }
}

function getInstallManifestPath(root, pluginName, targetName) {
  return path.join(
    root,
    ".kramme-install-manifests",
    `${encodeURIComponent(pluginName)}-${targetName}.json`,
  )
}

async function loadInstallManifest(root, pluginName, targetName) {
  const filePath = getInstallManifestPath(root, pluginName, targetName)
  if (!(await pathExists(filePath))) return null

  try {
    return sanitizeInstallRecord(await readJson(filePath))
  } catch {
    // Ignore invalid manifests and rebuild from the current install.
  }

  return null
}

async function writeInstallManifest(root, pluginName, targetName, entries) {
  await writeJson(getInstallManifestPath(root, pluginName, targetName), sanitizeInstallRecord(entries))
}

async function writeInstallState(root, state) {
  await writeJson(path.join(root, ".kramme-install-state.json"), state)
}

function getInstallEntries(state, pluginName, targetName) {
  const targetState = state.plugins?.[pluginName]?.[targetName]
  return sanitizeInstallRecord(targetState)
}

async function getPreviousInstallEntries(rootOrRoots, state, pluginName, targetName) {
  return (await loadPreviousInstallEntries(rootOrRoots, state, pluginName, targetName)).entries
}

async function loadPreviousInstallEntries(rootOrRoots, state, pluginName, targetName) {
  const roots = Array.isArray(rootOrRoots) ? rootOrRoots : [rootOrRoots]
  if (state.plugins?.[pluginName]?.[targetName]) {
    return {
      entries: getInstallEntries(state, pluginName, targetName),
      hasTrackedInstall: true,
    }
  }
  for (const root of uniqueRoots(roots)) {
    const manifest = await loadInstallManifest(root, pluginName, targetName)
    if (manifest) {
      return {
        entries: manifest,
        hasTrackedInstall: true,
      }
    }
  }
  return {
    entries: getInstallEntries(state, pluginName, targetName),
    hasTrackedInstall: false,
  }
}

function setInstallEntries(state, pluginName, targetName, entries) {
  if (!state.plugins || typeof state.plugins !== "object") {
    state.plugins = {}
  }
  if (!state.plugins[pluginName] || typeof state.plugins[pluginName] !== "object") {
    state.plugins[pluginName] = {}
  }
  state.plugins[pluginName][targetName] = sanitizeInstallRecord(entries)
}

function sanitizeEntryList(entries) {
  if (!Array.isArray(entries)) return []
  return entries
    .map((entry) => String(entry ?? "").trim())
    .filter(Boolean)
}

function unionEntryLists(...lists) {
  return Array.from(new Set(lists.flatMap((entries) => sanitizeEntryList(entries))))
}

function uniqueRoots(roots) {
  return Array.from(
    new Set(
      sanitizeEntryList(roots).map((root) => path.resolve(root)),
    ),
  )
}

function collectAllowedPermissionPatterns(permissionValue, patterns) {
  if (!isPlainObject(permissionValue)) return

  for (const [pattern, permission] of Object.entries(permissionValue)) {
    if (pattern === "*" || permission !== "allow") continue
    patterns.add(pattern)
  }
}

function mergePermissionValues(existing, next) {
  if (existing === undefined) return cloneJson(next)
  if (next === undefined) return cloneJson(existing)
  if (existing === "allow" || next === "allow") return "allow"

  const allowPatterns = new Set()
  collectAllowedPermissionPatterns(existing, allowPatterns)
  collectAllowedPermissionPatterns(next, allowPatterns)

  if (allowPatterns.size === 0) {
    return "deny"
  }

  const merged = { "*": "deny" }
  for (const pattern of allowPatterns) {
    merged[pattern] = "allow"
  }
  return merged
}

function permissionValueHasAllowance(permissionValue) {
  if (permissionValue === "allow") return true
  if (!isPlainObject(permissionValue)) return false

  return Object.entries(permissionValue)
    .some(([pattern, permission]) => pattern !== "*" && permission === "allow")
}

function stripLegacyPermissionValue(baseValue, previousValue) {
  if (baseValue === undefined) return undefined
  if (previousValue === undefined) return cloneJson(baseValue)

  // Broad legacy allows cannot be attributed safely, so do not carry them
  // forward when we are subtracting a reinstalling plugin from the base config.
  if (baseValue === "allow") {
    return undefined
  }
  if (!isPlainObject(baseValue)) {
    return undefined
  }
  if (!isPlainObject(previousValue)) {
    return cloneJson(baseValue)
  }

  const remaining = {}
  if (baseValue["*"] === "deny") {
    remaining["*"] = "deny"
  }

  const removedPatterns = new Set()
  collectAllowedPermissionPatterns(previousValue, removedPatterns)

  for (const [pattern, permission] of Object.entries(baseValue)) {
    if (pattern === "*" || permission !== "allow" || removedPatterns.has(pattern)) {
      continue
    }
    remaining[pattern] = "allow"
  }

  return permissionValueHasAllowance(remaining) ? remaining : undefined
}

function buildToolStateFromPermissionConfig(permissionEntries) {
  const tools = {}
  const permission = {}

  for (const tool of SOURCE_TOOLS) {
    const value = permissionEntries[tool]
    permission[tool] = value === undefined ? "deny" : cloneJson(value)
    tools[tool] = permissionValueHasAllowance(permission[tool])
  }

  return { tools, permission }
}

function combineOpenCodeConfigs(configs) {
  const combined = {
    $schema: "https://opencode.ai/config.json",
  }
  const command = {}
  const mcp = {}
  const tools = {}
  const permission = {}

  for (const rawConfig of configs) {
    const config = sanitizeInstallConfig(rawConfig)

    if (isPlainObject(config.command)) {
      Object.assign(command, cloneJson(config.command))
    }
    if (isPlainObject(config.mcp)) {
      Object.assign(mcp, cloneJson(config.mcp))
    }
    if (isPlainObject(config.tools)) {
      for (const [tool, enabled] of Object.entries(config.tools)) {
        tools[tool] = Boolean(tools[tool] || enabled)
      }
    }
    if (isPlainObject(config.permission)) {
      for (const [tool, permissionValue] of Object.entries(config.permission)) {
        permission[tool] = mergePermissionValues(permission[tool], permissionValue)
      }
    }
  }

  if (Object.keys(command).length > 0) {
    combined.command = command
  }
  if (Object.keys(mcp).length > 0) {
    combined.mcp = mcp
  }
  if (Object.keys(tools).length > 0) {
    combined.tools = tools
  }
  if (Object.keys(permission).length > 0) {
    combined.permission = permission
  }

  return combined
}

function buildOpenCodePluginConfig(commands, bundleConfig, permissionsMode) {
  const sanitizedBundleConfig = sanitizeInstallConfig(bundleConfig)
  const command = convertCommands(commands)
  const config = {
    $schema: bundleConfig?.$schema ?? "https://opencode.ai/config.json",
    command: Object.keys(command).length > 0 ? command : undefined,
    mcp: sanitizedBundleConfig.mcp,
  }

  applyPermissions(config, commands, permissionsMode)
  return config
}

function filterConfiguredCommands(commandConfig, visibleCommandNames) {
  if (!isPlainObject(commandConfig) || visibleCommandNames.size === 0) return undefined

  const filtered = {}
  for (const [name, command] of Object.entries(commandConfig)) {
    if (visibleCommandNames.has(normalizeName(name))) {
      filtered[name] = cloneJson(command)
    }
  }

  return Object.keys(filtered).length > 0 ? filtered : undefined
}

function hasCompleteVisibleConfiguredCommands(record, visibleCommandNames) {
  const configuredCommandNames = Object.keys(record.config.command ?? {})
    .map((name) => normalizeName(name))

  if (configuredCommandNames.length === 0) return true
  return configuredCommandNames.every((name) => visibleCommandNames.has(name))
}

function buildStoredOpenCodeTargetConfig(targetState, visibleCommandNames) {
  const record = sanitizeInstallRecord(targetState)
  const config = {}

  if (isPlainObject(record.config.mcp) && Object.keys(record.config.mcp).length > 0) {
    config.mcp = cloneJson(record.config.mcp)
  }

  if (visibleCommandNames.size === 0) {
    return config
  }

  const visibleCommands = record.commands
    .filter((command) => visibleCommandNames.has(normalizeName(command.name)))

  if (visibleCommands.length > 0) {
    config.command = convertCommands(visibleCommands)
  } else {
    const filteredCommands = filterConfiguredCommands(record.config.command, visibleCommandNames)
    if (filteredCommands) {
      config.command = filteredCommands
    }
  }

  if (visibleCommands.length > 0 && record.permissionsMode) {
    applyPermissions(config, visibleCommands, record.permissionsMode)
    return config
  }

  const canReuseStoredPermissions = hasCompleteVisibleConfiguredCommands(record, visibleCommandNames)

  if (canReuseStoredPermissions && isPlainObject(record.config.tools) && Object.keys(record.config.tools).length > 0) {
    config.tools = cloneJson(record.config.tools)
  }
  if (canReuseStoredPermissions && isPlainObject(record.config.permission) && Object.keys(record.config.permission).length > 0) {
    config.permission = cloneJson(record.config.permission)
  }

  return config
}

function getOpenCodeInstallTargets(state, preferredPluginName) {
  const targets = []

  let originalIndex = 0
  for (const [pluginName, pluginTargets] of Object.entries(state.plugins ?? {})) {
    if (!isPlainObject(pluginTargets)) continue
    const targetState = pluginTargets.opencode
    if (!isPlainObject(targetState)) continue
    targets.push({
      pluginName,
      targetState,
      preferred: pluginName === preferredPluginName,
      sortKey: sanitizeInstallTimestamp(targetState.updatedAtMs) ?? 0,
      originalIndex,
    })
    originalIndex += 1
  }

  targets.sort((left, right) => {
    if (left.preferred !== right.preferred) {
      return left.preferred ? 1 : -1
    }
    if (left.sortKey !== right.sortKey) {
      return left.sortKey - right.sortKey
    }
    if (left.originalIndex !== right.originalIndex) {
      return left.originalIndex - right.originalIndex
    }
    return left.pluginName.localeCompare(right.pluginName)
  })

  return targets
}

function getVisibleOpenCodeCommands(targets) {
  const visibleCommandNamesByPlugin = new Map()
  const seen = new Set()

  for (let index = targets.length - 1; index >= 0; index -= 1) {
    const target = targets[index]
    const record = sanitizeInstallRecord(target.targetState)
    const visibleCommandNames = new Set()
    const knownCommands = record.commands.length > 0
      ? record.commands.map((command) => command.name)
      : Object.keys(record.config.command ?? {})

    for (const commandName of knownCommands) {
      const normalizedName = normalizeName(commandName)
      if (seen.has(normalizedName)) continue
      visibleCommandNames.add(normalizedName)
      seen.add(normalizedName)
    }

    visibleCommandNamesByPlugin.set(target.pluginName, visibleCommandNames)
  }

  return visibleCommandNamesByPlugin
}

function needsLegacyOpenCodeBase(state, preferredPluginName) {
  return getOpenCodeInstallTargets(state, preferredPluginName)
    .some(({ pluginName, targetState }) => pluginName !== preferredPluginName && !hasStoredOpenCodeConfig(targetState))
}

function normalizeCommandMatcherName(commandName) {
  return String(commandName ?? "").trim().toLowerCase()
}

function deriveCommandFamilyPrefix(commandName) {
  const normalizedName = normalizeCommandMatcherName(commandName)
  const firstSeparator = normalizedName.indexOf(":")
  const lastSeparator = normalizedName.lastIndexOf(":")
  if (firstSeparator <= 0 || lastSeparator <= firstSeparator) {
    return undefined
  }
  return normalizedName.slice(0, lastSeparator + 1)
}

function buildLegacyPreferredCommandMatchers(previousPreferredConfig, previousPreferredEntries, currentPreferredCommands) {
  const previousConfig = sanitizeInstallConfig(previousPreferredConfig)
  const previousEntries = sanitizeInstallRecord(previousPreferredEntries)
  const currentCommands = sanitizeStoredCommands(currentPreferredCommands)
  const exactNames = new Set()
  const familyPrefixes = new Set()

  for (const commandName of Object.keys(previousConfig.command ?? {})) {
    exactNames.add(normalizeName(commandName))
  }
  for (const command of previousEntries.commands) {
    exactNames.add(normalizeName(command.name))
    const familyPrefix = deriveCommandFamilyPrefix(command.name)
    if (familyPrefix) {
      familyPrefixes.add(familyPrefix)
    }
  }
  for (const skillName of previousEntries.skills) {
    exactNames.add(normalizeName(skillName))
    const familyPrefix = deriveCommandFamilyPrefix(skillName)
    if (familyPrefix) {
      familyPrefixes.add(familyPrefix)
    }
  }
  for (const command of currentCommands) {
    const familyPrefix = deriveCommandFamilyPrefix(command.name)
    if (familyPrefix) {
      familyPrefixes.add(familyPrefix)
    }
  }

  return { exactNames, familyPrefixes }
}

function shouldStripLegacyPreferredCommand(commandName, matchers) {
  const normalizedName = normalizeName(commandName)
  const matcherName = normalizeCommandMatcherName(commandName)
  if (matchers.exactNames.has(normalizedName)) {
    return true
  }

  for (const familyPrefix of matchers.familyPrefixes) {
    if (matcherName.startsWith(familyPrefix)) {
      return true
    }
  }

  return false
}

function removeLegacyPreferredEntries(baseConfig, options = {}) {
  const filtered = sanitizeInstallConfig(baseConfig)
  const previous = sanitizeInstallConfig(options.previousPreferredConfig)
  const commandMatchers = buildLegacyPreferredCommandMatchers(
    options.previousPreferredConfig,
    options.previousPreferredEntries,
    options.currentPreferredCommands,
  )

  if (isPlainObject(filtered.command)) {
    for (const commandName of Object.keys(filtered.command)) {
      if (!shouldStripLegacyPreferredCommand(commandName, commandMatchers)) {
        continue
      }
      delete filtered.command[commandName]
    }
  }

  for (const serverName of Object.keys(previous.mcp ?? {})) {
    if (isPlainObject(filtered.mcp)) {
      delete filtered.mcp[serverName]
    }
  }

  const previousHadPermissionState =
    Object.keys(previous.command ?? {}).length > 0
    || Object.keys(previous.tools ?? {}).length > 0
    || Object.keys(previous.permission ?? {}).length > 0
  if (previousHadPermissionState) {
    const remainingPermissions = {}
    for (const tool of SOURCE_TOOLS) {
      const nextValue = stripLegacyPermissionValue(filtered.permission?.[tool], previous.permission?.[tool])
      if (nextValue !== undefined) {
        remainingPermissions[tool] = nextValue
      }
    }

    if (Object.keys(remainingPermissions).length === 0) {
      delete filtered.tools
      delete filtered.permission
    } else {
      const normalizedPermissions = buildToolStateFromPermissionConfig(remainingPermissions)
      filtered.tools = normalizedPermissions.tools
      filtered.permission = normalizedPermissions.permission
    }
  }

  return sanitizeInstallConfig(filtered)
}

function buildCombinedOpenCodeConfigFromState(state, options = {}) {
  const preferredPluginName = typeof options === "string" ? options : options.preferredPluginName
  const legacyBaseConfig = typeof options === "string" ? undefined : options.legacyBaseConfig
  const previousPreferredConfig = typeof options === "string" ? undefined : options.previousPreferredConfig
  const previousPreferredEntries = typeof options === "string" ? undefined : options.previousPreferredEntries
  const currentPreferredCommands = typeof options === "string" ? undefined : options.currentPreferredCommands
  const configs = []
  const targets = getOpenCodeInstallTargets(state, preferredPluginName)
  const visibleCommandNamesByPlugin = getVisibleOpenCodeCommands(targets)

  const filteredLegacyBaseConfig = removeLegacyPreferredEntries(legacyBaseConfig, {
    previousPreferredConfig,
    previousPreferredEntries,
    currentPreferredCommands,
  })
  if (Object.keys(filteredLegacyBaseConfig).length > 0) {
    configs.push(filteredLegacyBaseConfig)
  }

  for (const { pluginName, targetState } of targets) {
    const config = buildStoredOpenCodeTargetConfig(
      targetState,
      visibleCommandNamesByPlugin.get(pluginName) ?? new Set(),
    )
    if (Object.keys(config).length > 0) {
      configs.push(config)
    }
  }

  return combineOpenCodeConfigs(configs)
}

async function loadExistingOpenCodeConfig(configPathOrPaths) {
  const configPaths = Array.isArray(configPathOrPaths)
    ? configPathOrPaths
    : [configPathOrPaths]
  const configs = []

  for (const configPath of Array.from(new Set(configPaths.map((value) => path.resolve(value))))) {
    if (!(await pathExists(configPath))) continue

    try {
      configs.push(sanitizeInstallConfig(await readJson(configPath)))
    } catch {
      // Ignore invalid config candidates and keep searching.
    }
  }

  return configs.length > 0 ? combineOpenCodeConfigs(configs) : {}
}
async function writeJson(file, data) {
  const content = JSON.stringify(data, null, 2) + "\n"
  await writeText(file, content)
}

async function ensureDir(dir) {
  await fs.mkdir(dir, { recursive: true })
}

async function pathExists(filePath) {
  try {
    await fs.access(filePath)
    return true
  } catch {
    return false
  }
}

async function copyDir(sourceDir, targetDir) {
  await ensureDir(targetDir)
  const entries = await fs.readdir(sourceDir, { withFileTypes: true })
  for (const entry of entries) {
    const sourcePath = path.join(sourceDir, entry.name)
    const targetPath = path.join(targetDir, entry.name)
    if (entry.isDirectory()) {
      await copyDir(sourcePath, targetPath)
    } else if (entry.isFile()) {
      await ensureDir(path.dirname(targetPath))
      await fs.copyFile(sourcePath, targetPath)
    }
  }
}

async function bootstrapHookScripts(rootDir, bundleRootDir = path.dirname(rootDir)) {
  if (!(await pathExists(rootDir))) return

  const bootstrapMarker = "# kramme hook bundle bootstrap"
  const entries = await fs.readdir(rootDir, { withFileTypes: true })
  for (const entry of entries) {
    const fullPath = path.join(rootDir, entry.name)
    if (entry.isDirectory()) {
      await bootstrapHookScripts(fullPath, bundleRootDir)
      continue
    }
    if (!entry.isFile() || path.extname(entry.name) !== ".sh") {
      continue
    }

    const scriptDir = path.dirname(fullPath)
    const relativePluginRoot = (path.relative(scriptDir, bundleRootDir) || ".")
      .split(path.sep)
      .join("/")
    const bootstrapLines = [
      `${bootstrapMarker} start`,
      'if [ -z "${CLAUDE_PLUGIN_ROOT:-}" ]; then',
      '  _claude_hook_source="${BASH_SOURCE:-$0}"',
      '  _claude_hook_dir="$(CDPATH= cd -- "$(dirname -- "$_claude_hook_source")" && pwd)"',
      `  CLAUDE_PLUGIN_ROOT="$(CDPATH= cd -- "$_claude_hook_dir/${relativePluginRoot}" && pwd)"`,
      'fi',
      'export CLAUDE_PLUGIN_ROOT',
      'unset _claude_hook_source _claude_hook_dir',
      `${bootstrapMarker} end`,
    ]
    const source = await readText(fullPath)
    if (source.includes(bootstrapMarker)) continue

    const lineEnding = source.includes("\r\n") ? "\r\n" : "\n"
    const lines = source.split(/\r?\n/)
    const insertIndex = lines[0]?.startsWith("#!") ? 1 : 0
    lines.splice(insertIndex, 0, ...bootstrapLines)
    await writeText(fullPath, lines.join(lineEnding))
  }
}

async function rewriteCodexMarkdownResourcesFromSource(sourceDir, targetDir, knownCommands) {
  const entries = await fs.readdir(sourceDir, { withFileTypes: true })
  for (const entry of entries) {
    const sourcePath = path.join(sourceDir, entry.name)
    const targetPath = path.join(targetDir, entry.name)
    if (entry.isDirectory()) {
      await rewriteCodexMarkdownResourcesFromSource(sourcePath, targetPath, knownCommands)
      continue
    }
    if (!entry.isFile() || path.extname(entry.name) !== ".md" || entry.name === "SKILL.md") {
      continue
    }
    const source = await readText(targetPath)
    const transformed = transformContentForCodex(source, { knownCommands })
    if (transformed !== source) {
      await writeText(targetPath, transformed)
    }
  }
}

async function cleanupKrammeComponents(
  dir,
  { label, filter, recursive = false, prefixes = ["kramme:", "kramme-"], confirmOptions = {} } = {},
) {
  if (!(await pathExists(dir))) return
  const entries = await fs.readdir(dir, { withFileTypes: true })
  const matched = entries
    .filter(filter)
    .filter((entry) => prefixes.some((prefix) => entry.name.startsWith(prefix)))
    .map((entry) => entry.name)

  if (matched.length === 0) return

  console.log(`\nFound ${matched.length} existing kramme ${label}(s) in ${dir}:`)
  for (const name of matched) {
    console.log(`  - ${name}`)
  }

  const confirmed = await confirm(`Delete these ${label}s before installing?`, confirmOptions)
  if (!confirmed) {
    console.log(`Skipping ${label} cleanup.`)
    return
  }

  for (const name of matched) {
    await fs.rm(path.join(dir, name), { recursive, force: true })
  }
  console.log(`Deleted ${matched.length} ${label}(s).`)
}

async function cleanupInstalledEntries(
  dir,
  entries,
  { label, recursive = false, confirmOptions = {} } = {},
) {
  const matched = []
  for (const entry of sanitizeEntryList(entries)) {
    const targetPath = resolveManagedChild(dir, entry, `${label} entry`)
    if (await pathExists(targetPath)) {
      matched.push({ name: entry, path: targetPath })
    }
  }

  if (matched.length === 0) return true

  console.log(`\nFound ${matched.length} existing ${label}(s) from this plugin in ${dir}:`)
  for (const { name } of matched) {
    console.log(`  - ${name}`)
  }

  const confirmed = await confirm(`Delete these ${label}s before installing?`, confirmOptions)
  if (!confirmed) {
    console.log(`Skipping ${label} cleanup.`)
    return false
  }

  for (const { path: targetPath } of matched) {
    await fs.rm(targetPath, { recursive, force: true })
  }
  console.log(`Deleted ${matched.length} ${label}(s).`)
  return true
}

let nonInteractiveReaderInitialized = false
let nonInteractiveInputBuffer = ""
let nonInteractiveStreamEnded = false
let nonInteractiveAnswerWaiter = null
let nonInteractiveFallbackAnswer

function parseConfirmationAnswer(answer) {
  const normalized = String(answer ?? "").trim().toLowerCase()
  return normalized === "y" || normalized === "yes"
}

function readLineFromNonInteractiveBuffer() {
  const newlineIndex = nonInteractiveInputBuffer.indexOf("\n")
  if (newlineIndex < 0) return null
  const rawLine = nonInteractiveInputBuffer.slice(0, newlineIndex)
  nonInteractiveInputBuffer = nonInteractiveInputBuffer.slice(newlineIndex + 1)
  return rawLine.endsWith("\r") ? rawLine.slice(0, -1) : rawLine
}

function setupNonInteractiveReader() {
  if (nonInteractiveReaderInitialized) return
  nonInteractiveReaderInitialized = true
  process.stdin.setEncoding("utf8")
  process.stdin.on("data", (chunk) => {
    nonInteractiveInputBuffer += chunk

    if (!nonInteractiveAnswerWaiter) {
      if (nonInteractiveInputBuffer.includes("\n")) {
        process.stdin.pause()
      }
      return
    }

    const line = readLineFromNonInteractiveBuffer()
    if (line === null) return

    const resolve = nonInteractiveAnswerWaiter
    nonInteractiveAnswerWaiter = null
    process.stdin.pause()
    resolve(line)
  })

  process.stdin.on("end", () => {
    nonInteractiveStreamEnded = true
    if (!nonInteractiveAnswerWaiter) return
    const resolve = nonInteractiveAnswerWaiter
    nonInteractiveAnswerWaiter = null
    const line = readLineFromNonInteractiveBuffer()
    if (line !== null) {
      resolve(line)
      return
    }
    const trailing = nonInteractiveInputBuffer
    nonInteractiveInputBuffer = ""
    if (trailing.length > 0) {
      resolve(trailing)
      return
    }
    resolve(undefined)
  })

  process.stdin.pause()
}

function readNonInteractiveConfirmationAnswer() {
  setupNonInteractiveReader()
  const queued = readLineFromNonInteractiveBuffer()
  if (queued !== null) {
    return Promise.resolve(queued)
  }
  if (nonInteractiveStreamEnded) {
    const trailing = nonInteractiveInputBuffer
    nonInteractiveInputBuffer = ""
    if (trailing.length > 0) {
      return Promise.resolve(trailing)
    }
    return Promise.resolve(undefined)
  }
  if (nonInteractiveAnswerWaiter) {
    throw new Error("Concurrent non-interactive confirmations are not supported.")
  }
  return new Promise((resolve) => {
    nonInteractiveAnswerWaiter = resolve
    process.stdin.resume()
  })
}

async function confirm(message, options = {}) {
  if (options.yes) {
    return true
  }

  if (options.nonInteractive) {
    console.log(`${message} [y/N] (non-interactive mode: defaulting to No)`)
    return false
  }

  if (!process.stdin.isTTY) {
    process.stdout.write(`${message} [y/N] `)
    const answer = await readNonInteractiveConfirmationAnswer()
    if (answer !== undefined) {
      nonInteractiveFallbackAnswer = answer
      return parseConfirmationAnswer(answer)
    }
    return parseConfirmationAnswer(nonInteractiveFallbackAnswer)
  }

  const rl = readline.createInterface({ input: process.stdin, output: process.stdout })
  return new Promise((resolve) => {
    rl.question(`${message} [y/N] `, (answer) => {
      rl.close()
      resolve(parseConfirmationAnswer(answer))
    })
  })
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error)
  process.exit(1)
})
