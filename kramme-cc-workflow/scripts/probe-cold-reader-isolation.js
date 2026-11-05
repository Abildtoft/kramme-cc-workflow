#!/usr/bin/env node
// @ts-check
"use strict";

// Live check of the trackbed:cold-reader isolation contract. Each variant runs a
// short Agent SDK session that loads this plugin in a throwaway workspace whose
// CLAUDE.md and imported AGENTS.md hold random markers, then inspects what the
// launched subagent could see. It runs the `claude` on PATH, because the promise
// under test belongs to the installed host rather than the SDK's bundled copy.
// It spends model usage, so it runs only on demand.

const crypto = require("node:crypto");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

/** @typedef {import('@anthropic-ai/claude-agent-sdk').Options} SDKOptions */
/** @typedef {AsyncIterable<unknown> & {close?: () => void}} Query */
/** @typedef {(args: {prompt: string, options: SDKOptions}) => Query} QueryFunction */
/** @typedef {"isolated" | "control" | "unreadable"} Variant */
/** @typedef {{project: string, imported: string, parent: string, content: string}} Markers */
/** @typedef {{workspace: string, inputFile: string}} Workspace */
/** @typedef {{model: string, env: NodeJS.ProcessEnv, claudePath?: string, onStderr?: (text: string) => void}} SessionConfig */
/** @typedef {{variant: Variant, agent: string, version: string | null, passed: boolean, answer: string | null, problems: string[]}} VariantResult */

const PLUGIN_ROOT = path.resolve(__dirname, "..");
const PLUGIN_NAME = "trackbed";
const COLD_READER = `${PLUGIN_NAME}:cold-reader`;
const CONTROL_AGENT = "general-purpose";
/** @type {Variant[]} */
const VARIANTS = ["isolated", "control", "unreadable"];
const DEFAULT_MODEL = "sonnet";
const AGENT_TOOLS = new Set(["Agent", "Task"]);
const MARKER_PROBE = [
  "Isolation probe. Do not use any tools.",
  "Look only at what is already in your context: your instructions, any instruction files loaded for you, and this message.",
  "Reply with every string you can see that starts with MARKER_ followed by exactly 32 lowercase hexadecimal digits, one per line.",
  "If you see none, reply with exactly UNKNOWN. Do not guess.",
].join(" ");
const STDERR_TAIL = 500;
const USAGE = `Usage: probe-cold-reader-isolation.js [--model <model>] [--variant ${VARIANTS.join("|")}] [--claude-path <path>]`;

/** @param {() => string} [random] @returns {Markers} */
function createMarkers(random = () => crypto.randomBytes(16).toString("hex")) {
  return {
    project: `MARKER_${random()}`,
    imported: `MARKER_${random()}`,
    parent: `MARKER_${random()}`,
    content: `CONTENT_${random()}`,
  };
}

/** @param {string} root @param {Markers} markers @returns {Workspace} */
function stageWorkspace(root, markers) {
  const workspace = fs.realpathSync(
    fs.mkdtempSync(path.join(root, "cold-reader-probe-")),
  );
  fs.writeFileSync(
    path.join(workspace, "CLAUDE.md"),
    `# Probe project\n\nProject marker: ${markers.project}\n\n@AGENTS.md\n`,
  );
  fs.writeFileSync(
    path.join(workspace, "AGENTS.md"),
    `# Probe instructions\n\nImported marker: ${markers.imported}\n`,
  );
  const inputFile = path.join(workspace, "probe-input.md");
  fs.writeFileSync(inputFile, `${markers.content}\n`);
  return { workspace, inputFile };
}

/** @param {Variant} variant */
function agentFor(variant) {
  return variant === "control" ? CONTROL_AGENT : COLD_READER;
}

/** @param {Variant} variant @param {Workspace} staged */
function childPrompt(variant, staged) {
  return variant === "unreadable"
    ? `Read the file ${staged.inputFile} and reply with its first line only.`
    : MARKER_PROBE;
}

