"use strict";

const { stripWrappingQuotes } = require("./frontmatter");

function rewriteAskUserQuestionCodeBlocks(text) {
  const openFencePattern = /(^[ \t]*)(`{3,})([^\n]*)\r?\n/gm;
  let result = "";
  let cursor = 0;
  let match;

  while ((match = openFencePattern.exec(text))) {
    const [openingLine, indent, openingFence] = match;
    const bodyStart = match.index + openingLine.length;
    const closingFence = findAskUserQuestionClosingFence(
      text,
      bodyStart,
      indent,
      openingFence.length,
    );
    if (!closingFence) continue;

    const body = text.slice(bodyStart, closingFence.index);
    const parsed = parseAskUserQuestionBlock(body);
    if (!parsed) {
      openFencePattern.lastIndex = closingFence.afterIndex;
      continue;
    }

    result += text.slice(cursor, match.index);
    result += renderDirectChatQuestion(parsed, { indent });
    cursor = closingFence.afterIndex;
    openFencePattern.lastIndex = closingFence.afterIndex;
  }

  result += text.slice(cursor);
  return result;
}

function findAskUserQuestionClosingFence(
  text,
  fromIndex,
  openingIndent,
  minimumFenceLength,
) {
  const closingFencePattern = /(^[ \t]*)(`{3,})[ \t]*(?:\r?\n|$)/gm;
  closingFencePattern.lastIndex = fromIndex;

  let match;
  while ((match = closingFencePattern.exec(text))) {
    if (
      match[1].length <= openingIndent.length &&
      match[2].length >= minimumFenceLength
    ) {
      return { index: match.index, afterIndex: closingFencePattern.lastIndex };
    }
  }

  return null;
}

function parseAskUserQuestionBlock(body) {
  const lines = String(body).split(/\r?\n/);
  let index = 0;
  while (index < lines.length && lines[index].trim() === "") {
    index += 1;
  }

  if (/^AskUserQuestion\b/.test(lines[index]?.trim() ?? "")) {
    index += 1;
  }

  let header = "";
  let question = "";
  let multiSelect = false;
  const options = [];
  let currentOption = null;
  let sawStructuredPrompt = false;

  const pushCurrentOption = () => {
    if (!currentOption) return;
    options.push(currentOption);
    currentOption = null;
  };

  for (; index < lines.length; index += 1) {
    const trimmed = lines[index].trim();
    if (!trimmed) continue;

    let match = trimmed.match(/^header:\s*(.+)$/i);
    if (match) {
      header = stripWrappingQuotes(match[1]);
      sawStructuredPrompt = true;
      continue;
    }

    match = trimmed.match(/^question:\s*(.+)$/i);
    if (match) {
      const value = stripWrappingQuotes(match[1]);
      if (/^[|>][-+]?$/i.test(value)) {
        const block = readIndentedBlock(
          lines,
          index + 1,
          leadingWhitespaceLength(lines[index]),
        );
        question = value.startsWith(">")
          ? foldBlockScalar(block.value)
          : block.value;
        index = block.nextIndex - 1;
      } else {
        question = value;
      }
      sawStructuredPrompt = true;
      continue;
    }

    match = trimmed.match(/^multiSelect:\s*(.+)$/i);
    if (match) {
      multiSelect = /^true$/i.test(stripWrappingQuotes(match[1]));
      sawStructuredPrompt = true;
      continue;
    }

    if (/^options:\s*$/i.test(trimmed)) {
      sawStructuredPrompt = true;
      continue;
    }

    match = trimmed.match(/^-+\s*label:\s*(.+)$/i);
    if (match) {
      pushCurrentOption();
      currentOption = { label: stripWrappingQuotes(match[1]), description: "" };
      sawStructuredPrompt = true;
      continue;
    }

    match = trimmed.match(/^description:\s*(.+)$/i);
    if (match) {
      if (currentOption) {
        currentOption.description = stripWrappingQuotes(match[1]);
      }
      sawStructuredPrompt = true;
      continue;
    }

    match = trimmed.match(/^-+\s*\(freeform\)\s*(.+)$/i);
    if (match) {
      pushCurrentOption();
      options.push({ label: stripWrappingQuotes(match[1]), description: "" });
      sawStructuredPrompt = true;
      continue;
    }

    match = trimmed.match(/^-+\s*(.+)$/);
    if (match) {
      pushCurrentOption();
      options.push({ label: stripWrappingQuotes(match[1]), description: "" });
      sawStructuredPrompt = true;
      continue;
    }
  }

  pushCurrentOption();

  if (!sawStructuredPrompt || !question) {
    return null;
  }

  return { header, question, multiSelect, options };
}

function renderDirectChatQuestion(prompt, options = {}) {
  const indent = options.indent ?? "";
  const lines = ["Ask the user directly in chat:"];
  if (prompt.header) {
    lines.push(`Question label: ${prompt.header}`);
  }
  appendPrefixedMultiline(lines, "Question: ", prompt.question);
  if (prompt.multiSelect) {
    lines.push("Allow multiple selections if more than one option can apply.");
  }
  if (prompt.options.length > 0) {
    lines.push("Suggested options:");
    for (const option of prompt.options) {
      lines.push(
        option.description
          ? `- ${option.label} — ${option.description}`
          : `- ${option.label}`,
      );
    }
  }
  return lines.map((line) => `${indent}${line}`).join("\n");
}

function readIndentedBlock(lines, startIndex, parentIndent) {
  const blockLines = [];
  let index = startIndex;

  for (; index < lines.length; index += 1) {
    const line = lines[index];
    if (line.trim() !== "" && leadingWhitespaceLength(line) <= parentIndent) {
      break;
    }
    blockLines.push(line);
  }

  const contentIndent = blockLines
    .filter((line) => line.trim() !== "")
    .reduce(
      (minimum, line) => Math.min(minimum, leadingWhitespaceLength(line)),
      Infinity,
    );

  if (contentIndent === Infinity) {
    return { value: "", nextIndex: index };
  }

  const value = blockLines
    .map((line) => (line.trim() === "" ? "" : line.slice(contentIndent)))
    .join("\n")
    .replace(/\n+$/g, "");

  return { value, nextIndex: index };
}

function leadingWhitespaceLength(value) {
  const match = String(value ?? "").match(/^[ \t]*/);
  return match ? match[0].length : 0;
}

function foldBlockScalar(value) {
  return String(value)
    .split(/\n{2,}/)
    .map((paragraph) => paragraph.replace(/\n/g, " "))
    .join("\n\n");
}

function appendPrefixedMultiline(lines, prefix, value) {
  const valueLines = String(value ?? "").split(/\r?\n/);
  lines.push(`${prefix}${valueLines[0] ?? ""}`);
  for (const line of valueLines.slice(1)) {
    lines.push(line ? `  ${line}` : "");
  }
}

module.exports = {
  parseAskUserQuestionBlock,
  renderDirectChatQuestion,
  rewriteAskUserQuestionCodeBlocks,
};
