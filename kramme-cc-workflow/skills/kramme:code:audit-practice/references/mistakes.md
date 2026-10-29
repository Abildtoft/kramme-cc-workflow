# Agentic Practice Mistakes

Use this rubric in Step 3 of `SKILL.md`. Each entry names the evidence to read, the default LIKELY and CLEAR signals, a self-check question for when no evidence exists, the smallest useful change, and where to go next. Anything between LIKELY and CLEAR is POSSIBLE.

Dotted names such as `effort.requests_by_level` are fields of the session-signals JSON. Thresholds are defaults; depart from one only with a stated reason. With fewer than five analyzed sessions, session-only evidence supports POSSIBLE at most.

## Context Budget

These costs land on every session before it does any work.

### 1. Effort set too high

Higher effort buys longer reasoning on every request, spending output tokens and time without improving routine work.

- **Evidence:** `effort.requests_by_level` and `effort.median_thinking_seconds`; Claude Code `effortLevel`; Codex `model_reasoning_effort` and `plan_mode_reasoning_effort`.
- **LIKELY:** the top of the host's scale (`max` in Claude Code, `xhigh` in Codex) is the configured default or serves more than half of recorded requests.
- **CLEAR:** the default sits below the top, and fewer than a fifth of requests use the top level.
- **Self-check:** Do you raise effort for a hard problem and lower it afterwards, or leave it at the top?
- **Change:** set the default to the lowest level that handles routine work, and raise it per task for hard debugging or design.
- **Then:** the host's effort setting.

### 2. Overlong skills

A triggered skill loads whole, so every line the run does not act on displaces the task.

- **Evidence:** line counts and description lengths of repository and user-level `SKILL.md` files; how many skills are model-invocable, since their descriptions load into every session; whether long bodies move detail into files read on demand.
- **LIKELY:** several skills exceed 300 lines, any exceeds 500, or bodies inline reference tables, long examples, or rationale that the run never acts on.
- **CLEAR:** bodies stay short and route detail to files read on demand.
- **Self-check:** When a skill runs, does the agent need most of what it loads?
- **Change:** move reference material and examples into files read only at the step that needs them, and delete instructions the agent follows anyway.
- **Then:** `/kramme:skill:review`.

### 6. Token-heavy tooling

Tools added for the agent, such as MCP servers, hooks, scripts, and CLIs, can spend context on output the agent only skims.

- **Evidence:** `tool_output.by_tool` and `tool_output.by_shell_program` (calls, characters, largest result); MCP servers configured versus those that appear in the sample; hooks or scripts that print whole logs or JSON documents.
- **LIKELY:** an MCP server or project script averages more than about 5,000 characters per call, or returns single results above about 40,000 characters.
- **CLEAR:** added tools average under about 2,000 characters per call.
- **POSSIBLE:** configured MCP servers never appear in the sample.
- **Self-check:** Do your custom tools return summaries by default, with detail only on request?
- **Change:** give each heavy tool a compact default, such as selected fields, limits, summaries, or quiet flags, and remove MCP servers the sample never uses.
- **Then:** `/kramme:code:audit-agent-config` for repository MCP and hook entries.

### 13. Overloaded global steering

User-level instruction files load into every session in every repository, so each rule there taxes all work.

- **Evidence:** the user-level `CLAUDE.md` with its imports and the Codex `AGENTS.md`: total lines and words, and what the rules cover.
- **LIKELY:** the global files together exceed about 150 lines, or hold project-, stack-, or tool-specific rules, multi-step procedures, or rules that a project's own steering contradicts.
- **CLEAR:** a short list of preferences that hold in every repository.
- **Self-check:** Would every rule in your global file apply in any repository you open?
- **Change:** keep global steering to universal preferences; move project rules into that project's `AGENTS.md`, procedures into skills, and long references behind pointers.
- **Then:** `/kramme:docs:update-agents-md` for rules that belong to one project.

## Alignment

### 3. No alignment before work

Work that starts before the goal is shared gets redone when the result misses.

- **Evidence:** `alignment.sessions_corrected_without_alignment`, `prompts.sessions_with_corrections`, and `changes.sessions_with_edits`; specs, issues, or plans that precede implementation.
- **LIKELY:** corrections appear in at least a quarter of sessions with edits, and most of those sessions had no alignment step (questions, plan approval, or a spec, issue, or interview skill).
- **CLEAR:** corrections are rare, or follow an alignment step that changed course for a stated reason.
- **Self-check:** Before non-trivial work, do you and the agent agree on the goal, the constraints, and what done looks like?
- **Change:** before non-trivial work, have the agent restate the goal and plan or interview you on open decisions, and capture the result in a short spec or issue.
- **Then:** `/kramme:discovery:interview`, `/kramme:docs:feature-spec`, or `/kramme:linear:issue-define`.

### 4. Over-alignment

Alignment spends your attention; spending it on small, reversible changes is waste.

