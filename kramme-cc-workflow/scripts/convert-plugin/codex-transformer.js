// @ts-check
"use strict";

const path = require("path");
const {
  rewriteAskUserQuestionCodeBlocks,
} = require("./ask-user-question-parser");
const {
  codexName,
  formatFrontmatter,
  normalizeName,
  sanitizeDescription,
  uniqueName,
} = require("./frontmatter");
const {
  skillFrontmatterFieldByLoaderProperty,
} = require("../schemas/skill-contracts");

/**
 * @typedef {import("./contracts").ClaudeAgent} ClaudeAgent
 * @typedef {import("./contracts").ClaudeCommand} ClaudeCommand
 * @typedef {import("./contracts").ClaudeSkill} ClaudeSkill
 * @typedef {import("./contracts").ClaudePlugin} ClaudePlugin
 * @typedef {import("./contracts").CodexSkillFile} CodexSkillFile
 * @typedef {import("./contracts").CodexBundle} CodexBundle
 * @typedef {import("./contracts").CodexTransformOptions} CodexTransformOptions
 * @typedef {import("./contracts").JsonObject} JsonObject
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
const REQUIRED_HOOK_CONTROL_SKILLS = [
  "kramme:hooks:toggle",
  "kramme:hooks:configure-links",
];

/**
 * @param {ClaudeSkill[]} skills
 * @param {ClaudeCommand[]} commands
 * @param {string} platform
 */
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

/**
 * @param {ClaudePlugin} plugin
 * @returns {CodexBundle}
 */
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

  const agentSkillDefinitions = plugin.agents.map((agent) => ({
    agent,
    name: uniqueName(codexName(agent.name), usedSkillNames),
  }));
  const knownAgentSkills = buildKnownAgentSkillNames(agentSkillDefinitions);
  const agentSkills = agentSkillDefinitions.map(({ agent, name }) =>
    convertAgentSkill(agent, name, knownCommandNames, knownAgentSkills),
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
    codexPlugin: codexHookPluginFor(plugin, skills),
  };
}

function codexHookPluginFor(plugin, codexSkills) {
  if (!plugin.hooks) return undefined;
  if (!hasRequiredHookControlSkills(codexSkills)) return undefined;
  return convertCodexHookPlugin(plugin);
}

function hasRequiredHookControlSkills(skills) {
  const installedSkillNames = new Set(
    skills.map((skill) => normalizeName(skill.name)),
  );
  return REQUIRED_HOOK_CONTROL_SKILLS.every((skillName) =>
    installedSkillNames.has(normalizeName(skillName)),
  );
}

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
    sharedScriptDirs: [
      {
        sourceDir: path.join(plugin.root, "scripts", "dev-server"),
        targetDir: path.join("scripts", "dev-server"),
      },
    ],
    sharedScriptFiles: [
      {
        sourceFile: path.join(plugin.root, "scripts", "resolve-base.sh"),
        targetPath: path.join("scripts", "resolve-base.sh"),
      },
      {
        sourceFile: path.join(plugin.root, "scripts", "collect-review-diff.sh"),
        targetPath: path.join("scripts", "collect-review-diff.sh"),
      },
      {
        sourceFile: path.join(plugin.root, "scripts", "skill-usage.js"),
        targetPath: path.join("scripts", "skill-usage.js"),
      },
    ],
  };
}

/**
 * @param {ClaudeAgent} agent
 * @param {string} name
 * @param {Set<string>} knownCommands
 * @param {Map<string, string>} knownAgentSkills
 * @returns {CodexSkillFile}
 */
