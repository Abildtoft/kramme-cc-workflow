---
name: kramme:product:pulse
description: Generate a time-windowed product pulse report in docs/pulse-reports/ covering usage, quality, errors, performance, customer signals, and followups. Use for weekly recaps, launch checks, "how are we doing", or strategy feedback loops. Works with partial or manual sources. Not for QA test reports, PR review, or editing STRATEGY.md directly.
argument-hint: "[lookback window, e.g. 24h, 7d, 1h] [--inline]"
disable-model-invocation: true
user-invocable: true
---

# Product Pulse

Generate a compact, time-windowed report about what users experienced and how the product performed. Reports are durable product history and are written to `docs/pulse-reports/` unless `--inline` is passed.

## Workflow

1. **Parse arguments.**
   - Interpret the first non-flag argument as the lookback window.
   - Default to `24h` when no window is supplied.
   - Accept simple windows such as `1h`, `24h`, `7d`, `14d`, and `30d`.
   - If the window token cannot be parsed (e.g. `weekly`, `last sprint`), warn that the token was not understood and default to `24h`.
   - If `--inline` is present, reply with the report and do not write a file.

2. **Resolve product grounding.**
   - If repo-root `STRATEGY.md` exists, read it and extract target problem, users, key metrics, active tracks, and non-goals.
   - If its `last_updated` frontmatter is older than 90 days, mark relevant strategy context as `STALE:` in the report and treat strategy alignment as tentative.
   - If `STRATEGY.md` is absent, continue and mark the report with `MISSING PRODUCT CONTEXT: no STRATEGY.md found`.
   - Do not edit `STRATEGY.md` from this skill.

3. **Discover available sources.**
   - Check for obvious local evidence: log directories, analytics notes, error exports, support exports, issue tracker exports, release notes, and prior pulse reports.
   - Check available read-only connectors or MCP tools when present, such as Linear, GitHub, analytics, error tracking, or observability tools.
   - Ask the user for manual inputs only when no source can answer a section or when a source requires access not available in the current harness.

4. **Classify source coverage.**
   - **Measured:** evidence came from logs, telemetry, monitoring, issue trackers, support exports, or another concrete data source.
   - **Manual:** evidence came from the user during this run.
   - **Unavailable:** no usable source was available for the window.
   - Never present manual or unavailable coverage as measured data.

5. **Gather pulse dimensions.**
   - Usage: adoption, active users, core actions, notable dropoffs.
   - Quality: QA results, broken flows, support complaints, user confusion.
   - Errors: exceptions, incidents, failed jobs, noisy alerts.
   - Performance: latency, uptime, Core Web Vitals, slow routes, resource pressure.
   - Customer signals: support requests, customer needs, user feedback, sales notes, churn/loss reasons, or unavailable evidence.
   - Followups: product questions, owner-visible risks, and concrete next actions.
   - Strategy alignment: whether observed signals support or challenge active tracks and key metrics.

6. **Write the report.**
   - Read `assets/pulse-report-template.md` and populate it.
   - If writing to disk, create `docs/pulse-reports/` when needed.
   - Use filename format `{YYYY-MM-DD}-{window}.md`.
   - If the filename already exists, append `-2`, `-3`, and so on rather than overwriting.

7. **Summarize in chat.**
   - State the output path or `inline`.
   - List top signals, coverage gaps, and followups.
   - If the report contradicts `STRATEGY.md`, say so as a strategy-update candidate, but do not edit strategy automatically.

## Source Handling Rules

- Treat all external tools as read-only for this workflow.
- If a source requires credentials or is unavailable, mark it `Unavailable` with the exact missing access.
- If data only covers part of the window, mark the limitation in the Coverage table.
- If all evidence is manual, the report is still useful; label it as a manual pulse.

## Verification

Before claiming completion:

1. The report contains the requested lookback window.
2. Coverage clearly separates measured, manual, and unavailable sources.
3. Missing strategy or telemetry is marked with `MISSING PRODUCT CONTEXT` or `Unavailable`, not hidden.
4. File output goes under `docs/pulse-reports/` unless `--inline` was passed.
5. `STRATEGY.md` was not modified.
