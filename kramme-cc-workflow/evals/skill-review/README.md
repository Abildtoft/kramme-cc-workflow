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

Fixture mode is the default and is the mode used by credential-free PR CI. It scores the
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
static checks with JSON output and `high` failure threshold, Node unit tests,
Python unit tests, the full Bats test suite, and this eval. Machines without
`skillspector` installed fail at the SkillSpector step; run the focused eval and
test targets above when validating only the deterministic harness.

## Live Claude Adapter

Setup, local commands, and GitHub secret/variable names are documented in the
root [README](../../../README.md#live-claude-evals-with-separate-organization-credits).
The separate live workflow uses the pinned Agent SDK directly, outside required
PR gates. Its API calls spend credits only when deliberately configured.

`run-live-eval.js` invokes this existing runner with `claude-predict.js` as its
prediction command. The adapter reads version-1 context on stdin, invokes the
reviewer through a minimal local plugin, saves the final review before returning
stdout, and leaves scoring to the existing scorer. Progress and sanitized
tool/SDK event summaries live under `.context/claude-evals/`; no raw environment,
SDK auth files, or full transcripts are exported. Each attempt records its
organization alias, requested/resolved model, outcome, and available cost
estimate. A missing cost is unknown, rather than proof of zero spending.

The organization router switches only on a recognized insufficient-credit
payload. SDK 0.3.310's outer assistant `error` field must identify a billing or
invalid-request failure, and its synthetic text must exactly match one of the
known insufficient-balance messages. Typed API exceptions may instead carry
the matching structured payload. Model-authored billing claims, generic 400,
402, or 429 errors, spend caps, and unknown messages never trigger switching.
Temporary errors receive the SDK's bounded same-key retries. No model or
subscription fallback is configured.

The pinned SDK was exercised against a loopback-only mock API for both a full
skill-tool review and the real 400 insufficient-credit response. Its synthetic
billing text is `Credit balance is too low` with `api_error_status: 400`; the iterator throws after emitting
that error result, so the adapter retains the prior structured error category.
The unchanged skill's plugin-qualified runtime name is normalized to
`eval-review:kramme-skill-review`. Bundled SDK skills/plugins are disabled, and
unexpected skill/plugin loading stops the attempt.

The eval profile `read-only-review-v1` stages the reviewer skill and one fixture
without the answer key or the repository. The SDK environment is replaced with
an explicit allowlist and the selected API key. User/project settings and MCP
servers are disabled. A pre-tool hook enforces real-path boundaries and permits
only the specified skill invocation and file reads/searches. Symlinks in staged
inputs are rejected. Successful skill-tool execution must be observed before a
prediction is accepted. SkillSpector and ecosystem analyzers are unavailable;
this is a controlled skill-review profile, not a full interactive-host test.

Defaults are one case at a time, 12 SDK turns and 120 seconds per attempt, 10
minutes across all organizations for one case, and 24 minutes of work with a
25-minute runner timeout reserved for cleanup
inside a 30-minute CI job. Use `--max-turns`, `--attempt-timeout-ms`, and
`--case-timeout-ms` to lower limits. Credit exhaustion restarts the unfinished
read-only case in a fresh session on the next key. Successful earlier calls in
that failed attempt can still consume credits.

### Checkpoints and recovery

- `pool-state.json` records active/exhausted aliases, credential fingerprints,
  and recheck times. An exhausted entry becomes eligible after 24 hours; its
  next pending real case doubles as the availability check. This is independent
  of billing anniversaries and calendar-month spend caps.
- `runs/<id>/run.json` freezes case IDs, input/model/SDK/profile fingerprint,
  provenance, completed predictions, and attempt summaries. `report.json`
  includes scored completed items, pending work, and a full aggregate only
  when the entire run completes. An `ERROR` report carries the nested runner's
  redacted diagnostic; the CI job summary repeats it with scores, organizations
  used in order, estimated cost, and pending case IDs. Failing phrase checks return exit 1 even when
  all predictions completed. `PAUSED_NO_CREDITS` returns exit 2 and never a full
  passing score.
- A matching unfinished run resumes automatically. A different fingerprint
  starts a new run while retaining old evidence; an explicitly named mismatched
  run is rejected. Completed automatic runs do not cache future sweeps.
- `writer.lock` prevents concurrent local writers and records an active adapter
  PID as well as the owning runner. An adapter aborts if its owner dies; stale
  ownership is recovered only once both processes have stopped. Lock mutation
  is serialized by the short-lived `writer.guard`. For a foreign/invalid lock
  or a guard left by a crash, first confirm no eval process remains, then remove
  only the abandoned lock/guard. Moving a broken checkpoint
  aside is an explicit recovery operation; corrupt state never resets silently.
- API key replacement clears stale exhaustion state for that alias only. To
  force an early replenishment check without replacing the key, stop writers,
  back up `pool-state.json`, then clear that alias's `exhausted_at` and
  `recheck_after` to `null`. Preserve the rest of the pool.
- CI exports only validated pool and unfinished run JSON for the current
  inputs; completed runs and unfinished runs superseded by changed inputs leave
  the checkpoint so artifact retention can expire them. Their earlier report
  artifacts keep the evidence. Reports are a separate artifact.
  It restores artifacts from completed scheduled/manual runs of this workflow
  on the original repository's `main` branch, including failed runs. Missing or
  expired artifacts produce a fresh-start notice; malformed existing artifacts
  stop restoration. ZIP paths are validated and read individually, never
  extracted into the checkout.
- Hard cancellation can prevent upload and can repeat work after the last
  durable artifact. A crash between the provider response and checkpoint write
  can repeat a case even locally. Exactly-once billing is not guaranteed.
- Local history remains until deliberately removed. Stop writers, preserve any
  needed report, then retire specific run directories. CI artifacts follow their
  retention policy; never delete an unfinished run if you need its progress.

Run the focused offline tests with `make test-skill-review-live-eval`. They use
fake SDK sessions, including mid-case credit exhaustion, rather than spending
real credits to validate failover.
