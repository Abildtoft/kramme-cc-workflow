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

export interface CodexSkillFile {
  name: string;
  content: string;
  sourceDir?: string;
}

export interface CodexSourceSkillFile extends CodexSkillFile {
  sourceDir: string;
}

/** The `.codex-plugin/plugin.json` manifest Codex reads from the built plugin. */
export interface CodexPluginManifest extends JsonObject {
  name: string;
  version: string;
  description: string;
  skills: string;
  hooks?: string;
  mcpServers?: CodexMcpServers;
  author?: unknown;
}

/**
 * The native Codex plugin package produced from one Claude plugin. Codex
 * installs it from the generated marketplace into
 * `<codex-home>/<cacheRelativePath>`; `rootExpression` is the shell expression
 * converted skills use to reach that directory.
 */
export interface CodexPluginPackage {
  name: string;
  marketplaceName: string;
  version: string;
  manifest: CodexPluginManifest;
  /** Present only when hook packaging is eligible. */
  hooks?: JsonObject;
  hookSourceDir: string;
  cacheRelativePath: string;
  rootExpression: string;
}

export interface SharedScriptDir {
  executableFiles?: string[];
  sourceDir: string;
  targetDir: string;
}

export interface SharedScriptFile {
  executable?: boolean;
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

export interface CodexBundle {
  sharedScriptDirs: SharedScriptDir[];
  sharedScriptFiles: SharedScriptFile[];
  skillDirs: CodexSourceSkillFile[];
  generatedSkills: CodexSkillFile[];
  agentSkills: CodexSkillFile[];
  knownCommands: Set<string>;
  knownAgentSkills: Map<string, string>;
  mcpServers?: CodexMcpServers;
  codexPlugin: CodexPluginPackage;
}

export interface CodexTransformOptions {
  knownCommands?: Set<string>;
  knownAgentSkills?: Map<string, string>;
}

export interface ConfirmOptions {
  yes?: boolean;
  nonInteractive?: boolean;
}
