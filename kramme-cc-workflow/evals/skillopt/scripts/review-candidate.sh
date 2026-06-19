#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: review-candidate.sh <run-dir>
       review-candidate.sh --run-dir <run-dir>

Generates a candidate-review packet for a SkillOpt run that contains
best_skill.md. The run directory must stay under a
.context/skillopt-runs/skill-review/ path. The script writes review artifacts
only; it never modifies skills/kramme:skill:review/SKILL.md.
EOF
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
workflow_root="$(cd "$script_dir/../../.." && pwd -P)"
repo_root="$(cd "$workflow_root/.." && pwd -P)"
source_skill="$workflow_root/skills/kramme:skill:review/SKILL.md"
source_rel="${source_skill#"$repo_root"/}"
eval_runner="$workflow_root/evals/skill-review/run-eval.js"

run_dir=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --run-dir)
      if [ "$#" -lt 2 ]; then
        echo "review-candidate: --run-dir requires a path" >&2
        exit 2
      fi
      run_dir="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    -*)
      echo "review-candidate: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [ -n "$run_dir" ]; then
        echo "review-candidate: only one run directory may be provided" >&2
        usage >&2
        exit 2
      fi
      run_dir="$1"
      shift
      ;;
  esac
done

if [ -z "$run_dir" ]; then
  echo "review-candidate: run directory is required" >&2
  usage >&2
  exit 2
fi

if [ ! -d "$run_dir" ]; then
  echo "review-candidate: run directory does not exist: $run_dir" >&2
  exit 1
fi

run_dir_real="$(cd "$run_dir" && pwd -P)"

if [ ! -f "$run_dir_real/best_skill.md" ] && [ -f "$run_dir_real/skillopt-output/best_skill.md" ]; then
  run_dir_real="$(cd "$run_dir_real/skillopt-output" && pwd -P)"
fi

