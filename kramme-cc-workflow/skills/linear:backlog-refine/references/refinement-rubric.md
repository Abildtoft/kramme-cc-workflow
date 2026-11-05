# Refinement Rubric

Grade every backlog issue on five dimensions, report startability as a separate axis, check the backlog for conflicts between issues, and then map the grades to one action. Grades are a thinking aid; the report must cite the concrete evidence, not just the label.

The target state is `agent-ready`: the specification gives an autonomous agent enough information to implement and verify the issue once its declared prerequisites are satisfied. Report whether work can start separately. Every `rewrite`, `split`, and `ask` exists to move an issue toward that state or to establish that it cannot get there.

## Clarity

| Grade | Test |
| --- | --- |
| `clear` | A reader who has never seen the issue can name the problem, who it affects, and what "done" looks like from the title and description alone. |
| `vague` | The title or description names a topic or a solution but not the problem, the affected user, or a verifiable outcome. Typical signs: one-line descriptions, "improve X", "look into Y", TODO-style notes. |
| `empty` | No description, or a description that only restates the title. |

## Scope

| Grade | Test |
| --- | --- |
| `pr-sized` | One engineer can plausibly deliver it in one Pull Request: a single problem, a single affected area, and acceptance criteria that do not branch into unrelated behaviors. |
| `oversized` | Multiple independent outcomes, several affected areas, phased language such as "first ... then ...", or a checklist of more than roughly five unrelated tasks. Issues with existing sub-issues that already cover the work are not oversized. |
| `unknown` | Clarity is `vague` or `empty`, so scope cannot be judged. Do not guess; the action is `rewrite` or `ask`, never `split`. |

## Freshness

| Grade | Test |
| --- | --- |
| `active` | Updated, commented on, or related to active work within `--stale-days`. |
| `stale` | No update within `--stale-days` and no evidence either way about relevance. |

Freshness measures recency only. It never treats delivered work as obsolete and never selects a terminal state by itself.

## Resolution Evidence

| Grade | Test |
| --- | --- |
| `delivered` | Concrete evidence shows that the requested outcome or acceptance criteria were delivered or one of the issue's explicitly permitted resolutions occurred. For a parent, its own requested outcome or acceptance criteria must be delivered and every required child must be complete. |
| `cancel-supported` | Concrete evidence shows the work was superseded, abandoned, or is no longer relevant; or a stale, empty issue has no owner or remaining value signal after relations and comments are checked. |
| `none` | No sufficient evidence supports either terminal outcome. Continue grading the issue; do not infer a terminal action. |

Use the issue's own requested outcome and acceptance criteria as the completion boundary. Supporting evidence may include linked merged Pull Requests, shipped changes, passing acceptance coverage, comments that identify the delivered resolution, and completed required children. Inspect referenced evidence rather than relying on matching terminology or the state of a related issue.

For a parent issue:

- Verify that its requested outcome or acceptance criteria are delivered; child state alone is not enough when the parent outcome remains unmet.
- Verify every required child is complete.
- Ignore an unfinished child only when the parent explicitly identifies that child as optional, a follow-up, or out of scope.
- When child requiredness or delivery evidence is ambiguous, use `none`; never assume `delivered`.

Age alone, partial progress, a closed parent, similar code, or a completed duplicate is not delivery evidence for the issue being graded. Likewise, age alone is not cancellation evidence when the issue carries priority, customer need, a due date, a milestone, a blocking relation, or a recent value signal.

## Agent-Readiness

Synced Linear agent-readiness contract (keep aligned across Linear readiness workflows): An issue is `agent-ready` only when every item passes. Record the failing items for every other issue.

| Item | Test |
| --- | --- |
| Problem is stated | The issue says what is wrong or missing and for whom, not only what to build. |
| Outcome is observable | A reader can describe the user-visible or system-visible behavior after the change. |
| Acceptance criteria are verifiable by running something | Each criterion can be checked by a test, a command, a request, or a reproducible manual step with a stated expected result; none requires taste or a stakeholder's opinion. |
| Scope is bounded | The work is Pull Request-sized, and at least one explicit non-goal or boundary prevents the agent from expanding into neighboring work. |
| Decisions are made | No open questions, "TBD", "discuss with", or competing options remain in the body or recent comments. Decisions that were made in comments are reflected in the description. |
| Inputs are reachable | Reproduction steps, sample data, links, designs, or API contracts the work depends on are either in the issue or derivable from the repository. Nothing requires credentials, unreleased assets, or a person's tacit knowledge. |
| Dependencies are clear | Blocking relations are resolved or explicitly stated as prerequisites with their identifiers. |
| Done is detectable | The issue says how to confirm completion (tests to add or pass, behavior to demonstrate), so the agent can stop at the right point. |

