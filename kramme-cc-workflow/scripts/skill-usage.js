#!/usr/bin/env node
// @ts-check
"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");

const STATE_DIR = path.join(
  process.env.XDG_STATE_HOME || path.join(os.homedir(), ".local", "state"),
  "kramme-cc-workflow",
);
const DEFAULT_USAGE_FILE = path.join(STATE_DIR, "skill-usage.jsonl");
const SLASH_SKILL_PATTERN = /(?:^|\s)\/(kramme:[A-Za-z0-9:_-]+)/g;
const DIRECT_SKILL_PATTERN = /^\/?(kramme:[A-Za-z0-9:_-]+)(?:\s|$)/;
const SCAN_PRUNED_DIRS = new Set([
  ".cache",
  ".git",
  ".hg",
  ".next",
  ".npm",
  ".pnpm-store",
  ".svn",
  ".turbo",
  ".yarn",
  "build",
  "coverage",
  "dist",
  "node_modules",
]);

/**
 * @typedef {Object} ParsedArgs
 * @property {string[]} _
 * @property {boolean} [json]
 * @property {string} [file]
 * @property {string} [since]
 * @property {string} [kind]
 * @property {string} [limit]
 *
 * @typedef {Object} UsageRecord
 * @property {1} schemaVersion
 * @property {string} recordedAt
 * @property {string} sessionId
 * @property {string} cwd
 * @property {string} platform
 * @property {string} event
 * @property {string} skill
 * @property {"explicit" | "tool"} kind
 * @property {"prompt" | "tool_input"} source
 *
 * @typedef {Omit<UsageRecord, "source"> & { source: "scan", file: string }} ScannedUsageRecord
 * @typedef {UsageRecord | ScannedUsageRecord} UsageLikeRecord
 * @typedef {Object} UsageSummaryRow
 * @property {string} skill
 * @property {number} total
 * @property {number} explicit
 * @property {number} tool
 * @property {number} sessions
 * @property {string | null} firstUsedAt
 * @property {string | null} lastUsedAt
 *
 * @typedef {{ skill: string, total: string, explicit: string, tool: string, sessions: string, first: string, last: string }} PrintableUsageRow
 */

function main() {
  const [command, ...args] = process.argv.slice(2);

  if (
    !command ||
    command === "help" ||
    command === "--help" ||
    command === "-h"
  ) {
    printHelp(0);
    return;
  }

  if (command === "record") {
    record(args);
    return;
  }

  if (command === "report") {
    report(args);
    return;
  }

  if (command === "scan") {
    scan(args);
    return;
  }

  console.error(`Unknown command: ${command}`);
  printHelp(1);
}

/** @param {number} exitCode */
function printHelp(exitCode) {
  const help = `Usage:
  scripts/skill-usage.js record [--file <path>]
  scripts/skill-usage.js report [--file <path>] [--since <duration|date>] [--kind <explicit|tool|all>] [--json] [--limit <n>]
  scripts/skill-usage.js scan <file-or-dir...> [--since <duration|date>] [--json] [--limit <n>]

Records are stored in:
  ${DEFAULT_USAGE_FILE}

Environment:
  KRAMME_SKILL_USAGE_FILE  Override the usage JSONL file path.

Examples:
  scripts/skill-usage.js report --since 30d
  scripts/skill-usage.js report --kind explicit --json
  scripts/skill-usage.js scan ~/.claude/projects --json
`;
  const stream = exitCode === 0 ? process.stdout : process.stderr;
  stream.write(help);
  process.exit(exitCode);
}

/**
 * @param {string[]} args
 * @returns {ParsedArgs}
 */
