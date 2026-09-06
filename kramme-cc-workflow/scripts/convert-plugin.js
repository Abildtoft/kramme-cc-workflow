#!/usr/bin/env node
"use strict";

const path = require("path");
const os = require("os");

const ERROR_CAUSE_DEPTH_LIMIT = 5;

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

/** @typedef {Record<string, string | boolean | string[]> & { _: string[] }} ParsedArgs */

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

  if (command === "doctor") {
    const parsed = parseArgs(argv.slice(1));
    await runDoctor(parsed);
    return;
  }

  console.error(`Unknown command: ${command}`);
  printHelp(1);
}

/** @param {ParsedArgs} parsed */
async function runInstall(parsed) {
  const pluginInput = parsed._[0] ?? process.cwd();
  const targetName = resolveTargetName(parsed);

  rejectRemovedOpenCodeInstallOptions(parsed);

  if (parsed.also) {
    throw new Error(
      "--also is no longer supported; install the Codex target directly.",
    );
  }

  // Option errors must surface before plugin resolution errors, so read every
  // option before requiring the converter modules below.
  const { codexHome, agentsHome } = resolveHomeRoots(parsed);
  const confirmOptions = {
    yes: readBooleanOption(parsed, "yes", ["y"]),
    nonInteractive: readBooleanOption(parsed, "non-interactive", [
      "nonInteractive",
    ]),
  };

  const {
    convertClaudeToCodex,
  } = require("./convert-plugin/codex-transformer");
  const {
    loadClaudePlugin,
    resolvePluginInput,
  } = require("./convert-plugin/loader");
  const {
    resolveCodexOutputRoot,
    writeCodexBundle,
  } = require("./convert-plugin/codex-writer");

  const resolvedPluginPath = await resolvePluginInput(pluginInput);
  const plugin = await loadClaudePlugin(resolvedPluginPath);
  const codexRoot = resolveCodexOutputRoot(codexHome);

  const bundle = convertClaudeToCodex(plugin);
  if (!bundle) {
    throw new Error(`Target ${targetName} did not return a bundle.`);
  }

  const pluginName = String(plugin.manifest.name ?? "plugin");
  const writeOptions = {
    agentsHome,
    pluginName,
    confirm: {
      yes: confirmOptions.yes,
      nonInteractive: confirmOptions.nonInteractive,
    },
  };

  await writeCodexBundle(codexRoot, bundle, writeOptions);
  console.log(`Installed ${pluginName} to ${codexRoot}`);
}

/** @param {ParsedArgs} parsed */
function resolveTargetName(parsed) {
  const targetName = String(parsed.to ?? "codex");
  if (targetName !== "codex") {
    throw new Error(`Unknown target: ${targetName}`);
  }
  return targetName;
}

/** @param {ParsedArgs} parsed */
function rejectRemovedOpenCodeInstallOptions(parsed) {
  for (const option of REMOVED_OPENCODE_INSTALL_OPTIONS) {
    if (option.keys.some((key) => Object.hasOwn(parsed, key))) {
      throw new Error(`${option.label} is no longer supported; ${option.hint}`);
    }
  }
}

/** @param {ParsedArgs} parsed */
async function runStats(parsed) {
  const pluginInput = parsed._[0] ?? process.cwd();
  resolveTargetName(parsed);
  const outputAsJson = readBooleanOption(parsed, "json");
  const {
    convertClaudeToCodex,
  } = require("./convert-plugin/codex-transformer");
  const {
    loadClaudePlugin,
    resolvePluginInput,
  } = require("./convert-plugin/loader");
  const resolvedPluginPath = await resolvePluginInput(pluginInput);
  const plugin = await loadClaudePlugin(resolvedPluginPath);

  const codexBundle = convertClaudeToCodex(plugin);
  const stats = {
    codex_skills:
      codexBundle.skillDirs.length + codexBundle.generatedSkills.length,
    agent_skills: codexBundle.agentSkills?.length ?? 0,
  };

  if (outputAsJson) {
    console.log(JSON.stringify(stats));
    return;
  }

  for (const [key, value] of Object.entries(stats)) {
    console.log(`${key}=${value}`);
  }
}

