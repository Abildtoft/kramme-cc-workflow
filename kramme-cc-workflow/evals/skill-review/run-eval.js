#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const { aggregateScores, scoreItem } = require('./scorer');

const VALID_SPLITS = new Set(['train', 'val', 'test', 'all']);

function parseArgs(argv) {
  const options = {
    split: 'all',
    json: false,
    skill: null,
    predictionCommand: null,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === '--json') {
      options.json = true;
    } else if (arg === '--split') {
      index += 1;
      if (index >= argv.length) {
        throw new Error('--split requires a value');
      }
      options.split = argv[index];
    } else if (arg === '--skill') {
      index += 1;
      if (index >= argv.length) {
        throw new Error('--skill requires a path');
      }
      options.skill = argv[index];
    } else if (arg === '--prediction-command') {
      index += 1;
      if (index >= argv.length || argv[index].trim() === '') {
        throw new Error('--prediction-command requires a command');
      }
      options.predictionCommand = argv[index];
    } else if (arg === '--help' || arg === '-h') {
      options.help = true;
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }

  return options;
}

function usage() {
  return [
    'Usage: node evals/skill-review/run-eval.js [--split train|val|test|all] [--skill <path>] [--prediction-command <cmd>] [--json]',
    '',
    'By default, scores committed fixture review output.',
    'With --prediction-command, sends item context JSON on stdin and scores stdout.',
  ].join('\n');
}

function readJsonFile(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch (error) {
    throw new Error(`failed to read JSON ${filePath}: ${error.message}`);
  }
}

function resolveInside(rootDir, relativePath) {
  const resolved = path.resolve(rootDir, relativePath);
  const relative = path.relative(rootDir, resolved);
  if (relative.startsWith('..') || path.isAbsolute(relative)) {
    throw new Error(`path escapes eval root: ${relativePath}`);
  }
  return resolved;
}

function validateItem(item, evalRoot) {
  if (!item || typeof item !== 'object') {
    throw new Error('eval item must be an object');
  }
  if (typeof item.id !== 'string' || item.id.trim() === '') {
    throw new Error('eval item id must be a non-empty string');
  }
  if (typeof item.fixture_review_output !== 'string') {
    throw new Error(`${item.id}.fixture_review_output must be a string`);
  }
  if (!item.input_skill_dir && !item.input_skill_text) {
    throw new Error(`${item.id} must define input_skill_dir or input_skill_text`);
  }
  if (item.input_skill_dir) {
    if (typeof item.input_skill_dir !== 'string') {
      throw new Error(`${item.id}.input_skill_dir must be a string`);
    }

    const fixturePath = resolveInside(evalRoot, item.input_skill_dir);
    if (!fs.existsSync(fixturePath)) {
      throw new Error(`missing fixture for ${item.id}: ${item.input_skill_dir}`);
    }
    const stat = fs.statSync(fixturePath);
    if (!stat.isDirectory()) {
      throw new Error(`${item.id}.input_skill_dir is not a directory: ${item.input_skill_dir}`);
    }
    const skillPath = path.join(fixturePath, 'SKILL.md');
    if (!fs.existsSync(skillPath)) {
      throw new Error(`missing SKILL.md for ${item.id}: ${item.input_skill_dir}`);
    }
  }
}

function readSplit(split, evalRoot) {
  const filePath = path.join(evalRoot, 'items', split, 'items.json');
  const items = readJsonFile(filePath);
  if (!Array.isArray(items)) {
    throw new Error(`${filePath} must contain an array`);
  }
  if (items.length === 0) {
    throw new Error(`${filePath} must contain at least one item`);
  }

  return items.map((item) => ({ ...item, split }));
}

function loadItemsForSplit(split, evalRoot) {
  if (!VALID_SPLITS.has(split)) {
    throw new Error(`invalid split "${split}"; expected train, val, test, or all`);
  }

  const splits = split === 'all' ? ['train', 'val', 'test'] : [split];
  return splits.flatMap((splitName) => readSplit(splitName, evalRoot));
}

function adapterContextForItem(item, options) {
  const evalRoot = options.evalRoot || __dirname;
  const skill = options.skill || null;
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
    context.item.input_skill_file = path.join(inputSkillPath, 'SKILL.md');
  }

  return context;
}

function runPredictionCommand(item, options) {
  const command = options.predictionCommand;
  const context = adapterContextForItem(item, options);
  const result = spawnSync(command, {
    input: `${JSON.stringify(context)}\n`,
    encoding: 'utf8',
    shell: true,
    maxBuffer: 10 * 1024 * 1024,
    env: {
      ...process.env,
      SKILL_REVIEW_EVAL_ITEM_ID: item.id,
      SKILL_REVIEW_EVAL_SKILL: options.skill || '',
    },
  });

  if (result.error) {
    throw new Error(`prediction command failed for ${item.id}: ${result.error.message}`);
  }
  if (result.status !== 0) {
    const detail = (result.stderr || result.stdout || '').trim();
    const suffix = detail ? `: ${detail}` : '';
    throw new Error(`prediction command failed for ${item.id} with exit ${result.status}${suffix}`);
  }

  return result.stdout.trimEnd();
}

function predictionForItem(item, options = {}) {
  if (options.predictionCommand) {
    return {
      source: 'prediction_command',
      text: runPredictionCommand(item, options),
    };
  }

  return {
    source: 'fixture_review_output',
    text: item.fixture_review_output,
  };
}

function evaluateItems(items, options = {}) {
  const evalRoot = options.evalRoot || __dirname;
  const split = options.split || 'custom';
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

function runEval(options, evalRoot = __dirname) {
  const items = loadItemsForSplit(options.split, evalRoot);
  return evaluateItems(items, {
    evalRoot,
    split: options.split,
    skill: options.skill,
    predictionCommand: options.predictionCommand,
  });
}

function printHuman(result) {
  console.log(
    `skill-review eval split=${result.split} hard=${result.hard.toFixed(4)} soft=${result.soft.toFixed(4)} items=${result.items.length}`,
  );
  for (const item of result.items) {
    console.log(`- ${item.id}: hard=${item.hard} soft=${item.soft.toFixed(4)}`);
  }
}

function main(argv) {
  let options = {
    json: argv.includes('--json'),
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
            error: error.message,
            diagnostics: [error.message],
          },
          null,
          2,
        ),
      );
    } else {
      console.error(error.message);
      console.error(usage());
    }
    return 1;
  }
}

if (require.main === module) {
  process.exitCode = main(process.argv.slice(2));
}

module.exports = {
  adapterContextForItem,
  evaluateItems,
  loadItemsForSplit,
  parseArgs,
  predictionForItem,
  runEval,
  validateItem,
};