| Grade | Meaning |
| --- | --- |
| `agent-ready` | Every item passes with concrete evidence. The specification is complete; declared prerequisites may still prevent starting. |
| `needs-refinement` | An item fails or required evidence is unknown. A repository-grounded rewrite, an answer, or a supplied input could enable autonomous work. A missing product decision or inaccessible asset is a refinement gap when it is an input to implementation. |
| `human-only` | Human judgment, design direction, or privileged access is itself the required work and cannot be delegated to the agent. Keep such issues clear for humans; do not force them toward `agent-ready`. |

An investigation or spike can be `agent-ready` when it has a bounded question, reachable inputs, a defined evidence-based deliverable, and an observable stopping condition. For example, reproduce a regression and report the triggering conditions with a regression test. Do not classify by verbs such as "investigate" or "decide" alone; choosing a product direction that requires stakeholder judgment remains `human-only`.

For each `agent-ready` specification, assess startability separately: `ready-to-start` requires verified satisfied prerequisites and no unresolved blocker; `awaiting-prerequisite` names known unresolved dependencies by identifier; `unknown` names missing dependency or access evidence. Only `ready-to-start` issues are eligible for immediate implementation. A documented prerequisite passes the dependency clarity item but does not establish startability.

Do not infer agent-readiness from priority, an `agent-ready` label, assignment, state name, or a phrase such as "straightforward" alone. Those are supporting signals, not substitutes for the checklist. Record evidence for every passing item and gaps for failing or unknown items. Never promote an issue while required evidence is unknown.

Typical gaps and the action that closes them:

| Gap | Closing action |
| --- | --- |
| Expected behavior implied but unstated; the repository shows current behavior | `rewrite`: state current and expected behavior, derive criteria from the code |
| Criteria exist but are subjective ("looks good", "works well") | `rewrite`: replace with checkable statements; if none are possible, `ask` |
| Decision recorded in a comment but not the description | `rewrite`: fold the decision into the body |
| Open decision with no recorded answer | `ask`: one question to the owner; do not choose on their behalf |
| Several outcomes in one issue | `split`: each child to the agent-ready bar |
| Depends on a design or asset that does not exist yet | `needs-refinement` and `ask` for the missing input; `human-only` only when producing the human judgment or inaccessible work is itself the task |

## Duplicates

Treat two issues as duplicates when either holds:

- Linear records an explicit `duplicate` relation between them.
- Their problem statements describe the same user-visible defect or outcome in the same area, and neither description names a distinction from the other.

A competing approach to the same outcome is not such a distinction; see Conflicts. Shared labels, the same project, or overlapping keywords alone make issues `related`, not duplicates. Report related issues as a cluster without proposing `merge`.

## Conflicts

Open issues conflict when they cannot all be delivered as written, or when they pull the same surface or goal in different directions.

| Type | Test |
| --- | --- |
| `contradiction` | The issues cannot all be delivered as written: delivering one undoes, prevents, or invalidates another's outcome, acceptance criteria, or recorded decision. |
| `divergence` | Each issue can be delivered, but together they push the same surface, contract, or stated goal toward incompatible ends, leaving a direction choice undecided. |

Signals to check:

- Product: opposite changes to the same behavior, default, setting, or policy, such as adding versus removing, required versus optional, or shown versus hidden; different expected results for the same user action; the same surface optimized for different target users; opposing tradeoffs on the same flow, such as less friction versus more verification; a decision in one issue that rejects, rather than defers, what another requires.
- Technical: one issue removes, deprecates, or migrates away from a component, dependency, API, or pattern that another extends or newly depends on; incompatible changes to the same API, schema, event, or data contract; competing approaches to the same problem; acceptance criteria that require behavior another issue removes or changes; work that would breach a performance, size, cost, or security constraint another issue sets.

Not conflicts: issues that change the same area compatibly, which are `related`; duplicates that share an approach; follow-ups or refinements of another issue; overlaps that sequencing or a wording update reconciles without choosing between outcomes; different priorities alone; and the cost every change carries, such as more code or more options, unless an issue sets the specific budget or principle the other would breach.

Record each conflict's issues, type, perspective (`product`, `technical`, or both), and basis: `explicit` when an issue or comment already names the conflict, otherwise `inferred`. Quote or closely paraphrase the conflicting statement from each issue and name its source, such as the description, the acceptance criteria, or a comment. Shared keywords or labels alone never establish a conflict.

