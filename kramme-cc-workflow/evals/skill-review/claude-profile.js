// @ts-check
"use strict";

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { record } = require("./credit-pool");
const { writeJson, treeFiles } = require("./eval-state");
/** @typedef {import('./live-types').AdapterContext} AdapterContext */
const PROFILE = "read-only-review-v1";
// This SDK normalizes ':' within a skill name to '-' when qualifying a plugin skill.
const SKILL = "eval-review:kramme-skill-review";

class EvalFailure extends Error {
  /** @param {string} code */
  constructor(code) {
    super(code);
    this.code = code;
  }
}

/** @param {string} root @param {string} candidate */
function inside(root, candidate) {
  const relative = path.relative(root, candidate);
  return (
    relative === "" ||
    (!relative.startsWith(`..${path.sep}`) &&
      relative !== ".." &&
      !path.isAbsolute(relative))
  );
}

/** @param {string} source @param {string} destination */
function copyTree(source, destination) {
  const files = treeFiles(source);
  fs.mkdirSync(destination, { recursive: true, mode: 0o700 });
  for (const file of files) {
    const target = path.join(destination, path.relative(source, file));
    fs.mkdirSync(path.dirname(target), { recursive: true, mode: 0o700 });
    fs.copyFileSync(file, target);
  }
}

/** @param {AdapterContext} context */
function stageCase(context) {
  if (context.adapter_version !== 1 || !context.skill_path || !context.item?.id)
    throw new EvalFailure("invalid_adapter_context");
  const source = fs.statSync(context.skill_path).isDirectory()
    ? context.skill_path
    : path.dirname(context.skill_path);
  if (
    !fs
      .readFileSync(path.join(source, "SKILL.md"), "utf8")
      .includes("name: kramme:skill:review\n")
  )
    throw new EvalFailure("unsupported_reviewer");
  const temporary = fs.realpathSync(
    fs.mkdtempSync(path.join(os.tmpdir(), "kramme-eval-")),
  );
  const workspace = path.join(temporary, "work");
  const plugin = path.join(workspace, "plugin");
  const auth = path.join(temporary, "runtime");
  try {
    fs.mkdirSync(auth, { mode: 0o700 });
    copyTree(source, path.join(plugin, "skills", "kramme:skill:review"));
    writeJson(path.join(plugin, ".claude-plugin", "plugin.json"), {
      name: "eval-review",
      version: "1.0.0",
    });
    const fixture = path.join(workspace, "fixture");
    if (context.item.input_skill_path)
      copyTree(context.item.input_skill_path, fixture);
    else if (typeof context.item.input_skill_text === "string") {
      fs.mkdirSync(fixture, { mode: 0o700 });
      fs.writeFileSync(
        path.join(fixture, "SKILL.md"),
        context.item.input_skill_text,
        { mode: 0o600 },
      );
    } else throw new EvalFailure("missing_fixture");
    return {
      temporary,
      workspace: fs.realpathSync(workspace),
      plugin,
      auth,
      fixture,
    };
  } catch (error) {
    fs.rmSync(temporary, { recursive: true, force: true });
    throw error;
  }
}

/** Every file tool is checked before SDK auto-approval. Unlisted tools cannot run.
 * @param {string} workspace @param {string} name @param {unknown} input */
function toolAllowed(workspace, name, input) {
  const args = record(input);
  if (name === "Skill")
    return (
      args.skill === SKILL &&
      typeof args.args === "string" &&
      args.args === path.join(workspace, "fixture")
    );
  if (!["Read", "Glob", "Grep"].includes(name)) return false;
  const candidate = name === "Read" ? args.file_path : args.path || workspace;
  if (typeof candidate !== "string") return false;
  if (name === "Glob" || name === "Grep") {
    const pattern = name === "Glob" ? args.pattern : args.glob;
    if (
      typeof pattern === "string" &&
      (path.isAbsolute(pattern) || pattern.split(/[\\/]/).includes(".."))
    )
      return false;
  }
  try {
    return inside(
      workspace,
      fs.realpathSync(path.resolve(workspace, candidate)),
    );
  } catch {
    return false;
  }
}

/** @param {string} key @param {string} auth @param {NodeJS.ProcessEnv} parent */
function childEnvironment(key, auth, parent) {
  // SDK 0.3.310 replaces (rather than merges) its subprocess environment.
  return {
    PATH: parent.PATH || "/usr/bin:/bin",
    LANG: "en_US.UTF-8",
    ANTHROPIC_API_KEY: key,
    CLAUDE_CONFIG_DIR: auth,
    CLAUDE_AGENT_SDK_CLIENT_APP: "kramme-skill-review-evals/1.0.0",
    CLAUDE_CODE_MAX_RETRIES: "2",
    CLAUDE_CODE_NONSTREAMING_TIMEOUT_RETRIES: "0",
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC: "1",
    ...(parent.RUNNER_TRACKING_ID
      ? { RUNNER_TRACKING_ID: parent.RUNNER_TRACKING_ID }
      : {}),
  };
}

module.exports = {
  PROFILE,
  SKILL,
  EvalFailure,
  stageCase,
  toolAllowed,
  childEnvironment,
};
