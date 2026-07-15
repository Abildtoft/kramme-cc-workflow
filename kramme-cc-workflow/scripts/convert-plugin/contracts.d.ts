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
  mcpServers?: CodexMcpServers;
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

export interface CodexSourceSkillFile extends CodexSkillFile {
  sourceDir: string;
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
  sharedScriptDirs?: SharedScriptDir[];
  sharedScriptFiles?: SharedScriptFile[];
}

export interface SharedScriptDir {
  sourceDir: string;
  targetDir: string;
}

export interface SharedScriptFile {
  sourceFile: string;
  targetPath: string;
}

export interface CodexMcpServer extends JsonObject {
  command?: string;
  args?: string[];
  env?: Record<string, string>;
  url?: string;
  headers?: Record<string, string>;
}

export type CodexMcpServers = Record<string, CodexMcpServer>;

export type ManagedFileMap = Record<string, string[]>;

export interface InstallEntries {
  hookMarketplaces: string[];
  prompts: string[];
  pluginCaches: string[];
  skills: string[];
  skillFiles: ManagedFileMap;
  agentSkills: string[];
  agentSkillFiles: ManagedFileMap;
  updatedAtMs?: number;
}

export interface InstallState {
  version: 1;
  plugins: Record<string, Record<string, InstallEntries>>;
}

export interface HookTarget {
  finalRoot: string;
  overwriteExisting: boolean;
  stagedRoot: string;
}

export interface HookTargets {
  marketplace?: HookTarget;
  pluginCache?: HookTarget;
}

export type SharedScriptReplacement =
  | {
      sourcePrefix: string;
      targetPrefix: string;
      sourceText?: never;
      targetText?: never;
    }
  | {
      sourceText: string;
      targetText: string;
      sourcePrefix?: never;
      targetPrefix?: never;
    };

export interface CodexBundle {
  prompts: CodexPrompt[];
  skillDirs: CodexSourceSkillFile[];
  generatedSkills: CodexSkillFile[];
  agentSkills: CodexSkillFile[];
  knownCommands: Set<string>;
  knownAgentSkills: Map<string, string>;
  mcpServers?: CodexMcpServers;
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