function parseArgs(args) {
  /** @type {ParsedArgs} */
  const parsed = { _: [] };
  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i];
    if (arg === "--json") {
      parsed.json = true;
      continue;
    }
    if (arg === "--file") {
      parsed.file = args[++i];
      continue;
    }
    if (arg.startsWith("--file=")) {
      parsed.file = arg.slice("--file=".length);
      continue;
    }
    if (arg === "--since") {
      parsed.since = args[++i];
      continue;
    }
    if (arg.startsWith("--since=")) {
      parsed.since = arg.slice("--since=".length);
      continue;
    }
    if (arg === "--kind") {
      parsed.kind = args[++i];
      continue;
    }
    if (arg.startsWith("--kind=")) {
      parsed.kind = arg.slice("--kind=".length);
      continue;
    }
    if (arg === "--limit") {
      parsed.limit = args[++i];
      continue;
    }
    if (arg.startsWith("--limit=")) {
      parsed.limit = arg.slice("--limit=".length);
      continue;
    }
    parsed._.push(arg);
  }
  return parsed;
}

/** @param {ParsedArgs} parsed */
function usageFile(parsed) {
  return path.resolve(
    parsed.file || process.env.KRAMME_SKILL_USAGE_FILE || DEFAULT_USAGE_FILE,
  );
}

function readStdin() {
  return fs.readFileSync(0, "utf8");
}

/** @param {string[]} args */
function record(args) {
  const parsed = parseArgs(args);
  const inputText = readStdin();
  let input;

  try {
    input = inputText.trim() ? JSON.parse(inputText) : {};
  } catch {
    process.stdout.write("{}\n");
    return;
  }

  const records = buildUsageRecords(input);
  if (records.length === 0) {
    process.stdout.write("{}\n");
    return;
  }

  const file = usageFile(parsed);
  ensureUsageFile(file);
  appendJsonLines(file, records);
  process.stdout.write("{}\n");
}

/**
 * @param {unknown} input
 * @returns {UsageRecord[]}
 */
function buildUsageRecords(input) {
  const value = asRecord(input);
  const recordedAt = new Date().toISOString();
  /** @type {Omit<UsageRecord, "skill" | "kind" | "source">} */
  const base = {
    schemaVersion: 1,
    recordedAt,
    sessionId: stringValue(
      value.session_id ??
        value.sessionId ??
        value.conversation_id ??
        value.conversationId,
    ),
    cwd: stringValue(value.cwd ?? value.workspace ?? value.project_dir),
    platform: stringValue(value.platform ?? process.env.KRAMME_AGENT_PLATFORM),
    event: stringValue(
      value.hook_event_name ?? value.hookEventName ?? value.event ?? value.type,
    ),
  };

  /** @type {UsageRecord[]} */
  const records = [];
  for (const skill of extractPromptSkills(value)) {
    records.push({
      ...base,
      skill,
      kind: "explicit",
      source: "prompt",
    });
  }

  for (const skill of extractToolSkills(value)) {
    records.push({
      ...base,
      skill,
      kind: "tool",
      source: "tool_input",
    });
  }

  return dedupeRecords(records);
}

/** @param {Record<string, unknown>} input @returns {string[]} */
function extractPromptSkills(input) {
  const payload = asRecord(input.payload);
  const messages = Array.isArray(input.messages)
    ? input.messages[input.messages.length - 1]
    : undefined;
  const payloadMessages = Array.isArray(payload.messages)
    ? payload.messages[payload.messages.length - 1]
    : undefined;
  const roots = [
    input.prompt,
    input.message,
    messages,
    input.body,
    input.text,
    input.content,
    payload.prompt,
    payload.message,
    payloadMessages,
  ];
  return unique(
    roots
      .flatMap((root) => collectStrings(root))
      .flatMap((text) => extractSlashSkillNames(text)),
  );
}

