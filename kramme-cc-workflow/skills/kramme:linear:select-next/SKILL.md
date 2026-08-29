---
name: kramme:linear:select-next
description: "Requires Linear MCP. Selects valuable ready-to-start issues from a Linear team using structured flags or a free-form query, including explicit states and autonomous agent-readiness. Actively finds a strong parallel set and gives every reported issue a plain-language summary. Use when deciding what to pick up next. Not for creating, editing, implementing, or closing Linear issues."
argument-hint: "[team or selection query] [--state <name>] [--agent-ready-only] [--interest <preference>] [--mine|--unassigned|--both] [--project <name>] [--label <name>] [--limit <n>]"
disable-model-invocation: true
user-invocable: true
---

# Select Next Linear Issue

Choose the most valuable ready-to-start issue from a Linear team, optionally constrained by workflow state, autonomous agent-readiness, and the type of work the user wants to do. The skill recommends one issue and actively searches for 2-4 additional good issues that can be implemented in parallel, explaining every reported issue in plain language. It is read-only: it gathers Linear context, ranks candidates, explains the recommendation, and points to `kramme:linear:issue-implement` for follow-up.

## Boundaries

- **Do:** inspect available team issues, compare assigned-to-me and unassigned work, account for blockers/readiness/value, assess autonomous agent-readiness when requested, and identify independent issues that can run in parallel.
- **Do not:** create branches, change assignees, move statuses, add comments, create issues, or start implementation.
- **Handoff:** once the user picks an issue, suggest `kramme:linear:issue-implement {ISSUE-ID}`.

## Arguments

Parse `$ARGUMENTS` before Step 1.

- Accept either structured flags, a bare team name/key/ID, a free-form selection query, or a combination of them. When unflagged input may contain both a team and a query, match the longest exact leading substring against available Linear team names, keys, and IDs. If one matches, consume it as the team and parse the remainder as the query; if none matches, apply the whole-input rules below. Do not invent quoting or delimiter syntax.
- Parse flags and their values first. Explicit flags override constraints inferred from free-form text.
- `--state <name>`: include only a named workflow state. The flag is repeatable; repeated values are alternatives, so `--state Backlog --state "To Do"` includes either state. Match state names case-insensitively after normalizing spaces and hyphens.
- `--agent-ready-only`: return only issues that pass the autonomous agent-readiness checklist in `references/scoring-rubric.md`.
- `--mine`: include only issues assigned to the logged-in user.
- `--unassigned`: include only unassigned issues.
- `--both`: include assigned-to-me and unassigned issues. This is the default.
- `--project <name>`: filter to a project.
- `--label <name>`: filter to a label.
- `--limit <n>`: cap collected candidates per pool after priority-ordered pagination. Default 150, maximum 250.
- `--interest <description>`: describe the kind of work the user wants to do, such as `frontend polish`, `small bug fixes`, `backend architecture`, `high customer impact`, `low coordination`, or `docs and cleanup`. Treat this as a ranking preference, not a hard filter, unless the user explicitly says `only`.

Treat unflagged input as a free-form selection query when it begins with a selection request such as `find`, `identify`, `list`, `show`, `recommend`, or `select`, or when it contains an explicit constraint about state, assignee, readiness, project, label, or work preference. Extract only constraints stated by the user; do not invent filters from descriptive filler. In particular:

- Resolve state phrases such as `in Backlog or To-do state` to team workflow states in Step 3.
- Map `assigned to me`, `unassigned`, or an explicit request for both to the corresponding candidate pool.
- Map phrases such as `ready for autonomous agent-driven implementation`, `agent-ready`, or `can be implemented autonomously` to `--agent-ready-only` semantics.
- Preserve other work-type language as the interest preference, and preserve `only` as a hard preference filter.

For example, `Please identify Linear issues that are in Backlog or To-do state that are ready for autonomous agent-driven implementation` means: infer the team in Step 2, include only workflow states matching `Backlog` or `To-do`, enable agent-ready-only filtering, and do not interpret the sentence as a team name.

When unflagged input has no selection-query signal and no leading team match was found, first try the whole value as the team name/key/ID. If it resolves, use it as the team. If it does not resolve and the text contains additional words, treat it as a selection query only when its constraints can be parsed unambiguously; otherwise ask one short clarification question. If a team resolves and extra unflagged text remains, treat that remainder as selection-query text.

If mutually exclusive assignee flags are combined, stop and ask the user to choose one pool. Reject unknown flags, a `--limit` outside 1-250, or an empty flag value with one short message naming the offending token. Allow repeated `--state`; reject other repeated singleton flags.

## Workflow

1. **Check prerequisites.** If Linear MCP operations are unavailable, stop with `MISSING REQUIREMENT: Linear MCP is required to select the next issue`.

   Tool names vary by harness. This skill names operations by Linear MCP capability (`get_user`, `list_issues`, etc.); in Codex, use those bare capability names, and in environments that expose namespaced tool IDs, use the matching `mcp__linear__...` tool.

