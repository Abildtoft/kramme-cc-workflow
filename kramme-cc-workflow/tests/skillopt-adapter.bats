#!/usr/bin/env bats

workflow_root() {
  cd "$BATS_TEST_DIRNAME/.." && pwd -P
}

repo_root() {
  cd "$(workflow_root)/.." && pwd -P
}

export_boundary_dir() {
  printf "%s/.context/skillopt-runs" "$(repo_root)"
}

@test "skillopt adapter scripts pass bash syntax checks" {
  run bash -c '
    cd "'"$BATS_TEST_DIRNAME"'/.."
    bash -n evals/skillopt/scripts/prepare-splits.sh
    bash -n evals/skillopt/scripts/run-skillopt-skill-review.sh
    bash -n evals/skillopt/scripts/export-candidate.sh
  '

  [ "$status" -eq 0 ]
}

@test "skillopt adapter scripts are included in shell lint gate" {
  run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    make --no-print-directory -n lint-shell > "$BATS_TEST_TMPDIR/lint-shell.txt"
    grep -Fq "evals/skillopt/scripts/*.sh" "$BATS_TEST_TMPDIR/lint-shell.txt"
  '

  [ "$status" -eq 0 ]
}

@test "skillopt split preparation validates committed split files" {
  run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    bash evals/skillopt/scripts/prepare-splits.sh --check-only > "$BATS_TEST_TMPDIR/split.txt"
    grep -q "/evals/skill-review/items$" "$BATS_TEST_TMPDIR/split.txt"
  '

  [ "$status" -eq 0 ]
}

@test "skillopt split preparation requires a value for --split-dir" {
  run bash -c '
    cd "'"$BATS_TEST_DIRNAME"'/.."
    bash evals/skillopt/scripts/prepare-splits.sh --split-dir
  '

  [ "$status" -eq 2 ]
  [[ "$output" == *"--split-dir requires a value"* ]]
}

@test "skillopt runner dry-run prints command without requiring external checkout" {
  run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    before=$(shasum "skills/kramme:skill:review/SKILL.md")
    env -u SKILLOPT_REPO -u SKILLOPT_CMD bash evals/skillopt/scripts/run-skillopt-skill-review.sh --dry-run --run-id bats-dry-run > "$BATS_TEST_TMPDIR/out.txt"
    after=$(shasum "skills/kramme:skill:review/SKILL.md")
    test "$before" = "$after"
    grep -q "DRY RUN: SkillOpt command preview" "$BATS_TEST_TMPDIR/out.txt"
    grep -q "SKILLOPT_REPO is not set" "$BATS_TEST_TMPDIR/out.txt"
    grep -q "scripts/train.py" "$BATS_TEST_TMPDIR/out.txt"
    grep -q ".context/skillopt-runs/skill-review/bats-dry-run/skillopt-output" "$BATS_TEST_TMPDIR/out.txt"
  '

  [ "$status" -eq 0 ]
}

@test "skillopt runner resolves relative output root from repository root" {
  run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    repo_root="$(cd .. && pwd -P)"
    env -u SKILLOPT_REPO bash evals/skillopt/scripts/run-skillopt-skill-review.sh \
      --dry-run \
      --run-id bats-relative-out \
      --out-root .context/skillopt-runs/skill-review/bats-relative-out/custom-output \
      > "$BATS_TEST_TMPDIR/out.txt"

    grep -Fq "SKILLOPT_OUT_ROOT=$repo_root/.context/skillopt-runs/skill-review/bats-relative-out/custom-output" "$BATS_TEST_TMPDIR/out.txt"
  '

  [ "$status" -eq 0 ]
}

@test "skillopt runner expands a literal tilde output root before boundary validation" {
  run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    repo_root="$(cd .. && pwd -P)"
    out_root="~/.context/skillopt-runs/skill-review/bats-tilde-out/custom-output"
    env -u SKILLOPT_REPO HOME="$repo_root" bash evals/skillopt/scripts/run-skillopt-skill-review.sh \
      --dry-run \
      --run-id bats-tilde-out \
      --out-root "$out_root" \
      > "$BATS_TEST_TMPDIR/out.txt"

    grep -Fq "SKILLOPT_OUT_ROOT=$repo_root/.context/skillopt-runs/skill-review/bats-tilde-out/custom-output" "$BATS_TEST_TMPDIR/out.txt"
  '

  [ "$status" -eq 0 ]
}

@test "skillopt runner rejects real run without SKILLOPT_REPO" {
  run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    if env -u SKILLOPT_REPO bash evals/skillopt/scripts/run-skillopt-skill-review.sh --run-id bats-missing > "$BATS_TEST_TMPDIR/out.txt" 2> "$BATS_TEST_TMPDIR/err.txt"; then
      exit 1
    fi
    grep -q "SKILLOPT_REPO is required" "$BATS_TEST_TMPDIR/err.txt"
  '

  [ "$status" -eq 0 ]
}

