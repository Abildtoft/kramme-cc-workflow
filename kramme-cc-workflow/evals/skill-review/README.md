# Skill Review Eval Harness

This harness provides deterministic fixture scoring for `kramme:skill:review`.
By default, it is local-only: it does not invoke a model, call SkillOpt, reach
external services, or modify candidate skills. The committed fixtures are
synthetic examples used as eval data.

## Pilot Scope

This pilot targets `kramme:skill:review` only. Do not generalize its split,
fixtures, or scores to another skill without creating a separate deterministic
train/val/test split and candidate gate for that skill.

## Layout

```text
evals/skill-review/
├── fixtures/              # Synthetic skill directories
├── items/
│   ├── train/items.json   # Development examples
│   ├── val/items.json     # Candidate-selection examples
│   └── test/items.json    # Held-out examples
├── run-eval.js            # CLI runner
└── scorer.js              # Deterministic phrase scorer
```

## Item Schema

Each item is a JSON object:

```json
{
  "id": "train-good-skill",
  "input_skill_dir": "fixtures/good-skill",
  "difficulty": "easy",
  "fixture_review_output": "No findings found...",
  "expected_findings": [
    { "id": "frontmatter-missing", "match": "frontmatter is missing" }
  ],
  "forbidden_findings": [
    { "id": "false-positive-unsafe", "match": "unsafe side effects" }
  ],
  "required_checks": [
    { "id": "focused-pass", "match": "focused and composable pass" }
  ]
}
```

`input_skill_dir` is resolved relative to this harness directory and must stay
inside it. Future pasted-text items may use `input_skill_text` instead.
Each split file must contain at least one item; empty corpora fail validation
instead of reporting a perfect score. Each item must define at least one
scoring check across `expected_findings`, `forbidden_findings`, or
`required_checks`.

The scorer normalizes text before phrase matching, so punctuation and case do
not affect matches. Hard scoring passes only when every expected finding and
required check is present and every forbidden finding is absent. Soft scoring is
the fraction of those checks that passed.

## Prediction Modes

Fixture mode is the default and is the only mode used by CI. It scores the
committed `fixture_review_output` text in each item:

```bash
node evals/skill-review/run-eval.js --split all --json
```

Adapted mode is opt-in with `--prediction-command`. The runner sends one JSON
object per item to the command on stdin and scores the command's stdout as the
prediction text:

```bash
node evals/skill-review/run-eval.js \
  --split train \
  --skill skills/kramme:skill:review \
  --prediction-command "./scripts/review-skill-fixture.sh" \
  --json
```

The adapter JSON includes `adapter_version`, `eval_root`, the raw `skill`
argument, an absolute `skill_path`, and an `item` object with `id`, `split`,
`difficulty`, input skill text when present, and resolved fixture paths when
`input_skill_dir` is present. It does not include fixture review output or
scoring expectations. This keeps local fake adapters deterministic in tests
while allowing a separate live runner to use `--skill` to generate predictions.

## Output Shape

```json
{
  "split": "all",
  "skill": null,
  "hard": 1,
  "soft": 1,
  "diagnostics": [],
  "items": [
    {
      "id": "train-good-skill",
      "split": "train",
      "hard": 1,
      "soft": 1,
      "prediction": {
        "source": "fixture_review_output",
        "text": "No findings found..."
      },
      "diagnostics": {
        "missing_expected": [],
        "missing_required": [],
        "present_forbidden": []
      }
    }
  ]
}
```

When `--prediction-command` is used, each item reports
`"source": "prediction_command"` instead of `"fixture_review_output"`.

Run the full fixture eval:

```bash
make skill-eval-skill-review
```

This prints machine-readable aggregate JSON for the `train`, `val`, and
`test` splits. To run the focused harness tests:

```bash
make test-skill-review-eval
```

Before reviewing a generated candidate skill patch, run the local candidate
gate:

```bash
make skillopt-candidate-check
```

The candidate gate runs skill contract linting, changed-skill SkillSpector
static checks with JSON output and `high` failure threshold, the full Bats test
suite, and this eval. Machines without `skillspector` installed fail at the
SkillSpector step; run the focused eval and test targets above when validating
only the deterministic harness.
