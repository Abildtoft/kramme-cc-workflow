# Description Optimization

Systematic process for improving a skill's `description` field to maximize trigger accuracy — triggering when it should, not triggering when it shouldn't.

Based on the [Anthropic skill-creator](https://github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md) optimization loop.

## Why this matters

The `description` field is the only metadata the agent sees when deciding whether to load a skill. A weak description causes:
- **Under-triggering** — skill never activates for valid use cases
- **Over-triggering** — skill activates for unrelated requests, wasting context

## Step 1: Generate trigger eval queries

Create 20 queries: 10 should-trigger, 10 should-not-trigger.

### Should-trigger queries (10)

These must cover:
- Different phrasings of the same intent (formal, casual, terse)
- Cases where the user doesn't explicitly name the skill
- Uncommon but valid use cases
- Scenarios where this skill wins over similar skills

### Should-not-trigger queries (10)

These must cover:
- Near-misses with overlapping keywords
- Adjacent domains (similar but different capability)
- Ambiguous phrasing where a naive keyword match would false-positive
- Requests that sound related but belong to a different skill

### Quality characteristics

- **Realistic** — what actual users type, not contrived test strings
- **Concrete** — include file paths, column names, project context
- **Varied** — mix lengths, casing, abbreviations, even typos
- **Edge cases** — not clear-cut distinctions that any description would handle

### Output format

```json
[
  {"query": "create a new skill for linting markdown files", "should_trigger": true},
  {"query": "I need a skill that runs eslint on PRs", "should_trigger": true},
  {"query": "scaffold a plugin skill", "should_trigger": true},
  {"query": "how do I edit an existing skill's frontmatter", "should_trigger": false},
  {"query": "refactor the code-review agent prompt", "should_trigger": false},
  {"query": "add a new hook to hooks.json", "should_trigger": false}
]
```

## Step 2: Score the current description

For each query, evaluate: "Given ONLY the skill name and description below, would you trigger this skill?"

```
name: {skill-name}
description: {current-description}

User prompt: {query}

Answer: TRIGGER or SKIP
```

Compute metrics:
- **True Positives (TP)** — should-trigger queries that trigger
- **False Negatives (FN)** — should-trigger queries that don't trigger
- **False Positives (FP)** — shouldn't-trigger queries that trigger
- **True Negatives (TN)** — shouldn't-trigger queries that don't trigger
- **Precision** = TP / (TP + FP)
- **Recall** = TP / (TP + FN)
- **Accuracy** = (TP + TN) / total

## Step 3: Improve the description

Analyze failures and rewrite:

1. **Failed triggers (FN)** — what intent categories are missing from the description?
2. **False triggers (FP)** — what negative triggers or boundary markers are missing?

Rules for the rewrite:
- Stay under 1,024 characters
- Generalize from failures to broader intent categories — don't just add the specific failed query words
- Include negative triggers ("Not for...", "Don't use when...")
- Write in third person ("Creates...", "Guides...")
- Be "pushy" — bias toward triggering for ambiguous cases (under-triggering is worse than over-triggering)

## Step 4: Re-score and iterate

Score the new description against the same queries. Repeat Steps 3-4 until:
- All queries pass (precision and recall = 1.0)
- No improvement after 2 consecutive iterations
- Maximum 5 iterations reached

## Step 5: Apply the result

Replace the `description` field in the skill's SKILL.md frontmatter with the best-performing version (highest accuracy, with ties broken by recall).
