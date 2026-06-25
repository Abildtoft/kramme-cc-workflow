# Codebase Exploration Detail

Use this during Step 4 after reading and presenting the issue context. Scale the depth to the issue: a tightly-scoped issue that already lists files and patterns needs targeted verification; a broadly-scoped issue needs full exploration.

## Why This Phase Is Essential

Issues describe:

- **What** should be accomplished
- **Why** it matters
- **Acceptance criteria** for verification

They may not describe:

- Which files/modules to modify
- What patterns to follow
- How existing similar features are implemented

Exploration bridges this gap before any code changes.

## Exploration Steps

Run all of the following before drafting the technical plan:

1. **Check supporting and contract specs (if they exist):**

   ```bash
   for dir in siw/supporting-specs siw/contracts; do
     [ -d "$dir" ] && ls "$dir"
   done
   ```

   If supporting or contract specs exist, identify which ones are relevant:
   - Data model specs for entity-related work
   - API specs for endpoint-related work
   - Contract specs for interface, data shape, or integration guarantees
   - UI specs for frontend-related work

   Read relevant sections for detailed requirements.

2. **Search for similar features/patterns:**
   - Use Glob and Grep to find related code
   - Look for existing implementations of similar functionality
   - Identify relevant modules, services, or components

3. **Delegate broader exploration to a sub-agent when available:**

   On Claude Code, invoke the Task tool with `subagent_type=Explore`. On Codex or other harnesses, use the equivalent exploration agent if one is available; otherwise continue with direct Glob/Grep. The prompt:

   ```text
   Find existing implementations related to {feature description from issue}.
   Identify relevant files, patterns, and conventions used in this codebase.
   ```

4. **Identify key files and patterns:**
   - List files that will likely need modification
   - Note existing patterns to follow
   - Find test patterns for similar features

## Findings Template

```text
Codebase Exploration Results:

Supporting Specs Referenced:
- siw/supporting-specs/01-data-model.md#user-entity (if applicable)
- siw/supporting-specs/02-api-specification.md#endpoints (if applicable)
- siw/contracts/01-api-contract.md#request-shape (if applicable)

Relevant Files Found:
- {file 1} - {why relevant}
- {file 2} - {why relevant}

Existing Patterns:
- {pattern description} in {location}

Similar Implementations:
- {feature} in {files} - could serve as reference

Suggested Approach:
{brief technical approach based on findings}
```