/** @param {Variant} variant @param {Markers} markers @param {Workspace} staged */
function parentPrompt(variant, markers, staged) {
  return [
    "This is an automated isolation probe, not a review. Use only the Agent tool, exactly once.",
    `Parent-only marker: ${markers.parent}. Never repeat it, write it, or pass it to any agent.`,
    `Launch one new agent with subagent_type "${agentFor(variant)}" (not a fork and not a resumed agent) and give it exactly the prompt between the dashed lines, with nothing added or removed:`,
    "-----",
    childPrompt(variant, staged),
    "-----",
    "When it returns, reply with its answer verbatim and nothing else.",
  ].join("\n");
}

/** @param {NodeJS.ProcessEnv} parent @returns {Record<string, string>} */
function childEnvironment(parent) {
  // The SDK replaces the subprocess environment, so pass only what the CLI
  // needs to run and authenticate; this also keeps nested-session markers out.
  /** @type {Record<string, string>} */
  const env = {
    PATH: parent.PATH || "/usr/bin:/bin",
    LANG: "en_US.UTF-8",
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC: "1",
    // Wait for the subagent within the turn, so one run yields one final result.
    CLAUDE_CODE_DISABLE_BACKGROUND_TASKS: "1",
  };
  for (const name of [
    "HOME",
    "USER",
    "TMPDIR",
    "ANTHROPIC_API_KEY",
    "ANTHROPIC_AUTH_TOKEN",
    "CLAUDE_CODE_OAUTH_TOKEN",
    "CLAUDE_CONFIG_DIR",
  ]) {
    const value = parent[name];
    if (value) env[name] = value;
  }
  return env;
}

/** @param {NodeJS.ProcessEnv} env @returns {string | undefined} */
function findClaude(env) {
  for (const directory of (env.PATH || "").split(path.delimiter)) {
    const candidate = path.join(directory, "claude");
    if (directory && fs.existsSync(candidate)) return candidate;
  }
  return undefined;
}

/**
 * @param {Variant} variant
 * @param {Workspace} staged
 * @param {SessionConfig} config
 * @returns {SDKOptions}
 */
function sessionOptions(variant, staged, config) {
  // Withhold file tools so a marker can only reach a subagent through its
  // startup context. Do not use a Read deny rule for this: it also stops
  // CLAUDE.md from loading, and every variant would then pass while testing
  // nothing. The control variant exists to catch exactly that.
  const unreadable = variant === "unreadable";
  return {
    cwd: staged.workspace,
    env: childEnvironment(config.env),
    model: config.model,
    ...(config.claudePath
      ? { pathToClaudeCodeExecutable: config.claudePath }
      : {}),
    plugins: [{ type: "local", path: PLUGIN_ROOT }],
    settingSources: ["project"],
    settings: {
      disableAllHooks: true,
      permissions: { deny: unreadable ? [`Read(/${staged.inputFile})`] : [] },
    },
    tools: unreadable ? ["Agent", "Read"] : ["Agent"],
    allowedTools: ["Agent"],
    mcpServers: {},
    strictMcpConfig: true,
    persistSession: false,
    permissionMode: "dontAsk",
    forwardSubagentText: true,
    maxTurns: 6,
    stderr: config.onStderr || (() => {}),
  };
}

/** @param {unknown} value @returns {Record<string, unknown>} */
function record(value) {
  return value && typeof value === "object" && !Array.isArray(value)
    ? /** @type {Record<string, unknown>} */ (value)
    : {};
}

/** @param {unknown} content @returns {Record<string, unknown>[]} */
function blocks(content) {
  return Array.isArray(content) ? content.map(record) : [];
}

/** @param {unknown} content @returns {string} */
function textOf(content) {
  if (typeof content === "string") return content;
  return blocks(content)
    .filter((block) => block.type === "text" && typeof block.text === "string")
    .map((block) => String(block.text))
    .join("\n");
}

/** @param {string} text @returns {string[]} */
function lines(text) {
  return text
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);
}

/**
 * @param {Variant} variant
 * @param {unknown[]} events
 * @param {Markers} markers
 * @param {Workspace} staged
 * @returns {VariantResult}
 */