A conflict is resolved only when a recorded decision addresses it, such as an owner's comment choosing a direction; an earlier decision that a newer issue challenges leaves the conflict open. Apply the usual rules to a resolved conflict: a side whose description does not yet reflect the decision fails `Decisions are made`, and a `rewrite` folds the decision in; grade a side `cancel-supported` only when the record shows it was superseded. A conflict alone is never cancellation evidence.

For an unresolved conflict:

- A `contradiction` fails `Decisions are made` for every issue whose outcome it contests, because the backlog holds competing options for that outcome. A `divergence` alone fails no checklist item; report it so the owner can choose a direction.
- Never settle it on the owner's behalf: do not pick a side, cite the conflict as a reason to `cancel` either side, or write the choice into a draft. Name the decision, the option each side represents, the evidence that bears on it, such as priority, customer need, recency, or a linked decision, and who can decide, naming each side's owner when the issues record one.
- Issues that share an outcome but prescribe competing approaches are duplicates in a `contradiction`: merge them, carrying the competing approach into the canonical issue as an open decision, so the canonical issue fails `Decisions are made` until the approach is chosen.

## Action Mapping

Apply the first matching row:

| Condition | Action |
| --- | --- |
| `resolution-evidence = delivered` | `complete` |
| `resolution-evidence = cancel-supported` | `cancel` |
| Duplicate of a canonical issue | `merge` |
| Unresolved `contradiction` after terminal and duplicate checks | `ask` once for the whole conflict; do not split or rewrite a side yet |
| `clarity = clear` and `scope = oversized` | `split` |
| `clarity = clear` and `scope = pr-sized` and `agent-readiness = needs-refinement` closable from Linear and the repository | `rewrite` |
| `clarity = clear` and `scope = pr-sized` and `agent-readiness = needs-refinement` closable only by a person | `ask` |
| `clarity = vague` and enough context in Linear to draft a better description | `rewrite` |
| `clarity = vague` or `empty` and the missing information exists only with a person | `ask` |
| `clarity = clear` and `scope = pr-sized` and `freshness = stale` with no value signal | `ask` |
| `clarity = clear` and `scope = pr-sized` and `freshness = active` and `agent-readiness = agent-ready` or `human-only` | `keep` |
| `clarity = clear` and `scope = pr-sized` and `freshness = stale` with any value signal | `keep`, and note the staleness |
| `clarity = empty` and `freshness = stale` with no value signal and no owner after relations and comments are checked | `cancel` |

Value signals: Linear priority of Medium or higher, a customer need, a due date, a milestone or release, a `blocks` relation, or a comment from the last `--stale-days` asking for the work.

## Drafting Rules for `rewrite` and `split`

Draft to the agent-readiness checklist: the reader is an autonomous agent that will take the description at face value.

- Lead with the problem and the outcome; implementation direction is optional and must stay architectural.
- Name the affected user or stakeholder.
- Give acceptance criteria that are individually verifiable by running something, with the expected result stated.
- State explicit non-goals, and list decisions already made so the agent does not reopen them.
- Include how to confirm completion: which tests to add or pass and which behavior to demonstrate.
- Ground the draft in the repository where possible: confirm current behavior before describing it, and name the modules involved.
- Never invent decisions, criteria, or product intent the original issue and its comments do not support; leave the gap and route it to `ask`.
- Keep an outcome contested by an unresolved `contradiction` as an open decision that names the other issue, and never settle any conflict through a non-goal, an acceptance criterion, or a decision already made.
- Describe modules, behaviors, and contracts; do not include file paths, line numbers, or internal helper or class names, because they rot after refactors.
- Preserve every concrete fact from the original, such as reproduction steps, customer references, and links. Rewrite the framing, not the evidence.
- Split children must each be independently shippable; if a child only makes sense after another, say so in the child's description rather than folding them back together.

Each split child needs a full implementation brief, not only a title and one-line scope:

- Stable draft key and title; problem, affected user, and observable outcome.
- Explicit scope and non-goals, plus decisions already made.
- Individually checkable acceptance criteria with expected results, and a verification method the agent can use to detect completion.
- Reachable inputs and relevant module or contract context.
- Prerequisites identified by existing Linear identifier or sibling draft key; say "none" when no prerequisite exists. The apply phase translates these into `blockedBy` relations as well as description text.

Re-grade each complete child description against every checklist item. Preserve unresolved gaps and mark the child `needs-refinement` rather than padding the brief with invented requirements. Reject cyclic or unresolved draft-key references before presenting a split for approval; dependent children may be fully specified while still awaiting a prerequisite.
