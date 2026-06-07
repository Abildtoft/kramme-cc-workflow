# Judge Prompt Template

Adapted from EveryInc compound-engineering-plugin `ce-optimize/references/judge-prompt-template.md`, reviewed at commit `6f9ab03a031c054a8046659926251fb6c149269f`.

Use this template after degenerate gates pass and only for specs with `metric.primary.type: judge`.

## Item Evaluation

```text
You are a quality judge evaluating output items for an optimization experiment.

Score each item using the rubric below and return structured JSON. Be consistent: the same quality level should receive the same score across items.

<rubric>
{rubric}
</rubric>

<items>
{items_json}
</items>

<output-contract>
Return only a valid JSON array. No prose, no markdown, no explanation outside the JSON.

Each element must have:
- "item_id": the input item identifier
- every score/count/diagnostic field requested by the rubric
- "ambiguous": true when the item cannot be confidently scored

Example:
[
  {"item_id": "cluster-42", "score": 4, "distinct_topics": 1, "outlier_count": 0, "ambiguous": false},
  {"item_id": "cluster-17", "score": 2, "distinct_topics": 3, "outlier_count": 2, "ambiguous": false}
]

Rules:
- Evaluate each item independently.
- Score against the rubric, not against the rest of the batch.
- Every item in the batch must appear in the output.
- If context is thin, return a best-guess score and set "ambiguous": true.
</output-contract>
```

## Singleton Evaluation

Use this when `metric.judge.singleton_sample` is greater than 0.

```text
You are a quality judge evaluating singleton items that are currently not grouped.

Determine whether each singleton should have been grouped with an existing cluster, or whether it is genuinely unique. Return structured JSON.

<rubric>
{singleton_rubric}
</rubric>

<singletons>
{singletons_json}
</singletons>

<existing-clusters>
{cluster_summaries}
</existing-clusters>

<output-contract>
Return only a valid JSON array. No prose, no markdown.

Each element must have:
- "item_id": the singleton identifier
- every field requested by the singleton rubric

Example:
[
  {"item_id": "issue-1234", "should_cluster": true, "best_cluster_id": "cluster-42", "confidence": 4},
  {"item_id": "issue-5678", "should_cluster": false, "best_cluster_id": null, "confidence": 5}
]
</output-contract>
```

## Variables

| Variable              | Source                                          |
| --------------------- | ----------------------------------------------- |
| `{rubric}`            | Spec `metric.judge.rubric`                      |
| `{items_json}`        | Sampled experiment output items                 |
| `{singleton_rubric}`  | Spec `metric.judge.singleton_rubric`            |
| `{singletons_json}`   | Sampled singleton items                         |
| `{cluster_summaries}` | Summary of existing groups for singleton checks |
