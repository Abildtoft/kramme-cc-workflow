# Skill Evaluation with skillgrade

[skillgrade](https://github.com/mgechev/skillgrade) automates testing whether agents correctly discover, invoke, and produce correct output from skills.

## Installation

```bash
npm i -g skillgrade
```

Requires Node.js 20+ and Docker (or `--provider=local` for local execution).

## Where eval files live

Place `eval.yaml` inside the skill directory:

```
kramme:skill-name/
├── SKILL.md
├── eval.yaml          # Skill evaluation definition
├── graders/           # Deterministic grader scripts
│   └── check.sh
├── fixtures/          # Input files for eval tasks
└── references/
```

## eval.yaml structure

```yaml
version: "1"

defaults:
  agent: claude            # claude | gemini | codex
  provider: docker         # docker | local
  trials: 5
  timeout: 300
  threshold: 0.8
  docker:
    base: node:20-slim

tasks:
  - name: basic-usage
    instruction: |
      Describe the task the agent should accomplish using this skill.
      Be specific about expected output format and location.
    workspace:
      - src: source/path
        dest: destination
    graders:
      - type: deterministic
        run: bash graders/check.sh
        weight: 0.7
      - type: llm_rubric
        rubric: |
          Did the agent invoke the skill correctly? (0-0.5)
          Is the output well-structured and complete? (0-0.5)
        weight: 0.3
```

## Keep graders self-contained

Skill eval assets should be self-contained inside the skill directory. If you
want shared shell helpers, keep them alongside the graders for that skill:

```text
kramme:skill-name/
├── SKILL.md
├── eval.yaml
└── graders/
    ├── check.sh
    └── lib.sh
```

Source sibling helpers from a grader with:

```bash
source "$(dirname "$0")/lib.sh"
```

Typical helper functions:
- `check NAME RESULT MSG` — record a check result
- `file_exists PATH` — assert file exists
- `file_has_content PATH MIN_CHARS` — assert file has minimum character count
- `file_lacks_pattern PATH PATTERN` — assert pattern absent from file
- `file_has_pattern PATH PATTERN` — assert pattern present in file
- `finalize` — print JSON result and exit

## Deterministic graders

Scripts that return JSON with a 0.0-1.0 score:

```bash
#!/bin/bash
passed=0; total=2

if test -f output.txt; then
  passed=$((passed + 1))
fi

if grep -q "expected-content" output.txt 2>/dev/null; then
  passed=$((passed + 1))
fi

score=$(awk "BEGIN {printf \"%.2f\", $passed/$total}")
echo "{\"score\":${score},\"details\":\"${passed}/${total} passed\"}"
```

If the skill depends on tools that are not present in the base image, install them in `docker.setup` for that eval.

Required output fields: `score` (0.0-1.0) and `details` (string).
Optional: `checks` array with `{name, passed, message}` objects.

Use `awk` for arithmetic — `bc` is unavailable in `node:20-slim`.

## LLM rubric graders

Evaluate agent session transcripts against qualitative criteria:

```yaml
- type: llm_rubric
  rubric: |
    Skill discovery (0-0.3): Did the agent find and trigger the skill?
    Correctness (0-0.4): Is the output correct?
    Efficiency (0-0.3): Completed without unnecessary steps?
  weight: 0.3
```

## Running evaluations

```bash
# Quick smoke test (5 trials)
skillgrade --smoke

# Confidence estimate (15 trials)
skillgrade --reliable

# Regression check (30 trials)
skillgrade --regression

# Run specific task only
skillgrade --eval=basic-usage --trials=5

# Validate graders against reference solutions before running
skillgrade --validate

# View results in browser
skillgrade preview browser
```

## CI integration

```yaml
# .github/workflows/skill-eval.yml
- run: |
    npm i -g skillgrade
    cd skills/kramme:skill-name
    ANTHROPIC_API_KEY=${{ secrets.ANTHROPIC_API_KEY }} \
      skillgrade --regression --ci --threshold=0.8 --provider=local
```

Use `--provider=local` in CI to skip Docker overhead.

## Writing good evals

- **Grade outcomes, not steps** — check the result file, not which commands ran.
- **Name output files explicitly** — if the grader checks `output.html`, say so in the instruction.
- **Minimal scope** — 3-5 well-designed tasks beat 50 noisy ones.
- **Validate first** — run `--validate` with reference solutions before full evaluation.
- **Combine grader types** — use deterministic for objective checks (file exists, content matches) and LLM rubric for subjective quality (methodology, workflow adherence).

## Skills that need external services

Some skills cannot be fully evaluated in isolation because they require:
- **External APIs**: Linear (`kramme:linear:*`), GitHub/GitLab PRs (`kramme:pr:*`)
- **Browser automation**: `kramme:browse`, `kramme:qa`
- **Plugin infrastructure**: `kramme:hooks:*`
- **Agent Teams**: `kramme:*:team` variants

For these, write trigger-only evals (LLM rubric checking the agent's approach and plan) rather than full execution evals.