/** @param {Record<string, unknown>} input @returns {string[]} */
function extractScannedPromptSkills(input) {
  const payload = asRecord(input.payload);
  const message = input.message;
  const messageRecord = asRecord(message);
  const payloadMessage = payload.message;
  const payloadMessageRecord = asRecord(payloadMessage);
  const roots = [
    input.prompt,
    typeof message === "string"
      ? message
      : [messageRecord.content, messageRecord.text],
    input.body,
    input.text,
    input.content,
    payload.prompt,
    typeof payloadMessage === "string"
      ? payloadMessage
      : [payloadMessageRecord.content, payloadMessageRecord.text],
    payload.body,
    payload.text,
    payload.content,
  ];

  return unique(
    roots
      .flatMap((root) => collectPromptText(root))
      .flatMap((text) => extractSlashSkillNames(text)),
  );
}

/** @param {Record<string, unknown>} input @returns {string[]} */
function extractToolSkills(input) {
  const toolName = stringValue(
    input.tool_name ?? input.toolName ?? input.tool ?? input.name,
  ).toLowerCase();
  const toolInput = asRecord(input.tool_input ?? input.toolInput);

  if (toolName !== "skill" && !hasSkillToolShape(toolInput)) {
    return [];
  }

  const candidates = [
    toolInput.name,
    toolInput.skill,
    toolInput.skill_name,
    toolInput.skillName,
    toolInput.command,
    toolInput.prompt,
    toolInput.text,
  ];

  return unique(
    candidates.flatMap((candidate) => {
      if (typeof candidate !== "string") return [];
      return [
        ...extractDirectSkillName(candidate),
        ...extractSlashSkillNames(candidate),
      ];
    }),
  );
}

/** @param {Record<string, unknown>} toolInput */
function hasSkillToolShape(toolInput) {
  return Boolean(
    toolInput &&
    typeof toolInput === "object" &&
    (toolInput.skill || toolInput.skill_name || toolInput.skillName),
  );
}

/** @param {unknown} text @returns {string[]} */
function extractSlashSkillNames(text) {
  if (typeof text !== "string") return [];
  /** @type {string[]} */
  const names = [];
  for (const match of text.matchAll(SLASH_SKILL_PATTERN)) {
    names.push(match[1]);
  }
  return names;
}

/** @param {unknown} text @returns {string[]} */
function extractDirectSkillName(text) {
  const match = String(text).match(DIRECT_SKILL_PATTERN);
  return match ? [match[1]] : [];
}

/** @param {unknown} value @param {number} [depth] @returns {string[]} */
function collectStrings(value, depth = 0) {
  if (value == null || depth > 8) return [];
  if (typeof value === "string") return [value];
  if (Array.isArray(value)) {
    return value.flatMap((entry) => collectStrings(entry, depth + 1));
  }
  if (typeof value !== "object") return [];

  return Object.values(asRecord(value)).flatMap((entry) =>
    collectStrings(entry, depth + 1),
  );
}

/** @param {unknown} value @param {number} [depth] @returns {string[]} */
function collectPromptText(value, depth = 0) {
  if (value == null || depth > 8) return [];
  if (typeof value === "string") return [value];
  if (Array.isArray(value)) {
    return value.flatMap((entry) => collectPromptText(entry, depth + 1));
  }
  if (typeof value !== "object") return [];

  const record = asRecord(value);
  const blockType = stringValue(record.type).toLowerCase();
  if (blockType === "tool_result") return [];
  if (blockType === "text" || blockType === "input_text") {
    return [record.text, record.content].flatMap((entry) =>
      collectPromptText(entry, depth + 1),
    );
  }
  if (blockType) return [];

  return [record.text, record.content].flatMap((entry) =>
    collectPromptText(entry, depth + 1),
  );
}

/** @param {string[]} values @returns {string[]} */
function unique(values) {
  return [...new Set(values.filter(Boolean))];
}

/**
 * @param {UsageRecord[]} records
 * @returns {UsageRecord[]}
 */
function dedupeRecords(records) {
  const seen = new Set();
  const deduped = [];
  for (const record of records) {
    const key = `${record.kind}:${record.skill}`;
    if (seen.has(key)) continue;
    seen.add(key);
    deduped.push(record);
  }
  return deduped;
}

