"use strict";

/**
 * @typedef {{ id: string, match: string }} NormalizedExpectation
 * @typedef {{ id: string, match: string, passed: boolean, present: boolean }} ExpectationCheck
 * @typedef {{ hard: number, soft: number }} AggregateInput
 */

/** @param {unknown} value */
function normalizeText(value) {
  return String(value ?? "")
    .normalize("NFKC")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

/**
 * @param {unknown} expectation
 * @param {number} index
 * @param {string} kind
 * @returns {NormalizedExpectation}
 */
function normalizeExpectation(expectation, index, kind) {
  if (typeof expectation === "string") {
    if (normalizeText(expectation) === "") {
      throw new Error(
        `${kind}[${index}] must include at least one alphanumeric character`,
      );
    }
    return {
      id: `${kind}-${index + 1}`,
      match: expectation,
    };
  }

  if (!expectation || typeof expectation !== "object") {
    throw new Error(`${kind}[${index}] must be a string or object`);
  }

  const record = /** @type {Record<string, unknown>} */ (expectation);
  if (typeof record.match !== "string" || record.match.trim() === "") {
    throw new Error(`${kind}[${index}].match must be a non-empty string`);
  }
  if (normalizeText(record.match) === "") {
    throw new Error(
      `${kind}[${index}].match must include at least one alphanumeric character`,
    );
  }

  const fallbackId = `${kind}-${index + 1}`;
  if (
    record.id !== undefined &&
    (typeof record.id !== "string" || record.id.trim() === "")
  ) {
    throw new Error(`${kind}[${index}].id must be a non-empty string`);
  }

  return { id: record.id ?? fallbackId, match: record.match };
}

/**
 * @param {Record<string, unknown>} item
 * @param {string} field
 * @returns {NormalizedExpectation[]}
 */
function normalizeExpectationList(item, field) {
  const value = item[field] ?? [];
  if (!Array.isArray(value)) {
    throw new Error(`${item.id || "item"}.${field} must be an array`);
  }

  return value.map((entry, index) => normalizeExpectation(entry, index, field));
}

/**
 * @param {string} normalizedPrediction
 * @param {NormalizedExpectation} expectation
 * @param {boolean} shouldBePresent
 * @returns {ExpectationCheck}
 */
function matchExpected(normalizedPrediction, expectation, shouldBePresent) {
  const normalizedMatch = normalizeText(expectation.match);
  const present = ` ${normalizedPrediction} `.includes(` ${normalizedMatch} `);
  const passed = shouldBePresent ? present : !present;

  return {
    id: expectation.id,
    match: expectation.match,
    passed,
    present,
  };
}

/**
 * @param {unknown} item
 * @param {unknown} predictionText
 * @param {{ predictionSource?: string }} [options]
 */
function scoreItem(item, predictionText, options = {}) {
  if (!item || typeof item !== "object") {
    throw new Error("item must be an object");
  }
  const record = /** @type {Record<string, unknown>} */ (item);
  if (typeof record.id !== "string" || record.id.trim() === "") {
    throw new Error("item.id must be a non-empty string");
  }
  if (typeof predictionText !== "string") {
    throw new Error(`${record.id}.predictionText must be a string`);
  }

  const normalizedPrediction = normalizeText(predictionText);
  const expected = normalizeExpectationList(record, "expected_findings").map(
    (expectation) => matchExpected(normalizedPrediction, expectation, true),
  );
  const required = normalizeExpectationList(record, "required_checks").map(
    (expectation) => matchExpected(normalizedPrediction, expectation, true),
  );
  const forbidden = normalizeExpectationList(record, "forbidden_findings").map(
    (expectation) => matchExpected(normalizedPrediction, expectation, false),
  );

  const checks = [...expected, ...required, ...forbidden];
  const earned = checks.filter((check) => check.passed).length;
  const total = checks.length;
  if (total === 0) {
    throw new Error(`${record.id} must define at least one scoring check`);
  }

  const soft = earned / total;
  const diagnostics = {
    missing_expected: expected
      .filter((check) => !check.passed)
      .map((check) => check.id),
    missing_required: required
      .filter((check) => !check.passed)
      .map((check) => check.id),
    present_forbidden: forbidden
      .filter((check) => !check.passed)
      .map((check) => check.id),
  };
  const hardPassed =
    diagnostics.missing_expected.length === 0 &&
    diagnostics.missing_required.length === 0 &&
    diagnostics.present_forbidden.length === 0;

  return {
    id: record.id,
    hard: hardPassed ? 1 : 0,
    soft: Number(soft.toFixed(4)),
    prediction: {
      source: options.predictionSource || "fixture_review_output",
      text: predictionText,
    },
    diagnostics,
    checks: {
      expected,
      required,
      forbidden,
    },
  };
}

/** @param {unknown} itemResults */
function aggregateScores(itemResults) {
  if (!Array.isArray(itemResults)) {
    throw new Error("itemResults must be an array");
  }
  if (itemResults.length === 0) {
    throw new Error("cannot aggregate zero eval items");
  }

  const results = itemResults.map((result, index) =>
    normalizeAggregateInput(result, index),
  );
  const hard =
    results.reduce((sum, result) => sum + result.hard, 0) / results.length;
  const soft =
    results.reduce((sum, result) => sum + result.soft, 0) / results.length;

  return {
    hard: Number(hard.toFixed(4)),
    soft: Number(soft.toFixed(4)),
  };
}

/** @param {unknown} value @param {number} index @returns {AggregateInput} */
function normalizeAggregateInput(value, index) {
  if (!value || typeof value !== "object") {
    throw new Error(`itemResults[${index}] must be an object`);
  }
  const result = /** @type {Record<string, unknown>} */ (value);
  if (
    typeof result.hard !== "number" ||
    !Number.isFinite(result.hard) ||
    typeof result.soft !== "number" ||
    !Number.isFinite(result.soft)
  ) {
    throw new Error(
      `itemResults[${index}] hard and soft scores must be finite numbers`,
    );
  }
  return { hard: result.hard, soft: result.soft };
}

module.exports = {
  aggregateScores,
  scoreItem,
};