- **Evidence:** `alignment.median_questions_when_asked`, `alignment.max_questions_in_a_session`, and `alignment.sessions_with_questions` against `sessions.analyzed`; `alignment.plan_approvals`; steering rules that demand confirmation before routine actions.
- **LIKELY:** sessions that ask questions ask a median of more than five, most sessions open with an interview or plan round whatever their size, or steering requires approval for routine, reversible actions.
- **CLEAR:** questions cluster in a minority of sessions on large or ambiguous work.
- **Self-check:** Do you get asked about details you would accept either way?
- **Change:** align in proportion to ambiguity and blast radius: let the agent decide reversible details and report them, and remove blanket rules to always ask first.
- **Then:** adjust steering files, and prefer the non-interactive modes of skills, such as `--auto`, for routine work.

### 10. Too few prototypes

A throwaway build answers a design question faster than a discussion, and nobody needs to review its code.

- **Evidence:** branch names and commit subjects that mention a prototype, spike, or proof of concept; prototype directories; long alignment rounds in design-heavy sessions.
- **LIKELY:** design-heavy sessions show long alignment rounds, and the history shows no prototypes or spikes.
- **CLEAR:** prototypes or spikes precede larger design decisions.
- **Self-check:** When a design question stalls, do you ask the agent for a throwaway version to react to?
- **Change:** answer open design questions with a time-boxed prototype on a scratch branch, accepted without code review and deleted after the decision.
- **Then:** `/kramme:discovery:wayfinder` for initiatives too large to prototype in one go.

## Feedback Loops

### 5. Lax automated checks

Deterministic checks are the cheapest reviewer; whatever they let through, a person catches later and more slowly.

- **Evidence:** CI and hook configuration; type-checker and linter strictness.
- **LIKELY:** changes can merge without a blocking test run; a check cannot fail (`continue-on-error`, `|| true`, or warnings-only lint); or type checking is absent or non-strict where the stack supports strictness.
- **CLEAR:** CI blocks merges on tests, lint, and type checks with strict settings, and a fast local tier exists.
- **Self-check:** Could a change that breaks tests or types reach your main branch?
- **Change:** make every existing check blocking and strict, then add the missing check type before adding new rules.
- **Then:** `/kramme:code:agent-readiness` for its feedback-loop dimension.

### 11. Unverifiable agent work

An agent that cannot run checks or see its own output hands verification back to you.

- **Evidence:** documented test, lint, type-check, and build commands; browser automation for UI code; `verification.sessions_ending_after_unchecked_edits` against `changes.sessions_with_edits`.
- **LIKELY:** no documented one-command check exists, more than a third of sessions with edits end after unchecked edits, or UI code gives the agent no way to see the UI.
- **CLEAR:** checks are documented, and most sessions with edits run them after the last edit.
- **Self-check:** After the agent says it is done, how often do you find the result broken?
- **Change:** give the agent one documented command per check tier, name it in the steering file, and add browser automation for UI work.
- **Then:** `/kramme:verify:run`, and `/kramme:qa` for UI.

### 7. Too little automated review

A second agent, ideally on another model or prompt, catches what the authoring agent talked itself into before a person spends time on it.

- **Evidence:** `review.sessions_with_edits_and_automated_review` against `changes.sessions_with_edits`; AI review jobs or bots in CI.
- **LIKELY:** fewer than a quarter of sessions with edits ran a review skill or reviewer subagent, and CI has no automated reviewer.
- **CLEAR:** most sessions with edits, or CI, run an automated review.
- **Self-check:** Does every change get an automated review before you read it?
- **Change:** run an automated review on every change before human review, using a different model or prompt from the authoring agent.
- **Then:** `/kramme:pr:code-review`, `/kramme:pr:review-convergence`, or `/kramme:pr:adversarial-review`.

## Human Attention

### 9. Too much human review

Reading every line yourself does not scale with agent output; spend reading time where judgment matters.

- **Evidence:** `permissions.decisions_by_source` entries the user answered; permission modes that require approval for each edit; steering that requires the user to read every diff.
- **LIKELY:** the user approves routine edits or commands one at a time in most sessions, or steering mandates a human read of every change regardless of risk.
- **CLEAR:** routine actions run under pre-approved permissions, and human reading is reserved for risky changes.
- **Self-check:** Do you read every diff line before merging, including low-risk changes?
- **Change:** let checks and automated review take the first pass, and triage which changes need a human read.
- **Then:** `/kramme:pr:triage-risk`.

### 12. Babysitting

Watching and nudging the agent through routine steps spends your attention and stops you running work in parallel.