/** @param {string} file */
function ensureUsageFile(file) {
  fs.mkdirSync(path.dirname(file), { recursive: true, mode: 0o700 });
  if (!fs.existsSync(file)) {
    fs.closeSync(fs.openSync(file, "a", 0o600));
  }
}

/** @param {string} file @param {UsageRecord[]} records */
function appendJsonLines(file, records) {
  const lines =
    records.map((record) => JSON.stringify(record)).join("\n") + "\n";
  fs.appendFileSync(file, lines, { mode: 0o600 });
}

/** @param {string[]} args */
function report(args) {
  const parsed = parseArgs(args);
  const file = usageFile(parsed);
  const since = parseSince(parsed.since);
  const kind = parsed.kind || "all";
  const limit = parsed.limit == null ? null : Number(parsed.limit);

  if (!["all", "explicit", "tool"].includes(kind)) {
    throw new Error(`Unknown kind: ${kind}`);
  }
  if (limit != null && (!Number.isInteger(limit) || limit < 1)) {
    throw new Error(`Invalid --limit value: ${parsed.limit}`);
  }

  const records = readRecords(file).filter((record) => {
    if (kind !== "all" && record.kind !== kind) return false;
    if (!since) return true;
    const recordedAt = Date.parse(record.recordedAt);
    return Number.isFinite(recordedAt) && recordedAt >= since.getTime();
  });

  const summary = summarize(records, limit);
  if (parsed.json) {
    process.stdout.write(JSON.stringify(summary, null, 2) + "\n");
    return;
  }

  renderTable(summary, file, since, kind);
}

/** @param {string[]} args */
function scan(args) {
  const parsed = parseArgs(args);
  const since = parseSince(parsed.since);
  const limit = parsed.limit == null ? null : Number(parsed.limit);

  if (parsed._.length === 0) {
    throw new Error("scan requires at least one file or directory path");
  }
  if (limit != null && (!Number.isInteger(limit) || limit < 1)) {
    throw new Error(`Invalid --limit value: ${parsed.limit}`);
  }

  const records = parsed._.flatMap((entry) =>
    scanPath(path.resolve(entry)),
  ).filter((record) => {
    if (!since) return true;
    const recordedAt = Date.parse(record.recordedAt);
    return Number.isFinite(recordedAt) && recordedAt >= since.getTime();
  });
  const summary = summarize(records, limit);

  if (parsed.json) {
    process.stdout.write(JSON.stringify(summary, null, 2) + "\n");
    return;
  }

  renderTable(summary, parsed._.join(","), since, "explicit");
}

/** @param {string} entry @returns {ScannedUsageRecord[]} */
function scanPath(entry) {
  if (!fs.existsSync(entry)) return [];
  const stat = fs.statSync(entry);
  if (stat.isDirectory()) {
    if (shouldPruneScanDirectory(entry)) return [];
    return fs
      .readdirSync(entry)
      .flatMap((child) => scanPath(path.join(entry, child)));
  }
  if (!stat.isFile()) return [];

  return scanFile(entry);
}

/** @param {string} entry */
function shouldPruneScanDirectory(entry) {
  return SCAN_PRUNED_DIRS.has(path.basename(entry));
}

/** @param {string} file @returns {ScannedUsageRecord[]} */
function scanFile(file) {
  const content = fs.readFileSync(file, "utf8");
  let parsedJsonLine = false;
  const lineRecords = content
    .split(/\r?\n/)
    .filter(Boolean)
    .flatMap((line) => {
      try {
        const parsed = JSON.parse(line);
        parsedJsonLine = true;
        return recordsFromScannedObject(parsed, file);
      } catch {
        return [];
      }
    });

  if (parsedJsonLine) return lineRecords;

  try {
    return recordsFromScannedObject(JSON.parse(content), file);
  } catch {
    return extractSlashSkillNames(content).map((skill) =>
      scannedRecord({ skill, file }),
    );
  }
}

