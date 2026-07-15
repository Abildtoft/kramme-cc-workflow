"use strict";

const YAML = require("yaml");
const { Scalar, isMap, isScalar, isSeq } = YAML;

const CODEX_DESCRIPTION_MAX_LENGTH = 1024;
const YAML_PARSE_OPTIONS = { prettyErrors: false };
const YAML_STRINGIFY_OPTIONS = { lineWidth: 0 };
const LEGACY_STRING_FLOW_KEYS = new Set([
  "argument-hint",
  "description",
  "disable-model-invocation",
  "model",
  "name",
  "summary",
  "user-invocable",
]);

/** @typedef {{ key?: unknown, treatSequenceItemAsMap?: boolean }} LegacyScalarOptions */

/** @param {unknown} value */
function stripWrappingQuotes(value) {
  const trimmed = String(value ?? "").trim();
  if (!trimmed) return "";
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'")) ||
    (trimmed.startsWith("`") && trimmed.endsWith("`"))
  ) {
    return trimmed.slice(1, -1);
  }
  return trimmed;
}

/** @param {unknown} value */
function normalizeName(value) {
  const trimmed = String(value ?? "").trim();
  if (!trimmed) return "item";
  const normalized = trimmed
    .toLowerCase()
    .replace(/[\\/]+/g, "-")
    .replace(/[:\s]+/g, "-")
    .replace(/[^a-z0-9_-]+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-+|-+$/g, "");
  return normalized || "item";
}

/** @param {unknown} value */
function codexName(value) {
  const trimmed = String(value ?? "").trim();
  if (!trimmed) return "item";
  const normalized = trimmed
    .toLowerCase()
    .replace(/[\\/]+/g, "-")
    .replace(/\s+/g, "-")
    .replace(/[^a-z0-9_:-]+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-+|-+$/g, "");
  return normalized || "item";
}

/** @param {unknown} value @param {number} [maxLength] */
function sanitizeDescription(value, maxLength = CODEX_DESCRIPTION_MAX_LENGTH) {
  const normalized = String(value ?? "")
    .replace(/\s+/g, " ")
    .trim();
  if (normalized.length <= maxLength) return normalized;
  const ellipsis = "...";
  return (
    normalized.slice(0, Math.max(0, maxLength - ellipsis.length)).trimEnd() +
    ellipsis
  );
}

/** @param {string} base @param {Set<string>} used */
function uniqueName(base, used) {
  if (!used.has(base)) {
    used.add(base);
    return base;
  }
  let index = 2;
  while (used.has(`${base}-${index}`)) {
    index += 1;
  }
  const name = `${base}-${index}`;
  used.add(name);
  return name;
}

/** @param {string} raw */
function parseFrontmatter(raw) {
  const lines = raw.split(/\r?\n/);
  if (lines.length === 0 || lines[0].trim() !== "---") {
    return { data: {}, body: raw };
  }

  const endIndex = findClosingFrontmatterDelimiter(lines);
  if (endIndex === -1) {
    return { data: {}, body: raw };
  }

  const yamlLines = lines.slice(1, endIndex);
  const body = lines.slice(endIndex + 1).join("\n");
  const data = parseYamlDocument(yamlLines.join("\n"));
  return { data, body };
}

/** @param {string[]} lines */
function findClosingFrontmatterDelimiter(lines) {
  for (let i = 1; i < lines.length; i += 1) {
    if (lines[i].trim() === "---") return i;
  }
  return -1;
}

/** @param {string} source @returns {Record<string, unknown>} */
function parseYamlDocument(source) {
  if (!String(source ?? "").trim()) return {};
  const normalizedSource = normalizeLegacyPlainScalars(source);
  const document = YAML.parseDocument(normalizedSource, YAML_PARSE_OPTIONS);
  if (document.errors.length > 0) {
    throw new Error(`Invalid frontmatter YAML: ${document.errors[0].message}`);
  }

  const value = yamlNodeToValue(document.contents);
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  return /** @type {Record<string, unknown>} */ (value);
}

