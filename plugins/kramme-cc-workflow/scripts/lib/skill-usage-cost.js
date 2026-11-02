// @ts-check
"use strict";

const fs = require("fs");
const path = require("path");

const TOOL_ONLY_ROW = "(tool only)";
const UNKNOWN_AGENT_TYPE = "(unknown)";
// Claude Code writes this phrase into the assistant API-error record it
// appends when the subscription session limit stops a turn.
const LIMIT_HIT_TEXT = "hit your session limit";
const PLUGIN_PREFIX = "kramme-cc-workflow:";
const SUBAGENT_FILE_PATTERN = /^agent-(.+)\.jsonl$/;
const TABLE_AGENT_TYPES = 3;

/**
 * @typedef {{ line: string | null, overlong: boolean }} CostLine
 * @typedef {{ skippedLines: number, readFailures: number }} CostDiagnostics
 * @typedef {Object} CostDeps
 * @property {(file: string) => AsyncIterable<CostLine>} readLines
 * @property {(file: string, count: number, reason: string) => void} skipped
 * @property {(file: string, error: unknown) => void} readFailure
 * @typedef {{ transcript: string, subagentsDir: string | null }} TranscriptEntry
 * @typedef {{ transcript: string, meta: string }} SubagentEntry
 * @typedef {{ sessionId: string, recordedAt: string, kind: string, skill: string }} CostUsageRecord
 * @typedef {{ sessionId: string, entrySkill: string }} EntrySession
 * @typedef {{ agentType: string, modelOverride: boolean, weightedTokens: number }} SubagentSummary
 * @typedef {{ costUSD: number | null, unknownModelCost: boolean, limitHit: boolean, weightedTokens: number, readSucceeded: boolean }} ScannedTranscriptFacts
 * @typedef {{ costUSD: number | null, unknownModelCost: boolean, limitHit: boolean, weightedTokens: number }} TranscriptFacts
 * @typedef {TranscriptFacts & { hasTranscript: boolean, subagents: SubagentSummary[] }} SessionSummary
 * @typedef {ReturnType<typeof buildRow>} CostRow
 */

/**
 * Weights one assistant usage block by relative API price: cache writes cost
 * 1.25x input, cache reads 0.1x, and output 5x.
 * @param {unknown} usage
 */
function weightedTokens(usage) {
  const value = asRecord(usage);
  return (
    count(value.input_tokens) +
    1.25 * count(value.cache_creation_input_tokens) +
    0.1 * count(value.cache_read_input_tokens) +
    5 * count(value.output_tokens)
  );
}

/** @param {number[]} values @returns {number | null} */
function median(values) {
  if (values.length === 0) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 1
    ? sorted[middle]
    : (sorted[middle - 1] + sorted[middle]) / 2;
}

/**
 * Picks each session's entry skill: its earliest explicit record, or the
 * `(tool only)` row when the session has only tool records. `since` applies
 * to that entry record, or to the earliest record of a tool-only session.
 * The recorder appends each session's records in order, so the first record
 * seen is the earliest.
 */
function createSessionGrouper() {
  /** @type {Map<string, { explicit: CostUsageRecord | null, first: CostUsageRecord }>} */
  const sessions = new Map();
  return {
    /** @param {CostUsageRecord} record */
    add(record) {
      if (!record.sessionId) return;
      const session = sessions.get(record.sessionId) || {
        explicit: null,
        first: record,
      };
      if (!session.explicit && record.kind === "explicit") {
        session.explicit = record;
      }
      sessions.set(record.sessionId, session);
    },
    /** @param {Date | null} since @returns {EntrySession[]} */
    entries(since) {
      /** @type {EntrySession[]} */
      const result = [];
      for (const [sessionId, session] of sessions) {
        const entry = session.explicit || session.first;
        if (since) {
          const recordedAt = Date.parse(entry.recordedAt);
          if (!Number.isFinite(recordedAt) || recordedAt < since.getTime()) {
            continue;
          }
        }
        result.push({
          sessionId,
          entrySkill: session.explicit ? session.explicit.skill : TOOL_ONLY_ROW,
        });
      }
      return result;
    },
  };
}

/**
 * Maps session ids to `<project>/<id>.jsonl` and the optional
 * `<project>/<id>/subagents` directory using directory listings only.
 * @param {string} projectsDir
 * @param {Pick<CostDeps, "readFailure">} sink
 * @returns {Promise<Map<string, TranscriptEntry>>}
 */