@test "skillopt runner rejects default command when custom environment is missing" {
  run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    fake_repo="$BATS_TEST_TMPDIR/skillopt"
    mkdir -p "$fake_repo/scripts" "$fake_repo/skillopt"
    printf "#!/usr/bin/env python3\n" > "$fake_repo/scripts/train.py"

    if env -u SKILLOPT_CMD SKILLOPT_REPO="$fake_repo" bash evals/skillopt/scripts/run-skillopt-skill-review.sh --run-id bats-missing-env > "$BATS_TEST_TMPDIR/out.txt" 2> "$BATS_TEST_TMPDIR/err.txt"; then
      exit 1
    fi
    grep -q "requires SkillOpt environment '\''kramme_skill_review'\''" "$BATS_TEST_TMPDIR/err.txt"
  '

  [ "$status" -eq 0 ]
}

@test "skillopt runner requires a value for --run-id and --out-root" {
  run bash -c '
    cd "'"$BATS_TEST_DIRNAME"'/.."
    bash evals/skillopt/scripts/run-skillopt-skill-review.sh --run-id
  '
  [ "$status" -eq 2 ]
  [[ "$output" == *"--run-id requires a value"* ]]

  run bash -c '
    cd "'"$BATS_TEST_DIRNAME"'/.."
    bash evals/skillopt/scripts/run-skillopt-skill-review.sh --out-root
  '
  [ "$status" -eq 2 ]
  [[ "$output" == *"--out-root requires a value"* ]]
}

@test "skillopt config roots eval command at exported repository root" {
  run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    grep -Fq '\''repo_eval_command: make -C "$REPO_ROOT/kramme-cc-workflow" skill-eval-skill-review'\'' evals/skillopt/configs/skill-review.yaml
  '

  [ "$status" -eq 0 ]
}

@test "skillopt candidate export copies review artifacts under context boundary" {
  boundary_dir="$(export_boundary_dir)/skill-review"
  mkdir -p "$boundary_dir"
  scratch_dir="$(mktemp -d "$boundary_dir/bats-export-valid-XXXXXX")"

  run bash -c '
    set -euo pipefail
    run_dir="'"$scratch_dir"'/fake-run/skillopt-output"
    mkdir -p "$run_dir/steps/step_0001"
    printf "# Candidate\n" > "$run_dir/best_skill.md"
    printf "{\"history\":[]}\n" > "$run_dir/history.json"
    printf "{\"config\":true}\n" > "$run_dir/config.json"
    printf "{\"hard\":1}\n" > "$run_dir/steps/step_0001/eval_results.json"

    script="'"$BATS_TEST_DIRNAME"'/../evals/skillopt/scripts/export-candidate.sh"
    dest=$(bash "$script" --run-dir "$run_dir")
    expected="$(cd "$(dirname "$run_dir")" && pwd -P)/candidate-review"

    test "$dest" = "$expected"
    test -f "$dest/best_skill.md"
    test -f "$dest/history.json"
    test -f "$dest/config.json"
    test -f "$dest/artifacts/steps/step_0001/eval_results.json"
  '

  rm -r "$scratch_dir"
  [ "$status" -eq 0 ]
}

@test "skillopt candidate export accepts destination paths containing spaces" {
  boundary_dir="$(export_boundary_dir)/skill-review"
  mkdir -p "$boundary_dir"
  scratch_dir="$(mktemp -d "$boundary_dir/bats export spaces XXXXXX")"

  run bash -c '
    set -euo pipefail
    run_dir="'"$scratch_dir"'/fake run/skillopt-output"
    mkdir -p "$run_dir"
    printf "# Candidate\n" > "$run_dir/best_skill.md"

    script="'"$BATS_TEST_DIRNAME"'/../evals/skillopt/scripts/export-candidate.sh"
    dest=$(bash "$script" --run-dir "$run_dir")
    test -f "$dest/best_skill.md"
  '

  rm -r "$scratch_dir"
  [ "$status" -eq 0 ]
}

@test "skillopt candidate export rejects destinations outside context boundary" {
  run bash -c '
    set -euo pipefail
    run_dir="$BATS_TEST_TMPDIR/fake-run/skillopt-output"
    mkdir -p "$run_dir"
    printf "# Candidate\n" > "$run_dir/best_skill.md"

    script="'"$BATS_TEST_DIRNAME"'/../evals/skillopt/scripts/export-candidate.sh"
    if bash "$script" --run-dir "$run_dir" --dest-dir "$BATS_TEST_TMPDIR/outside" > "$BATS_TEST_TMPDIR/out.txt" 2> "$BATS_TEST_TMPDIR/err.txt"; then
      exit 1
    fi
    grep -q "destination path must stay under" "$BATS_TEST_TMPDIR/err.txt"
  '

  [ "$status" -eq 0 ]
}

