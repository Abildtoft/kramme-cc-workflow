# SkillOpt Adapter

This directory contains the local bridge between the committed
`skill-review` eval split and an external SkillOpt checkout. SkillOpt itself
stays outside this repository: use `SKILLOPT_REPO` to point at a local clone or
installation checkout, and keep optimizer output under `.context/`.

References:

- SkillOpt docs: https://microsoft.github.io/SkillOpt/docs/guideline.html
- SkillOpt repository: https://github.com/microsoft/SkillOpt

## Safety Model

- The scripts never write to `skills/**`.
- The default output root is
  `.context/skillopt-runs/skill-review/<run-id>/`.
- Candidate export copies artifacts into
  `.context/skillopt-runs/skill-review/<run-id>/candidate-review/`.
- Applying `best_skill.md` to `skills/kramme:skill:review/SKILL.md` is a
  separate human review step and is not automated here.
- Tests use dry-run and fake run directories only; they do not call live
  models.

## Prerequisites

Install or clone SkillOpt separately:

```bash
git clone https://github.com/microsoft/SkillOpt.git .context/skillopt
cd .context/skillopt
python3 -m pip install -e .
export SKILLOPT_REPO="$PWD"
cd ../..
```

Then configure the model credentials required by your SkillOpt backend. Do not
commit credentials or generated outputs.

## Split Preparation

The committed eval split already follows SkillOpt's deterministic `split_dir`
shape:

```text
evals/skill-review/items/
├── train/items.json
├── val/items.json
└── test/items.json
```

Validate the split before a run:

```bash
bash evals/skillopt/scripts/prepare-splits.sh --check-only
```

The script only checks that the split files exist, parse as JSON arrays, and are
non-empty. It does not copy the split by default because the current layout is
already the layout SkillOpt expects.

## Dry Run

Preview the external command without requiring SkillOpt or model credentials:

```bash
bash evals/skillopt/scripts/run-skillopt-skill-review.sh --dry-run
```

The default command uses SkillOpt's `scripts/train.py` entry point with
`configs/skill-review.yaml`, the committed split directory, the current
`kramme:skill:review` skill as `skill_init`, and an output root under
`.context/skillopt-runs/skill-review/<run-id>/skillopt-output`.

## Real Pilot Run

After `SKILLOPT_REPO`, credentials, and the external `kramme_skill_review`
SkillOpt `EnvAdapter` registration are configured:

```bash
bash evals/skillopt/scripts/run-skillopt-skill-review.sh --run-id first-pilot
```

The default command refuses to start unless the external checkout contains that
custom environment registration, because stock SkillOpt only runs registered
benchmark adapters. If your external checkout uses a different command shape,
set `SKILLOPT_CMD`. The runner exports these variables before invoking it:

- `REPO_ROOT`
- `SKILLOPT_CONFIG`
- `SKILLOPT_SPLIT_DIR`
- `SKILLOPT_SKILL_INIT`
- `SKILLOPT_OUT_ROOT`

Example:

```bash
SKILLOPT_CMD='python scripts/train.py --config "$SKILLOPT_CONFIG" --split_dir "$SKILLOPT_SPLIT_DIR" --skill_init "$SKILLOPT_SKILL_INIT" --out_root "$SKILLOPT_OUT_ROOT"' \
  bash evals/skillopt/scripts/run-skillopt-skill-review.sh --run-id first-pilot
```

## Candidate Export

After a run writes `best_skill.md`, copy review artifacts into the candidate
review directory:

```bash
bash evals/skillopt/scripts/export-candidate.sh \
  --run-dir .context/skillopt-runs/skill-review/first-pilot/skillopt-output
```

The helper copies `best_skill.md`, common top-level run metadata, and
score/eval/result JSON artifacts. It refuses destinations outside a
`.context/skillopt-runs/` path.

## Candidate Review Packet

After a run writes `best_skill.md`, generate the human review packet:

```bash
bash evals/skillopt/scripts/review-candidate.sh \
  .context/skillopt-runs/skill-review/first-pilot/skillopt-output
```

The script writes these files under
`.context/skillopt-runs/skill-review/<run-id>/candidate-review/`:

