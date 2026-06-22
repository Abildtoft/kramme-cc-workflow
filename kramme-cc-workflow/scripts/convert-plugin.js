#!/usr/bin/env node
"use strict";

const path = require("path");
const os = require("os");
const { convertClaudeToCodex } = require("./convert-plugin/codex-transformer");
const {
  loadClaudePlugin,
  resolvePluginInput,
} = require("./convert-plugin/loader");
const {
  ensureCodexAgentsFile,
  resolveCodexOutputRoot,
  writeCodexBundle,
} = require("./convert-plugin/codex-writer");

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

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