/** @param {unknown} input @param {string} file @returns {ScannedUsageRecord[]} */
function recordsFromScannedObject(input, file) {
  if (Array.isArray(input)) {
    return input.flatMap((entry) => recordsFromScannedObject(entry, file));
  }
  if (!input || typeof input !== "object") return [];
  const record = asRecord(input);
  const payload = asRecord(record.payload);

  const messages = Array.isArray(record.messages)
    ? record.messages
    : Array.isArray(payload.messages)
      ? payload.messages
      : null;
  if (messages) {
    return messages.flatMap((message) => {
      const messageRecord = asRecord(message);
      return recordsFromScannedObject(
        {
          ...messageRecord,
          session_id: messageRecord.session_id ?? record.session_id,
          sessionId: messageRecord.sessionId ?? record.sessionId,
        },
        file,
      );
    });
  }

  if (!isUserMessage(record)) return [];
  const message = asRecord(record.message);
  const recordedAt = firstString(
    record.recordedAt,
    record.timestamp,
    record.created_at,
    record.createdAt,
    message.createdAt,
    message.timestamp,
  );
  return extractScannedPromptSkills(record).map((skill) =>
    scannedRecord({
      skill,
      file,
      recordedAt,
      sessionId: firstString(
        record.session_id,
        record.sessionId,
        record.conversation_id,
        record.conversationId,
      ),
    }),
  );
}

/** @param {{ skill: string, file: string, recordedAt?: string, sessionId?: string }} input @returns {ScannedUsageRecord} */
function scannedRecord({ skill, file, recordedAt = "", sessionId = "" }) {
  return {
    schemaVersion: 1,
    recordedAt,
    sessionId,
    cwd: "",
    platform: "",
    event: "scan",
    skill,
    kind: "explicit",
    source: "scan",
    file,
  };
}

/** @param {Record<string, unknown>} input */
function isUserMessage(input) {
  const role = firstString(
    input.role,
    input.type,
    asRecord(input.message).role,
  );
  return !role || ["user", "human"].includes(role.toLowerCase());
}

/** @param {string} file @returns {UsageRecord[]} */
function readRecords(file) {
  if (!fs.existsSync(file)) return [];
  const content = fs.readFileSync(file, "utf8");
  return content
    .split(/\r?\n/)
    .filter(Boolean)
    .flatMap((line) => {
      try {
        const record = normalizeUsageRecord(JSON.parse(line));
        return record ? [record] : [];
      } catch {
        return [];
      }
    });
}

/** @param {unknown} value @returns {UsageRecord | null} */
function normalizeUsageRecord(value) {
  const record = asRecord(value);
  if (typeof record.skill !== "string") return null;
  const kind = record.kind === "tool" ? "tool" : "explicit";
  return {
    schemaVersion: 1,
    recordedAt: stringValue(record.recordedAt),
    sessionId: stringValue(record.sessionId),
    cwd: stringValue(record.cwd),
    platform: stringValue(record.platform),
    event: stringValue(record.event),
    skill: record.skill,
    kind,
    source: kind === "tool" ? "tool_input" : "prompt",
  };
}

