#!/usr/bin/env bats

@test "skillopt adapter scripts pass bash syntax checks" {
  run bash -c '
    cd "'"$BATS_TEST_DIRNAME"'/.."
    bash -n evals/skillopt/scripts/prepare-splits.sh
    bash -n evals/skillopt/scripts/run-skillopt-skill-review.sh
    bash -n evals/skillopt/scripts/export-candidate.sh
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

@test "skillopt runner dry-run prints command without requiring external checkout" {
  run bash -c '
    set -euo pipefail
    cd "'"$BATS_TEST_DIRNAME"'/.."
    before=$(shasum "skills/kramme:skill:review/SKILL.md")
    env -u SKILLOPT_REPO bash evals/skillopt/scripts/run-skillopt-skill-review.sh --dry-run --run-id bats-dry-run > "$BATS_TEST_TMPDIR/out.txt"
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

    if SKILLOPT_REPO="$fake_repo" bash evals/skillopt/scripts/run-skillopt-skill-review.sh --run-id bats-missing-env > "$BATS_TEST_TMPDIR/out.txt" 2> "$BATS_TEST_TMPDIR/err.txt"; then
      exit 1
    fi
    grep -q "requires SkillOpt environment '\''kramme_skill_review'\''" "$BATS_TEST_TMPDIR/err.txt"
  '

  [ "$status" -eq 0 ]
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
  run bash -c '
    set -euo pipefail
    run_dir="$BATS_TEST_TMPDIR/.context/skillopt-runs/skill-review/fake-run/skillopt-output"
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

  [ "$status" -eq 0 ]
}

@test "skillopt candidate export rejects destinations outside context boundary" {
  run bash -c '
    set -euo pipefail
    run_dir="$BATS_TEST_TMPDIR/.context/skillopt-runs/skill-review/fake-run/skillopt-output"
    mkdir -p "$run_dir"
    printf "# Candidate\n" > "$run_dir/best_skill.md"

    script="'"$BATS_TEST_DIRNAME"'/../evals/skillopt/scripts/export-candidate.sh"
    if bash "$script" --run-dir "$run_dir" --dest-dir "$BATS_TEST_TMPDIR/outside" > "$BATS_TEST_TMPDIR/out.txt" 2> "$BATS_TEST_TMPDIR/err.txt"; then
      exit 1
    fi
    grep -q "destination must stay under" "$BATS_TEST_TMPDIR/err.txt"
  '

  [ "$status" -eq 0 ]
}
