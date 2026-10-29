#!/usr/bin/env node
// @ts-check
"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { classifyOpenAIError, record } = require("./credit-pool");
const { predictWithPool, runAdapter } = require("./live-predict");
const { PROVIDERS } = require("./providers");
const {
  PROFILE,
  TOOLS,
  EvalFailure,
  stageCase,
  toolAllowed,
} = require("./review-profile");

/** @typedef {import('./live-types').AdapterContext} AdapterContext */
/** @typedef {import('./live-types').Attempt} Attempt */
/** @typedef {import('./live-predict').SessionConfig} SessionConfig */
/** @typedef {(url: string, init: {method: string, headers: Record<string, string>, body: string, signal: AbortSignal}) => Promise<Response>} FetchFunction */
/** @typedef {{fetch?: FetchFunction, now?: () => number}} Dependencies */
const SKILL = "kramme:skill:review";
// Fingerprinted with each run; change it when the request shape, tools, or retry policy change.
const RUNTIME = "openai-responses-1";
const ENDPOINT = "https://api.openai.com/v1/responses";
const MAX_RETRIES = 2;
const MAX_RETRY_DELAY_MS = 60000;
const MAX_READ_LINES = 2000;
const MAX_RESULTS = 200;
const MAX_TOOL_OUTPUT = 100000;
const INSTRUCTIONS =
  "This is a read-only fixture review. Use only the Skill, Read, Glob, and Grep tools; they reach only the staged eval workspace. Load the requested reviewer skill with the Skill tool, then follow its instructions for the fixture. SkillSpector and ecosystem analyzers are unavailable in this eval profile; mark their evidence N/A. Return the final review as text.";

/** @param {string} name @param {string} description @param {Record<string, unknown>} properties */
function tool(name, description, properties) {
  return {
    type: "function",
    name,
    description,
    strict: true,
    parameters: {
      type: "object",
      properties,
      required: Object.keys(properties),
      additionalProperties: false,
    },
  };
}

/** @param {string} type @param {string} description */
function optional(type, description) {
  return { type: [type, "null"], description };
}

// The same tool surface as the Claude profile, implemented locally.
const TOOL_DEFINITIONS = [
  tool("Skill", "Load a skill's instructions with the given arguments.", {
    skill: { type: "string", description: "Skill name." },
    args: { type: "string", description: "Arguments for the skill." },
  }),
  tool("Read", "Read a text file. Returns numbered lines.", {
    file_path: { type: "string", description: "Absolute file path." },
    offset: optional("integer", "First line to read; null starts at line 1."),
    limit: optional("integer", `Lines to read; null reads ${MAX_READ_LINES}.`),
  }),
  tool("Glob", "List files matching a glob pattern such as **/*.md.", {
    pattern: { type: "string", description: "Glob relative to path." },
    path: optional("string", "Directory to search; null uses the workspace."),
  }),
  tool("Grep", "Search file contents with a JavaScript regular expression.", {
    pattern: { type: "string", description: "Regular expression." },
    path: optional("string", "File or directory; null uses the workspace."),
    glob: optional("string", "Only search files matching this glob."),
    output_mode: {
      type: ["string", "null"],
      enum: ["content", "files_with_matches", "count", null],
      description: "Defaults to files_with_matches.",
    },
    case_insensitive: optional("boolean", "Ignore case."),
  }),
];

