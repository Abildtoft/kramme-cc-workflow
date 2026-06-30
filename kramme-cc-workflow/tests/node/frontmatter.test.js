"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  codexName,
  formatFrontmatter,
  parseFrontmatter,
  sanitizeDescription,
} = require("../../scripts/convert-plugin/frontmatter");

test("parseFrontmatter preserves YAML collections while quoting legacy string fields", () => {
  const parsed = parseFrontmatter(`---
name: Example Skill
description: [draft]
allowed-tools: [Read, Bash]
user-invocable: true
---
Body text`);

  assert.deepEqual(parsed.data, {
    name: "Example Skill",
    description: "[draft]",
    "allowed-tools": ["Read", "Bash"],
    "user-invocable": true,
  });
  assert.equal(parsed.body, "Body text");
});

test("formatFrontmatter omits undefined fields without dropping false values", () => {
  const formatted = formatFrontmatter(
    {
      name: "sample",
      "argument-hint": undefined,
      "disable-model-invocation": false,
      "user-invocable": true,
    },
    "Instructions.",
  );

  assert.equal(
    formatted,
    `---
name: sample
disable-model-invocation: false
user-invocable: true
---

Instructions.`,
  );
});

test("codexName and sanitizeDescription normalize generated metadata", () => {
  assert.equal(codexName("Kramme:Review Bot/One"), "kramme:review-bot-one");
  assert.equal(sanitizeDescription("  A\n\nlong\t description  "), "A long description");
  assert.equal(sanitizeDescription("abcdef", 5), "ab...");
});