@test "skillopt candidate export rejects a destination that merely resembles the context boundary" {
  run bash -c '
    set -euo pipefail
    run_dir="$BATS_TEST_TMPDIR/fake-run/skillopt-output"
    mkdir -p "$run_dir"
    printf "# Candidate\n" > "$run_dir/best_skill.md"

    lookalike="$BATS_TEST_TMPDIR/.context/skillopt-runs/skill-review/escape"
    mkdir -p "$lookalike"

    script="'"$BATS_TEST_DIRNAME"'/../evals/skillopt/scripts/export-candidate.sh"
    if bash "$script" --run-dir "$run_dir" --dest-dir "$lookalike" > "$BATS_TEST_TMPDIR/out.txt" 2> "$BATS_TEST_TMPDIR/err.txt"; then
      exit 1
    fi
    grep -q "destination path must stay under" "$BATS_TEST_TMPDIR/err.txt"
    ! find "$lookalike" -mindepth 1 | grep -q .
  '

  [ "$status" -eq 0 ]
}

@test "skillopt candidate export rejects a destination sitting beside the boundary directory" {
  repo_root="$(repo_root)"
  run bash -c '
    set -euo pipefail
    run_dir="$BATS_TEST_TMPDIR/fake-run/skillopt-output"
    mkdir -p "$run_dir"
    printf "# Candidate\n" > "$run_dir/best_skill.md"

    script="'"$BATS_TEST_DIRNAME"'/../evals/skillopt/scripts/export-candidate.sh"
    if bash "$script" --run-dir "$run_dir" --dest-dir "'"$repo_root"'/.context/skillopt-runs-evil/x" > "$BATS_TEST_TMPDIR/out.txt" 2> "$BATS_TEST_TMPDIR/err.txt"; then
      exit 1
    fi
    grep -q "destination path must stay under" "$BATS_TEST_TMPDIR/err.txt"
    [ ! -e "'"$repo_root"'/.context/skillopt-runs-evil" ]
  '

  [ "$status" -eq 0 ]
}

@test "skillopt candidate export rejects a destination that escapes the boundary via traversal" {
  boundary_dir="$(export_boundary_dir)"
  mkdir -p "$boundary_dir"

  run bash -c '
    set -euo pipefail
    run_dir="$BATS_TEST_TMPDIR/fake-run/skillopt-output"
    mkdir -p "$run_dir"
    printf "# Candidate\n" > "$run_dir/best_skill.md"

    script="'"$BATS_TEST_DIRNAME"'/../evals/skillopt/scripts/export-candidate.sh"
    if bash "$script" --run-dir "$run_dir" --dest-dir "'"$boundary_dir"'/../escape-via-traversal" > "$BATS_TEST_TMPDIR/out.txt" 2> "$BATS_TEST_TMPDIR/err.txt"; then
      exit 1
    fi
    grep -q "destination path must stay under" "$BATS_TEST_TMPDIR/err.txt"
  '

  [ "$status" -eq 0 ]
  [ ! -e "$(repo_root)/.context/escape-via-traversal" ]
}

@test "skillopt candidate export rejects a destination reached through a symlink that escapes the repository" {
  boundary_dir="$(export_boundary_dir)"
  mkdir -p "$boundary_dir"
  outside_target="$BATS_TEST_TMPDIR/escape-target"
  mkdir -p "$outside_target"
  symlink_fixture="$(mktemp -d "$boundary_dir/bats-export-symlink-escape-XXXXXX")"
  symlink_path="$symlink_fixture/link"
  ln -s "$outside_target" "$symlink_path"

  run bash -c '
    set -euo pipefail
    run_dir="$BATS_TEST_TMPDIR/fake-run/skillopt-output"
    mkdir -p "$run_dir"
    printf "# Candidate\n" > "$run_dir/best_skill.md"

    script="'"$BATS_TEST_DIRNAME"'/../evals/skillopt/scripts/export-candidate.sh"
    if bash "$script" --run-dir "$run_dir" --dest-dir "'"$symlink_path"'/nested" > "$BATS_TEST_TMPDIR/out.txt" 2> "$BATS_TEST_TMPDIR/err.txt"; then
      exit 1
    fi
    grep -q "destination path must stay under" "$BATS_TEST_TMPDIR/err.txt"
  '

  rm -r "$symlink_fixture"
  [ "$status" -eq 0 ]
  [ ! -e "$outside_target/nested" ]
}

@test "skillopt candidate export requires a value for --run-dir and --dest-dir" {
  run bash -c '
    cd "'"$BATS_TEST_DIRNAME"'/.."
    bash evals/skillopt/scripts/export-candidate.sh --run-dir
  '
  [ "$status" -eq 2 ]
  [[ "$output" == *"--run-dir requires a value"* ]]

  run bash -c '
    cd "'"$BATS_TEST_DIRNAME"'/.."
    run_dir="$BATS_TEST_TMPDIR/fake-run"
    mkdir -p "$run_dir"
    bash evals/skillopt/scripts/export-candidate.sh --run-dir "$run_dir" --dest-dir
  '
  [ "$status" -eq 2 ]
  [[ "$output" == *"--dest-dir requires a value"* ]]
}
