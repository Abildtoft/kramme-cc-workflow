# Health Score Rubric

Compute a weighted 0-100 health score across QA categories. The score provides a single comparable metric across QA runs.

## Category Scores

Each category starts at 100. Deduct per finding found in that category.

| Finding Severity | Deduction |
|------------------|-----------|
| Blocker | -25 |
| Major | -15 |
| Minor | -8 |
| Info | -3 |

Minimum score per category is 0.

## Categories and Weights

| Category | Weight | What it measures |
|----------|--------|-----------------|
| Console | 15% | JavaScript errors, unhandled rejections, warnings |
| Network | 10% | Failed API calls, 4xx/5xx responses, CORS errors |
| Visual | 10% | Layout overflow, broken images, text overlap, clipping |
| Functional | 25% | Broken flows, dead buttons, form failures, navigation dead-ends |
| Data | 10% | Stale data, missing empty states, wrong context, pagination bugs |
| Interaction | 15% | Buttons, forms, dropdowns, modals, keyboard navigation |
| Content | 15% | Copy errors, missing labels, developer jargon, unclear messages |

## Computation

```
score = round(Σ (category_score × weight))
```

Where `category_score = max(0, 100 - Σ deductions_in_category)`.

## Mapping Findings to Categories

Each QA finding maps to one category based on its primary symptom:

- **Console**: JavaScript errors, unhandled promise rejections, deprecation warnings
- **Network**: Failed HTTP requests, slow responses (> 3s), CORS errors, mixed content
- **Visual**: Overflow, clipping, broken images, layout shift, unreadable text
- **Functional**: Broken core flow, page crash, data loss, feature not working
- **Data**: Wrong data displayed, stale state, missing empty state, broken pagination
- **Interaction**: Button doesn't respond, form won't submit, dropdown broken, modal stuck
- **Content**: Typo, unclear error message, developer jargon visible, missing placeholder text

If a finding spans multiple categories, assign it to the most severe one.

## Score Interpretation

| Score | Label | Meaning |
|-------|-------|---------|
| 90-100 | Excellent | No blockers, minimal issues. Ready to ship. |
| 75-89 | Good | No blockers, some minor issues. Ready with caveats. |
| 50-74 | Fair | Major issues present. Needs work before shipping. |
| 25-49 | Poor | Multiple major issues or blockers. Significant work needed. |
| 0-24 | Critical | Fundamental breakage. Core flows are broken. |
