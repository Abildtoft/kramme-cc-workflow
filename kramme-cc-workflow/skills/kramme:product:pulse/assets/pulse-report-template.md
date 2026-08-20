# Product Pulse

**Window:** <lookback window>  
**Date:** <YYYY-MM-DD>  
**Report mode:** <Measured / Mixed / Manual>  
**Strategy context:** <STRATEGY.md summary or MISSING PRODUCT CONTEXT: no STRATEGY.md found>

## Executive Summary

<3-5 sentences on what users experienced, what changed, and what needs attention.>

## Coverage

| Area | Status | Source | Caveat |
| ---- | ------ | ------ | ------ |
| Usage | <Measured / Manual / Unavailable> | <source> | <coverage limitation> |
| Quality | <Measured / Manual / Unavailable> | <source> | <coverage limitation> |
| Errors | <Measured / Manual / Unavailable> | <source> | <coverage limitation> |
| Performance | <Measured / Manual / Unavailable> | <source> | <coverage limitation> |
| Customer Signals | <Measured / Manual / Unavailable> | <source> | <coverage limitation> |

## Launch Evidence

<Populate this section for every PRODUCT PULSE HANDOFF whose evidence window overlaps the report window. Otherwise write `N/A — no overlapping launch handoff`. Group repeated handoff copies by stable launch identity, assign one report-local Launch ID to each unique launch, and use it in every related table.>

### Launch context

| Launch ID | Stable launch identity | Release / gate | Source launch ticket | Durable evidence record | Record mode | Decision history and current outcome | Unresolved signals and requirements | Coverage gaps and owners |
| --------- | ---------------------- | -------------- | -------------------- | ----------------------- | ----------- | ------------------------------------ | ----------------------------------- | ------------------------ |
| <launch ID> | <immutable release/artifact/deploy ID or canonical launch ID> | <release identity and current gate> | <URL/path; mark temporary or retired when applicable> | <approved retained URL/path> | <canonical full record / reference to canonical record> | <advance / hold / rollback / complete with timestamps> | <yellow/red, CONFUSION, UNVERIFIED, and MISSING REQUIREMENT entries with owners/stop boundaries, or none> | <gap, owner, stop boundary, and next step, or none> |

### Launch sources

| Launch ID | Source ID | Coverage | Provenance | Dimensions | Evidence window | Source evidence pointer | Durable evidence pointer | Limitations |
| --------- | --------- | -------- | ---------- | ---------- | --------------- | ----------------------- | ------------------------ | ----------- |
| <launch ID> | <stable source ID> | <Measured / Manual / Unavailable> | <provider telemetry/query / issue or support export / operator or user / unavailable> | <usage, quality, errors, performance, customer signals> | <UTC range> | <sanitized dashboard/query/export/ticket pointer> | <canonical record section or approved access-controlled pointer> | <coverage, access, redaction, or retention limits> |

### Sampling plan and observations — <Launch ID> / <Gate or plan ID>

<In a canonical full record, repeat this subsection for every gate / plan ID. In reference mode, name the canonical record, row counts, coverage bounds, and integrity hash instead of copying the complete history again.>

- **Gate / plan ID:** <stable identifier>
- **Cadence and source:** <cadence plus policy, evidence, or confirmed fallback>
- **Original bounds:** <start UTC, duration, and stop UTC>
- **Decision metrics and queries:** <metrics, exact source/query, thresholds and sources, expected denominators, and sample-sufficiency rules>
- **Early stop conditions and safe dispositions:** <red, rollback, unavailable evidence, user stop, loss of staffed coverage>
- **Watcher / recurrence:** <person watching and supported recurring-monitoring mechanism, or one-shot re-entry plan>

| Timestamp (UTC) | Gate / plan ID | Exposure | Source ID / query | Metric | Value / denominator | Threshold and source | Sample sufficiency | Decision | Notes |
| --------------- | -------------- | -------- | ----------------- | ------ | ------------------- | -------------------- | ------------------ | -------- | ----- |
| <timestamp> | <stable gate / plan ID> | <gate exposure> | <stable source ID and sanitized query template> | <metric> | <value and denominator> | <threshold and source> | <state and rule> | <green / hold / rollback> | <sanitized limitations or context> |

## Signals

### Usage

- <signal, metric, or MISSING PRODUCT CONTEXT/Unavailable marker>

### Quality

- <signal, QA result, support signal, or gap>

### Errors

- <error or incident signal, or gap>

### Performance

- <performance signal, or gap>

### Customer Signals

- <customer/support/feedback signal, or gap>

## Strategy Alignment

| Active Track or Metric | Signal | Interpretation |
| ---------------------- | ------ | -------------- |
| <track or metric> | <supporting/challenging/missing signal> | <what this means for product direction> |

## Followups

| Priority | Followup | Owner | Source |
| -------- | -------- | ----- | ------ |
| <High/Medium/Low> | <action or question> | <owner or MISSING PRODUCT CONTEXT: unknown> | <signal source> |

## Notes

- <Anything important about source quality, missing access, or manual assumptions.>
