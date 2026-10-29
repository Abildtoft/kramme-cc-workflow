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

## Live Provider Adapters

The optional live evaluator runs `kramme:skill:review` against the existing
synthetic fixtures with Claude or OpenAI models. Each provider has its own
ordered organization pool. The evaluator uses organization A until a
recognized insufficient-credit error, restarts the unfinished case on B, and
continues in configured order. When every organization is empty it pauses;
later runs recheck exhausted entries after 24 hours. It finishes the finite
eval sweep even when credits remain.

Providers never fall back to each other. Every run, checkpoint directory, and
CI artifact belongs to one provider, and the provider is part of the run
fingerprint.

| `--provider` | Runtime | Key variables | Model variable | State directory |
| --- | --- | --- | --- | --- |
| `anthropic` (default) | Pinned Claude Agent SDK | `ANTHROPIC_EVAL_KEY_*` | `ANTHROPIC_EVAL_MODEL` | `.context/claude-evals/` |
| `openai` | Responses API tool loop, no SDK | `OPENAI_EVAL_KEY_*` | `OPENAI_EVAL_MODEL` | `.context/openai-evals/` |

The separate live workflow runs outside required PR gates. Its API calls spend
credits only when deliberately configured.

### Setup and local runs

Run these commands from the repository root.

1. Create a dedicated API key in each credit-bearing organization. For OpenAI,
   use a project key in each organization. Keep auto-reload or auto-recharge
   disabled and purchased balances absent if you want the evaluator to spend
   only the granted credits.
   - Anthropic credits renew on each subscription's billing cycle, rather than
     a shared calendar-month reset. Anthropic confirms that these credits cover
     direct Agent SDK runs; the official Claude Code GitHub Action has different
     eligibility. See
     [monthly API credits](https://support.claude.com/en/articles/17154008-monthly-api-credits-for-max-and-team-plans).
   - OpenAI reports an empty prepaid balance as `credit_balance_exhausted`, and
     its organization and project spend limits as separate codes. A spend
     limit below the credit balance stops the run instead of rotating, so
     raise or remove those limits for eval projects. See
     [OpenAI error codes](https://developers.openai.com/api/docs/guides/error-codes).
2. Run `npm ci` to install the pinned Claude SDK development dependency; the
   OpenAI adapter needs no package. Copy the provider's pool example,
   [Anthropic](credit-pool.example.json) or
   [OpenAI](openai-credit-pool.example.json), under `.context/` and edit its
   ordered `alias` / `key_env` entries for your organizations. Each named
   `ANTHROPIC_EVAL_KEY_*` or `OPENAI_EVAL_KEY_*` environment variable supplies
   its key; never put keys in the configuration file.
3. Set `ANTHROPIC_EVAL_MODEL` or `OPENAI_EVAL_MODEL` to an explicit available
   model ID and validate without API calls:

   ```bash
   node kramme-cc-workflow/evals/skill-review/run-live-eval.js \
     --organizations .context/eval-organizations.json --dry-run
   node kramme-cc-workflow/evals/skill-review/run-live-eval.js --provider openai \
     --organizations .context/openai-eval-organizations.json --dry-run
   ```

4. Remove `--dry-run` to perform one live sweep. The runner resumes matching
   unfinished runs automatically. `--run-id <id>` explicitly resumes/replays a
   run; changed inputs require a new ID. A completed automatic run is followed
   by a fresh sweep on the next invocation.

Exit codes are `0` for complete/passing, `1` for errors or completed check
failures, and `2` for an incomplete credit pause. Rate limits use bounded
retries on the same key; authentication, ambiguous billing, and spend-cap
errors stop with a diagnostic.

### Daily CI

To enable daily CI at 07:23 UTC, configure these GitHub Actions values for each
provider you want to run. A provider's job stays disabled until both of its
variables are set.

| Kind | Name | Value |
| --- | --- | --- |
| Secret | `ANTHROPIC_EVAL_KEYS_JSON` / `OPENAI_EVAL_KEYS_JSON` | A JSON object mapping that provider's configured environment-variable names to keys, for example `{"OPENAI_EVAL_KEY_A":"your-first-key","OPENAI_EVAL_KEY_B":"your-second-key"}`. |
| Variable | `ANTHROPIC_EVAL_ORGANIZATIONS` / `OPENAI_EVAL_ORGANIZATIONS` | An ordered JSON array such as `[{"alias":"org-a","key_env":"OPENAI_EVAL_KEY_A"},{"alias":"org-b","key_env":"OPENAI_EVAL_KEY_B"}]`. Every listed `key_env` needs a key in that provider's secret. |
| Variable | `ANTHROPIC_EVAL_MODEL` / `OPENAI_EVAL_MODEL` | The explicit model ID for that provider. |

Then run **Live Skill Review Eval** manually on `main`, or let the daily
schedule run after the workflow is merged. It serializes runs, and each
provider job restores validated checkpoints from prior trusted runs. The
Claude job uploads `claude-eval-checkpoint` plus `claude-eval-report`; the
OpenAI job uploads `openai-eval-checkpoint` plus `openai-eval-report`. Read
each job summary: a handled credit pause means **incomplete**, even when the
workflow exits successfully. State artifacts expire after 90 days or the
repository's shorter retention limit; loss of a checkpoint can repeat recent
cases.

### Isolation and verification

Each session sees only the selected key and the staged reviewer/fixture files.
It cannot read scoring expectations or run arbitrary tools. The read-only
profile omits SkillSpector and ecosystem scanners. The existing phrase scorer
gives an initial regression signal; inspect diagnostics before making quality
claims.

Default PR tests remain offline; live evals are separate from required merge
gates. Run `make -C kramme-cc-workflow test-skill-review-live-eval` for
credential-free adapter tests. Checkpoint archive tests require `zip` and
`unzip`, present on the supported GitHub runners and macOS; install them on
other development hosts if missing.

### Adapter behavior

`run-live-eval.js` invokes this existing runner with the provider's adapter,
`claude-predict.js` or `openai-predict.js`, as its prediction command. Both
adapters share the organization rotation in `live-predict.js`. Each reads
version-1 context on stdin, invokes the reviewer, saves the final review before
returning stdout, and leaves scoring to the existing scorer. Progress and
sanitized tool/API event summaries live in the provider's state directory; no
raw environment, auth files, or full transcripts are exported. Each attempt
records its organization alias, requested/resolved model, outcome, and
available cost estimate. A missing cost is unknown, rather than proof of zero
spending.

The eval profile `read-only-review-v1` is shared. It stages the reviewer skill
and one fixture without the answer key or the repository, and permits only the
reviewer skill invocation and file reads/searches inside that workspace. Real-
path checks run before every tool call, and symlinks in staged inputs are
rejected. Successful reviewer invocation must be observed before a prediction
is accepted. SkillSpector and ecosystem analyzers are unavailable; this is a
controlled skill-review profile, not a full interactive-host test.

Defaults are one case at a time, 12 turns and 120 seconds per attempt, 10
minutes across all organizations for one case, and 24 minutes of work with a
25-minute runner timeout reserved for cleanup inside a 30-minute CI job. Use
`--max-turns`, `--attempt-timeout-ms`, and `--case-timeout-ms` to lower
limits. Credit exhaustion restarts the unfinished read-only case in a fresh
session on the next key. Successful earlier calls in that failed attempt can
still consume credits.

#### Claude

The Claude router switches only on a recognized insufficient-credit payload.
SDK 0.3.310's outer assistant `error` field must identify a billing or
invalid-request failure, and its synthetic text must exactly match one of the
known insufficient-balance messages. Typed API exceptions may instead carry
the matching structured payload. Model-authored billing claims, generic 400,
402, or 429 errors, spend caps, and unknown messages never trigger switching.
Temporary errors receive the SDK's bounded same-key retries. No model or
subscription fallback is configured.

The pinned SDK was exercised against a loopback-only mock API for both a full
skill-tool review and the real 400 insufficient-credit response. Its synthetic
billing text is `Credit balance is too low` with `api_error_status: 400`; the
iterator throws after emitting that error result, so the adapter retains the
prior structured error category. The unchanged skill's plugin-qualified
runtime name is normalized to `eval-review:kramme-skill-review`. Bundled SDK
skills/plugins are disabled, and unexpected skill/plugin loading stops the
attempt.

The SDK environment is replaced with an explicit allowlist and the selected
API key. User/project settings and MCP servers are disabled. A pre-tool hook
applies the profile's boundary before SDK approval.

#### OpenAI

The OpenAI adapter calls `https://api.openai.com/v1/responses` with `fetch`
and implements the profile's `Skill`, `Read`, `Glob`, and `Grep` tools itself.
`Skill` returns the staged reviewer's `SKILL.md` for the exact fixture
argument; the file tools run in the eval process after the profile's boundary
check. Requests use `store: false` and resend the whole conversation,
including reasoning items, on every turn. The selected key travels only in the
`Authorization` header. The adapter records the resolved model and per-attempt
token usage in the trace; it does not estimate cost.

The router switches only on HTTP 429 with `error.code`
`credit_balance_exhausted`, or a failed response carrying that code:

| Error | Outcome |
| --- | --- |
| `credit_balance_exhausted` | Mark the organization exhausted and restart the case on the next key. |
| `organization_spend_limit_exceeded`, `project_spend_limit_exceeded` | Stop with `spend_limit`. |
| `organization_usage_limit_exceeded` | Stop with `usage_limit`. |
| `insufficient_quota` type or code without one of the codes above | Stop with `billing_error`; it cannot tell an empty balance from a limit. |
| Other 429s, 408, 409, 5xx, network failures | Retry twice on the same key, honoring `retry-after-ms` or `retry-after`, then stop with `retry_exhausted`. |
| 401 or 403 | Stop with `authentication_failed` or `permission_denied`. |

Model-authored billing text is ordinary review output. This profile measures
the reviewer skill with OpenAI models; it does not exercise the Codex host.
Codex 0.165 maps `credit_balance_exhausted` and both spend-limit codes to one
`Quota exceeded` message, so a Codex-hosted adapter could not tell an empty
balance from a configured limit.

### Checkpoints and recovery

- Each provider's state directory holds its own `pool-state.json`, run
  directories, and writer lock. Use a separate `--state-dir` per provider; a
  shared directory would reset the other provider's exhaustion state.
- `pool-state.json` records active/exhausted aliases, credential fingerprints,
  and recheck times. An exhausted entry becomes eligible after 24 hours; its
  next pending real case doubles as the availability check. This is independent
  of billing anniversaries and calendar-month spend caps.
- `runs/<id>/run.json` freezes case IDs, input/model/runtime/profile/provider
  fingerprint, provenance, completed predictions, and attempt summaries.
  `report.json` includes scored completed items, pending work, and a full
  aggregate only when the entire run completes. An `ERROR` report carries the
  nested runner's redacted diagnostic; the CI job summary repeats it with
  scores, organizations used in order, estimated cost, and pending case IDs.
  Failing phrase checks return exit 1 even when all predictions completed.
  `PAUSED_NO_CREDITS` returns exit 2 and never a full passing score.
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
  Each provider job restores its own checkpoint artifact from completed
  scheduled/manual runs of this workflow on the original repository's `main`
  branch, including failed runs. Missing or expired artifacts produce a
  fresh-start notice; malformed existing artifacts stop restoration. ZIP paths
  are validated and read individually, never extracted into the checkout.
- Hard cancellation can prevent upload and can repeat work after the last
  durable artifact. A crash between the provider response and checkpoint write
  can repeat a case even locally. Exactly-once billing is not guaranteed.
- Local history remains until deliberately removed. Stop writers, preserve any
  needed report, then retire specific run directories. CI artifacts follow their
  retention policy; never delete an unfinished run if you need its progress.

Run the focused offline tests with `make test-skill-review-live-eval`. They use
fake SDK sessions and a fake Responses endpoint, including mid-case credit
exhaustion, rather than spending real credits to validate failover.
