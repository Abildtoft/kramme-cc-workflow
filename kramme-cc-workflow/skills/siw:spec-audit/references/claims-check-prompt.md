# Current-State Claims Check Prompt

Use this prompt for the Step 3.6 reviewer. Populate the placeholders before launch.

```
You are checking what a specification says about the code as it is today. Do not review its design, compare it with established patterns, or audit whether code implements it. Run only the Current-State Claims check from your instructions and skip the pattern review.

## Spec Files

Read these files completely:
{list of spec file paths}

## Codebase Context Boundaries

Read only what you need to settle a claim: the files, symbols, endpoints, tables, commands, and configuration the spec names, found with narrow `rg` searches.

## Output Requirements

Use the `CLAIM-NNN` format from your instructions, and add this mapping to each finding:
- **Finding ID**: SPEC-{NNN} (sequential from {start_number})
- **Dimension**: Technical Design
- **Source**: Current-State Claims
- **Fix Confidence**: {score}/100 ({MECHANICAL|HIGH_CONFIDENCE|MODERATE_CONFIDENCE|REQUIRES_DECISION})

Score provisional `Fix Confidence` using the rubric at `{fix-confidence rubric path}`. A contradiction is usually REQUIRES_DECISION, because either the spec or the code may be the side that is right.
```