/** @param {string} text */
function escapeRegExp(text) {
  return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/** Supports `**`, `*`, `?`, and `{a,b}`; other characters match literally.
 * @param {string} pattern */
function globPattern(pattern) {
  let source = "";
  for (let index = 0; index < pattern.length; index++) {
    const char = pattern[index];
    const close = pattern.indexOf("}", index);
    if (char === "*" && pattern[index + 1] === "*") {
      index++;
      if (pattern[index + 1] === "/") {
        index++;
        source += "(?:.*/)?";
      } else source += ".*";
    } else if (char === "*") source += "[^/]*";
    else if (char === "?") source += "[^/]";
    else if (char === "{" && close > index) {
      source += `(?:${pattern
        .slice(index + 1, close)
        .split(",")
        .map(escapeRegExp)
        .join("|")})`;
      index = close;
    } else source += escapeRegExp(char);
  }
  return new RegExp(`^${source}$`);
}

/** Staged trees contain only regular files; anything else is skipped.
 * @param {string} entry @returns {string[]} */
function walk(entry) {
  const stat = fs.lstatSync(entry);
  if (stat.isFile()) return [entry];
  if (!stat.isDirectory()) return [];
  return fs
    .readdirSync(entry)
    .sort()
    .flatMap((name) => walk(path.join(entry, name)));
}

/** Run one tool call that `toolAllowed` has already approved.
 * @param {string} workspace @param {string} name @param {Record<string, unknown>} args */
function runTool(workspace, name, args) {
  if (name === "Skill") {
    const directory = path.join(
      workspace,
      "plugin",
      "skills",
      "kramme:skill:review",
    );
    const body = fs.readFileSync(path.join(directory, "SKILL.md"), "utf8");
    return `Base directory for this skill: ${directory}\n\n${body}\n\nARGUMENTS: ${args.args}`;
  }
  const target = fs.realpathSync(
    path.resolve(
      workspace,
      String(name === "Read" ? args.file_path : args.path || workspace),
    ),
  );
  if (name === "Read") {
    if (!fs.statSync(target).isFile())
      return `Error: ${target} is not a file. Use Glob to list directories.`;
    const offset = Math.max(1, Number(args.offset) || 1);
    const limit = Math.min(
      MAX_READ_LINES,
      Math.max(1, Number(args.limit) || MAX_READ_LINES),
    );
    const lines = fs
      .readFileSync(target, "utf8")
      .split("\n")
      .slice(offset - 1, offset - 1 + limit);
    return lines.length
      ? lines
          .map(
            (line, i) =>
              `${String(offset + i).padStart(6)}\t${line.slice(0, 2000)}`,
          )
          .join("\n")
      : "No lines in that range.";
  }
  const files = walk(target).map((file) => ({
    file,
    relative: path.relative(target, file).split(path.sep).join("/"),
  }));
  if (name === "Glob") {
    const matcher = globPattern(String(args.pattern));
    const matches = files.filter((entry) => matcher.test(entry.relative));
    return matches.length
      ? matches
          .slice(0, MAX_RESULTS)
          .map((entry) => entry.file)
          .join("\n")
      : "No files found.";
  }
  const glob = typeof args.glob === "string" ? args.glob : null;
  const filter = glob === null ? null : globPattern(glob);
  const expression = new RegExp(
    String(args.pattern),
    args.case_insensitive === true ? "i" : "",
  );
  /** @type {string[]} */
  const results = [];
  for (const { file, relative } of files) {
    if (
      filter &&
      !filter.test(glob?.includes("/") ? relative : path.basename(file))
    )
      continue;
    const hits = fs
      .readFileSync(file, "utf8")
      .split("\n")
      .flatMap((line, i) => (expression.test(line) ? [{ line, i }] : []));
    if (!hits.length) continue;
    if (args.output_mode === "content")
      results.push(...hits.map((hit) => `${file}:${hit.i + 1}:${hit.line}`));
    else if (args.output_mode === "count")
      results.push(`${file}:${hits.length}`);
    else results.push(file);
  }
  return results.length
    ? results.slice(0, MAX_RESULTS).join("\n")
    : "No matches found.";
}

/** @param {unknown} code */
function traceCode(code) {
  return typeof code === "string" && /^[a-z_]{1,64}$/.test(code)
    ? code
    : "unknown";
}

/** @param {number} retry @param {Headers | null} headers */
function retryDelay(retry, headers) {
  for (const [name, scale] of /** @type {const} */ ([
    ["retry-after-ms", 1],
    ["retry-after", 1000],
  ])) {
    const value = headers?.get(name)?.trim();
    if (value && Number.isFinite(Number(value)) && Number(value) >= 0)
      return Math.min(Number(value) * scale, MAX_RETRY_DELAY_MS);
  }
  return Math.min(1000 * 2 ** retry, MAX_RETRY_DELAY_MS);
}

/** @param {number} milliseconds @param {AbortSignal} signal */
function sleep(milliseconds, signal) {
  return new Promise((resolve, reject) => {
    const stop = () => {
      clearTimeout(timer);
      reject(new Error("aborted"));
    };
    const timer = setTimeout(() => {
      signal.removeEventListener("abort", stop);
      resolve(undefined);
    }, milliseconds);
    if (signal.aborted) stop();
    else signal.addEventListener("abort", stop, { once: true });
  });
}

/** One Responses API call with bounded same-key retries for throttling and
 * transient failures. Billing, authentication, and request errors never retry.
 * @param {FetchFunction} send @param {string} key @param {unknown} body
 * @param {AbortSignal} signal @param {Attempt} attempt */
async function createResponse(send, key, body, signal, attempt) {
  for (let retry = 0; ; retry++) {
    /** @type {Response | null} */
    let response = null;
    try {
      response = await send(ENDPOINT, {
        method: "POST",
        headers: {
          authorization: `Bearer ${key}`,
          "content-type": "application/json",
        },
        body: JSON.stringify(body),
        signal,
      });
      // Body reads can fail after fetch has successfully received headers.
      if (response.ok) return record(await response.json());
    } catch (error) {
      if (signal.aborted || error instanceof SyntaxError) throw error;
      attempt.trace.push({ event: "api_error", detail: "network" });
    }
    if (response && !response.ok) {
      const payload = await response.json().catch(() => null);
      const error = record(record(payload).error);
      const outcome = classifyOpenAIError(
        response.status,
        error.code,
        error.type,
      );
      attempt.trace.push({
        event: "api_error",
        detail: `${response.status}:${traceCode(error.code)}`,
      });
      if (outcome !== "retryable") throw new EvalFailure(outcome);
    }
    if (retry >= MAX_RETRIES) throw new EvalFailure("retry_exhausted");
    const delay = retryDelay(retry, response?.headers || null);
    attempt.trace.push({
      event: "api_retry",
      detail: `attempt=${retry + 1} delay_ms=${delay}`,
    });
    await sleep(delay, signal);
  }
}

/** @param {{input: number, cached: number, output: number, reasoning: number}} total @param {unknown} value */
function addUsage(total, value) {
  const usage = record(value);
  /** @param {unknown} count */
  const tokens = (count) =>
    typeof count === "number" && Number.isSafeInteger(count) && count >= 0
      ? count
      : 0;
  total.input += tokens(usage.input_tokens);
  total.cached += tokens(record(usage.input_tokens_details).cached_tokens);
  total.output += tokens(usage.output_tokens);
  total.reasoning += tokens(
    record(usage.output_tokens_details).reasoning_tokens,
  );
}

/** A stateless Responses API tool loop: every request carries the full
 * conversation, including reasoning items, and nothing is stored server-side.
 * @param {AdapterContext} context @param {SessionConfig} config @param {Dependencies} [dependencies] */
async function runSession(context, config, dependencies = {}) {
  const staged = stageCase(context);
  const controller = new AbortController();
  const abort = () => controller.abort();
  config.signal.addEventListener("abort", abort, { once: true });
  const timer = setTimeout(abort, config.timeout);
  const send = dependencies.fetch || fetch;
  const usage = { input: 0, cached: 0, output: 0, reasoning: 0 };
  let invoked = false;
  /** @type {unknown[]} */
  const input = [
    {
      role: "user",
      content: `Use the Skill tool to invoke ${SKILL} with args exactly ${staged.fixture}. Review that fixture and return the final findings and rubric snapshot.`,
    },
  ];
  try {
    if (config.signal.aborted) throw new EvalFailure("interrupted");
    for (let turn = 0; turn < config.maxTurns; turn++) {
      const response = await createResponse(
        send,
        config.key,
        {
          model: config.model,
          instructions: INSTRUCTIONS,
          input,
          tools: TOOL_DEFINITIONS,
          store: false,
        },
        controller.signal,
        config.attempt,
      );
      if (typeof response.model === "string")
        config.attempt.model = response.model;
      addUsage(usage, response.usage);
      if (response.status === "failed") {
        const error = record(response.error);
        config.attempt.trace.push({
          event: "api_error",
          detail: `failed:${traceCode(error.code)}`,
        });
        throw new EvalFailure(
          classifyOpenAIError(null, error.code, error.type),
        );
      }
      if (response.status !== "completed") {
        config.attempt.trace.push({ event: "result", detail: "incomplete" });
        throw new EvalFailure("incomplete_result");
      }
      const output = Array.isArray(response.output)
        ? response.output.map(record)
        : [];
      input.push(...output);
      const calls = output.filter((item) => item.type === "function_call");
      if (!calls.length) {
        config.attempt.trace.push({ event: "result", detail: "success" });
        const text = output
          .filter((item) => item.type === "message")
          .flatMap((item) =>
            Array.isArray(item.content) ? item.content.map(record) : [],
          )
          .filter(
            (part) =>
              part.type === "output_text" && typeof part.text === "string",
          )
          .map((part) => part.text)
          .join("\n");
        if (!invoked || !text.trim() || !config.attempt.model)
          throw new EvalFailure("missing_review_evidence");
        return text;
      }
      for (const call of calls) {
        if (typeof call.call_id !== "string")
          throw new EvalFailure("invalid_response");
        const name = String(call.name);
        /** @type {Record<string, unknown>} */
        let args = {};
        try {
          args = record(JSON.parse(String(call.arguments)));
        } catch {
          // Unparseable arguments fail the boundary check below.
        }
        const allowed = toolAllowed(staged.workspace, name, args, SKILL);
        config.attempt.trace.push({
          event: "tool",
          detail: `${TOOLS.includes(name) ? name : "other"}:${allowed ? "allow" : "deny"}`,
        });
        let result = "Error: Denied by the read-only eval input boundary.";
        if (allowed)
          try {
            result = runTool(staged.workspace, name, args);
            if (name === "Skill") {
              invoked = true;
              config.attempt.trace.push({
                event: "skill_invoked",
                detail: SKILL,
              });
            }
          } catch (error) {
            result = `Error: ${error instanceof Error ? error.message : "tool failed"}`;
          }
        input.push({
          type: "function_call_output",
          call_id: call.call_id,
          output: result.slice(0, MAX_TOOL_OUTPUT),
        });
      }
    }
    config.attempt.trace.push({ event: "result", detail: "error_max_turns" });
    throw new EvalFailure("incomplete_result");
  } catch (error) {
    // A timeout can surface as an aborted body read or retry wait.
    if (controller.signal.aborted)
      throw new EvalFailure(
        config.signal.aborted ? "interrupted" : "attempt_timeout",
      );
    if (error instanceof EvalFailure) throw error;
    throw new EvalFailure("runtime_error");
  } finally {
    clearTimeout(timer);
    config.signal.removeEventListener("abort", abort);
    if (usage.input || usage.output)
      config.attempt.trace.push({
        event: "usage",
        detail: `input=${usage.input} cached=${usage.cached} output=${usage.output} reasoning=${usage.reasoning}`,
      });
    fs.rmSync(staged.temporary, { recursive: true, force: true });
  }
}

function runtimeVersion() {
  return RUNTIME;
}

/** @param {AdapterContext} context @param {NodeJS.ProcessEnv} env @param {Dependencies} [dependencies] */
function predict(context, env, dependencies = {}) {
  return predictWithPool(
    context,
    env,
    PROVIDERS.openai,
    runSession,
    dependencies,
  );
}

if (require.main === module) runAdapter(predict);

module.exports = {
  PROFILE,
  SKILL,
  ENDPOINT,
  TOOL_DEFINITIONS,
  globPattern,
  retryDelay,
  runTool,
  runtimeVersion,
  runSession,
  predict,
};