function evaluate(variant, events, markers, staged) {
  const agent = agentFor(variant);
  /** @type {string[]} */ const problems = [];
  /** @type {Record<string, unknown>[]} */ const agentCalls = [];
  /** @type {string[]} */ const childTexts = [];
  /** @type {Map<string, Record<string, unknown>>} */ const childCalls =
    new Map();
  /** @type {Record<string, unknown>[]} */ const childResults = [];
  /** @type {Map<string, string>} */ const agentResults = new Map();
  /** @type {string | null} */ let version = null;
  let initialized = false;
  let succeeded = false;

  for (const raw of events) {
    const event = record(raw);
    const parent = event.parent_tool_use_id;
    const content = blocks(record(event.message).content);
    if (event.type === "system" && event.subtype === "init") {
      initialized = true;
      if (typeof event.claude_code_version === "string")
        version = event.claude_code_version;
      const plugins = Array.isArray(event.plugins)
        ? event.plugins.map((plugin) => record(plugin).name)
        : [];
      if (!plugins.includes(PLUGIN_NAME))
        problems.push(`plugin ${PLUGIN_NAME} did not load`);
      if (Array.isArray(event.plugin_errors) && event.plugin_errors.length > 0)
        problems.push("plugin reported load errors");
      if (Array.isArray(event.agents) && !event.agents.includes(agent))
        problems.push(`agent type ${agent} is not registered`);
    } else if (event.type === "assistant" && typeof parent === "string") {
      for (const block of content) {
        if (block.type === "text" && typeof block.text === "string")
          childTexts.push(block.text);
        if (block.type === "tool_use" && typeof block.id === "string")
          childCalls.set(block.id, block);
      }
    } else if (event.type === "assistant") {
      for (const block of content)
        if (block.type === "tool_use" && AGENT_TOOLS.has(String(block.name)))
          agentCalls.push(block);
    } else if (event.type === "user" && typeof parent === "string") {
      for (const block of content)
        if (block.type === "tool_result") childResults.push(block);
    } else if (event.type === "user") {
      for (const block of content)
        if (block.type === "tool_result")
          agentResults.set(String(block.tool_use_id), textOf(block.content));
    } else if (event.type === "result") {
      succeeded = event.subtype === "success" && !event.is_error;
    }
  }

  if (!initialized) problems.push("session never initialized");
  if (!succeeded) problems.push("session did not finish successfully");
  if (agentCalls.length !== 1)
    problems.push(`expected one agent launch, saw ${agentCalls.length}`);
  const call = agentCalls[0];
  const input = record(call?.input);
  const delegated = typeof input.prompt === "string" ? input.prompt : "";
  if (call && input.subagent_type !== agent)
    problems.push(
      `launched ${String(input.subagent_type)} instead of ${agent}`,
    );
  if (call && input.resume !== undefined)
    problems.push("resumed an earlier agent instead of starting a new one");
  if (call && delegated.trim() !== childPrompt(variant, staged))
    problems.push("parent changed the probe prompt; result is inconclusive");

  const result = call ? agentResults.get(String(call.id)) || "" : "";
  const answer = (childTexts.at(-1) || result).trim();
  const seen = [...childTexts, result].join("\n");
  const answerLines = lines(answer);

  if (seen.includes(markers.parent))
    problems.push("subagent saw the parent conversation");
  if (variant !== "unreadable" && childCalls.size > 0)
    problems.push(
      "subagent used a tool, so its answer does not show what it had at startup",
    );
  if (variant === "isolated") {
    if (seen.includes(markers.project) || seen.includes(markers.imported))
      problems.push("cold reader saw project instruction files");
    if (answer !== "UNKNOWN")
      problems.push("cold reader did not answer UNKNOWN");
  } else if (variant === "control") {
    if (
      !answerLines.includes(markers.project) ||
      !answerLines.includes(markers.imported)
    )
      problems.push(
        "control agent did not report both project markers; the probe cannot detect a leak",
      );
  } else {
    const reads = [...childCalls.values()].filter(
      (block) =>
        block.name === "Read" &&
        record(block.input).file_path === staged.inputFile,
    );
    if (reads.length === 0)
      problems.push("cold reader never tried to read the named file");
    if (childResults.some((block) => !block.is_error))
      problems.push("a subagent tool call succeeded despite the deny rules");
    if (seen.includes(markers.content))
      problems.push("cold reader returned content it should not have read");
    if (answerLines[0] !== `UNREADABLE: ${staged.inputFile}`)
      problems.push("cold reader answered instead of reporting UNREADABLE");
  }

  return {
    variant,
    agent,
    version,
    passed: problems.length === 0,
    answer: answer || null,
    problems,
  };
}

