---
name: kramme:research
description: "Investigates a question against primary sources and saves one cited Markdown artifact. Use for reading legwork: official docs/API facts, source-code or spec checks, standards, and first-party service behavior before planning or implementation. Not for making product or architecture decisions, implementing code, broad web search, secondary blog summaries, or uncited answers."
argument-hint: "[research question or topic] [--output <path>]"
disable-model-invocation: false
user-invocable: true
---

# Research

Investigate a bounded question against primary sources and preserve the answer as a cited Markdown artifact. The skill gathers source-backed facts; it does not decide what to build.

**Arguments:** "$ARGUMENTS"

## Boundaries

- **Does:** Research a specific question using primary sources: official documentation, source code, specifications, standards, schemas, first-party APIs, release notes, or other owner-published source-of-truth artifacts.
- **Does:** Write one cited Markdown artifact whose substantive claims trace back to sources.
- **Does:** Surface conflicts, gaps, and unknowns explicitly.
- **Does not:** Implement changes, create Pull Requests, choose product or architecture direction, run broad secondary-source web searches, cite blogs or summaries as authority, or answer only in chat.

## Workflow

1. **Establish the research question**
   - Treat `$ARGUMENTS` as the research question after removing supported options.
   - Recognize `--output <path>` as an explicit artifact path.
   - If no question is provided and no clear question can be inferred from the conversation, ask for one bounded research question.
   - If the user asks for implementation too, complete the research artifact first and hand the findings back to the implementation workflow.

2. **Resolve the artifact path**
   - Derive `<slug>` from the question by lowercasing it, replacing each run of non-alphanumeric characters with one hyphen, trimming leading and trailing hyphens, and limiting it to 80 characters. If the slug is empty, use `research`.
   - If `--output <path>` is provided, store it as the candidate path. Otherwise inspect the workspace for an existing research-note convention, such as `.context/research/`, `docs/research/`, `research/`, or similarly named prior research Markdown files. Use the clearest existing convention.
   - If no convention exists, use `.context/research/<slug>.md` as the candidate path.
   - Resolve the candidate path before writing. Treat relative paths as relative to the current working tree root when available, otherwise the current working directory.
   - Refuse to write outside the current working tree unless the user explicitly confirms the exact resolved path after being warned that it is outside the workspace.
   - If the target path already exists, do not overwrite silently. Read the existing file enough to identify it, then ask whether to overwrite it, update it as a refresh, write to the next available suffixed path such as `<slug>-2.md`, or abort.
   - If a parent path exists but is not a directory, stop with the exact path and filesystem issue.
   - Create the destination directory only after the resolved path is accepted.

3. **Identify acceptable sources**
   - Prefer sources in this order:
     1. User-provided primary material, local repository source, tests, schemas, configuration, specifications, and generated API references.
     2. Official documentation, standards, RFCs, source repositories, first-party API references, changelogs, and release notes.
     3. First-party issue trackers, discussions, or support articles only when they are the closest available owner-published source for the claim.
   - Use secondary sources only as pointers to primary sources. Do not cite them as authority.
   - If a needed source cannot be accessed, record the access gap. If no primary source can be accessed at all, stop and ask the user for source material or permission to write a gap-only artifact.

4. **Investigate with claim-to-source traceability**
   - Read enough source material to answer the question; do not stop at the first plausible result.
   - Attach every substantive claim to a source URL or repository path, with line numbers or anchors when available.
   - When sources disagree, record the conflict and identify which source is more authoritative instead of silently choosing.
   - Mark unsupported claims as `UNVERIFIED` or omit them.

5. **Write the cited Markdown artifact**
   - Use this structure:

   ```markdown
   # Research: <question>

   ## Question

   <bounded question being answered>

   ## Scope

   - Included: <what was researched>
   - Excluded: <adjacent areas intentionally not researched>

   ## Sources

   - <source title or path> — <URL/path and why this is primary>

   ## Findings

   1. <source-backed finding with citation>
   2. <source-backed finding with citation>

   ## Conflicts And Gaps

   - <conflicting source, inaccessible source, or UNVERIFIED item>

   ## Non-Decisions

   - <decisions this research does not make>
   ```

   - Include the current date in the artifact only as artifact metadata, not in the skill instructions.
   - Do not include secrets, credentials, private customer data, raw production data, or sensitive logs. Summarize and redact when sensitive evidence is relevant.

6. **Report completion**
   - Return the artifact path, whether it was created, refreshed, overwritten, or written to a suffixed path, the number of primary sources used, and any conflicts or gaps that affect downstream planning.
   - If no artifact was written because source access failed, report the missing source access and the smallest source material needed to continue.

## Artifact Lifecycle

- **Produced by:** Step 5 writes exactly one Markdown research artifact.
- **Consumed by:** Planning, discovery, implementation, review, or user decision workflows that need source-backed facts.
- **Refreshed by:** Re-run this skill when the question changes, dependency versions change, source documents move, or downstream work needs current facts, then explicitly choose update/overwrite when an existing artifact is found.
- **Retired by:** Delete or archive the artifact when the related planning or implementation work is complete, or when a newer research artifact supersedes it.

## Error Handling

| Condition | Response |
| --- | --- |
| Missing question | Ask for one bounded research question. |
| Output path cannot be written | Stop with the exact path and filesystem issue. |
| Output path resolves outside the working tree | Warn with the exact resolved path and write only after explicit confirmation. |
| Output path already exists | Ask whether to overwrite, refresh, choose a suffixed path, or abort. |
| No primary source access | Ask for source material or permission to write a gap-only artifact. |
| Only secondary sources found | Use them only to locate primary sources; otherwise record the gap. |
| User asks for a decision | Provide source-backed facts and explicit non-decisions; route decision-making to the relevant planning workflow. |
