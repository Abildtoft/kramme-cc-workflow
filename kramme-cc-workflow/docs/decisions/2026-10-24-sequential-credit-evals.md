# Sequential organization credits for live skill-review evals

- Status: ACCEPTED
- Date: 2026-10-24
- Deciders: repository maintainer

## Context

The maintainer has several Claude API organizations, each receiving monthly credits, with no purchased balance. The allocations cannot be pooled. The existing skill-review fixture harness supports live predictions, but default CI only scores committed answers. The approved approach uses each organization until it cannot fund the next request, then tries the next organization's key.

## Decision

Add an optional, direct Claude Agent SDK adapter inside `evals/skill-review/`. Keep the existing version-1 prediction protocol, fixture mode, scorer, and PR gates. Evaluate only `kramme:skill:review`; this does not expand the July 6 eval cap or the SkillOpt pilot.

Use an ordered key pool. Rotate only on a recognized insufficient-credit error from the runtime, never arbitrary model text or a status code alone. Bound same-key transient retries and session turns/runtime. Restart an unfinished read-only case after rotation. Pause when all keys are exhausted and recheck each entry after 24 hours using pending work. Different billing anniversaries do not require a shared reset date. Keep auto-reload off and do not purchase credits.

Stage the reviewer and fixture without expected answers; replace the SDK child environment with the selected key and explicit runtime values. Disable unrelated settings and MCP. Enforce read-only tool and real-path boundaries before tool approval. Require observed reviewer skill execution. This profile omits scanners and does not claim full interactive-host fidelity.

Persist successful predictions and sanitized attempt evidence before returning stdout. Fingerprint inputs, model, SDK, and profile so a resumed run cannot mix versions. Use one local writer lock and one CI concurrency group. A separate scheduled/manual workflow on trusted `main` restores validated data artifacts and publishes explicit complete/failed/paused states. It remains disabled until explicit model and organization variables are configured. No live run is required in PR CI.

## Tradeoffs and alternatives

- Static sharding across organizations avoids mid-case restarts but requires allocating work before knowing the real balances. Sequential failover fits the maintainer's requested consumption order.
- An external proxy or shared state service could continue individual requests across keys and survive more CI failures. The small read-only pilot does not justify another deployed component; restart a case and use workflow artifacts.
- Artifact retention and hard cancellation can lose recent progress. Preserve completed local predictions and disclose possible repeats; do not promise exactly-once billing.
- Use real insufficient-credit errors for routing rather than estimated cost thresholds or a balance scraper. Unknown billing errors stop for diagnosis.
- Keep the existing phrase scorer as an observational signal. Do not optimize against held-out cases or claim comprehensive quality from a passing score.

## Verification

Fake-SDK tests cover depletion, partial-case restart, replenishment, checkpoints, credential/answer isolation, and failure classification. CLI/workflow tests keep ordinary checks offline and enforce trusted artifact sources and branch guards. A separately observed manual live run is needed after model and keys are set.
