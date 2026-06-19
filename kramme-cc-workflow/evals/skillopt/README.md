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

## Python Adapters

No Python SkillOpt environment adapter is committed in this PR. SkillOpt's
current benchmark registration lives in the external checkout, so a complete
custom benchmark would require an external `EnvAdapter` plus registration in
that checkout. This repo-local bridge keeps the pilot boundary in shell scripts
and config until the external adapter contract is chosen.