function convertAgentSkill(agent, name, knownCommands, knownAgentSkills) {
  const descriptionSource =
    agent.description == null
      ? `Converted from Claude agent ${agent.name}`
      : agent.description;
  const description = sanitizeDescription(
    transformAgentContentForCodex(descriptionSource, {
      knownCommands,
      knownAgentSkills,
    }),
  );
  const frontmatter = { name, description };

  let body = transformAgentContentForCodex(agent.body.trim(), {
    knownCommands,
    knownAgentSkills,
  });
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

function buildKnownAgentSkillNames(agentSkillDefinitions) {
  const knownAgentSkills = new Map();
  for (const { agent, name } of agentSkillDefinitions) {
    if (agent.sourcePath) {
      knownAgentSkills.set(
        codexName(path.basename(agent.sourcePath, ".md")),
        name,
      );
    }
  }
  for (const { agent, name } of agentSkillDefinitions) {
    knownAgentSkills.set(codexName(agent.name), name);
  }
  return knownAgentSkills;
}

function convertCommandSkill(command, knownCommands, name, knownAgentSkills) {
  const frontmatter = {
    name,
    description: sanitizeDescription(
      command.description ?? `Converted from Claude command ${command.name}`,
    ),
    [ARGUMENT_HINT_FIELD]: command.argumentHint,
    "allowed-tools":
      command.allowedTools && command.allowedTools.length > 0
        ? command.allowedTools
        : undefined,
    [DISABLE_MODEL_INVOCATION_FIELD]: command.disableModelInvocation,
    [USER_INVOCABLE_FIELD]: true,
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
    [ARGUMENT_HINT_FIELD]: skill.argumentHint,
    "allowed-tools":
      skill.allowedTools && skill.allowedTools.length > 0
        ? skill.allowedTools
        : undefined,
    [DISABLE_MODEL_INVOCATION_FIELD]: skill.disableModelInvocation,
    [USER_INVOCABLE_FIELD]: skill.userInvocable,
    [PLATFORMS_FIELD]:
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

/**
 * @param {string} body
 * @param {CodexTransformOptions} [options]
 * @returns {string}
 */
function transformContentForCodex(body, options = {}) {
  let result = body;
  result = rewriteTaskCalls(result, options.knownAgentSkills);
  result = rewriteSlashCommandReferences(result, options.knownCommands);
  result = rewriteAgentMentions(result, options.knownAgentSkills);
  result = rewriteCodexAgentFileReferences(result, options.knownAgentSkills);
  return normalizeCodexInstructionText(result);
}

function transformAgentContentForCodex(body, options) {
  const transformed = transformContentForCodex(body, options);
  if (!/`?CLAUDE\.md`?/.test(transformed)) return transformed;

  const instructionFiles =
    "`AGENTS.md`, `CLAUDE.md`, and closest nested equivalents";
  const claudeInstructionPattern =
    /`?CLAUDE\.md`?( conventions| or equivalent| violation| rule)?/g;

  return transformed.replace(
    claudeInstructionPattern,
    (match, modifier, offset) => {
      const currentClause =
        transformed
          .slice(0, offset)
          .split(/[\n!?;:]|\.(?!md\b)/i)
          .at(-1) ?? "";
      if (/`?AGENTS\.md`?/.test(currentClause)) return match;

      switch (modifier) {
        case " conventions":
          return `conventions from ${instructionFiles}`;
        case " or equivalent":
          return "`AGENTS.md`, `CLAUDE.md`, or closest nested equivalent";
        case " violation":
          return `violation of ${instructionFiles}`;
        case " rule":
          return `rule from ${instructionFiles}`;
        default:
          return instructionFiles;
      }
    },
  );
}

function rewriteTaskCalls(text, knownAgentSkills) {
  const taskPattern = /^(\s*-?\s*)Task\s+([a-z][a-z0-9-]*)\(([^)]+)\)/gm;
  return text.replace(taskPattern, (_match, prefix, agentName, args) => {
    const normalizedAgentName = codexName(agentName);
    const skillName =
      knownAgentSkills?.get(normalizedAgentName) ?? normalizedAgentName;
    const trimmedArgs = args.trim();
    return `${prefix}Use the $${skillName} skill to: ${trimmedArgs}`;
  });
}

function rewriteSlashCommandReferences(text, knownCommands) {
  const slashCommandPattern =
    /(?<![:\w])\/([a-z][a-z0-9_:-]*?)(?=[\s,.`"')\]}]|$)/gi;
  return text.replace(slashCommandPattern, (match, commandName) => {
    if (commandName.includes("/")) return match;
    if (
      ["dev", "tmp", "etc", "usr", "var", "bin", "home"].includes(commandName)
    )
      return match;
    const codexified = codexName(commandName);
    if (knownCommands && !knownCommands.has(codexified)) return match;
    return `$${codexified}`;
  });
}

function rewriteAgentMentions(text, knownAgentSkills) {
  const agentRefPattern =
    /@([a-z][a-z0-9-]*-(?:agent|reviewer|researcher|analyst|specialist|oracle|sentinel|guardian|strategist))/gi;
  return text.replace(agentRefPattern, (_match, agentName) => {
    const normalizedAgentName = codexName(agentName);
    const skillName =
      knownAgentSkills?.get(normalizedAgentName) ?? normalizedAgentName;
    return `$${skillName} skill`;
  });
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

/** @type {Array<[RegExp, string]>} */
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
  [/\bthe same `?AskUserQuestion`? prompt\b/g, "the same direct chat prompt"],
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
  [
    /\bMonitor task progress via `?TaskList`?(?=[\s.,:;)]|$)/g,
    "Monitor task progress with list_agents",
  ],
  [
    /\bMonitor `?TaskList`? for\b/g,
    "Monitor agent progress with list_agents for",
  ],
  [/\busing `?SendMessage`?(?=[\s.,:;)]|$)/g, "using send_message"],
  [/\bvia `?SendMessage`?(?=[\s.,:;)]|$)/g, "with send_message"],
  [/\bSendMessage tool\b/g, "send_message"],
  [/\bTaskList tool\b/g, "list_agents"],
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

/**
 * @param {JsonObject} value
 * @returns {JsonObject}
 */
function cloneJson(value) {
  return JSON.parse(JSON.stringify(value));
}

module.exports = {
  convertClaudeToCodex,
  transformContentForCodex,
};
