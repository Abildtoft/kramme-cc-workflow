export type JsonObject = Record<string, unknown>;

export interface ClaudePluginManifest extends JsonObject {
  agents?: unknown;
  commands?: unknown;
  skills?: unknown;
  hooks?: unknown;
  mcpServers?: unknown;
  name?: unknown;
  version?: unknown;
  description?: unknown;
  author?: unknown;
}

export interface ClaudeAgent {
  name: unknown;
  description?: string;
  capabilities?: string[];
  model?: unknown;
  body: string;
  sourcePath?: string;
}

export interface ClaudeCommand {
  name: unknown;
  description?: unknown;
  argumentHint?: unknown;
  model?: unknown;
  allowedTools?: string[];
  disableModelInvocation?: unknown;
  body: string;
  sourcePath?: string;
}

export interface ClaudeSkill {
  name: string;
  description?: string;
  argumentHint?: string;
  model?: unknown;
  allowedTools?: string[];
  disableModelInvocation?: boolean;
  userInvocable?: boolean;
  platforms?: string[];
  body: string;
  sourceDir: string;
  skillPath?: string;
}

export interface ClaudePlugin {
  root: string;
  manifest: ClaudePluginManifest;
  agents: ClaudeAgent[];
  commands: ClaudeCommand[];
  skills: ClaudeSkill[];
  hooks?: JsonObject;
  mcpServers?: JsonObject;
}

export interface CodexPrompt {
  name: string;
  content: string;
}

export interface CodexSkillFile {
  name: string;
  content: string;
  sourceDir?: string;
}

export interface CodexHookManifest extends JsonObject {
  name: string;
  version: string;
  description: string;
  hooks: string;
  author?: unknown;
}

export interface CodexHookPlugin {
  name: string;
  marketplaceName: string;
  version: string;
  manifest: CodexHookManifest;
  hooks: JsonObject;
  hookSourceDir: string;
  sharedScriptDirs?: Array<{ sourceDir: string; targetDir: string }>;
  sharedScriptFiles?: Array<{ sourceFile: string; targetPath: string }>;
}

export interface CodexBundle {
  prompts: CodexPrompt[];
  skillDirs: CodexSkillFile[];
  generatedSkills: CodexSkillFile[];
  agentSkills: CodexSkillFile[];
  knownCommands: Set<string>;
  knownAgentSkills: Map<string, string>;
  mcpServers?: JsonObject;
  codexPlugin?: CodexHookPlugin;
}

export interface CodexTransformOptions {
  knownCommands?: Set<string>;
  knownAgentSkills?: Map<string, string>;
}

export interface WriteCodexOptions {
  pluginName?: string;
  agentsHome?: string;
  confirm?: {
    yes?: boolean;
    nonInteractive?: boolean;
  };
}