case "$run_dir_real/" in
  */.context/skillopt-runs/skill-review/*) ;;
  *)
    echo "review-candidate: run directory must stay under a .context/skillopt-runs/skill-review path: $run_dir_real" >&2
    exit 1
    ;;
esac

best_skill="$run_dir_real/best_skill.md"
if [ ! -f "$best_skill" ]; then
  echo "review-candidate: missing best_skill.md in run directory: $run_dir_real" >&2
  exit 1
fi

if [ ! -f "$source_skill" ]; then
  echo "review-candidate: missing source skill: $source_skill" >&2
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "review-candidate: node is required to run evals and write the review report" >&2
  exit 1
fi

if [ "$(basename "$run_dir_real")" = "candidate-review" ]; then
  review_dir="$run_dir_real"
else
  review_dir="$(dirname "$run_dir_real")/candidate-review"
fi
mkdir -p "$review_dir"
review_dir="$(cd "$review_dir" && pwd -P)"

baseline_file="$review_dir/baseline.md"
candidate_file="$review_dir/candidate.md"
patch_file="$review_dir/diff.patch"
baseline_eval_json="$review_dir/baseline-eval.json"
candidate_eval_json="$review_dir/candidate-eval.json"
baseline_eval_stderr="$review_dir/baseline-eval.stderr"
candidate_eval_stderr="$review_dir/candidate-eval.stderr"
patch_check_stderr="$review_dir/patch-check.stderr"
score_report="$review_dir/score-report.json"
review_md="$review_dir/review.md"

cp "$source_skill" "$baseline_file"
cp "$best_skill" "$candidate_file"

set +e
diff -u --label "a/$source_rel" --label "b/$source_rel" "$baseline_file" "$candidate_file" > "$patch_file"
diff_exit=$?
set -e

case "$diff_exit" in
  0)
    diff_status="unchanged"
    ;;
  1)
  diff_status="changed"
    ;;
  *)
    echo "review-candidate: diff generation failed" >&2
    exit "$diff_exit"
    ;;
esac

patch_check_status="not_needed"
if [ "$diff_status" = "changed" ]; then
  if git -C "$repo_root" apply --check "$patch_file" 2> "$patch_check_stderr"; then
    patch_check_status="pass"
  else
    patch_check_status="fail"
  fi
else
  : > "$patch_check_stderr"
fi

run_eval() {
  local skill_path="$1"
  local output_path="$2"
  local stderr_path="$3"

  if [ ! -f "$eval_runner" ]; then
    printf "missing_runner"
    return
  fi

  if node "$eval_runner" --split all --skill "$skill_path" --json > "$output_path" 2> "$stderr_path"; then
    printf "pass"
  else
    printf "fail"
  fi
}

baseline_eval_status="$(run_eval "$baseline_file" "$baseline_eval_json" "$baseline_eval_stderr")"
candidate_eval_status="$(run_eval "$candidate_file" "$candidate_eval_json" "$candidate_eval_stderr")"

export BASELINE_EVAL_JSON="$baseline_eval_json"
export BASELINE_EVAL_STATUS="$baseline_eval_status"
export BASELINE_EVAL_STDERR="$baseline_eval_stderr"
export CANDIDATE_EVAL_JSON="$candidate_eval_json"
export CANDIDATE_EVAL_STATUS="$candidate_eval_status"
export CANDIDATE_EVAL_STDERR="$candidate_eval_stderr"
export CANDIDATE_FILE="$candidate_file"
export DIFF_PATCH="$patch_file"
export DIFF_STATUS="$diff_status"
export PATCH_CHECK_STATUS="$patch_check_status"
export PATCH_CHECK_STDERR="$patch_check_stderr"
export REPO_ROOT="$repo_root"
export REVIEW_DIR="$review_dir"
export REVIEW_MD="$review_md"
export RUN_DIR="$run_dir_real"
export SCORE_REPORT="$score_report"
export SOURCE_REL="$source_rel"
export SOURCE_SKILL="$source_skill"

node <<'NODE'
const fs = require('fs');
const path = require('path');

function readJson(filePath) {
  if (!filePath || !fs.existsSync(filePath)) {
    return null;
  }
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch (error) {
    return { parse_error: error.message };
  }
}

function readText(filePath) {
  if (!filePath || !fs.existsSync(filePath)) {
    return '';
  }
  return fs.readFileSync(filePath, 'utf8');
}

function scoreOf(result) {
  if (!result || typeof result.hard !== 'number' || typeof result.soft !== 'number') {
    return { hard: null, soft: null };
  }
  return { hard: result.hard, soft: result.soft };
}

function scoreDelta(candidate, baseline, field) {
  if (typeof candidate[field] !== 'number' || typeof baseline[field] !== 'number') {
    return null;
  }
  return Number((candidate[field] - baseline[field]).toFixed(4));
}

function headingsFrom(filePath) {
  return readText(filePath)
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => /^#{1,6}\s+\S/.test(line));
}

function difference(left, right) {
  const rightSet = new Set(right);
  return left.filter((entry) => !rightSet.has(entry));
}

function formatScore(value) {
  return typeof value === 'number' ? value.toFixed(4) : 'n/a';
}

const baselineEval = readJson(process.env.BASELINE_EVAL_JSON);
const candidateEval = readJson(process.env.CANDIDATE_EVAL_JSON);
const baselineScore = scoreOf(baselineEval);
const candidateScore = scoreOf(candidateEval);
const baselineHeadings = headingsFrom(path.join(process.env.REVIEW_DIR, 'baseline.md'));
const candidateHeadings = headingsFrom(process.env.CANDIDATE_FILE);
const hardDelta = scoreDelta(candidateScore, baselineScore, 'hard');
const softDelta = scoreDelta(candidateScore, baselineScore, 'soft');
const diffStatus = process.env.DIFF_STATUS;
const patchCheckStatus = process.env.PATCH_CHECK_STATUS;

let recommendationStatus = 'NEEDS_REVIEW';
let recommendationRationale = 'Candidate patch applies and fixture evals do not regress, but the eval runner does not score candidate content; inspect manually before applying.';

if (diffStatus === 'unchanged') {
  recommendationStatus = 'NO_CHANGE';
  recommendationRationale = 'Candidate content is identical to the current source skill.';
} else if (patchCheckStatus !== 'pass') {
  recommendationStatus = 'REJECT';
  recommendationRationale = 'Candidate patch does not apply cleanly to the current source skill.';
} else if (process.env.BASELINE_EVAL_STATUS !== 'pass' || process.env.CANDIDATE_EVAL_STATUS !== 'pass') {
  recommendationStatus = 'REJECT';
  recommendationRationale = 'One or more eval commands failed; inspect stderr artifacts before review.';
} else if ((typeof hardDelta === 'number' && hardDelta < 0) || (typeof softDelta === 'number' && softDelta < 0)) {
  recommendationStatus = 'REJECT';
  recommendationRationale = 'Candidate eval score regresses from the baseline score.';
}

const report = {
  generated_at: new Date().toISOString(),
  run_dir: process.env.RUN_DIR,
  review_dir: process.env.REVIEW_DIR,
  source_skill: process.env.SOURCE_SKILL,
  files: {
    baseline: path.join(process.env.REVIEW_DIR, 'baseline.md'),
    candidate: process.env.CANDIDATE_FILE,
    diff_patch: process.env.DIFF_PATCH,
    review: process.env.REVIEW_MD,
  },
  comparison: {
    status: diffStatus,
    patch_check: {
      status: patchCheckStatus,
      command: `git -C ${process.env.REPO_ROOT} apply --check ${process.env.DIFF_PATCH}`,
      stderr: process.env.PATCH_CHECK_STDERR,
    },
    changed_sections: {
      added_headings: difference(candidateHeadings, baselineHeadings),
      removed_headings: difference(baselineHeadings, candidateHeadings),
      baseline_heading_count: baselineHeadings.length,
      candidate_heading_count: candidateHeadings.length,
    },
  },
  evals: {
    note: 'run-eval.js records the --skill path and scores committed fixture outputs.',
    baseline: {
      status: process.env.BASELINE_EVAL_STATUS,
      command: `node evals/skill-review/run-eval.js --split all --skill ${path.join(process.env.REVIEW_DIR, 'baseline.md')} --json`,
      output: process.env.BASELINE_EVAL_JSON,
      stderr: process.env.BASELINE_EVAL_STDERR,
      score: baselineScore,
    },
    candidate: {
      status: process.env.CANDIDATE_EVAL_STATUS,
      command: `node evals/skill-review/run-eval.js --split all --skill ${process.env.CANDIDATE_FILE} --json`,
      output: process.env.CANDIDATE_EVAL_JSON,
      stderr: process.env.CANDIDATE_EVAL_STDERR,
      score: candidateScore,
    },
    delta: {
      hard: hardDelta,
      soft: softDelta,
    },
  },
  candidate_gate: {
    status: 'not_run',
    command: 'make -C kramme-cc-workflow skillopt-candidate-check',
    note: 'Run this gate after a human applies the candidate patch in a normal source edit.',
  },
  source_manifest: {
    obligation: 'If the candidate absorbs new external patterns, update skills/kramme:skill:review/references/sources.yaml in the manual source edit.',
  },
  recommendation: {
    status: recommendationStatus,
    rationale: recommendationRationale,
  },
};

fs.writeFileSync(process.env.SCORE_REPORT, `${JSON.stringify(report, null, 2)}\n`);

const sectionLines = [];
if (report.comparison.changed_sections.added_headings.length > 0) {
  sectionLines.push(`Added headings: ${report.comparison.changed_sections.added_headings.join(', ')}`);
}
if (report.comparison.changed_sections.removed_headings.length > 0) {
  sectionLines.push(`Removed headings: ${report.comparison.changed_sections.removed_headings.join(', ')}`);
}
if (sectionLines.length === 0) {
  sectionLines.push('No heading-level section additions or removals detected; inspect diff.patch for line edits.');
}

const review = [
  '# SkillOpt Candidate Review',
  '',
  `Generated: ${report.generated_at}`,
  `Source skill: ${report.source_skill}`,
  `Run directory: ${report.run_dir}`,
  '',
  '## Recommendation',
  '',
  `${report.recommendation.status}: ${report.recommendation.rationale}`,
  '',
  '## Files',
  '',
  `- baseline.md: ${report.files.baseline}`,
  `- candidate.md: ${report.files.candidate}`,
  `- diff.patch: ${report.files.diff_patch}`,
  `- score-report.json: ${process.env.SCORE_REPORT}`,
  '',
  '## Scores',
  '',
  `- Baseline: hard=${formatScore(baselineScore.hard)} soft=${formatScore(baselineScore.soft)} status=${process.env.BASELINE_EVAL_STATUS}`,
  `- Candidate: hard=${formatScore(candidateScore.hard)} soft=${formatScore(candidateScore.soft)} status=${process.env.CANDIDATE_EVAL_STATUS}`,
  `- Delta: hard=${formatScore(hardDelta)} soft=${formatScore(softDelta)}`,
  `- Note: ${report.evals.note}`,
  '',
  '## Gate Status',
  '',
  `- Patch applicability: ${patchCheckStatus}`,
  `- Candidate gate: ${report.candidate_gate.status}`,
  `- Candidate gate command after manual apply: \`${report.candidate_gate.command}\``,
  '',
  '## Changed Sections',
  '',
  ...sectionLines.map((line) => `- ${line}`),
  '',
  '## Manual Apply Only',
  '',
  'Manual apply only: inspect diff.patch, apply the candidate in a normal source edit, then run the candidate gate. This script does not modify source skill files.',
  '',
  '## Source Manifest Check',
  '',
  report.source_manifest.obligation,
  '',
].join('\n');

fs.writeFileSync(process.env.REVIEW_MD, review);
NODE

echo "$review_dir"
