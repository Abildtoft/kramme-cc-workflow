#!/usr/bin/env bats

script_path() {
  printf "%s/../evals/skillopt/scripts/review-candidate.sh" "$BATS_TEST_DIRNAME"
}

workflow_root() {
  cd "$BATS_TEST_DIRNAME/.." && pwd -P
}

repo_root() {
  cd "$(workflow_root)/.." && pwd -P
}

source_skill() {
  printf "%s/skills/kramme:skill:review/SKILL.md" "$(workflow_root)"
}

@test "skillopt candidate review script passes bash syntax check" {
  run bash -n "$(script_path)"

  [ "$status" -eq 0 ]
}

@test "skillopt candidate review rejects missing best skill" {
  run_dir="$BATS_TEST_TMPDIR/.context/skillopt-runs/skill-review/missing/skillopt-output"
  mkdir -p "$run_dir"

  run bash "$(script_path)" "$run_dir"

  [ "$status" -eq 1 ]
  [[ "$output" == *"missing best_skill.md"* ]]
}

@test "skillopt candidate review rejects run directories outside context boundary" {
  run_dir="$BATS_TEST_TMPDIR/outside"
  mkdir -p "$run_dir"
  printf "# Candidate\n" > "$run_dir/best_skill.md"

  run bash "$(script_path)" "$run_dir"

  [ "$status" -eq 1 ]
  [[ "$output" == *"must stay under a .context/skillopt-runs/skill-review path"* ]]
}

@test "skillopt candidate review writes review packet and source-applicable patch" {
  run bash -c '
    set -euo pipefail
    workflow_root="'"$(workflow_root)"'"
    repo_root="'"$(repo_root)"'"
    source_skill="'"$(source_skill)"'"
    run_dir="'"$BATS_TEST_TMPDIR"'/.context/skillopt-runs/skill-review/fake-run/skillopt-output"
    mkdir -p "$run_dir"
    review_dir="$(cd "$(dirname "$run_dir")" && pwd -P)/candidate-review"

    cp "$source_skill" "$run_dir/best_skill.md"
    printf "\n## Candidate Review Test Appendix\n\nThis line makes the candidate differ from baseline.\n" >> "$run_dir/best_skill.md"

    before=$(shasum "$source_skill")
    actual=$(bash "$workflow_root/evals/skillopt/scripts/review-candidate.sh" "$run_dir")
    after=$(shasum "$source_skill")

    test "$actual" = "$review_dir"
    test "$before" = "$after"
    test -f "$review_dir/baseline.md"
    test -f "$review_dir/candidate.md"
    test -f "$review_dir/diff.patch"
    test -f "$review_dir/score-report.json"
    test -f "$review_dir/review.md"

    grep -Fq "Manual apply only" "$review_dir/review.md"
    grep -Fq "kramme-cc-workflow/skills/kramme:skill:review/SKILL.md" "$review_dir/diff.patch"
    git -C "$repo_root" apply --check "$review_dir/diff.patch"

    node -e "
      const fs = require(\"fs\");
      const report = JSON.parse(fs.readFileSync(process.argv[1], \"utf8\"));
      if (report.comparison.status !== \"changed\") process.exit(1);
      if (report.comparison.patch_check.status !== \"pass\") process.exit(1);
      if (report.evals.baseline.status !== \"pass\") process.exit(1);
      if (report.evals.candidate.status !== \"pass\") process.exit(1);
      if (report.candidate_gate.command !== \"make -C kramme-cc-workflow skillopt-candidate-check\") process.exit(1);
      if (report.recommendation.status !== \"NEEDS_REVIEW\") process.exit(1);
    " "$review_dir/score-report.json"
  '

  [ "$status" -eq 0 ]
}

@test "skillopt candidate review does not accept malformed candidate content" {
  run bash -c '
    set -euo pipefail
    workflow_root="'"$(workflow_root)"'"
    run_dir="'"$BATS_TEST_TMPDIR"'/.context/skillopt-runs/skill-review/malformed/skillopt-output"
    mkdir -p "$run_dir"
    printf "# not a valid skill\n" > "$run_dir/best_skill.md"

    review_dir=$(bash "$workflow_root/evals/skillopt/scripts/review-candidate.sh" "$run_dir")

    node -e "
      const fs = require(\"fs\");
      const report = JSON.parse(fs.readFileSync(process.argv[1], \"utf8\"));
      if (report.evals.candidate.status !== \"pass\") process.exit(1);
      if (report.recommendation.status === \"ACCEPT\") process.exit(1);
      if (report.recommendation.status !== \"NEEDS_REVIEW\") process.exit(1);
    " "$review_dir/score-report.json"
  '

  [ "$status" -eq 0 ]
}

@test "skillopt candidate review reports no-change candidates without source edits" {
  run bash -c '
    set -euo pipefail
    workflow_root="'"$(workflow_root)"'"
    source_skill="'"$(source_skill)"'"
    run_dir="'"$BATS_TEST_TMPDIR"'/.context/skillopt-runs/skill-review/no-change/skillopt-output"
    mkdir -p "$run_dir"
    review_dir="$(cd "$(dirname "$run_dir")" && pwd -P)/candidate-review"
    cp "$source_skill" "$run_dir/best_skill.md"

    before=$(shasum "$source_skill")
    bash "$workflow_root/evals/skillopt/scripts/review-candidate.sh" --run-dir "$run_dir" > "$BATS_TEST_TMPDIR/out.txt"
    after=$(shasum "$source_skill")

    test "$before" = "$after"
    test "$(cat "$BATS_TEST_TMPDIR/out.txt")" = "$review_dir"
    test -f "$review_dir/diff.patch"
    node -e "
      const fs = require(\"fs\");
      const report = JSON.parse(fs.readFileSync(process.argv[1], \"utf8\"));
      if (report.comparison.status !== \"unchanged\") process.exit(1);
      if (report.recommendation.status !== \"NO_CHANGE\") process.exit(1);
    " "$review_dir/score-report.json"
  '

  [ "$status" -eq 0 ]
}
