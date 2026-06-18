'use strict';

function normalizeText(value) {
  return String(value ?? '')
    .normalize('NFKC')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function normalizeExpectation(expectation, index, kind) {
  if (typeof expectation === 'string') {
    if (normalizeText(expectation) === '') {
      throw new Error(`${kind}[${index}] must include at least one alphanumeric character`);
    }
    return {
      id: `${kind}-${index + 1}`,
      match: expectation,
    };
  }

  if (!expectation || typeof expectation !== 'object') {
    throw new Error(`${kind}[${index}] must be a string or object`);
  }

  if (typeof expectation.match !== 'string' || expectation.match.trim() === '') {
    throw new Error(`${kind}[${index}].match must be a non-empty string`);
  }
  if (normalizeText(expectation.match) === '') {
    throw new Error(`${kind}[${index}].match must include at least one alphanumeric character`);
  }

  return {
    id: expectation.id || `${kind}-${index + 1}`,
    match: expectation.match,
  };
}

function normalizeExpectationList(item, field) {
  const value = item[field] ?? [];
  if (!Array.isArray(value)) {
    throw new Error(`${item.id || 'item'}.${field} must be an array`);
  }

  return value.map((entry, index) => normalizeExpectation(entry, index, field));
}

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

function scoreItem(item, predictionText, options = {}) {
  if (!item || typeof item !== 'object') {
    throw new Error('item must be an object');
  }
  if (typeof item.id !== 'string' || item.id.trim() === '') {
    throw new Error('item.id must be a non-empty string');
  }
  if (typeof predictionText !== 'string') {
    throw new Error(`${item.id}.predictionText must be a string`);
  }

  const normalizedPrediction = normalizeText(predictionText);
  const expected = normalizeExpectationList(item, 'expected_findings').map(
    (expectation) => matchExpected(normalizedPrediction, expectation, true),
  );
  const required = normalizeExpectationList(item, 'required_checks').map(
    (expectation) => matchExpected(normalizedPrediction, expectation, true),
  );
  const forbidden = normalizeExpectationList(item, 'forbidden_findings').map(
    (expectation) => matchExpected(normalizedPrediction, expectation, false),
  );

  const checks = [...expected, ...required, ...forbidden];
  const earned = checks.filter((check) => check.passed).length;
  const total = checks.length;
  if (total === 0) {
    throw new Error(`${item.id} must define at least one scoring check`);
  }

  const soft = earned / total;
  const diagnostics = {
    missing_expected: expected.filter((check) => !check.passed).map((check) => check.id),
    missing_required: required.filter((check) => !check.passed).map((check) => check.id),
    present_forbidden: forbidden.filter((check) => !check.passed).map((check) => check.id),
  };
  const hardPassed =
    diagnostics.missing_expected.length === 0 &&
    diagnostics.missing_required.length === 0 &&
    diagnostics.present_forbidden.length === 0;

  return {
    id: item.id,
    hard: hardPassed ? 1 : 0,
    soft: Number(soft.toFixed(4)),
    prediction: {
      source: options.predictionSource || 'fixture_review_output',
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

function aggregateScores(itemResults) {
  if (!Array.isArray(itemResults)) {
    throw new Error('itemResults must be an array');
  }
  if (itemResults.length === 0) {
    throw new Error('cannot aggregate zero eval items');
  }

  const hard = itemResults.reduce((sum, result) => sum + result.hard, 0) / itemResults.length;
  const soft = itemResults.reduce((sum, result) => sum + result.soft, 0) / itemResults.length;

  return {
    hard: Number(hard.toFixed(4)),
    soft: Number(soft.toFixed(4)),
  };
}

module.exports = {
  aggregateScores,
  normalizeText,
  scoreItem,
};
