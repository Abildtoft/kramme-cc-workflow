# Audit Agent Prompt

Use this prompt structure for each Explore agent in Step 3.3. Populate the placeholders for the assigned dimension group before launch.

```
You are auditing a specification document for quality. Do NOT look at any implementation code. Do NOT use Grep or Glob against the codebase. Analyze the spec text ONLY using the Read tool on the provided spec files.

## Spec Files

Read these files completely:
{list of spec file paths}

## Your Assigned Dimensions

Analyze the spec against each dimension below. For each finding, report:
- **Finding ID**: SPEC-{NNN} (use sequential numbers starting from {start_number})
- **Dimension**: {which dimension}
- **Title**: Brief description
- **Location**: Source file > section heading
- **Details**: What the issue is, with quotes from the spec
- **Severity**: Critical | Major | Minor
- **Recommendation**: Specific action to fix
- **Fix Confidence**: {score}/100 ({MECHANICAL|HIGH_CONFIDENCE|MODERATE_CONFIDENCE|REQUIRES_DECISION})

## Rules

- **Report on every dimension.** Even if no findings, confirm the dimension was analyzed.
- **Do not return early.** Continue until you have checked every section against every assigned dimension.
- **Quote the spec.** When flagging an issue, include the relevant text from the spec.
- **Be specific in recommendations.** "Add more detail" is not enough. Say what detail is missing.
- **Score provisional fix confidence on every finding using `references/fix-confidence-rubric.md`.** Sum the four 0-25 sub-scores, then apply the tier boundaries, the sub-score guardrail, and the safety caps documented in that file before writing the provisional `Fix Confidence`.

{Dimension-specific instructions inserted here — see Section 3.4}

## Work Context Adjustments

This spec has Work Type: {work_context.work_type}

Priority dimensions (flag even minor issues): {work_context.priority_dimensions}
Deprioritized dimensions (cap at Minor severity): {work_context.deprioritized}

When evaluating **deprioritized dimensions**:
- Assess severity normally and keep that original severity in the finding data
- Tag each finding with: **[Deprioritized — cap to Minor during aggregation]**
- Do NOT downgrade the severity yourself; the lead applies the Minor cap in Step 4.3.5 after recording `original_severity`

When evaluating **priority dimensions**:
- Apply strict scrutiny. Even small gaps should be flagged.
- Tag priority findings with: **[Priority dimension]**

{If work_context is Production Feature or not specified, omit this entire section from the agent prompt.}
```
