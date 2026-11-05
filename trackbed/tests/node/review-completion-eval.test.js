"use strict";
const { test } = require("node:test");
const assert = require("node:assert/strict");
const { score } = require("../../evals/review-completion/score.js");
const fs = require("node:fs");
const path = require("node:path");
/** @type {import('../../evals/review-completion/score.js').Case[]} */
const cases = JSON.parse(
  fs.readFileSync(
    path.join(__dirname, "../../evals/review-completion/cases.json"),
    "utf8",
  ),
);
/** @returns {import('../../evals/review-completion/score.js').Observation[]} */
const observations = () =>
  cases.map((item) => ({
    id: item.id,
    trace: "fixture-only",
    status: item.expected,
    aspects: item.aspects,
    violations: [],
    helperCheckExit: item.expected === "COMPLETE" ? 0 : 1,
    hostJobsMatch: true,
    limitationReported: true,
  }));
test("scorer accepts complete observations including explicit filter and cancellation controls", () => {
  assert.equal(score(observations()).passed, true);
});
test("scorer rejects missing cases and shortcuts even with a passing ledger", () => {
  assert.equal(score([]).passed, false);
  const rows = observations();
  rows[0].violations = ["parent-substitution"];
  assert.equal(score(rows).passed, false);
  rows[0].violations = [];
  rows[0].hostJobsMatch = false;
  assert.equal(score(rows).passed, false);
});
test("scorer rejects false completion, missing disclosure, and altered scope", () => {
  /** @type {[number, Partial<import('../../evals/review-completion/score.js').Observation>][]} */
  const mutations = [
    [3, { helperCheckExit: 0 }],
    [3, { limitationReported: false }],
    [4, { aspects: ["all"] }],
    [0, { trace: "" }],
    [0, { status: "INCOMPLETE" }],
  ];
  for (const [index, mutation] of mutations) {
    const rows = observations();
    Object.assign(rows[index], mutation);
    assert.equal(score(rows).passed, false);
  }
  assert.throws(
    () => score([observations()[0], observations()[0]]),
    /Duplicate/,
  );
});