async function indexTranscripts(projectsDir, sink) {
  /** @type {Map<string, TranscriptEntry>} */
  const index = new Map();
  const projects = await listDirectory(projectsDir, sink);
  for (const project of projects) {
    if (!project.isDirectory()) continue;
    const projectDir = path.join(projectsDir, project.name);
    const entries = await listDirectory(projectDir, sink);
    const sessionDirs = new Set(
      entries.filter((entry) => entry.isDirectory()).map((entry) => entry.name),
    );
    for (const entry of entries) {
      if (!entry.isFile() || !entry.name.endsWith(".jsonl")) continue;
      const sessionId = entry.name.slice(0, -".jsonl".length);
      if (!sessionId || index.has(sessionId)) continue;
      index.set(sessionId, {
        transcript: path.join(projectDir, entry.name),
        subagentsDir: sessionDirs.has(sessionId)
          ? path.join(projectDir, sessionId, "subagents")
          : null,
      });
    }
  }
  return index;
}

/** @param {string} dir @param {Pick<CostDeps, "readFailure">} sink @param {boolean} [ignoreMissing] @returns {Promise<fs.Dirent[]>} */
async function listDirectory(dir, sink, ignoreMissing = false) {
  try {
    const entries = await fs.promises.readdir(dir, { withFileTypes: true });
    return entries.sort((a, b) => a.name.localeCompare(b.name));
  } catch (error) {
    if (!(ignoreMissing && asRecord(error).code === "ENOENT")) {
      sink.readFailure(dir, error);
    }
    return [];
  }
}

/**
 * Finds direct and workflow-nested subagent transcripts. Workflow directories
 * can be nested, while journal files are ignored because they are not agent
 * transcripts.
 * @param {string} dir
 * @param {Pick<CostDeps, "readFailure">} sink
 * @returns {Promise<SubagentEntry[]>}
 */
async function listSubagentFiles(dir, sink) {
  /** @type {SubagentEntry[]} */
  const result = [];
  for (const entry of await listDirectory(dir, sink, true)) {
    const child = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      result.push(...(await listSubagentFiles(child, sink)));
      continue;
    }
    const match = entry.isFile() ? SUBAGENT_FILE_PATTERN.exec(entry.name) : null;
    if (!match) continue;
    result.push({
      transcript: child,
      meta: path.join(dir, `agent-${match[1]}.meta.json`),
    });
  }
  return result;
}

/** @param {TranscriptEntry | undefined} entry @param {CostDeps} deps @returns {Promise<SessionSummary>} */
async function summarizeSession(entry, deps) {
  if (!entry) return { ...emptyFacts(), hasTranscript: false, subagents: [] };

  const mainScan = await scanTranscript(entry.transcript, deps);
  const { readSucceeded, ...main } = mainScan;
  /** @type {SubagentSummary[]} */
  const subagents = [];
  const dir = entry.subagentsDir;
  for (const file of dir ? await listSubagentFiles(dir, deps) : []) {
    const meta = await readSubagentMeta(file.meta, deps);
    const scanned = await scanTranscript(file.transcript, deps);
    subagents.push({ ...meta, weightedTokens: scanned.weightedTokens });
  }
  return { ...main, hasTranscript: readSucceeded, subagents };
}

/** @returns {TranscriptFacts} */
function emptyFacts() {
  return {
    costUSD: null,
    unknownModelCost: false,
    limitHit: false,
    weightedTokens: 0,
  };
}

/**
 * Streams one transcript. Only lines naming `cost-state` or `assistant` are
 * parsed, and each assistant `message.id` counts once because Claude Code
 * repeats the same usage on every content-block line of a message.
 * @param {string} file @param {CostDeps} deps
 * @returns {Promise<ScannedTranscriptFacts>}
 */
async function scanTranscript(file, deps) {
  const result = emptyFacts();
  /** @type {Set<string>} */
  const seenMessages = new Set();
  let overlongLines = 0;
  let malformedLines = 0;
  let readSucceeded = true;

  try {
    for await (const boundedLine of deps.readLines(file)) {
      if (boundedLine.overlong) {
        overlongLines += 1;
        continue;
      }
      const line = boundedLine.line || "";
      if (!line.includes('"cost-state"') && !line.includes('"assistant"')) {
        continue;
      }
      const record = parseObject(line);
      if (!record) {
        malformedLines += 1;
        continue;
      }
      if (record.type === "cost-state") {
        // Snapshots are cumulative, so the last one is the session total.
        if (typeof record.totalCostUSD === "number") {
          result.costUSD = record.totalCostUSD;
          result.unknownModelCost = record.hasUnknownModelCost === true;
        }
        continue;
      }
      if (record.type !== "assistant") continue;
      const message = asRecord(record.message);
      if (record.isApiErrorMessage === true && hasLimitText(message.content)) {
        result.limitHit = true;
      }
      if (typeof message.id === "string") {
        if (seenMessages.has(message.id)) continue;
        seenMessages.add(message.id);
      }
      result.weightedTokens += weightedTokens(message.usage);
    }
  } catch (error) {
    readSucceeded = false;
    deps.readFailure(file, error);
  }

  deps.skipped(file, overlongLines, "overlong JSONL");
  deps.skipped(file, malformedLines, "malformed JSONL");
  return { ...result, readSucceeded };
}