2. **Resolve the user and team.**
   - Call Linear MCP `get_user` with `query: "me"` and store the logged-in user's name/id.
   - If a team argument was provided, resolve it with Linear MCP `get_team`.
   - If no team was provided, call Linear MCP `list_teams`. Use the only team if exactly one is available; otherwise ask one short plain-text question for the target team.
   - If the team cannot be resolved, stop and show the team value that failed.

3. **Resolve requested and available states.**
   - Call Linear MCP `list_issue_statuses` for the selected team.
   - When the arguments requested one or more states, resolve every requested name case-insensitively after removing spaces and hyphens. Use exactly the resolved states as the candidate state set. If any requested state does not resolve, stop and show the unresolved value plus the team's available state names; never silently broaden an explicit state filter.
   - Treat issues as available when their state type or state name indicates backlog/unstarted/todo/ready work.
   - Exclude completed, canceled, duplicate, archived, and started-by-someone-else issues.
   - Include started issues only when assigned to the logged-in user and the state name does not imply blocked/waiting/review.
   - Explicit requested states still pass through the exclusions above. A request for a completed, canceled, duplicate, archived, blocked, waiting, or review state does not make those issues eligible; explain the conflict and stop rather than returning unsafe candidates.
   - If status metadata is unavailable and explicit states were requested, filter locally only when every returned issue record includes a state name and at least one record establishes each requested normalized state name. Apply the same exclusions. If the records omit state names, or the results cannot distinguish an unknown requested state from a valid state with no issues, stop with `MISSING REQUIREMENT: Linear status metadata is required to validate explicit state filters`; never guess that the requested state exists. Otherwise filter locally by available state name using the default exclusions.

4. **Fetch candidate issues.**
   - Build the requested pools:
     - `mine`: `assignee: "me"`
     - `unassigned`: `assignee: null`
   - For each pool, collect candidates in priority order before recency: Urgent (`priority: 1`), High (`2`), Medium (`3`), Low (`4`), then None (`0`).
   - For each priority bucket, call Linear MCP `list_issues` with selected `team`, pool assignee filter, available `state` filters, optional `project`, optional `label`, priority, and a page `limit` no larger than the remaining pool cap. Follow the returned cursor until that bucket is exhausted or the pool cap is reached.
   - If the Linear tool cannot filter by state in one call, run the priority-paged query once per available state and merge results.
   - If the Linear tool cannot filter by priority, page through `list_issues` until the pool cap is reached, then sort locally by Linear priority before enrichment and report the weaker confidence if the pool cap was reached.
   - Dedupe by issue identifier or UUID.
   - If any pool hits the cap before all pages are exhausted, state that ranking is based on the highest-priority collected candidates and suggest increasing `--limit` or narrowing by project/label.

5. **Enrich the shortlist.**
   - If there are no candidates, report that no available assigned/unassigned issues were found for the team and filters.
   - Enrich candidates in batches of up to 25, ordered by Linear priority, due date, project metadata, blocker/unblock hints, customer-impact hints, and match against the `--interest` terms when present. For each candidate, call Linear MCP `get_issue` with `includeRelations: true`, `includeCustomerNeeds: true`, and `includeReleases: true` when supported.
   - After each batch, apply Steps 6-8 provisionally. Continue through further batches until the best recommendation has four good parallel candidates or every candidate collected in Step 4 has been enriched and assessed. Reaching the collection cap bounds the candidate set but is not by itself a reason to stop enriching it. A good parallel candidate must pass all readiness and hard-filter requirements and be independent of both the recommendation and every other issue in the proposed parallel set.
   - With `--agent-ready-only`, every issue in the recommendation and parallel set must also be `agent-ready`. Never classify an issue as agent-ready from title keywords alone. A candidate may pass provisionally only when every applicable checklist item has concrete evidence from its description, fetched relations and metadata, reachable linked inputs, or relevant comments.
   - Call Linear MCP `list_comments` only when a high-value candidate's description and fetched relations do not establish a required decision or dependency, or when recent comments may have superseded that evidence. If required evidence is still unavailable, classify the issue as `needs-refinement` under `--agent-ready-only`; without that hard filter, disclose the evidence gap and lower confidence rather than claiming it is `agent-ready`.
   - Do not stop after the first batch merely because it contains one strong recommendation. Finding a defensible parallel set is part of the required result.
   - Keep the analysis read-only even if the best next action appears to be "assign this to me" or "ask for clarification".

