#!/usr/bin/env node
"use strict"

const fs = require("fs/promises")
const path = require("path")
const os = require("os")
const readline = require("readline")

const PERMISSION_MODES = ["none", "broad", "from-commands"]

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
  if (command !== "install") {
    console.error(`Unknown command: ${command}`)
    printHelp(1)
    return
  }

  const parsed = parseArgs(argv.slice(1))
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
  const outputRoot = resolveOutputRoot(parsed.output ?? parsed.o)
  const codexHome = resolveCodexRoot(parsed["codex-home"] ?? parsed.codexHome)
  const agentsHome = resolveAgentsRoot(parsed["agents-home"] ?? parsed.agentsHome)
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

  const primaryOutput = targetName === "codex" ? codexHome : outputRoot
  const writeOptions = {
    agentsHome,
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
    const extraRoot = extra === "codex" ? codexHome : path.join(outputRoot, extra)
    await handler.write(extraRoot, extraBundle, writeOptions)
    console.log(`Installed ${plugin.manifest.name} to ${extraRoot}`)
  }

  if (allTargets.includes("codex")) {
    await ensureCodexAgentsFile(codexHome)
  }
}

function printHelp(exitCode) {
  const help = `Usage: scripts/convert-plugin.js install <plugin-name|path> [options]

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

function resolveOutputRoot(value) {
  if (value && String(value).trim()) {
    const expanded = expandHome(String(value).trim())
    return path.resolve(expanded)
  }
  return path.join(os.homedir(), ".config", "opencode")
}

function resolveCodexRoot(value) {
  if (value && String(value).trim()) {
    const expanded = expandHome(String(value).trim())
    return path.resolve(expanded)
  }
  return path.join(os.homedir(), ".codex")
}

function resolveAgentsRoot(value) {
  if (value && String(value).trim()) {
    const expanded = expandHome(String(value).trim())
    return path.resolve(expanded)
  }
  return path.join(os.homedir(), ".agents")
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

  const rootCandidates = [process.cwd(), resolveScriptRoot()]
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
  const plugins = plugin.hooks ? [convertHooks(plugin.hooks)] : []

  const config = {
    $schema: "https://opencode.ai/config.json",
    command: Object.keys(commandMap).length > 0 ? commandMap : undefined,
    mcp: mcp && Object.keys(mcp).length > 0 ? mcp : undefined,
  }

  applyPermissions(config, commands, options.permissions)

  return {
    config,
    agents: agentFiles,
    plugins,
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

function convertHooks(hooks) {
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

  const content = `${unmappedComment}import type { Plugin } from "@opencode-ai/plugin"\n\nexport const ConvertedHooks: Plugin = async ({ $ }) => {\n  return {\n${handlerBlocks.join(",\n")}\n  }\n}\n\nexport default ConvertedHooks\n`

  return {
    name: "converted-hooks.ts",
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
      const escapedCommand = escapeTemplateLiteral(String(hook.command ?? ""))
      if (condition) {
        statements.push(`if (${condition}) { await $\`${escapedCommand}\` }`)
      } else {
        statements.push(`await $\`${escapedCommand}\``)
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

  const sourceTools = [
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
  let enabled = new Set()
  const patterns = {}
  let hasAllowedToolsDeclaration = false

  if (mode === "broad") {
    enabled = new Set(sourceTools)
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
      enabled = new Set(sourceTools)
    }
  }

  const permission = {}
  const tools = {}

  for (const tool of sourceTools) {
    tools[tool] = mode === "broad" ? true : enabled.has(tool)
  }

  if (mode === "broad") {
    for (const tool of sourceTools) {
      permission[tool] = "allow"
    }
  } else {
    for (const tool of sourceTools) {
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

function convertClaudeToCodex(plugin, options) {
  const { skills, commands } = filterByPlatform(plugin.skills, plugin.commands, "codex")
  const skillDirs = skills
    .filter((skill) => skill.userInvocable === false)
    .map((skill) => ({ name: skill.name, sourceDir: skill.sourceDir }))

  const usedSkillNames = new Set(skillDirs.map((skill) => codexName(skill.name)))
  const knownCommandNames = new Set()
  const commandSkills = commands.map((command) => {
    const skillName = uniqueName(codexName(command.name), usedSkillNames)
    knownCommandNames.add(skillName)
    return convertCommandSkill(command, knownCommandNames, skillName)
  })

  const agentSkills = plugin.agents.map((agent) => convertAgentSkill(agent, usedSkillNames))

  return {
    prompts: [],
    skillDirs,
    generatedSkills: commandSkills,
    agentSkills,
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
    "disable-model-invocation": command.disableModelInvocation,
  }
  const sections = []
  if (command.allowedTools && command.allowedTools.length > 0) {
    sections.push(`## Allowed tools\n${command.allowedTools.map((tool) => `- ${tool}`).join("\n")}`)
  }
  const transformedBody = transformContentForCodex(command.body.trim(), { knownCommands })
  sections.push(transformedBody)
  const body = sections.filter(Boolean).join("\n\n").trim()
  const content = formatFrontmatter(frontmatter, body.length > 0 ? body : command.body)
  return { name, content }
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

  const slashCommandPattern = /(?<![:\w])\/([a-z][a-z0-9_:-]*?)(?=[\s,."')\]}]|$)/gi
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

  return result
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

async function writeOpenCodeBundle(outputRoot, bundle, extraOpts = {}) {
  const paths = resolveOpenCodePaths(outputRoot)
  await ensureDir(paths.root)
  await writeJson(paths.configPath, bundle.config)

  const agentsDir = paths.agentsDir
  if (bundle.agents.length > 0) {
    await cleanupKrammeAgents(agentsDir, extraOpts.confirm)
  }
  for (const agent of bundle.agents) {
    await writeText(path.join(agentsDir, `${agent.name}.md`), agent.content + "\n")
  }

  if (bundle.plugins.length > 0) {
    const pluginsDir = paths.pluginsDir
    for (const plugin of bundle.plugins) {
      await writeText(path.join(pluginsDir, plugin.name), plugin.content + "\n")
    }
  }

  if (bundle.skillDirs.length > 0) {
    const skillsRoot = paths.skillsDir
    await cleanupKrammeSkills(skillsRoot, extraOpts.confirm)
    for (const skill of bundle.skillDirs) {
      await copyDir(skill.sourceDir, path.join(skillsRoot, skill.name))
    }
  }
}

function resolveOpenCodePaths(outputRoot) {
  const base = path.basename(outputRoot)
  if (base === "opencode" || base === ".opencode") {
    return {
      root: outputRoot,
      configPath: path.join(outputRoot, "opencode.json"),
      agentsDir: path.join(outputRoot, "agents"),
      pluginsDir: path.join(outputRoot, "plugins"),
      skillsDir: path.join(outputRoot, "skills"),
    }
  }

  return {
    root: outputRoot,
    configPath: path.join(outputRoot, "opencode.json"),
    agentsDir: path.join(outputRoot, ".opencode", "agents"),
    pluginsDir: path.join(outputRoot, ".opencode", "plugins"),
    skillsDir: path.join(outputRoot, ".opencode", "skills"),
  }
}

async function writeCodexBundle(outputRoot, bundle, extraOpts = {}) {
  const codexRoot = resolveCodexOutputRoot(outputRoot)
  await ensureDir(codexRoot)

  const promptsDir = path.join(codexRoot, "prompts")
  await cleanupKrammePrompts(promptsDir, extraOpts.confirm)
  for (const prompt of bundle.prompts) {
    await writeText(path.join(promptsDir, `${prompt.name}.md`), prompt.content + "\n")
  }

  const skillsRoot = path.join(codexRoot, "skills")
  await cleanupKrammeSkills(skillsRoot, extraOpts.confirm, ["kramme:", "kramme-", "impl-"])

  for (const skill of bundle.skillDirs) {
    await copyDir(skill.sourceDir, path.join(skillsRoot, skill.name))
  }

  for (const skill of bundle.generatedSkills) {
    await writeText(path.join(skillsRoot, skill.name, "SKILL.md"), skill.content + "\n")
  }

  if (bundle.agentSkills) {
    const agentsHome = extraOpts.agentsHome ?? path.join(os.homedir(), ".agents")
    const agentSkillsRoot = path.join(agentsHome, "skills")
    await cleanupKrammeSkills(agentSkillsRoot, extraOpts.confirm)
    for (const skill of bundle.agentSkills) {
      await writeText(path.join(agentSkillsRoot, skill.name, "SKILL.md"), skill.content + "\n")
    }
  }

  const config = renderCodexConfig(bundle.mcpServers)
  if (config) {
    await writeText(path.join(codexRoot, "config.toml"), config)
  }
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
- Task/Subagent/Parallel: run sequentially in main thread; use multi_tool_use.parallel for tool calls
- TodoWrite/TodoRead: use file-based todos in todos/ with file-todos skill
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

async function cleanupKrammeAgents(agentsDir, confirmOptions = {}) {
  if (!(await pathExists(agentsDir))) return
  const entries = await fs.readdir(agentsDir, { withFileTypes: true })
  const krammeAgents = entries
    .filter((entry) => entry.isFile() && entry.name.endsWith(".md"))
    .filter((entry) => entry.name.startsWith("kramme:") || entry.name.startsWith("kramme-"))
    .map((entry) => entry.name)

  if (krammeAgents.length === 0) return

  console.log(`\nFound ${krammeAgents.length} existing kramme agent(s) in ${agentsDir}:`)
  for (const name of krammeAgents) {
    console.log(`  - ${name}`)
  }

  const confirmed = await confirm("Delete these agents before installing?", confirmOptions)
  if (!confirmed) {
    console.log("Skipping agent cleanup.")
    return
  }

  for (const name of krammeAgents) {
    const targetPath = path.join(agentsDir, name)
    await fs.rm(targetPath, { force: true })
  }
  console.log(`Deleted ${krammeAgents.length} agent(s).`)
}

async function cleanupKrammePrompts(promptsDir, confirmOptions = {}) {
  if (!(await pathExists(promptsDir))) return
  const entries = await fs.readdir(promptsDir, { withFileTypes: true })
  const krammePrompts = entries
    .filter((entry) => entry.isFile() && entry.name.endsWith(".md"))
    .filter((entry) => entry.name.startsWith("kramme:") || entry.name.startsWith("kramme-"))
    .map((entry) => entry.name)

  if (krammePrompts.length === 0) return

  console.log(`\nFound ${krammePrompts.length} existing kramme prompt(s) in ${promptsDir}:`)
  for (const name of krammePrompts) {
    console.log(`  - ${name}`)
  }

  const confirmed = await confirm("Delete these prompts before installing?", confirmOptions)
  if (!confirmed) {
    console.log("Skipping prompt cleanup.")
    return
  }

  for (const name of krammePrompts) {
    const targetPath = path.join(promptsDir, name)
    await fs.rm(targetPath, { force: true })
  }
  console.log(`Deleted ${krammePrompts.length} prompt(s).`)
}

async function cleanupKrammeSkills(
  skillsDir,
  confirmOptions = {},
  managedPrefixes = ["kramme:", "kramme-"],
) {
  if (!(await pathExists(skillsDir))) return
  const entries = await fs.readdir(skillsDir, { withFileTypes: true })
  const krammeSkills = entries
    .filter((entry) => entry.isDirectory())
    .filter((entry) => managedPrefixes.some((prefix) => entry.name.startsWith(prefix)))
    .map((entry) => entry.name)

  if (krammeSkills.length === 0) return

  console.log(`\nFound ${krammeSkills.length} existing kramme skill(s) in ${skillsDir}:`)
  for (const name of krammeSkills) {
    console.log(`  - ${name}`)
  }

  const confirmed = await confirm("Delete these skills before installing?", confirmOptions)
  if (!confirmed) {
    console.log("Skipping skill cleanup.")
    return
  }

  for (const name of krammeSkills) {
    const targetPath = path.join(skillsDir, name)
    await fs.rm(targetPath, { recursive: true, force: true })
  }
  console.log(`Deleted ${krammeSkills.length} skill(s).`)
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
