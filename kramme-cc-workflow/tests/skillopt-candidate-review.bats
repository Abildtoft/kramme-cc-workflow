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

boundary_dir() {
  printf "%s/.context/skillopt-runs/skill-review" "$(repo_root)"
}

@test "skillopt candidate review script passes bash syntax check" {
  run bash -n "$(script_path)"

  [ "$status" -eq 0 ]
}

@test "skillopt candidate review requires a value for --run-dir" {
  run bash "$(script_path)" --run-dir

  [ "$status" -eq 2 ]
  [[ "$output" == *"--run-dir requires a value"* ]]
}

@test "skillopt candidate review rejects missing best skill" {
  mkdir -p "$(boundary_dir)"
  scratch_dir="$(mktemp -d "$(boundary_dir)/bats-missing-XXXXXX")"
  run_dir="$scratch_dir/skillopt-output"
  mkdir -p "$run_dir"

  run bash "$(script_path)" "$run_dir"

  rm -r "$scratch_dir"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing best_skill.md"* ]]
}

@test "skillopt candidate review rejects run directories outside context boundary" {
  run_dir="$BATS_TEST_TMPDIR/outside"
  mkdir -p "$run_dir"
  printf "# Candidate\n" > "$run_dir/best_skill.md"

  run bash "$(script_path)" "$run_dir"

  [ "$status" -eq 1 ]
  [[ "$output" == *"run directory path must stay under"* ]]
}

@test "skillopt candidate review rejects a run directory that merely resembles the context boundary" {
  run_dir="$BATS_TEST_TMPDIR/.context/skillopt-runs/skill-review/escape/skillopt-output"
  mkdir -p "$run_dir"
  printf "# Candidate\n" > "$run_dir/best_skill.md"

  run bash "$(script_path)" "$run_dir"

  [ "$status" -eq 1 ]
  [[ "$output" == *"run directory path must stay under"* ]]
}

@test "skillopt candidate review rejects a run directory sitting beside the boundary directory" {
  repo_root="$(repo_root)"
  fixture_dir="$(mktemp -d "$repo_root/.context/skillopt-runs/skill-review-legacy-XXXXXX")"
  run_dir="$fixture_dir/skillopt-output"
  mkdir -p "$run_dir"
  printf "# Candidate\n" > "$run_dir/best_skill.md"

  run bash "$(script_path)" "$run_dir"

  rm -r "$fixture_dir"
  [ "$status" -eq 1 ]
  [[ "$output" == *"run directory path must stay under"* ]]
}

@test "skillopt candidate review rejects a run directory that escapes the boundary via traversal" {
  boundary_dir="$(boundary_dir)"
  repo_root="$(repo_root)"
  mkdir -p "$boundary_dir"
  outside_dir="$(mktemp -d "$repo_root/.context/escape-via-traversal-XXXXXX")"
  printf "# Candidate\n" > "$outside_dir/best_skill.md"

  run bash "$(script_path)" "$boundary_dir/../../$(basename "$outside_dir")"

  rm -r "$outside_dir"
  [ "$status" -eq 1 ]
  [[ "$output" == *"run directory path must stay under"* ]]
}

@test "skillopt candidate review rejects a run directory reached through a symlink that escapes the repository" {
  boundary_dir="$(boundary_dir)"
  mkdir -p "$boundary_dir"
  outside_target="$BATS_TEST_TMPDIR/escape-target"
  mkdir -p "$outside_target/skillopt-output"
  printf "# Candidate\n" > "$outside_target/skillopt-output/best_skill.md"
  symlink_fixture="$(mktemp -d "$boundary_dir/bats-review-symlink-escape-XXXXXX")"
  symlink_path="$symlink_fixture/link"
  ln -s "$outside_target" "$symlink_path"

  run bash "$(script_path)" "$symlink_path/skillopt-output"

  rm -r "$symlink_fixture"
  [ "$status" -eq 1 ]
  [[ "$output" == *"run directory path must stay under"* ]]
}

@test "skillopt candidate review writes review packet and source-applicable patch" {
  mkdir -p "$(boundary_dir)"
  scratch_dir="$(mktemp -d "$(boundary_dir)/bats-review-XXXXXX")"

  run bash -c '
    set -euo pipefail
    workflow_root="'"$(workflow_root)"'"
    repo_root="'"$(repo_root)"'"
    source_skill="'"$(source_skill)"'"
    run_dir="'"$scratch_dir"'/skillopt-output"
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

  rm -r "$scratch_dir"
  [ "$status" -eq 0 ]
}

@test "skillopt candidate review does not accept malformed candidate content" {
  mkdir -p "$(boundary_dir)"
  scratch_dir="$(mktemp -d "$(boundary_dir)/bats-malformed-XXXXXX")"

  run bash -c '
    set -euo pipefail
    workflow_root="'"$(workflow_root)"'"
    run_dir="'"$scratch_dir"'/skillopt-output"
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

  rm -r "$scratch_dir"
  [ "$status" -eq 0 ]
}

@test "skillopt candidate review reports no-change candidates without source edits" {
  mkdir -p "$(boundary_dir)"
  scratch_dir="$(mktemp -d "$(boundary_dir)/bats-no-change-XXXXXX")"

  run bash -c '
    set -euo pipefail
    workflow_root="'"$(workflow_root)"'"
    source_skill="'"$(source_skill)"'"
    run_dir="'"$scratch_dir"'/skillopt-output"
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

  rm -r "$scratch_dir"
  [ "$status" -eq 0 ]
}