- `baseline.md` - the current committed `kramme:skill:review` skill text.
- `candidate.md` - the SkillOpt `best_skill.md` candidate text.
- `diff.patch` - a source-applicable patch for inspection.
- `score-report.json` - eval status, score deltas, patch-check status, and
  the review recommendation.
- `review.md` - the concise human review summary.

`review-candidate.sh` runs `git apply --check` against `diff.patch`, but it
does not apply the patch or write to `skills/**`. Manual apply only: inspect the
packet, apply candidate edits in a normal source change, update
`skills/kramme:skill:review/references/sources.yaml` if the candidate absorbs
new external patterns, then run:

```bash
make -C kramme-cc-workflow skillopt-candidate-check
```

The eval runner currently records the `--skill` path while scoring committed
fixture outputs, so changed candidates report `NEEDS_REVIEW` even when the
fixture scores do not regress. Treat equal baseline/candidate scores as a gate
status signal, not proof that generated behavior improved.

## Pilot Acceptance Checklist

A SkillOpt candidate for `kramme:skill:review` is eligible for manual source
application only when all of these are true:

- `prepare-splits.sh --check-only` passes for the committed train, val, and
  held-out test items.
- The run output stays under
  `.context/skillopt-runs/skill-review/<run-id>/` and includes `best_skill.md`.
- `review-candidate.sh` writes the manual review packet with `baseline.md`,
  `candidate.md`, `diff.patch`, `score-report.json`, and `review.md`.
- `score-report.json` shows the patch check passes, baseline and candidate
  eval commands pass, and hard and soft score deltas do not regress.
- A human inspects `diff.patch` and `review.md` for scope, instruction quality,
  source-attribution obligations, and overfitting to fixture or session-derived
  examples.
- After manual application in a normal source edit,
  `make skillopt-candidate-check` passes.

Reject or rerun the candidate when any item fails, when the recommendation is
`REJECT`, when the candidate weakens safety instructions, or when the change is
only justified by examples that are not represented in deterministic evals.

## Expansion Criteria

Do not add another skill to this optimization loop until the target skill meets
all of these criteria:

- High usage or high impact justifies the maintenance cost of an eval split and
  candidate review process.
- Output is checkable with deterministic fixtures instead of relying only on
  subjective review.
- Train, val, and held-out test items exist and represent distinct examples;
  test items must not be used for prompt tuning or candidate selection.
- Fixtures include false-positive cases so optimization cannot win by
  reporting more findings indiscriminately.
- The SkillOpt runner can keep generated output under `.context/` and avoid
  writing to `skills/**`.
- A candidate gate exists that runs the relevant contracts, tests, static
  checks, and deterministic evals after manual application.
- The manual review packet has enough evidence to decide whether the candidate
  should be accepted, rejected, or sent back for more eval work.

The next candidate skills, in order, are:

1. `kramme:pr:resolve-review` - high leverage because it changes source code in
   response to review findings and needs strong false-positive protection.
2. `kramme:pr:code-review` - high usage, but broader finding categories require
   a larger deterministic split before optimization is safe.
3. `kramme:session:automate-repeats` - useful after the review skills because
   it depends on session-mining evidence and needs stricter privacy guardrails.

Each expansion should start with a new deterministic eval split and candidate
gate. Do not generalize the `skill-review` split or treat the pilot result as
evidence that another skill is ready.

## SkillOpt-Sleep Trial Guardrails

SkillOpt-Sleep is optional and proposal-only. It may mine prior sessions to
stage candidate skill edits, but Sleep-derived output cannot be committed,
auto-applied, or used to bypass the deterministic eval and candidate review
packet.

For any Sleep trial:

- Keep raw transcripts and private session content out of git.
- Keep scratch extraction, generated candidates, and run metadata under
  `.context/`.
- Use privacy-conscious extracted examples rather than raw session logs.
- Build or update deterministic train, val, and held-out test fixtures before
  accepting a candidate.
- Run the same candidate gate after manual application.

Sleep can help propose what to test next. It does not change the acceptance
standard.

## Python Adapters

No Python SkillOpt environment adapter is committed in this PR. SkillOpt's
current benchmark registration lives in the external checkout, so a complete
custom benchmark would require an external `EnvAdapter` plus registration in
that checkout. This repo-local bridge keeps the pilot boundary in shell scripts
and config until the external adapter contract is chosen.