/** @param {UsageLikeRecord[]} records @param {number | null} limit @returns {UsageSummaryRow[]} */
function summarize(records, limit) {
  /** @type {Map<string, Omit<UsageSummaryRow, "sessions"> & { sessions: Set<string> }>} */
  const bySkill = new Map();

  for (const record of records) {
    const key = record.skill;
    let entry = bySkill.get(key);
    if (!entry) {
      entry = {
        skill: key,
        total: 0,
        explicit: 0,
        tool: 0,
        firstUsedAt: null,
        lastUsedAt: null,
        sessions: new Set(),
      };
      bySkill.set(key, entry);
    }

    entry.total += 1;
    if (record.kind === "tool") entry.tool += 1;
    else entry.explicit += 1;
    if (record.sessionId) entry.sessions.add(record.sessionId);

    const timestamp = stringValue(record.recordedAt);
    if (timestamp) {
      if (!entry.firstUsedAt || timestamp < entry.firstUsedAt) {
        entry.firstUsedAt = timestamp;
      }
      if (!entry.lastUsedAt || timestamp > entry.lastUsedAt) {
        entry.lastUsedAt = timestamp;
      }
    }
  }

  const rows = [...bySkill.values()]
    .map((entry) => ({
      ...entry,
      sessions: entry.sessions.size,
    }))
    .sort((a, b) => b.total - a.total || a.skill.localeCompare(b.skill));

  return limit == null ? rows : rows.slice(0, limit);
}

/** @param {string | undefined} value @returns {Date | null} */
function parseSince(value) {
  if (!value) return null;
  const match = String(value).match(/^(\d+)([mhdw])$/);
  if (match) {
    const amount = Number(match[1]);
    const unit = match[2];
    /** @type {Record<string, number>} */
    const multipliers = {
      m: 60 * 1000,
      h: 60 * 60 * 1000,
      d: 24 * 60 * 60 * 1000,
      w: 7 * 24 * 60 * 60 * 1000,
    };
    return new Date(Date.now() - amount * multipliers[unit]);
  }

  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new Error(`Invalid --since value: ${value}`);
  }
  return parsed;
}

/** @param {UsageSummaryRow[]} rows @param {string} file @param {Date | null} since @param {string} kind */
function renderTable(rows, file, since, kind) {
  if (rows.length === 0) {
    process.stdout.write("No skill usage records found.\n");
    return;
  }

  /** @type {PrintableUsageRow[]} */
  const printableRows = rows.map((row) => ({
    skill: row.skill,
    total: String(row.total),
    explicit: String(row.explicit),
    tool: String(row.tool),
    sessions: String(row.sessions),
    first: compactDate(row.firstUsedAt),
    last: compactDate(row.lastUsedAt),
  }));

  /** @type {Array<[string, keyof PrintableUsageRow]>} */
  const columns = [
    ["Skill", "skill"],
    ["Total", "total"],
    ["Explicit", "explicit"],
    ["Tool", "tool"],
    ["Sessions", "sessions"],
    ["First Used", "first"],
    ["Last Used", "last"],
  ];
  const widths = columns.map(([label, key]) =>
    Math.max(label.length, ...printableRows.map((row) => row[key].length)),
  );

  const header = columns
    .map(([label], index) => label.padEnd(widths[index]))
    .join("  ");
  const divider = widths.map((width) => "-".repeat(width)).join("  ");
  const body = printableRows
    .map((row) =>
      columns
        .map(([, key], index) => row[key].padEnd(widths[index]))
        .join("  "),
    )
    .join("\n");

  const filters = [
    `file=${file}`,
    since ? `since=${since.toISOString()}` : null,
    kind !== "all" ? `kind=${kind}` : null,
  ].filter(Boolean);

  process.stdout.write(
    `${filters.join(" ")}\n${header}\n${divider}\n${body}\n`,
  );
}

/** @param {string | null} value */
function compactDate(value) {
  if (!value) return "-";
  return value.replace("T", " ").replace(/\.\d{3}Z$/, "Z");
}

/** @param {unknown} value */
function stringValue(value) {
  return typeof value === "string" ? value : "";
}

/** @param {...unknown} values */
function firstString(...values) {
  return values.find((value) => typeof value === "string") || "";
}

function runCli() {
  try {
    main();
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exit(1);
  }
}

/** @param {unknown} value @returns {Record<string, unknown>} */
function asRecord(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? /** @type {Record<string, unknown>} */ (value)
    : {};
}

if (require.main === module) {
  runCli();
}

module.exports = {
  runCli,
};
