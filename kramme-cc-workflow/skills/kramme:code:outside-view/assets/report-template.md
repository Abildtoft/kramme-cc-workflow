# Outside View Report Template

Use this structure when writing `OUTSIDE_VIEW_REPORT.md` or a custom `--output` path. Replace all placeholders. Carry the previous report's `Run History` rows forward verbatim before appending the current run.

```markdown
# Outside View Report

**Date:** {YYYY-MM-DD} **Project:** {project} **Raters:** {N successful in-repo + cross-model?} **Model diversity:** {alternative model id | none + reason} **Output:** {path}

## Scorecard

| Rater | Frame        | Model   |  Score | One sentence to the owner |
| ----- | ------------ | ------- | -----: | ------------------------- |
| 1     | bare probe   | {model} | {n}/10 | {sentence}                |
| 2     | {persona id} | {model} | {n}/10 | {sentence}                |

**Mean:** {mean}/10 **Spread:** {min}–{max} **Trend:** {vs previous run, or first recorded run}

## Complaint Clusters

### OV-001: {Cluster title}

- **Support:** {k} of {N successful raters} ({consensus | split | single-voice})
- **Fingerprint:** {durable normalized root-cause fingerprint}
- **Raters:** {rater numbers / persona ids}
- **Representative quotes:** {one or two verbatim complaint excerpts}
- **Examples cited:** {files or areas raters pointed at, or "none — holistic"}

{Repeat for each cluster. Drop nothing; single-complaint clusters are normal.}

## Strengths

{What raters genuinely praised. Keeps the score interpretable and guards against reading every run as bad news.}

## Delta vs Structured Audit

**Compared against:** {report path + its date, or "no comparison available — run /kramme:code:weakness-audit before the next outside-view run"}

| Cluster | Status | Structured-audit reference |
| --- | --- | --- |
| OV-001 | {covered / filtered / blind spot} | {WA-### / filtered-candidate note / —} |

## Rubric Blind Spot Candidates

{Clusters absent from the structured audit, with recurrence counts from Run History.}

- **OV-00N ({title})** — seen in {k} consecutive runs. {Promotion candidate: name the concrete target — a weakness-audit rubric signal, a deslop pattern, a lint or CI gate, or a documentation fix — or "watch: first appearance, no promotion yet".}

## Coverage Notes

- **Elicitation mode:** {concurrent subagents | sequential (reduced isolation)}
- **Failed raters:** {none | which and why}
- **Cross-model rater:** {ran via {cli} | unavailable | failed: reason}
- **Rater footprints (self-reported):**
  - Rater 1 ({frame}): {directories, files, and docs it reported examining}
  - Rater 2 ({frame}): {...}
- **Unvisited areas:** {top-level areas no rater reported touching, or "none — every major area touched by at least one rater"}
- **Footprint caveat:** footprints are self-reported after impressions formed; this run samples salience, it does not certify coverage. Weight conclusions accordingly.

## Run History

| Date | Mean | Scores | Top clusters | Blind spots | Personas | Model diversity |
| --- | --: | --- | --- | --- | --- | --- | --- |
| {YYYY-MM-DD} | {mean} | {comma-separated} | {top 3 cluster titles} | {every `fingerprint: title`, or none} | {persona ids} | {model | none + reason} |
```

Keep `Run History` append-only: earlier rows are carried forward unchanged. The complete `Blind spots` cell, not the top-three summary, is the source for recurrence counting; persona ids remain the source for rotation.
