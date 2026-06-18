# Skill Review Eval Harness

This harness provides deterministic fixture scoring for `kramme:skill:review`.
It is intentionally local-only: it does not invoke a model, call SkillOpt, reach
external services, or modify candidate skills. The committed fixtures are
synthetic examples used as eval data.

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

Run the full fixture eval:

```bash
node evals/skill-review/run-eval.js --split all --json
```

The optional `--skill <path>` argument is accepted and recorded in output for
later SkillOpt adapter work. This harness still scores only the committed
fixture review output.
