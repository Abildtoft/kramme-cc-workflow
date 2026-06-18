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

## Summary

- Addressed 3 findings, deferred 0 findings.
- Added Bats coverage for missing custom SkillOpt environment registration and the documented candidate-review export path.
- No breaking config behavior beyond failing earlier with a clearer message when the external SkillOpt checkout is missing the custom environment.

## Verification

- `bats kramme-cc-workflow/tests/skillopt-adapter.bats`: passed.
- `bash -n` for all three SkillOpt adapter scripts: passed.
- `bash kramme-cc-workflow/evals/skillopt/scripts/run-skillopt-skill-review.sh --dry-run --run-id resolve-review-check`: passed.
- `shellcheck --severity=error` for all three SkillOpt adapter scripts: passed.
- `make -C kramme-cc-workflow test-skill-review-eval`: passed.
- `python3 kramme-cc-workflow/scripts/lint-skill-contracts.py`: passed.
- `make -C kramme-cc-workflow lint-python`: not run successfully because `ruff` is not installed in this environment.
