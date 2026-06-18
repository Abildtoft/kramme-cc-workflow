#### Finding #1: SkillOpt environment registration preflight

**Location:** `kramme-cc-workflow/evals/skillopt/configs/skill-review.yaml:49`

**Issue:** The config uses `env.name: kramme_skill_review`, but a stock SkillOpt checkout only runs registered benchmark adapters, so the default real run would fail before training.

**Action taken:** Added a real-run preflight in `run-skillopt-skill-review.sh` that requires the external checkout to contain the `kramme_skill_review` environment when using the default command, while still allowing custom runners through `SKILLOPT_CMD`. Updated the README to document the external adapter requirement.

---

#### Finding #2: Incorrect `SKILLOPT_REPO` setup path

**Location:** `kramme-cc-workflow/evals/skillopt/README.md:41`

**Issue:** The setup instructions exported `SKILLOPT_REPO="$PWD/.context/skillopt"` after changing into `.context/skillopt`, which points at a nested non-existent checkout.

**Action taken:** Updated the install snippet to export `SKILLOPT_REPO="$PWD"` while inside the SkillOpt checkout, then return to the repository root before running repo-local commands.

---

#### Finding #3: Candidate review default destination mismatch

**Location:** `kramme-cc-workflow/evals/skillopt/scripts/export-candidate.sh:61`

**Issue:** The export helper defaulted to `<run-id>/skillopt-output/candidate-review`, while the README documents `<run-id>/candidate-review`.

**Action taken:** Changed the default destination to the run output directory's parent `candidate-review` sibling and updated the Bats test to assert the documented path.

---

#### Finding #4: SkillOpt eval command rooted in external checkout

**Location:** `kramme-cc-workflow/evals/skillopt/configs/skill-review.yaml:54`

**Issue:** `repo_eval_command` used `make -C kramme-cc-workflow`, but the runner changes into `SKILLOPT_REPO` before invoking SkillOpt, so an external adapter running this command would look for the workflow checkout inside the SkillOpt checkout.

**Action taken:** Changed the configured eval command to use the runner-exported `REPO_ROOT`, so the command targets the repository checkout regardless of SkillOpt's current working directory. Added Bats coverage that asserts the config is rooted through `REPO_ROOT`.

---

#### Finding #5: Relative `--out-root` resolved from caller cwd

**Location:** `kramme-cc-workflow/evals/skillopt/scripts/run-skillopt-skill-review.sh:82`

**Issue:** Relative `--out-root` values were resolved against the caller's current directory before the repository `.context` boundary check, so the documented `.context/skillopt-runs/...` path was rejected when invoked from `kramme-cc-workflow/`.

**Action taken:** Resolved relative `--out-root` paths against the repository root before validation. Added a dry-run regression test covering the documented relative output path from the workflow directory.

---

## Summary

- Addressed 5 findings, deferred 0 findings.
- Added Bats coverage for missing custom SkillOpt environment registration, the documented candidate-review export path, repository-rooted eval commands, and repository-rooted relative output paths.
- No breaking config behavior beyond failing earlier with a clearer message when the external SkillOpt checkout is missing the custom environment.

## Verification

- `bats kramme-cc-workflow/tests/skillopt-adapter.bats`: passed.
- `bash -n` for all three SkillOpt adapter scripts: passed.
- `bash evals/skillopt/scripts/run-skillopt-skill-review.sh --dry-run --run-id resolve-review-check --out-root .context/skillopt-runs/skill-review/resolve-review-check/custom-output`: passed from `kramme-cc-workflow/`.
- `shellcheck --severity=error` for all three SkillOpt adapter scripts: passed.
- `make -C kramme-cc-workflow test-skill-review-eval`: passed.
- `make -C kramme-cc-workflow lint-shell`: passed.
- `python3 kramme-cc-workflow/scripts/lint-skill-contracts.py`: passed.
- `make -C kramme-cc-workflow lint-python`: not run successfully because `ruff` is not installed in this environment.
- `make -C kramme-cc-workflow test`: inconclusive; interrupted after it remained stuck in unrelated `tests/convert-plugin.bats` for over nine minutes.
