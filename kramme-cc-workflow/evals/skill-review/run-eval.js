#!/usr/bin/env node
// @ts-check
"use strict";

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");
const { aggregateScores, scoreItem } = require("./scorer");

const VALID_SPLITS = new Set(["train", "val", "test", "all"]);
const DEFAULT_PREDICTION_TIMEOUT_MS = 120000;
const PREDICTION_TIMEOUT_ENV = "SKILL_REVIEW_EVAL_PREDICTION_TIMEOUT_MS";
const PREDICTION_TIMEOUT_SENTINEL = "__SKILL_REVIEW_EVAL_PREDICTION_TIMEOUT__";
const PROCESS_GROUP_TIMEOUT_RUNNER = String.raw`
my $timeout = shift @ARGV;
my $sentinel = shift @ARGV;
my $command = shift @ARGV;

my $pid = fork();
die "failed to fork prediction command: $!\n" unless defined $pid;

if ($pid == 0) {
  setpgrp(0, 0) or die "failed to create prediction process group: $!\n";
  exec "/bin/sh", "-c", $command;
  die "failed to exec prediction shell: $!\n";
}

my $timed_out = 0;
local $SIG{ALRM} = sub {
  $timed_out = 1;
  kill "KILL", -$pid;
};

alarm($timeout);
my $waited = waitpid($pid, 0);
my $status = $?;
alarm(0);

if ($timed_out) {
  print STDERR "$sentinel\n";
  exit 124;
}

die "failed to wait for prediction command: $!\n" if $waited == -1;
exit(128 + ($status & 127)) if $status & 127;
exit(($status >> 8) & 255);
`;

/**
 * @typedef {Object} EvalCliOptions
 * @property {string} split
 * @property {boolean} json
 * @property {string | null} skill
 * @property {string | null} predictionCommand
 * @property {boolean} [help]
 *
 * @typedef {Object} EvalItem
 * @property {string} id
 * @property {string} fixture_review_output
 * @property {string} [input_skill_dir]
 * @property {string} [input_skill_text]
 * @property {string} [split]
 * @property {string} [difficulty]
 * @property {unknown[]} [expected_findings]
 * @property {unknown[]} [required_checks]
 * @property {unknown[]} [forbidden_findings]
 *
 * @typedef {Object} Prediction
 * @property {"prediction_command" | "fixture_review_output"} source
 * @property {string} text
 *
 * @typedef {Object} EvalResult
 * @property {string} split
 * @property {string | null} skill
 * @property {number} hard
 * @property {number} soft
 * @property {string[]} diagnostics
 * @property {Array<Record<string, unknown> & { id: string, hard: number, soft: number }>} items
 *
 * @typedef {Object} AdapterOptions
 * @property {string} [evalRoot]
 * @property {string} [split]
 * @property {string | null} [skill]
 * @property {string | null} [predictionCommand]
 *
 * @typedef {Object} AdapterContextItem
 * @property {string} id
 * @property {string | null} split
 * @property {string | null} difficulty
 * @property {string | null} input_skill_dir
 * @property {string | null} input_skill_text
 * @property {string} [input_skill_path]
 * @property {string} [input_skill_file]
 *
 * @typedef {Object} AdapterContext
 * @property {number} adapter_version
 * @property {string} eval_root
 * @property {string | null} skill
 * @property {string | null} skill_path
 * @property {AdapterContextItem} item
 */

/**
 * @param {string[]} argv
 * @returns {EvalCliOptions}
 */
function parseArgs(argv) {
  /** @type {EvalCliOptions} */
  const options = {
    split: "all",
    json: false,
    skill: null,
    predictionCommand: null,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--json") {
      options.json = true;
    } else if (arg === "--split") {
      index += 1;
      if (index >= argv.length) {
        throw new Error("--split requires a value");
      }
      options.split = argv[index];
    } else if (arg === "--skill") {
      index += 1;
      if (index >= argv.length) {
        throw new Error("--skill requires a path");
      }
      options.skill = argv[index];
    } else if (arg === "--prediction-command") {
      index += 1;
      if (index >= argv.length || argv[index].trim() === "") {
        throw new Error("--prediction-command requires a command");
      }
      options.predictionCommand = argv[index];
    } else if (arg === "--help" || arg === "-h") {
      options.help = true;
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }

  return options;
}

