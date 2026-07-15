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

test("scoreItem rejects non-string expectation IDs", () => {
  assert.throws(
    () =>
      scoreItem(
        {
          id: "review-case",
          expected_findings: [{ id: 42, match: "missing timeout" }],
        },
        "The review flags a missing timeout.",
      ),
    /expected_findings\[0\]\.id must be a non-empty string/,
  );
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

test("aggregateScores rejects malformed score entries", () => {
  assert.throws(
    () => aggregateScores([null]),
    /itemResults\[0\] must be an object/,
  );
  assert.throws(
    () => aggregateScores([{ hard: "1", soft: 0.5 }]),
    /itemResults\[0\] hard and soft scores must be finite numbers/,
  );
  assert.throws(
    () => aggregateScores([{ hard: 1, soft: Number.NaN }]),
    /itemResults\[0\] hard and soft scores must be finite numbers/,
  );
});
