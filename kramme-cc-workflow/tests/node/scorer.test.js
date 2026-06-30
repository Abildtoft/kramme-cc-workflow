"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  aggregateScores,
  scoreItem,
} = require("../../evals/skill-review/scorer");

test("scoreItem passes when expected and required phrases are present", () => {
  const result = scoreItem(
    {
      id: "review-case",
      expected_findings: [{ id: "missing-timeout", match: "missing timeout" }],
      required_checks: ["regression test"],
      forbidden_findings: ["false positive"],
    },
    "The review flags a missing timeout and asks for a regression test.",
    { predictionSource: "unit-test" },
  );

  assert.equal(result.hard, 1);
  assert.equal(result.soft, 1);
  assert.deepEqual(result.diagnostics, {
    missing_expected: [],
    missing_required: [],
    present_forbidden: [],
  });
  assert.equal(result.prediction.source, "unit-test");
});

test("scoreItem records forbidden findings and missing checks", () => {
  const result = scoreItem(
    {
      id: "review-case",
      expected_findings: ["SQL injection"],
      required_checks: ["line reference"],
      forbidden_findings: [{ id: "speculation", match: "probably broken" }],
    },
    "This is probably broken.",
  );

  assert.equal(result.hard, 0);
  assert.equal(result.soft, 0);
  assert.deepEqual(result.diagnostics, {
    missing_expected: ["expected_findings-1"],
    missing_required: ["required_checks-1"],
    present_forbidden: ["speculation"],
  });
});

test("aggregateScores averages hard and soft scores", () => {
  assert.deepEqual(
    aggregateScores([
      { hard: 1, soft: 1 },
      { hard: 0, soft: 0.3333 },
    ]),
    { hard: 0.5, soft: 0.6666 },
  );
});