/**
 * @param {Variant} variant
 * @param {SessionConfig & {query: QueryFunction, tmp: string, markers?: Markers}} context
 * @returns {Promise<VariantResult>}
 */
async function runVariant(variant, context) {
  const markers = context.markers || createMarkers();
  const staged = stageWorkspace(context.tmp, markers);
  /** @type {unknown[]} */ const events = [];
  /** @type {Query | undefined} */ let session;
  let stderr = "";
  try {
    session = context.query({
      prompt: parentPrompt(variant, markers, staged),
      options: sessionOptions(variant, staged, {
        ...context,
        onStderr: (text) => {
          stderr = `${stderr}${text}`.slice(-STDERR_TAIL);
        },
      }),
    });
    for await (const event of session) events.push(event);
  } catch (error) {
    return {
      variant,
      agent: agentFor(variant),
      version: null,
      passed: false,
      answer: null,
      problems: [
        `session failed: ${error instanceof Error ? error.message : String(error)}${stderr ? `\n${stderr.trim()}` : ""}`,
      ],
    };
  } finally {
    session?.close?.();
    fs.rmSync(staged.workspace, { recursive: true, force: true });
  }
  return evaluate(variant, events, markers, staged);
}

/** @param {string[]} argv @returns {{model: string, variants: Variant[], claudePath?: string}} */
function parseArgs(argv) {
  let model = DEFAULT_MODEL;
  let variants = [...VARIANTS];
  /** @type {string | undefined} */ let claudePath;
  for (let index = 0; index < argv.length; index += 2) {
    const flag = argv[index];
    const value = argv[index + 1];
    if (flag === "--model" && value && !value.startsWith("--")) model = value;
    else if (
      flag === "--variant" &&
      VARIANTS.includes(/** @type {Variant} */ (value))
    )
      variants = [/** @type {Variant} */ (value)];
    else if (flag === "--claude-path" && value && !value.startsWith("--"))
      claudePath = value;
    else throw new Error(USAGE);
  }
  return { model, variants, ...(claudePath ? { claudePath } : {}) };
}

/**
 * @param {string[]} argv
 * @param {{query?: QueryFunction, env?: NodeJS.ProcessEnv, tmp?: string, write?: (text: string) => void}} [dependencies]
 * @returns {Promise<number>}
 */
async function main(argv, dependencies = {}) {
  const write =
    dependencies.write || ((text) => void process.stdout.write(text));
  /** @type {ReturnType<typeof parseArgs>} */ let parsed;
  try {
    parsed = parseArgs(argv);
  } catch (error) {
    write(`${error instanceof Error ? error.message : String(error)}\n`);
    return 2;
  }
  const query =
    dependencies.query ||
    /** @type {QueryFunction} */ (
      (await import("@anthropic-ai/claude-agent-sdk")).query
    );
  const env = dependencies.env || process.env;
  const claudePath = parsed.claudePath || findClaude(env);
  /** @type {VariantResult[]} */ const results = [];
  for (const variant of parsed.variants)
    results.push(
      await runVariant(variant, {
        query,
        model: parsed.model,
        env,
        claudePath,
        tmp: dependencies.tmp || os.tmpdir(),
      }),
    );
  const passed = results.every((result) => result.passed);
  write(
    `${JSON.stringify({ probe: "cold-reader-isolation", claude: claudePath || "bundled with the Agent SDK", model: parsed.model, passed, results }, null, 2)}\n`,
  );
  return passed ? 0 : 1;
}

if (require.main === module)
  main(process.argv.slice(2)).then((code) => {
    process.exitCode = code;
  });

module.exports = {
  COLD_READER,
  CONTROL_AGENT,
  VARIANTS,
  agentFor,
  childEnvironment,
  childPrompt,
  createMarkers,
  evaluate,
  findClaude,
  main,
  parentPrompt,
  parseArgs,
  runVariant,
  sessionOptions,
  stageWorkspace,
};