function usage() {
  return [
    "Usage: node evals/skill-review/run-eval.js [--split train|val|test|all] [--skill <path>] [--prediction-command <cmd>] [--json]",
    "",
    "By default, scores committed fixture review output.",
    "With --prediction-command, sends item context JSON on stdin and scores stdout.",
  ].join("\n");
}

/**
 * @param {string} filePath
 * @returns {unknown}
 */
function readJsonFile(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (error) {
    throw new Error(`failed to read JSON ${filePath}: ${errorMessage(error)}`);
  }
}

/**
 * @param {string} rootDir
 * @param {string} relativePath
 */
function resolveInside(rootDir, relativePath) {
  const resolved = path.resolve(rootDir, relativePath);
  const relative = path.relative(rootDir, resolved);
  if (relative.startsWith("..") || path.isAbsolute(relative)) {
    throw new Error(`path escapes eval root: ${relativePath}`);
  }
  return resolved;
}

/**
 * @param {unknown} item
 * @returns {asserts item is EvalItem}
 */
function assertEvalItemShape(item) {
  if (!item || typeof item !== "object" || Array.isArray(item)) {
    throw new Error("eval item must be an object");
  }
  const record = /** @type {Record<string, unknown>} */ (item);
  if (typeof record.id !== "string" || record.id.trim() === "") {
    throw new Error("eval item id must be a non-empty string");
  }
  if (typeof record.fixture_review_output !== "string") {
    throw new Error(`${record.id}.fixture_review_output must be a string`);
  }
  for (const field of [
    "input_skill_dir",
    "input_skill_text",
    "split",
    "difficulty",
  ]) {
    if (record[field] !== undefined && typeof record[field] !== "string") {
      throw new Error(`${record.id}.${field} must be a string`);
    }
  }
  for (const field of [
    "expected_findings",
    "required_checks",
    "forbidden_findings",
  ]) {
    if (record[field] !== undefined && !Array.isArray(record[field])) {
      throw new Error(`${record.id}.${field} must be an array`);
    }
  }
}

/**
 * @param {EvalItem} item
 * @param {string} evalRoot
 * @returns {void}
 */
function validateItem(item, evalRoot) {
  assertEvalItemShape(item);
  if (!item.input_skill_dir && !item.input_skill_text) {
    throw new Error(
      `${item.id} must define input_skill_dir or input_skill_text`,
    );
  }
  if (item.input_skill_dir) {
    const fixturePath = resolveInside(evalRoot, item.input_skill_dir);
    if (!fs.existsSync(fixturePath)) {
      throw new Error(
        `missing fixture for ${item.id}: ${item.input_skill_dir}`,
      );
    }
    const stat = fs.statSync(fixturePath);
    if (!stat.isDirectory()) {
      throw new Error(
        `${item.id}.input_skill_dir is not a directory: ${item.input_skill_dir}`,
      );
    }
    const skillPath = path.join(fixturePath, "SKILL.md");
    if (!fs.existsSync(skillPath)) {
      throw new Error(
        `missing SKILL.md for ${item.id}: ${item.input_skill_dir}`,
      );
    }
  }
}

/**
 * @param {string} split
 * @param {string} evalRoot
 * @returns {EvalItem[]}
 */
function readSplit(split, evalRoot) {
  const filePath = path.join(evalRoot, "items", split, "items.json");
  const items = readJsonFile(filePath);
  if (!Array.isArray(items)) {
    throw new Error(`${filePath} must contain an array`);
  }
  if (items.length === 0) {
    throw new Error(`${filePath} must contain at least one item`);
  }

  return items.map((item) => {
    assertEvalItemShape(item);
    return { ...item, split };
  });
}

/**
 * @param {string} split
 * @param {string} evalRoot
 * @returns {EvalItem[]}
 */