/** @param {ParsedArgs} parsed */
async function runDoctor(parsed) {
  validateDoctorArgs(parsed);
  resolveTargetName(parsed);
  const outputAsJson = readBooleanOption(parsed, "json");
  const { codexHome, agentsHome: agentsRoot } = resolveHomeRoots(parsed);
  const {
    collectConverterDiagnostics,
  } = require("./convert-plugin/diagnostics");
  const diagnostic = await collectConverterDiagnostics({
    agentsRoot,
    codexHome,
    pluginInput: parsed._[0],
  });
  const output = sanitizeDiagnosticPaths(diagnostic);

  if (outputAsJson) {
    console.log(JSON.stringify(output));
    return;
  }

  for (const [key, value] of Object.entries(output)) {
    console.log(`${key}=${formatDoctorHumanValue(value)}`);
  }
}

/** @param {unknown} value */
function formatDoctorHumanValue(value) {
  if (value === null || value === undefined) return "none";
  const rendered =
    typeof value === "object" ? JSON.stringify(value) : String(value);
  return rendered.replace(
    /[\u0000-\u001f\u007f-\u009f\u2028\u2029]/g,
    (character) =>
      `\\u${character.charCodeAt(0).toString(16).padStart(4, "0")}`,
  );
}

/** @param {ParsedArgs} parsed */
function validateDoctorArgs(parsed) {
  if (parsed._.length !== 1) {
    throw new Error("doctor requires exactly one plugin name or path.");
  }

  const allowed = new Set([
    "_",
    "agents-home",
    "agentsHome",
    "codex-home",
    "codexHome",
    "json",
    "to",
  ]);
  const unsupported = Object.keys(parsed).find((key) => !allowed.has(key));
  if (unsupported) {
    throw new Error(`doctor does not support --${unsupported}.`);
  }
}

/**
 * @param {ParsedArgs} parsed
 * @param {string} kebabKey
 * @param {string[]} [aliasKeys]
 */
function readOptionValue(parsed, kebabKey, aliasKeys = []) {
  for (const key of [kebabKey, ...aliasKeys]) {
    if (Object.hasOwn(parsed, key)) return parsed[key];
  }
  return undefined;
}

/**
 * @param {ParsedArgs} parsed
 * @param {string} kebabKey
 * @param {string[]} aliasKeys
 */
function readPathOption(parsed, kebabKey, aliasKeys) {
  const value = readOptionValue(parsed, kebabKey, aliasKeys);
  if (value === undefined) return undefined;
  if (typeof value !== "string" || !value.trim()) {
    throw new Error(`--${kebabKey} requires a directory.`);
  }
  return value.trim();
}

/**
 * @param {ParsedArgs} parsed
 * @param {string} kebabKey
 * @param {string[]} [aliasKeys]
 */
function readBooleanOption(parsed, kebabKey, aliasKeys = []) {
  const value = readOptionValue(parsed, kebabKey, aliasKeys);
  if (value === undefined) return false;
  if (typeof value === "boolean") return value;
  const normalized =
    typeof value === "string" ? value.trim().toLowerCase() : "";
  if (["true", "1", "yes"].includes(normalized)) return true;
  if (["false", "0", "no"].includes(normalized)) return false;
  throw new Error(
    `--${kebabKey} requires a boolean value when one is provided.`,
  );
}

/** @param {ParsedArgs} parsed */
function resolveHomeRoots(parsed) {
  return {
    codexHome: resolveRoot(
      readPathOption(parsed, "codex-home", ["codexHome"]),
      ".codex",
    ),
    agentsHome: resolveRoot(
      readPathOption(parsed, "agents-home", ["agentsHome"]),
      ".agents",
    ),
  };
}

/** @param {Record<string, unknown>} diagnostic */
function sanitizeDiagnosticPaths(diagnostic) {
  return {
    ...diagnostic,
    plugin_source: sanitizeHomePath(diagnostic.plugin_source),
    codex_root: sanitizeHomePath(diagnostic.codex_root),
    agents_root: sanitizeHomePath(diagnostic.agents_root),
    install_state_path: sanitizeHomePath(diagnostic.install_state_path),
  };
}