/** @param {unknown} content */
function hasLimitText(content) {
  return (
    Array.isArray(content) &&
    content.some(
      (block) =>
        asRecord(block).type === "text" &&
        String(asRecord(block).text).includes(LIMIT_HIT_TEXT),
    )
  );
}

/**
 * Reads only `agentType` and whether `model` overrides the parent model; the
 * task `description` is never retained.
 * @param {string} file @param {CostDeps} deps
 */
async function readSubagentMeta(file, deps) {
  let line = "";
  try {
    for await (const boundedLine of deps.readLines(file)) {
      line = boundedLine.line || "";
      break;
    }
  } catch (error) {
    deps.readFailure(file, error);
    return { agentType: UNKNOWN_AGENT_TYPE, modelOverride: false };
  }
  const meta = parseObject(line) || {};
  if (typeof meta.agentType !== "string" || meta.agentType === "") {
    deps.skipped(file, 1, "invalid subagent meta");
    return { agentType: UNKNOWN_AGENT_TYPE, modelOverride: false };
  }
  return {
    agentType: meta.agentType,
    modelOverride: typeof meta.model === "string" && meta.model.trim() !== "",
  };
}

/** @param {Array<{ entrySkill: string, summary: SessionSummary }>} sessions @returns {CostRow[]} */
function buildCostRows(sessions) {
  /** @type {Map<string, Array<SessionSummary>>} */
  const bySkill = new Map();
  for (const { entrySkill, summary } of sessions) {
    const group = bySkill.get(entrySkill) || [];
    group.push(summary);
    bySkill.set(entrySkill, group);
  }

  return [...bySkill]
    .map(([entrySkill, summaries]) => buildRow(entrySkill, summaries))
    .sort(
      (a, b) =>
        b.totalCostUSD - a.totalCostUSD ||
        b.sessions - a.sessions ||
        a.entrySkill.localeCompare(b.entrySkill),
    );
}

/** @param {string} entrySkill @param {SessionSummary[]} summaries */
function buildRow(entrySkill, summaries) {
  /** @type {number[]} */
  const costs = [];
  /** @type {Map<string, { agentType: string, launches: number, modelOverrides: number, weightedTokens: number }>} */
  const agentTypes = new Map();
  let mainTokens = 0;
  let subagentTokens = 0;
  for (const summary of summaries) {
    if (summary.costUSD != null) costs.push(summary.costUSD);
    mainTokens += summary.weightedTokens;
    for (const subagent of summary.subagents) {
      subagentTokens += subagent.weightedTokens;
      const agent = agentTypes.get(subagent.agentType) || {
        agentType: subagent.agentType,
        launches: 0,
        modelOverrides: 0,
        weightedTokens: 0,
      };
      agent.launches += 1;
      if (subagent.modelOverride) agent.modelOverrides += 1;
      agent.weightedTokens += subagent.weightedTokens;
      agentTypes.set(subagent.agentType, agent);
    }
  }
  const allTokens = mainTokens + subagentTokens;
  const maxCost = costs.length === 0 ? null : Math.max(...costs);
  const medianCost = median(costs);

  return {
    entrySkill,
    sessions: summaries.length,
    sessionsWithTranscript: countWhere(summaries, (s) => s.hasTranscript),
    sessionsWithCost: costs.length,
    totalCostUSD: roundUSD(sum(costs, (cost) => cost)),
    medianCostUSD: medianCost == null ? null : roundUSD(medianCost),
    maxCostUSD: maxCost == null ? null : roundUSD(maxCost),
    unknownModelCostSessions: countWhere(summaries, (s) => s.unknownModelCost),
    limitHitSessions: countWhere(summaries, (s) => s.limitHit),
    mainWeightedTokens: Math.round(mainTokens),
    subagentWeightedTokens: Math.round(subagentTokens),
    subagentShare: share(subagentTokens, allTokens),
    agentTypes: [...agentTypes.values()]
      .sort(
        (a, b) =>
          b.weightedTokens - a.weightedTokens ||
          a.agentType.localeCompare(b.agentType),
      )
      .map((agent) => ({
        ...agent,
        weightedTokens: Math.round(agent.weightedTokens),
        share: share(agent.weightedTokens, allTokens),
      })),
  };
}