function loadItemsForSplit(split, evalRoot) {
  if (!VALID_SPLITS.has(split)) {
    throw new Error(
      `invalid split "${split}"; expected train, val, test, or all`,
    );
  }

  const splits = split === "all" ? ["train", "val", "test"] : [split];
  return splits.flatMap((splitName) => readSplit(splitName, evalRoot));
}

/**
 * @param {EvalItem} item
 * @param {AdapterOptions} options
 * @returns {AdapterContext}
 */
function adapterContextForItem(item, options) {
  const evalRoot = options.evalRoot || __dirname;
  const skill = options.skill || null;
  /** @type {AdapterContext} */
  const context = {
    adapter_version: 1,
    eval_root: evalRoot,
    skill,
    skill_path: skill ? path.resolve(skill) : null,
    item: {
      id: item.id,
      split: item.split || options.split || null,
      difficulty: item.difficulty || null,
      input_skill_dir: item.input_skill_dir || null,
      input_skill_text: item.input_skill_text || null,
    },
  };

  if (item.input_skill_dir) {
    const inputSkillPath = resolveInside(evalRoot, item.input_skill_dir);
    context.item.input_skill_path = inputSkillPath;
    context.item.input_skill_file = path.join(inputSkillPath, "SKILL.md");
  }

  return context;
}

function predictionTimeoutMs() {
  const rawValue = process.env[PREDICTION_TIMEOUT_ENV];
  if (!rawValue) {
    return DEFAULT_PREDICTION_TIMEOUT_MS;
  }

  const value = Number(rawValue);
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new Error(`${PREDICTION_TIMEOUT_ENV} must be a positive integer`);
  }

  return value;
}

/** @param {string | null | undefined} stderr */
function stripPredictionTimeoutSentinel(stderr) {
  return (stderr || "")
    .split(/\r?\n/)
    .filter((line) => line !== PREDICTION_TIMEOUT_SENTINEL)
    .join("\n")
    .trim();
}

/** @param {unknown} error */
function spawnErrorCode(error) {
  if (error && typeof error === "object" && "code" in error) {
    return /** @type {{ code?: unknown }} */ (error).code;
  }
  return undefined;
}

/**
 * @param {string} command
 * @param {import("child_process").SpawnSyncOptionsWithStringEncoding & { timeout: number }} options
 */
function runShellCommandWithTimeout(command, options) {
  if (process.platform === "win32") {
    return spawnSync(command, {
      ...options,
      shell: true,
      timeout: options.timeout,
      killSignal: "SIGKILL",
    });
  }

  // Run the shell in its own process group so timeout cleanup reaches children.
  const { timeout, ...spawnOptions } = options;
  return spawnSync(
    "perl",
    [
      "-MTime::HiRes=alarm",
      "-e",
      PROCESS_GROUP_TIMEOUT_RUNNER,
      String(timeout / 1000),
      PREDICTION_TIMEOUT_SENTINEL,
      command,
    ],
    spawnOptions,
  );
}

/**
 * @param {EvalItem} item
 * @param {AdapterOptions & { predictionCommand: string }} options
 */
function runPredictionCommand(item, options) {
  const command = options.predictionCommand;
  const context = adapterContextForItem(item, options);
  const timeout = predictionTimeoutMs();
  const result = runShellCommandWithTimeout(command, {
    input: `${JSON.stringify(context)}\n`,
    encoding: "utf8",
    maxBuffer: 10 * 1024 * 1024,
    timeout,
    env: {
      ...process.env,
      SKILL_REVIEW_EVAL_ITEM_ID: item.id,
      SKILL_REVIEW_EVAL_SKILL: options.skill || "",
    },
  });

  if (result.error) {
    if (spawnErrorCode(result.error) === "ETIMEDOUT") {
      throw new Error(
        `prediction command timed out for ${item.id} after ${timeout}ms`,
      );
    }
    throw new Error(
      `prediction command failed for ${item.id}: ${result.error.message}`,
    );
  }
  if (
    result.status === 124 &&
    (result.stderr || "").split(/\r?\n/).includes(PREDICTION_TIMEOUT_SENTINEL)
  ) {
    throw new Error(
      `prediction command timed out for ${item.id} after ${timeout}ms`,
    );
  }
  if (result.status !== 0) {
    const detail =
      stripPredictionTimeoutSentinel(result.stderr) ||
      (result.stdout || "").trim();
    const suffix = detail ? `: ${detail}` : "";
    throw new Error(
      `prediction command failed for ${item.id} with exit ${result.status}${suffix}`,
    );
  }

  return result.stdout.trimEnd();
}