/** @param {unknown} value */
function sanitizeHomePath(value) {
  const resolved = path.resolve(String(value));
  const home = path.resolve(os.homedir());
  if (resolved === home) return "~";
  if (resolved.startsWith(`${home}${path.sep}`)) {
    return `~${path.sep}${path.relative(home, resolved)}`;
  }
  return resolved;
}

/** @param {unknown} value */
function sanitizeDoctorError(value) {
  const home = path.resolve(os.homedir());
  const homeBoundary = new RegExp(
    `(^|[\\s"'(=,:])${escapeRegExp(home)}(?=$|${escapeRegExp(path.sep)}|["'\\)\\],:;])`,
    "g",
  );
  const redacted = String(value).replace(homeBoundary, "$1~");
  return formatDoctorHumanValue(redacted);
}

/** @param {string} value */
function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/** @param {number} exitCode */
function printHelp(exitCode) {
  const help = `Usage:
  scripts/convert-plugin.js install <plugin-name|path> [options]
  scripts/convert-plugin.js stats <plugin-name|path> [options]
  scripts/convert-plugin.js doctor <plugin-name|path> [options]

Options:
  --to <target>           Target format: codex (default: codex)
  --codex-home <dir>      Codex root (default: ~/.codex)
  --agents-home <dir>     Agents root (default: ~/.agents)
  --yes, -y               Assume "yes" for all cleanup confirmations
  --non-interactive       Never prompt; use default answers for confirmations
  --json                  (stats and doctor) print JSON instead of key=value lines

Long boolean options (--yes, --non-interactive, --json) also accept an explicit
=true or =false value (or 1/0, yes/no); any other value is rejected.

Stats fields:
  codex_skills            Number of Codex skills (skill directories plus generated command skills)
  agent_skills            Number of generated Codex agent skills

Doctor fields:
  schema_version, plugin_name, plugin_version, plugin_source
  codex_root, agents_root, install_state_path
  install_state_status, install_state_from_disk, install_state_recovery_reason
  transaction_health
`;
  console.log(help);
  if (exitCode) process.exit(exitCode);
}

/** @param {string | undefined} value */
function isHelp(value) {
  return value === "-h" || value === "--help";
}

/** @param {string[]} argv @returns {ParsedArgs} */
function parseArgs(argv) {
  /** @type {ParsedArgs} */
  const result = { _: [] };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg.startsWith("--")) {
      const body = arg.slice(2);
      const separator = body.indexOf("=");
      if (separator !== -1) {
        result[body.slice(0, separator)] = body.slice(separator + 1);
        continue;
      }
      const next = argv[i + 1];
      if (next && !next.startsWith("-")) {
        result[body] = next;
        i += 1;
      } else {
        result[body] = true;
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

/** @param {string | undefined} value @param {...string} defaultSegments */
function resolveRoot(value, ...defaultSegments) {
  if (value === undefined) {
    return path.join(os.homedir(), ...defaultSegments);
  }
  return path.resolve(expandHome(value));
}

/** @param {string} value */
function expandHome(value) {
  if (value === "~") return os.homedir();
  if (value.startsWith(`~${path.sep}`)) {
    return path.join(os.homedir(), value.slice(2));
  }
  return value;
}

/** @param {unknown} error */
function formatError(error) {
  if (!(error instanceof Error)) return error;

  /** @type {string[]} */
  const messages = [];
  /** @type {unknown} */
  let current = error;

  for (let depth = 0; depth < ERROR_CAUSE_DEPTH_LIMIT; depth += 1) {
    if (!(current instanceof Error)) break;

    const normalized = current.message.split(/\r?\n/, 1)[0].trim();
    const alreadyRendered = messages.some(
      (message) =>
        message === normalized ||
        message.endsWith(`: ${normalized}`) ||
        message.startsWith(`${normalized} `),
    );
    if (normalized && !alreadyRendered) {
      messages.push(normalized);
    }

    if (current.cause === undefined) break;
    current = current.cause;
  }

  return messages.join(": ");
}

main().catch((error) => {
  const formatted = formatError(error);
  console.error(
    process.argv[2] === "doctor" ? sanitizeDoctorError(formatted) : formatted,
  );
  process.exit(1);
});
