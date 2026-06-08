---
name: kramme:docs:review
description: "Review one Markdown document outside tracked SIW workflows: requirements, implementation plans, strategy drafts, README/docs drafts, proposals, and decision drafts. Classifies the document, selects focused review lenses, and returns severity-ordered findings inline by default or in a requested report file. Not for source-code review, PR diffs, live-product review, or documents under siw/; use SIW audit skills for tracked SIW artifacts."
argument-hint: "[markdown-path] [--inline|--file|--output <path>]"
disable-model-invocation: true
user-invocable: true
---

# Document Review

Review one Markdown document without changing it. Classify the document, apply focused review lenses, and return concrete findings with section or line references.

**Arguments:** "$ARGUMENTS"

## Boundaries

This skill reviews document quality only.

- **Does:** Review one Markdown document for coherence, scope, feasibility, product fit, security/privacy risk, design implications, and reader usefulness when those lenses apply.
- **Does:** Return findings inline by default, or write a generated report only when `--file` or `--output <path>` is present.
- **Does not:** Edit the source document, review source code, inspect PR diffs, test running software, or create tracking issues.
- **Does not:** Replace SIW audits. Documents under `siw/` route to `/kramme:siw:spec-audit` or `/kramme:siw:product-audit`.

## Workflow

1. **Parse arguments**
   - Extract exactly one Markdown path from `$ARGUMENTS`.
   - Recognize `--inline`, `--file`, and `--output <path>`.
   - If no path is provided, ask for one Markdown document path.
   - If more than one path is provided, stop and ask the user to choose one document. Do not batch documents.
   - If `--inline` is present, set `OUTPUT_MODE=inline`.
   - If `--file` is present, set `OUTPUT_MODE=file` and `OUTPUT_PATH=DOC_REVIEW.md`.
   - If `--output <path>` is present, set `OUTPUT_MODE=file` and `OUTPUT_PATH` to that path. `--output` overrides `--file`.
   - If no output flag is present, set `OUTPUT_MODE=inline`.

2. **Validate the target**
   - Confirm the path exists, is readable, and has a Markdown extension (`.md`, `.markdown`, `.mdown`, or `.mkd`).
   - If the path is under `siw/`, stop before reviewing:
     - Use `/kramme:siw:spec-audit <path>` for specs, plans, issue definitions, phase docs, or implementation-facing SIW documents.
     - Use `/kramme:siw:product-audit <path>` for product strategy, value proposition, product narrative, or product-audit SIW documents.
   - If the user asks to review source code, PR changes, or a live app instead, route to the relevant code, PR, QA, or product review skill.

3. **Validate report output**
   - If `OUTPUT_MODE=file`, resolve `OUTPUT_PATH` inside the current working directory or repository root.
   - Reject an output path that resolves to the source document.
   - Reject an output path outside the working tree unless the user explicitly supplied an absolute path.
   - Treat the report as generated output: overwriting `DOC_REVIEW.md` or the explicit `--output` path is allowed.

4. **Read the document with locations**
   - Read the full document with line numbers.
   - Build a section map from Markdown headings, including heading text and start line.
   - Do not inspect source-code files to verify implementation claims. If a claim requires codebase verification, mark it as a coverage gap or `UNVERIFIED` rather than silently expanding scope.

5. **Classify the document**
   - Choose exactly one primary type:
     - `requirements`: feature requirements, PRD, user stories, acceptance criteria.
     - `implementation-plan`: step plan, migration plan, rollout plan, technical approach.
     - `strategy`: product/company/team strategy, goals, positioning, priorities.
     - `readme-docs`: README, guide, runbook, API docs, user docs, onboarding docs.
     - `proposal-decision`: proposal, RFC, decision draft, option comparison.
   - If the document mixes types, choose the type that best matches its primary job and note secondary types in coverage.
   - If the document is too ambiguous to classify, emit a `CONFUSION:` block naming the ambiguity and ask what the document is meant to achieve.

