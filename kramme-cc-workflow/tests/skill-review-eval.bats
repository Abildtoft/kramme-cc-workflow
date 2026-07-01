#!/usr/bin/env bats

@test "skill review eval runner emits parseable aggregate JSON" {
  run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    node evals/skill-review/run-eval.js --split all --json > "$BATS_TEST_TMPDIR/out.json"
    node -e "
      const fs = require(\"fs\");
      const data = JSON.parse(fs.readFileSync(process.argv[1], \"utf8\"));
      if (data.split !== \"all\") process.exit(1);
      if (typeof data.hard !== \"number\" || typeof data.soft !== \"number\") process.exit(1);
      if (!Array.isArray(data.items) || data.items.length < 5) process.exit(1);
      if (!Array.isArray(data.diagnostics)) process.exit(1);
    " "$BATS_TEST_TMPDIR/out.json"
  '

  [ "$status" -eq 0 ]
}

@test "skill review eval Make target uses aggregate JSON command" {
  run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    make --no-print-directory -n skill-eval-skill-review > "$BATS_TEST_TMPDIR/make.txt"
    grep -Fx "node evals/skill-review/run-eval.js --split all --json" "$BATS_TEST_TMPDIR/make.txt"
  '

  [ "$status" -eq 0 ]
}

@test "skill review eval focused Make target runs this Bats file" {
  run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    make --no-print-directory -n test-skill-review-eval > "$BATS_TEST_TMPDIR/make.txt"
    grep -Fx "bats tests/skill-review-eval.bats" "$BATS_TEST_TMPDIR/make.txt"
  '

  [ "$status" -eq 0 ]
}

@test "skill review eval modules export only cross-module helpers" {
  run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    node <<'"'"'NODE'"'"'
const assert = require("assert");
assert.deepStrictEqual(
  Object.keys(require("./evals/skill-review/run-eval.js")).sort(),
  ["evaluateItems", "loadItemsForSplit"],
);
assert.deepStrictEqual(
  Object.keys(require("./evals/skill-review/scorer.js")).sort(),
  ["aggregateScores", "scoreItem"],
);
NODE
  '

  [ "$status" -eq 0 ]
}

@test "skillopt candidate check Make target keeps deterministic gate order" {
  run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    env -u BASE_REF -u SKILLSPECTOR_BASE make --no-print-directory -n skillopt-candidate-check > "$BATS_TEST_TMPDIR/make.txt"
    node -e "
      const fs = require(\"fs\");
      const lines = fs.readFileSync(process.argv[1], \"utf8\").trim().split(/\n+/);
      const expected = [
        \"python3 scripts/lint-skill-contracts.py\",
        \"./scripts/run-skillspector.sh --changed --base \\\"origin/main\\\" --format json --fail-on high\",
        \"./tests/run-tests.sh\",
        \"node evals/skill-review/run-eval.js --split all --json\",
      ];
      if (lines.length !== expected.length) {
        console.error(lines.join(\"\\n\"));
        process.exit(1);
      }
      for (let index = 0; index < expected.length; index += 1) {
        if (lines[index] !== expected[index]) {
          console.error(lines.join(\"\\n\"));
          process.exit(1);
        }
      }
    " "$BATS_TEST_TMPDIR/make.txt"
  '

  [ "$status" -eq 0 ]
}

@test "skill review eval runner selects requested split only" {
  run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    node evals/skill-review/run-eval.js --split train --json > "$BATS_TEST_TMPDIR/train.json"
    node -e "
      const fs = require(\"fs\");
      const data = JSON.parse(fs.readFileSync(process.argv[1], \"utf8\"));
      if (data.split !== \"train\") process.exit(1);
      if (data.items.length !== 2) process.exit(1);
      if (!data.items.every((item) => item.split === \"train\")) process.exit(1);
    " "$BATS_TEST_TMPDIR/train.json"
  '

  [ "$status" -eq 0 ]
}

@test "skill review eval prediction command receives skill context and scores stdout" {
  run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    cat > "$BATS_TEST_TMPDIR/fake-predict.js" <<'"'"'NODE'"'"'
const fs = require("fs");
const context = JSON.parse(fs.readFileSync(0, "utf8"));

if (context.skill !== "candidate-skill") {
  console.error(`unexpected skill: ${context.skill}`);
  process.exit(2);
}
if (!context.skill_path.endsWith("/candidate-skill")) {
  console.error(`unexpected skill_path: ${context.skill_path}`);
  process.exit(2);
}
if (!context.item.input_skill_path || !context.item.input_skill_file.endsWith("/SKILL.md")) {
  console.error("missing input skill paths");
  process.exit(2);
}

if (context.item.id === "train-good-skill") {
  console.log(`No findings found.

Rubric snapshot:
- Focused and composable: Pass
- Progressively disclosed: Pass`);
} else if (context.item.id === "train-missing-frontmatter") {
  console.log(`Major: Frontmatter is missing, including disable model invocation.

Rubric snapshot:
- Self describing boundaries: Fail`);
} else {
  console.error(`unexpected item: ${context.item.id}`);
  process.exit(2);
}
NODE

    node evals/skill-review/run-eval.js \
      --split train \
      --skill candidate-skill \
      --prediction-command "node \"$BATS_TEST_TMPDIR/fake-predict.js\"" \
      --json > "$BATS_TEST_TMPDIR/train.json"
    node -e "
      const fs = require(\"fs\");
      const data = JSON.parse(fs.readFileSync(process.argv[1], \"utf8\"));
      if (data.skill !== \"candidate-skill\") process.exit(1);
      if (!data.items.every((item) => item.prediction.source === \"prediction_command\")) process.exit(1);
      if (!data.items.every((item) => item.hard === 1)) process.exit(1);
    " "$BATS_TEST_TMPDIR/train.json"
  '

  [ "$status" -eq 0 ]
}

@test "skill review eval scores prediction command output instead of fixture text" {
  run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    cat > "$BATS_TEST_TMPDIR/empty-review.js" <<'"'"'NODE'"'"'
console.log("No findings found.");
NODE

    node evals/skill-review/run-eval.js \
      --split train \
      --prediction-command "node \"$BATS_TEST_TMPDIR/empty-review.js\"" \
      --json > "$BATS_TEST_TMPDIR/train.json"
    node -e "
      const fs = require(\"fs\");
      const data = JSON.parse(fs.readFileSync(process.argv[1], \"utf8\"));
      const item = data.items.find((entry) => entry.id === \"train-missing-frontmatter\");
      if (!item) process.exit(1);
      if (item.prediction.source !== \"prediction_command\") process.exit(1);
      if (item.hard !== 0) process.exit(1);
      if (!item.diagnostics.missing_expected.includes(\"frontmatter-missing\")) process.exit(1);
    " "$BATS_TEST_TMPDIR/train.json"
  '

  [ "$status" -eq 0 ]
}

@test "skill review eval reports prediction command failures as JSON diagnostics" {
  run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    if node evals/skill-review/run-eval.js \
      --split train \
      --prediction-command "node \"$BATS_TEST_TMPDIR/missing-adapter.js\"" \
      --json > "$BATS_TEST_TMPDIR/out.json" 2> "$BATS_TEST_TMPDIR/err.txt"; then
      exit 1
    fi
    if [ -s "$BATS_TEST_TMPDIR/err.txt" ]; then
      cat "$BATS_TEST_TMPDIR/err.txt"
      exit 1
    fi
    node -e "
      const fs = require(\"fs\");
      const data = JSON.parse(fs.readFileSync(process.argv[1], \"utf8\"));
      if (!/prediction command failed for train-good-skill/.test(data.error)) process.exit(1);
      if (!Array.isArray(data.diagnostics) || data.diagnostics[0] !== data.error) process.exit(1);
    " "$BATS_TEST_TMPDIR/out.json"
  '

  [ "$status" -eq 0 ]
}

@test "skill review eval bounds hanging prediction commands" {
  run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    cat > "$BATS_TEST_TMPDIR/hanging-review.js" <<'"'"'NODE'"'"'
const fs = require("fs");
const marker = process.argv[2];
setTimeout(() => fs.writeFileSync(marker, "alive"), 200);
setTimeout(() => {}, 1000);
NODE

    if SKILL_REVIEW_EVAL_PREDICTION_TIMEOUT_MS=25 \
      node evals/skill-review/run-eval.js \
      --split train \
      --prediction-command "node \"$BATS_TEST_TMPDIR/hanging-review.js\" \"$BATS_TEST_TMPDIR/leaked-child\" & wait" \
      --json > "$BATS_TEST_TMPDIR/out.json" 2> "$BATS_TEST_TMPDIR/err.txt"; then
      exit 1
    fi
    if [ -s "$BATS_TEST_TMPDIR/err.txt" ]; then
      cat "$BATS_TEST_TMPDIR/err.txt"
      exit 1
    fi
    node -e "
      const fs = require(\"fs\");
      const data = JSON.parse(fs.readFileSync(process.argv[1], \"utf8\"));
      if (!/prediction command timed out for train-good-skill after 25ms/.test(data.error)) process.exit(1);
      if (!Array.isArray(data.diagnostics) || data.diagnostics[0] !== data.error) process.exit(1);
    " "$BATS_TEST_TMPDIR/out.json"
    sleep 0.3
    [ ! -e "$BATS_TEST_TMPDIR/leaked-child" ]
  '

  [ "$status" -eq 0 ]
}

@test "skill review eval rejects blank prediction command values" {
  run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    if node evals/skill-review/run-eval.js \
      --split train \
      --prediction-command "  " \
      --json > "$BATS_TEST_TMPDIR/out.json" 2> "$BATS_TEST_TMPDIR/err.txt"; then
      exit 1
    fi
    if [ -s "$BATS_TEST_TMPDIR/err.txt" ]; then
      cat "$BATS_TEST_TMPDIR/err.txt"
      exit 1
    fi
    node -e "
      const fs = require(\"fs\");
      const data = JSON.parse(fs.readFileSync(process.argv[1], \"utf8\"));
      if (data.error !== \"--prediction-command requires a command\") process.exit(1);
      if (!Array.isArray(data.diagnostics) || data.diagnostics[0] !== data.error) process.exit(1);
    " "$BATS_TEST_TMPDIR/out.json"
  '

  [ "$status" -eq 0 ]
}

@test "skill review eval includes a passing clean fixture" {
  run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    node evals/skill-review/run-eval.js --split train --json > "$BATS_TEST_TMPDIR/train.json"
    node -e "
      const fs = require(\"fs\");
      const data = JSON.parse(fs.readFileSync(process.argv[1], \"utf8\"));
      const item = data.items.find((entry) => entry.id === \"train-good-skill\");
      if (!item) process.exit(1);
      if (item.hard !== 1 || item.soft !== 1) process.exit(1);
      if (item.diagnostics.missing_expected.length !== 0) process.exit(1);
      if (item.diagnostics.present_forbidden.length !== 0) process.exit(1);
    " "$BATS_TEST_TMPDIR/train.json"
  '

  [ "$status" -eq 0 ]
}

@test "skill review scorer penalizes forbidden findings" {
  run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    node <<'"'"'NODE'"'"'
const { scoreItem } = require("./evals/skill-review/scorer.js");
const result = scoreItem(
  {
    id: "forbidden-penalty",
    expected_findings: [],
    required_checks: [],
    forbidden_findings: [{ id: "unsafe-false-positive", match: "unsafe side effects" }],
  },
  "Major: unsafe side effects are present.",
);

if (result.hard !== 0) process.exit(1);
if (result.soft !== 0) process.exit(1);
if (result.diagnostics.present_forbidden[0] !== "unsafe-false-positive") process.exit(1);
NODE
  '

  [ "$status" -eq 0 ]
}

@test "skill review scorer matches whole normalized tokens only" {
  run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    node <<'"'"'NODE'"'"'
const { scoreItem } = require("./evals/skill-review/scorer.js");
const result = scoreItem(
  {
    id: "token-boundary",
    expected_findings: [],
    required_checks: [{ id: "secure-fail", match: "secure fail" }],
    forbidden_findings: [],
  },
  "Insecure failure was not reported.",
);

if (result.hard !== 0) process.exit(1);
if (result.soft !== 0) process.exit(1);
if (result.diagnostics.missing_required[0] !== "secure-fail") process.exit(1);
NODE
  '

  [ "$status" -eq 0 ]
}

@test "skill review eval fails when a fixture directory is missing" {
  run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    node <<'"'"'NODE'"'"'
const { evaluateItems } = require("./evals/skill-review/run-eval.js");

try {
  evaluateItems(
    [
      {
        id: "missing-fixture",
        input_skill_dir: "fixtures/does-not-exist",
        difficulty: "easy",
        fixture_review_output: "No findings found.",
        expected_findings: [],
        forbidden_findings: [],
        required_checks: [],
      },
    ],
    {
      evalRoot: process.cwd() + "/evals/skill-review",
      split: "test",
    },
  );
  process.exit(1);
} catch (error) {
  if (!/missing fixture/.test(error.message)) {
    console.error(error.message);
    process.exit(1);
  }
}
NODE
  '

  [ "$status" -eq 0 ]
}

@test "skill review eval rejects empty item sets" {
  run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    node <<'"'"'NODE'"'"'
const { evaluateItems } = require("./evals/skill-review/run-eval.js");

try {
  evaluateItems([], {
    evalRoot: process.cwd() + "/evals/skill-review",
    split: "test",
  });
  process.exit(1);
} catch (error) {
  if (!/zero eval items/.test(error.message)) {
    console.error(error.message);
    process.exit(1);
  }
}
NODE
  '

  [ "$status" -eq 0 ]
}

@test "skill review eval emits JSON diagnostics for argument parse errors" {
  run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    if node evals/skill-review/run-eval.js --json --unknown > "$BATS_TEST_TMPDIR/out.json" 2> "$BATS_TEST_TMPDIR/err.txt"; then
      exit 1
    fi
    if [ -s "$BATS_TEST_TMPDIR/err.txt" ]; then
      cat "$BATS_TEST_TMPDIR/err.txt"
      exit 1
    fi
    node -e "
      const fs = require(\"fs\");
      const data = JSON.parse(fs.readFileSync(process.argv[1], \"utf8\"));
      if (!/unknown argument: --unknown/.test(data.error)) process.exit(1);
      if (!Array.isArray(data.diagnostics) || data.diagnostics[0] !== data.error) process.exit(1);
    " "$BATS_TEST_TMPDIR/out.json"
  '

  [ "$status" -eq 0 ]
}

@test "skill review eval rejects empty split files" {
  run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    mkdir -p "$BATS_TEST_TMPDIR/eval/items/train"
    printf "[]\n" > "$BATS_TEST_TMPDIR/eval/items/train/items.json"
    node <<'"'"'NODE'"'"'
const { loadItemsForSplit } = require("./evals/skill-review/run-eval.js");

try {
  loadItemsForSplit("train", process.env.BATS_TEST_TMPDIR + "/eval");
  process.exit(1);
} catch (error) {
  if (!/must contain at least one item/.test(error.message)) {
    console.error(error.message);
    process.exit(1);
  }
}
NODE
  '

  [ "$status" -eq 0 ]
}

@test "skill review scorer rejects punctuation-only expectations" {
  run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    node <<'"'"'NODE'"'"'
const { scoreItem } = require("./evals/skill-review/scorer.js");

try {
  scoreItem(
    {
      id: "punctuation-only",
      expected_findings: [{ id: "punctuation", match: "---" }],
      required_checks: [],
      forbidden_findings: [],
    },
    "Any prediction text.",
  );
  process.exit(1);
} catch (error) {
  if (!/alphanumeric/.test(error.message)) {
    console.error(error.message);
    process.exit(1);
  }
}
NODE
  '

  [ "$status" -eq 0 ]
}

@test "skill review scorer rejects items without scoring checks" {
  run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    node <<'"'"'NODE'"'"'
const { scoreItem } = require("./evals/skill-review/scorer.js");

try {
  scoreItem(
    {
      id: "no-checks",
      expected_findings: [],
      required_checks: [],
      forbidden_findings: [],
    },
    "No findings found.",
  );
  process.exit(1);
} catch (error) {
  if (!/at least one scoring check/.test(error.message)) {
    console.error(error.message);
    process.exit(1);
  }
}
NODE
  '

  [ "$status" -eq 0 ]
}