/** @param {CostRow[]} rows @param {CostDiagnostics} diagnostics @param {boolean | undefined} json @param {Date | null} since @returns {string} */
function renderCost(rows, diagnostics, json, since) {
  const degraded = diagnostics.skippedLines > 0 || diagnostics.readFailures > 0;
  if (json) {
    const result = degraded ? { summary: rows, diagnostics } : rows;
    return JSON.stringify(result, null, 2) + "\n";
  }

  const filters = since ? ` since=${since.toISOString()}` : "";
  let output = `API-equivalent cost from local Claude Code cost-state records${filters}\n`;
  if (rows.length === 0) {
    output += "No Claude Code skill sessions found.\n";
  } else {
    output += renderTable(rows);
  }
  if (degraded) {
    output += `diagnostics skippedLines=${diagnostics.skippedLines} readFailures=${diagnostics.readFailures}\n`;
  }
  return output;
}

/** @param {CostRow[]} rows */
function renderTable(rows) {
  const columns =
    "Entry Skill|Sessions|Transcripts|Total $|Median $|Limit Hits|Subagent Share|Top Agent Types".split(
      "|",
    );
  const body = rows.map((row) => [
    row.entrySkill,
    String(row.sessions),
    String(row.sessionsWithTranscript),
    row.totalCostUSD.toFixed(2),
    row.medianCostUSD == null ? "-" : row.medianCostUSD.toFixed(2),
    String(row.limitHitSessions),
    percent(row.subagentShare),
    row.agentTypes
      .slice(0, TABLE_AGENT_TYPES)
      .map(
        (agent) =>
          `${agent.agentType.replace(PLUGIN_PREFIX, "")} ${percent(agent.share)}`,
      )
      .join(", ") || "-",
  ]);
  const widths = columns.map((label, index) =>
    Math.max(label.length, ...body.map((cells) => cells[index].length)),
  );
  /** @param {string[]} cells */
  const format = (cells) =>
    cells
      .map((cell, index) =>
        index === cells.length - 1 ? cell : cell.padEnd(widths[index]),
      )
      .join("  ");

  const subagentTokens = sum(rows, (row) => row.subagentWeightedTokens);
  const allTokens = sum(rows, (row) => row.mainWeightedTokens) + subagentTokens;
  const footer =
    `total sessions=${sum(rows, (row) => row.sessions)}` +
    ` transcripts=${sum(rows, (row) => row.sessionsWithTranscript)}` +
    ` cost=$${sum(rows, (row) => row.totalCostUSD).toFixed(2)}` +
    ` limitHits=${sum(rows, (row) => row.limitHitSessions)}` +
    ` subagentShare=${percent(share(subagentTokens, allTokens))}`;

  return [
    format(columns),
    widths.map((width) => "-".repeat(width)).join("  "),
    ...body.map(format),
    footer,
    "",
  ].join("\n");
}

/**
 * @template T
 * @param {T[]} items
 * @param {(item: T) => number} pick
 */
function sum(items, pick) {
  return items.reduce((total, item) => total + pick(item), 0);
}

/**
 * @template T
 * @param {T[]} items
 * @param {(item: T) => boolean} test
 */
function countWhere(items, test) {
  return items.filter(test).length;
}

/** @param {unknown} value */
function count(value) {
  return typeof value === "number" && Number.isFinite(value) && value > 0
    ? value
    : 0;
}

/** @param {number} value */
function roundUSD(value) {
  return Math.round(value * 100) / 100;
}

/** @param {number} part @param {number} whole */
function share(part, whole) {
  return whole > 0 ? Math.round((part / whole) * 10000) / 10000 : 0;
}

/** @param {number} value */
function percent(value) {
  return `${(value * 100).toFixed(1)}%`;
}

/** @param {string} line @returns {Record<string, unknown> | null} */
function parseObject(line) {
  try {
    return asRecord(JSON.parse(line));
  } catch {
    return null;
  }
}

/** @param {unknown} value @returns {Record<string, unknown>} */
function asRecord(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? /** @type {Record<string, unknown>} */ (value)
    : {};
}

module.exports = {
  TOOL_ONLY_ROW,
  buildCostRows,
  createSessionGrouper,
  indexTranscripts,
  median,
  renderCost,
  summarizeSession,
  weightedTokens,
};
