"use strict";

const CODEX_DESCRIPTION_MAX_LENGTH = 1024;

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
  const data = parseYamlLines(yamlLines);
  return { data, body };
}

function findClosingFrontmatterDelimiter(lines) {
  for (let i = 1; i < lines.length; i += 1) {
    if (lines[i].trim() === "---") return i;
  }
  return -1;
}

function parseYamlLines(lines) {
  const data = {};
  let currentKey = null;
  for (let i = 0; i < lines.length; i += 1) {
    const parsedLine = parseYamlLine(lines[i]);
    if (parsedLine.type === "empty" || parsedLine.type === "unsupported") {
      continue;
    }

    if (parsedLine.type === "sequence-item") {
      if (!currentKey) continue;
      if (!Array.isArray(data[currentKey])) {
        data[currentKey] = [];
      }
      data[currentKey].push(parseYamlValue(parsedLine.value));
      continue;
    }

    const { key, value } = parsedLine;
    currentKey = key;
    if (!value) {
      data[key] = [];
      continue;
    }
    if (isBlockScalar(value)) {
      const block = readYamlBlockScalar(lines, i + 1, value);
      i = block.nextIndex - 1;
      data[key] = block.value;
      currentKey = null;
      continue;
    }
    data[key] = parseYamlValue(value);
  }
  return data;
}

function parseYamlLine(line) {
  const raw = String(line ?? "");
  const trimmed = raw.trim();
  if (!trimmed) return { type: "empty" };

  if (trimmed.startsWith("- ")) {
    return { type: "sequence-item", value: trimmed.slice(2) };
  }

  const idx = raw.indexOf(":");
  if (idx === -1 || /^[ \t]/.test(raw)) return { type: "unsupported" };
  return {
    type: "mapping",
    key: raw.slice(0, idx).trim(),
    value: raw.slice(idx + 1).trim(),
  };
}

function isBlockScalar(value) {
  return value === "|" || value === ">";
}

function readYamlBlockScalar(lines, startIndex, style) {
  const blockLines = [];
  let index = startIndex;
  while (index < lines.length && /^[ \t]+/.test(lines[index])) {
    blockLines.push(lines[index].replace(/^[ \t]{1,2}/, ""));
    index += 1;
  }
  const joiner = style === "|" ? "\n" : " ";
  return { value: blockLines.join(joiner).trimEnd(), nextIndex: index };
}

function parseYamlValue(value) {
  if (
    (value.startsWith('"') && value.endsWith('"')) ||
    (value.startsWith("'") && value.endsWith("'"))
  ) {
    return value.slice(1, -1);
  }
  if (value.startsWith("[") && value.endsWith("]")) {
    const inner = value.slice(1, -1).trim();
    if (!inner) return [];
    return inner.split(",").map((item) => parseYamlValue(item.trim()));
  }
  if (value === "true") return true;
  if (value === "false") return false;
  if (value === "null" || value === "~") return null;
  if (/^-?\d+(\.\d+)?$/.test(value)) return Number(value);
  return value;
}

function formatFrontmatter(data, body) {
  const yaml = Object.entries(data)
    .filter(([, value]) => value !== undefined)
    .map(([key, value]) => formatYamlLine(key, value))
    .join("\n");

  if (yaml.trim().length === 0) {
    return body;
  }

  return ["---", yaml, "---", "", body].join("\n");
}

function formatYamlLine(key, value) {
  if (Array.isArray(value)) {
    const items = value.map((item) => `  - ${formatYamlValue(item)}`);
    return [key + ":", ...items].join("\n");
  }
  return `${key}: ${formatYamlValue(value)}`;
}

function formatYamlValue(value) {
  if (value === null || value === undefined) return "";
  if (typeof value === "number" || typeof value === "boolean")
    return String(value);
  const raw = String(value);
  if (raw.includes("\n")) {
    return `|\n${raw
      .split("\n")
      .map((line) => `  ${line}`)
      .join("\n")}`;
  }
  if (raw.includes(":") || raw.startsWith("[") || raw.startsWith("{")) {
    return JSON.stringify(raw);
  }
  return raw;
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