/**
 * @param {EvalItem} item
 * @param {{ predictionCommand?: string | null, evalRoot?: string, split?: string, skill?: string | null }} [options]
 * @returns {Prediction}
 */
function predictionForItem(item, options = {}) {
  if (options.predictionCommand) {
    return {
      source: "prediction_command",
      text: runPredictionCommand(item, {
        ...options,
        predictionCommand: options.predictionCommand,
      }),
    };
  }

  return {
    source: "fixture_review_output",
    text: item.fixture_review_output,
  };
}

/**
 * @param {EvalItem[]} items
 * @param {{ evalRoot?: string, split?: string, skill?: string | null, predictionCommand?: string | null }} [options]
 * @returns {EvalResult}
 */
function evaluateItems(items, options = {}) {
  const evalRoot = options.evalRoot || __dirname;
  const split = options.split || "custom";
  const skill = options.skill || null;
  const predictionCommand = options.predictionCommand || null;

  for (const item of items) {
    validateItem(item, evalRoot);
  }

  const itemResults = items.map((item) => {
    const prediction = predictionForItem(item, {
      evalRoot,
      split,
      skill,
      predictionCommand,
    });
    return {
      ...scoreItem(item, prediction.text, {
        predictionSource: prediction.source,
      }),
      split: item.split || split,
      input_skill_dir: item.input_skill_dir || null,
      difficulty: item.difficulty || null,
    };
  });
  const aggregate = aggregateScores(itemResults);

  return {
    split,
    skill,
    hard: aggregate.hard,
    soft: aggregate.soft,
    diagnostics: [],
    items: itemResults,
  };
}

/**
 * @param {EvalCliOptions} options
 * @param {string} [evalRoot]
 * @returns {EvalResult}
 */
function runEval(options, evalRoot = __dirname) {
  const items = loadItemsForSplit(options.split, evalRoot);
  return evaluateItems(items, {
    evalRoot,
    split: options.split,
    skill: options.skill,
    predictionCommand: options.predictionCommand,
  });
}

/** @param {EvalResult} result */
function printHuman(result) {
  console.log(
    `skill-review eval split=${result.split} hard=${result.hard.toFixed(4)} soft=${result.soft.toFixed(4)} items=${result.items.length}`,
  );
  for (const item of result.items) {
    console.log(`- ${item.id}: hard=${item.hard} soft=${item.soft.toFixed(4)}`);
  }
}

/** @param {string[]} argv */
function main(argv) {
  /** @type {EvalCliOptions} */
  let options = {
    split: "all",
    json: argv.includes("--json"),
    skill: null,
    predictionCommand: null,
  };

  try {
    options = parseArgs(argv);
    if (options.help) {
      console.log(usage());
      return 0;
    }

    const result = runEval(options);
    if (options.json) {
      console.log(JSON.stringify(result, null, 2));
    } else {
      printHuman(result);
    }
    return 0;
  } catch (error) {
    if (options.json) {
      console.log(
        JSON.stringify(
          {
            error: errorMessage(error),
            diagnostics: [errorMessage(error)],
          },
          null,
          2,
        ),
      );
    } else {
      console.error(errorMessage(error));
      console.error(usage());
    }
    return 1;
  }
}

/** @param {unknown} error */
function errorMessage(error) {
  return error instanceof Error ? error.message : String(error);
}

if (require.main === module) {
  process.exitCode = main(process.argv.slice(2));
}

module.exports = {
  evaluateItems,
  loadItemsForSplit,
};