/** @param {string} source */
function normalizeLegacyPlainScalars(source) {
  /** @type {string[]} */
  const normalized = [];
  let blockScalarParentIndent = null;

  const lines = String(source ?? "").split("\n");
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    if (blockScalarParentIndent !== null) {
      if (
        !String(line ?? "").trim() ||
        leadingWhitespaceLength(line) > blockScalarParentIndent
      ) {
        normalized.push(line);
        continue;
      }
      blockScalarParentIndent = null;
    }

    normalized.push(
      normalizeLegacyPlainScalarLine(line, {
        treatSequenceItemAsMap: shouldTreatSequenceItemAsMap(lines, index),
      }),
    );
    if (startsYamlBlockScalar(line)) {
      blockScalarParentIndent = leadingWhitespaceLength(line);
    }
  }

  return normalized.join("\n");
}

/** @param {string} line */
function startsYamlBlockScalar(line) {
  const value = yamlLineValue(line);
  if (!value) return false;
  const compactMapping = parseCompactMappingValue(value);
  const scalar = compactMapping ? compactMapping.value : value;
  return /^[|>][+-]?\d*(?:\s+#.*)?$/.test(scalar);
}

/** @param {string} line */
function yamlLineValue(line) {
  const raw = String(line ?? "");
  if (!raw.trim() || raw.trimStart().startsWith("#")) return null;

  const mappingMatch = raw.match(/^(\s*[^#\s][^:]*:\s+)(.+)$/);
  if (mappingMatch) return mappingMatch[2].trim();

  const sequenceMatch = raw.match(/^(\s*-\s+)(.+)$/);
  if (sequenceMatch) return sequenceMatch[2].trim();

  return null;
}

/** @param {string} line */
function leadingWhitespaceLength(line) {
  const match = String(line ?? "").match(/^[ \t]*/);
  return match ? match[0].length : 0;
}

/** @param {string} line @param {LegacyScalarOptions} [options] */
function normalizeLegacyPlainScalarLine(line, options = {}) {
  if (!String(line ?? "").trim() || String(line).trimStart().startsWith("#")) {
    return line;
  }

  const sequenceMatch = String(line).match(/^(\s*-\s+)(.+)$/);
  if (sequenceMatch) {
    const compactMapping = parseCompactMappingValue(sequenceMatch[2]);
    if (compactMapping && options.treatSequenceItemAsMap) {
      const value = compactMapping.value
        ? ` ${quoteLegacyPlainScalar(compactMapping.value, {
            key: compactMapping.key,
          })}`
        : "";
      return `${sequenceMatch[1]}${compactMapping.key}:${value}`;
    }
    return sequenceMatch[1] + quoteLegacyPlainScalar(sequenceMatch[2]);
  }

  const mappingMatch = String(line).match(/^(\s*([^#\s][^:]*):\s+)(.+)$/);
  if (mappingMatch) {
    return (
      mappingMatch[1] +
      quoteLegacyPlainScalar(mappingMatch[3], { key: mappingMatch[2] })
    );
  }

  return line;
}

/** @param {string[]} lines @param {number} index */
function shouldTreatSequenceItemAsMap(lines, index) {
  const line = String(lines[index] ?? "");
  const sequenceMatch = line.match(/^(\s*)-\s+(.+)$/);
  if (!sequenceMatch || !parseCompactMappingValue(sequenceMatch[2])) {
    return false;
  }

  const next = nextSignificantYamlLine(lines, index + 1);
  return Boolean(
    next && leadingWhitespaceLength(next) > leadingWhitespaceLength(line),
  );
}

/** @param {string[]} lines @param {number} startIndex */
function nextSignificantYamlLine(lines, startIndex) {
  for (let index = startIndex; index < lines.length; index += 1) {
    const line = String(lines[index] ?? "");
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    return line;
  }
  return null;
}

/** @param {unknown} value */
function parseCompactMappingValue(value) {
  const match = String(value ?? "").match(/^([^#\s][^:]*):(.*)$/);
  if (!match) return null;
  const separator = match[2];
  if (separator && !/^\s+/.test(separator)) return null;
  return { key: match[1].trim(), value: separator.trim() };
}

/** @param {string} value @param {LegacyScalarOptions} [options] */
function quoteLegacyPlainScalar(value, options = {}) {
  const trimmed = String(value ?? "").trim();
  if (!shouldQuoteLegacyPlainScalar(trimmed, options)) return value;
  return JSON.stringify(trimmed);
}

/** @param {string} value @param {LegacyScalarOptions} [options] */
function shouldQuoteLegacyPlainScalar(value, options = {}) {
  if (!value) return false;
  if (/^["']/.test(value)) return false;
  if (/^[\[{]/.test(value)) {
    if (LEGACY_STRING_FLOW_KEYS.has(String(options.key ?? "").trim())) {
      return true;
    }
    return !isValidYamlFlowCollection(value);
  }
  if (/^[|>]/.test(value)) return false;
  if (value === "true" || value === "false") return false;
  if (value === "null" || value === "~") return false;
  if (/^-?\d+(\.\d+)?$/.test(value)) return false;
  return true;
}

/** @param {unknown} value */
function isValidYamlFlowCollection(value) {
  const trimmed = String(value ?? "").trim();
  const isSequence = trimmed.startsWith("[");
  const isMapping = trimmed.startsWith("{");
  if (!isSequence && !isMapping) return false;
  if (isSequence && !trimmed.endsWith("]")) return false;
  if (isMapping && !trimmed.endsWith("}")) return false;

  const document = YAML.parseDocument(trimmed, YAML_PARSE_OPTIONS);
  if (document.errors.length > 0) return false;
  return isSequence ? isSeq(document.contents) : isMap(document.contents);
}

/** @param {unknown} node @returns {unknown} */
function yamlNodeToValue(node) {
  if (!node) return null;
  if (isScalar(node)) return yamlScalarToValue(node);
  if (isSeq(node)) return node.items.map((item) => yamlNodeToValue(item));
  if (isMap(node)) {
    /** @type {Record<string, unknown>} */
    const data = {};
    for (const pair of node.items) {
      if (!pair?.key) continue;
      const key = yamlNodeToValue(pair.key);
      if (key === undefined || key === null) continue;
      data[String(key)] = yamlNodeToValue(pair.value);
    }
    return data;
  }
  if (node && typeof node === "object" && "toJSON" in node) {
    const toJSON = /** @type {{ toJSON?: unknown }} */ (node).toJSON;
    if (typeof toJSON === "function") return toJSON.call(node);
  }
  return undefined;
}

/** @param {import("yaml").Scalar} node */
function yamlScalarToValue(node) {
  if (
    typeof node.value === "string" &&
    (node.type === Scalar.BLOCK_FOLDED || node.type === Scalar.BLOCK_LITERAL)
  ) {
    return node.value.trimEnd();
  }
  return node.value;
}

/** @param {Record<string, unknown>} data @param {string} body */
function formatFrontmatter(data, body) {
  const frontmatter = stripUndefinedEntries(data);
  const yaml = YAML.stringify(frontmatter, YAML_STRINGIFY_OPTIONS).trimEnd();

  if (yaml.trim().length === 0) {
    return body;
  }

  return ["---", yaml, "---", "", body].join("\n");
}

/** @param {Record<string, unknown>} data */
function stripUndefinedEntries(data) {
  /** @type {Record<string, unknown>} */
  const result = {};
  for (const [key, value] of Object.entries(data ?? {})) {
    if (value !== undefined) {
      result[key] = value;
    }
  }
  return result;
}

module.exports = {
  codexName,
  formatFrontmatter,
  normalizeName,
  parseFrontmatter,
  sanitizeDescription,
  stripWrappingQuotes,
  uniqueName,
};