6. **Select review lenses**
   - Always apply:
     - `coherence`: internal consistency, terminology, narrative order, contradictions, missing connective tissue.
     - `scope`: boundaries, non-goals, unowned work, vague commitments, hidden expansion.
   - Apply `feasibility` to requirements, implementation plans, proposals, migrations, timelines, staffing assumptions, or technical commitments.
   - Apply `product` to requirements, strategy, proposals, user-facing docs, value propositions, adoption claims, metrics, and prioritization.
   - Apply `security-privacy` when the document mentions authentication, authorization, user data, secrets, payments, compliance, external integrations, permissions, destructive actions, or operational access.
   - Apply `design-ux` when the document describes UI, onboarding, workflows, user behavior, navigation, copy, accessibility, or service/API experience.
   - Apply `reader-success` to README/docs documents, runbooks, tutorials, API docs, onboarding docs, and documents intended to help someone complete a task.

7. **Review for findings**
   - Findings must be grounded in the document. Cite the nearest section heading and line number when available.
   - Report only issues with concrete user, maintainer, business, safety, or execution impact.
   - Do not report taste preferences, speculative concerns, or items that require reviewing source code.
   - Deduplicate findings by root cause. If one issue appears in multiple places, cite the strongest location and mention repeats in the body.
   - Severity definitions:
     - `Critical`: the document could drive materially wrong work, unsafe behavior, a major product misdecision, or an irreversible execution mistake.
     - `Major`: a normal reader or implementer is likely to make the wrong call, miss required work, or proceed with an untestable plan.
     - `Minor`: clarity, completeness, or sequencing issue that creates friction but is unlikely to cause the wrong work by itself.
     - `Nit`: small wording or structure issue with low risk; use sparingly.

8. **Synthesize the report**
   - Lead with findings ordered by severity, then by document order.
   - Use stable IDs: `DOC-001`, `DOC-002`, etc.
   - Each finding must use this structure:

   ```markdown
   ### DOC-001: <short finding title> [<Severity>]
   Location: `<path>` - <section heading or "front matter">, line <line-or-range>
   Lens: <lens>

   Problem: <what is wrong, stated concretely>

   Why it matters: <impact on reader, decision, implementation, safety, or outcome>

   Concrete fix: <specific edit or decision that would resolve it>
   ```

   - After findings, include:

   ```markdown
   ## Coverage

   **Document type:** <primary type; secondary: ... if applicable>
   **Lenses reviewed:** <comma-separated list>
   **Residual risk:** <unverified assumptions, source-code claims not checked, missing context, or "None identified">
   ```

   - If there are no findings, say:

   ```markdown
   No findings.

   ## Coverage

   **Document type:** <primary type>
   **Lenses reviewed:** <comma-separated list>
   **Residual risk:** <coverage caveats or "None identified">
   ```

9. **Deliver output**
   - If `OUTPUT_MODE=inline`, return the report in the final response.
   - If `OUTPUT_MODE=file`, write the report to `OUTPUT_PATH` and return a brief summary with the path and finding counts by severity.
   - Treat `DOC_REVIEW.md` as a working artifact that should not be committed and can be cleaned up by `/kramme:workflow-artifacts:cleanup`.

## Error Handling

| Condition | Response |
| --- | --- |
| Missing path | Ask for one Markdown document path. |
| Multiple paths | Ask the user to choose exactly one document. |
| Missing or unreadable file | Stop with the exact path and say what could not be read. |
| Non-Markdown input | Route to `/kramme:docs:to-markdown` first, then review the resulting Markdown. |
| Path under `siw/` | Route to the relevant SIW audit skill and do not run this generic review. |
| Output path equals input path | Reject and ask for a different output path or use inline output. |
| Source-code verification needed | Mark as residual risk or `UNVERIFIED`; do not inspect code as part of this skill. |

## Examples

```bash
/kramme:docs:review docs/proposal.md
/kramme:docs:review README.md --file
/kramme:docs:review docs/strategy.md --output STRATEGY_REVIEW.md
```