- **Evidence:** `prompts.short_nudges` and `prompts.interrupts` against `prompts.total`; `prompts.median_per_session`; permission decisions the user answered; Codex approval policies.
- **LIKELY:** nudges and interrupts make up more than a fifth of prompts, or the user answers permission prompts for routine actions in most sessions.
- **CLEAR:** prompts are mostly substantive, and sessions run long stretches unattended.
- **Self-check:** Can you start a task, leave, and come back to a finished, checked result?
- **Change:** pre-approve safe commands or run in a sandboxed worktree, hand over complete tasks with done criteria, and run sessions in parallel.
- **Then:** `/kramme:linear:issue-to-pr` or `/kramme:code:plan-to-pr` for hands-off runs.

## Codebase

### 14. Hard-to-navigate codebase

An agent that cannot find the right files spends its context searching and edits the wrong place.

- **Evidence:** pointers from steering files to code maps or architecture docs; the top-level layout; the largest source files; `changes.median_exploration_calls_before_first_edit`.
- **LIKELY:** steering offers no pointers to where things live, central files exceed about 1,000 lines, or sessions take a median of more than about 25 search and read calls before the first edit.
- **CLEAR:** documented entry points lead to the right files within a few calls.
- **Self-check:** Could a newcomer find where a feature lives from the docs alone?
- **Change:** add a short code map linked from the steering file, and split or deepen the modules the agent struggles to find its way through.
- **Then:** `/kramme:code:agent-readiness` or `/kramme:code:refactor-opportunities`.

### 15. No shared language

When you, the code, and the agent use different words for one concept, every prompt needs translating and misunderstandings slip through.

- **Evidence:** a glossary or domain-language document and pointers to it; ADRs; competing names for one concept across code and docs.
- **LIKELY:** a domain-heavy codebase has no glossary, and core concepts appear under competing names.
- **CLEAR:** a maintained glossary exists, steering points to it, and the code uses its terms.
- **Self-check:** Do you and the agent use the same names for your core concepts?
- **Change:** keep a short glossary of domain terms, point the steering file at it, and rename code that drifts from it.
- **Then:** `/kramme:docs:ubiquitous-language`, and `/kramme:docs:adr` for the decisions behind the terms.

### 16. Test-hostile architecture

When behavior is reachable only through internals, the agent writes tests that mock its own code and break on every refactor.

- **Evidence:** the sampled test files: mocks of first-party modules, imports of internal paths, and assertions on call order or private state; whether module boundaries are enforced.
- **LIKELY:** most sampled tests mock first-party modules or reach into internals.
- **CLEAR:** tests exercise public interfaces with real collaborators and mock only external boundaries.
- **Self-check:** Can the agent test a behavior without mocking your own code?
- **Change:** deepen modules so behavior is testable through small public interfaces, enforce those boundaries, and move tests onto them.
- **Then:** `/kramme:test:audit`, then `/kramme:code:refactor-opportunities`.

## Learning and Thinking

### 8. No session review

Past sessions record where time went; unless an agent reads them back, the same friction repeats.

- **Evidence:** session-review skills in `skills`; learning notes, memory, or retros, and when they last changed.
- **LIKELY:** the sample shows no session-review skill, and no learning notes changed in the last 90 days.
- **CLEAR:** session reviews or learning updates recur.
- **Self-check:** When did an agent last read your past sessions looking for repeated friction?
- **Change:** schedule a recurring session review, and fold what it finds into skills and steering files.
- **Then:** `/kramme:session:automate-repeats`, and a monthly rerun of this audit.

### 17. Too little strategic thinking

Without a strategy, the agent's speed goes into whatever is loudest instead of what matters.

- **Evidence:** strategy or roadmap documents and when they last changed; recent ADRs; the mix of recent commit subjects.
- **LIKELY:** no strategy anchor exists, and recent history is mostly fixes and chores.
- **CLEAR:** a current strategy anchor exists, and recent work traces back to it.
- **Self-check:** Can you say what you are deliberately not building this quarter, and why?
- **Change:** keep a one-page strategy with goals and non-goals, and check new work against it.
- **Then:** `/kramme:product:strategy`, `/kramme:discovery:strategic-inquiry`, or `/kramme:discovery:wayfinder`.

### 18. Too little thinking

Delegating the typing is the point; delegating the design thinking leaves nobody who understands the result.

- **Evidence (weak):** `prompts.median_first_prompt_chars` read together with `prompts.corrections`.
- **LIKELY:** only when opening prompts are very short (a median under about 80 characters) and corrections are frequent.
- **CLEAR:** rarely provable from artifacts; prefer UNOBSERVABLE.
- **Self-check:** Before delegating, could you explain the design you want and why? Afterwards, could you explain what changed?
- **Change:** think through the approach before delegating, and explain the result back to yourself before accepting it.
- **Then:** `/kramme:learn:verify-understanding` or `/kramme:discovery:interview`.

## Pairing Rules

- **3 and 4** can both be LIKELY when alignment effort lands on the wrong tasks. Recommend calibrating by task size, not more or less alignment overall.
- **7 and 9** move review effort from people to automation. Recommend the change for 7 before cutting human review under 9.
- **11 and 12** share a cause. Recommend fixing verification first; babysitting usually drops once the agent can prove its own work.