6. **Score value and readiness.** Read `references/scoring-rubric.md` and apply it. Use the rubric to classify each issue as:
   - `ready`: clear enough and unblocked enough to begin.
   - `clarify-first`: valuable, but missing acceptance criteria, owner decision, design detail, or technical boundary.
   - `blocked`: blocked by another issue, external dependency, approval, or explicit blocked/waiting state/label.
   - `not-now`: low value, stale without evidence, duplicate-looking, or outside the current team/project focus.
   - When `--agent-ready-only` or equivalent autonomous-implementation intent was requested, separately classify `agent-readiness` as `agent-ready`, `needs-refinement`, or `human-only`. Ordinary `ready` means work can begin; `agent-ready` is stricter and means an implementation agent can complete and verify the issue without obtaining a human decision, unavailable design, privileged access, or subjective sign-off. Otherwise do not perform or report the stricter autonomous classification.
   - With `--agent-ready-only`, exclude `needs-refinement` and `human-only` issues from the recommendation, parallel candidates, and ranked shortlist. Retain valuable excluded issues in `High-value but not agent-ready` with their specific gaps. If no issue passes, say so; do not weaken the filter.
   - If `--interest` was provided, add a `preference fit` assessment based on title, description, labels, project, customer needs, comments, and likely implementation area. Preference fit can break ties or surface a close alternative, but it must not outrank a materially higher-value ready issue unless the user explicitly asked for `only` that work type.
   - Write a `plain-language summary` for every issue that will appear in the report. Use one or two concise sentences that explain the problem to solve or the outcome that will change and why it matters. Prefer familiar words and direct phrasing. Avoid unnecessary internal code names, unexplained acronyms, implementation details, and simply repeating the title.

7. **Select the next issue.**
   - Prefer the highest-value `ready` issue that passes every hard argument constraint, including `agent-ready` when requested.
   - If a `clarify-first` or `blocked` issue has materially higher value than all ready issues, mention it as the highest-value non-ready issue, but do not present it as the next issue to start.
   - Break close ties using: strong preference fit, assigned-to-me ownership, urgent/high priority, unblocks more work, clearer acceptance criteria, smaller coordination cost, older age only when otherwise ready.
   - If the selected issue does not match the user's stated interest well, explain why value/readiness outweighed preference and name the best matching ready alternative.

8. **Detect parallel candidates.**
   - Always make a deliberate attempt to return 2-4 good parallel candidates among ready issues that pass every hard argument constraint. They must be independent of the recommended issue and of one another.
   - Treat issues as parallel-friendly when they have no blocker/blocked-by relationship, touch different product areas or likely code areas, have independent acceptance criteria, and do not require the same migration, schema change, feature flag, or release gate.
   - Treat issues as sequential/coordinate when they share dependencies, project phase, owner decision, data model, API contract, broad refactor, or likely files.
   - If independence is inferred rather than explicit, label it as an inference and name the evidence.
   - Rank qualifying parallel candidates by value and readiness after independence is established; do not use low-value filler merely to reach four.
   - If exhaustive assessment up to the candidate cap yields fewer than two good parallel candidates, return every good candidate found and state why the remaining pool failed the parallelism bar. Never present uncertain or dependent issues as good parallel candidates.

9. **Report the recommendation.** Use this structure:

   ```text
   Applied criteria: {team, states, assignee pool, project/label, agent-ready-only, interest}
   Recommended next issue: {IDENTIFIER} - {title}
   Plain-language summary: {one or two concise sentences explaining the problem or outcome and why it matters}
   Why this one: {3-5 bullets on value, readiness, urgency, unblock impact}
   Preference fit: {strong|partial|weak|not provided} - {one-line evidence}
   Readiness: {ready|clarify-first|blocked} - {one-line reason}
   Agent-readiness: {agent-ready|needs-refinement|human-only} - {one-line evidence; include only when autonomous readiness was requested}
   Handoff: /kramme:linear:issue-implement {IDENTIFIER}

   Parallel candidates:
   | Issue | Plain-language summary | Why independent | Caveat |
   | --- | --- | --- | --- |
   | ... | ... | ... | ... |

   Ranked shortlist:
   | Rank | Issue | Plain-language summary | State | Pool | Readiness | Agent-readiness (when requested) | Preference fit | Why |
   | --- | --- | --- | --- | --- | --- | --- | --- | --- |
   | ... | ... | ... | ... | ... | ... | ... | ... | ... |

   High-value but not ready or not agent-ready (include agent-readiness only when requested):
   | Issue | Plain-language summary | Readiness | Agent-readiness | What is needed |
   | --- | --- | --- | --- | --- |
   | ... | ... | ... | ... | ... |
   ```

   Every issue shown anywhere in the report must include its plain-language summary. Omit the Agent-readiness field and columns when autonomous readiness was not requested. Omit empty sections except `Parallel candidates`; when fewer than two good parallel candidates exist, preserve that section and explain the exhausted search rather than silently omitting it.

## Red Flags

- Recommending an issue only because it has the highest Linear priority while it is blocked or underspecified.
- Treating all unassigned issues as available without filtering out completed/canceled/started work.
- Presenting inferred parallelism as certain when issue descriptions do not reveal implementation overlap.
- Stopping after the first 25 candidates without finding four good parallel candidates or enriching and assessing the entire collected candidate set.
- Filling the parallel section with dependent, unclear, or low-value issues just to reach a target count.
- Summarizing an issue with internal jargon, unexplained acronyms, implementation details, or a restatement of its title.
- Treating `ready` and `agent-ready` as synonyms, or weakening `--agent-ready-only` because no candidate passes.
- Silently broadening an explicit state request when a named workflow state cannot be resolved.
- Starting branch setup or implementation instead of handing off to `kramme:linear:issue-implement`.
