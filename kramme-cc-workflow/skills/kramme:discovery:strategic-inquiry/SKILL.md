---
name: kramme:discovery:strategic-inquiry
description: "Generate ranked strategic questions and investigation briefs that surface unknown unknowns and coherence gaps in a product or codebase — implicit assumptions, contradictions between artifacts, conspicuous absences, load-bearing decisions, and unresolved history. Each question ships with why it matters, the evidence that prompted it, a concrete investigation method, and where the answer lives (repo, production, users, or a team decision). Writes STRATEGIC_INQUIRY.md. Use when the user asks what they should be worried about, which questions to ask, where the blind spots are, or wants the coherence of what exists challenged. Not for finding defects in what is already built — use kramme:code:weakness-audit, kramme:pr:code-review, or kramme:product:review for reviews and audits."
argument-hint: "[focus, e.g. 'onboarding', src/auth, or omit for whole repo] [--max-questions N] [--output <path>] [--inline]"
disable-model-invocation: true
user-invocable: true
---

# Strategic Inquiry

Propose the strategic questions and investigations a review or audit cannot produce. Reviews and audits evaluate what exists against known criteria; this skill interrogates what the codebase and product *presuppose* — the assumptions nobody wrote down, the contradictions between artifacts, the things conspicuously not built, and the decisions everything else silently depends on.

**Arguments:** "$ARGUMENTS"

**What it touches:** writes one report file, `STRATEGIC_INQUIRY.md` by default (skipped with `--inline`). Read-only otherwise. Do not modify implementation code, and do not fix anything found along the way.

## What This Skill Is Not

This boundary is the skill's identity. Enforce it during filtering (step 5):

- A finding ("this function has a race condition") belongs to a review skill. A strategic question ("the sync engine assumes single-writer — what happens to the product if multi-device editing becomes table stakes?") belongs here.
- If a question can be fully answered by reading more of the repo, it is usually an audit item in disguise. The most valuable output points *outside* the repo: production behavior, users, the market, or a decision the team has not consciously made.
- Success is not a list of problems. Success is the user saying "we never thought to ask that" or "we assumed that was settled."

## Inputs

- **Focus** (optional): a product area (`onboarding`), a path (`src/auth`), or a theme (`pricing`). Default: the whole repository and product.
- **`--max-questions N`**: cap on ranked questions in the report. Default `10`, cap `15`. Fewer, sharper questions beat inventory.
- **`--output <path>`**: report path. Default `STRATEGIC_INQUIRY.md` at the repo root. Refuse paths outside the working tree unless the user explicitly confirms.
- **`--inline`**: reply with the report content instead of writing a file.

If a path-shaped focus does not resolve, ask whether it was meant as a theme instead of guessing.

## Workflow

### 1. Collect stated beliefs

Read what the project *claims* about itself, so later steps can test claims against reality:

1. Strategy and product anchors: `STRATEGY.md`, `README.md`, `docs/` overviews, landing/marketing copy in the repo, pricing pages if present.
2. Decision records: `docs/decisions/`, `docs/adr/`, `doc/adr/`, `architecture/decisions/`. Accepted ADRs count as *conscious* decisions — the interesting questions live where no ADR exists.
3. Project instructions and conventions: `AGENTS.md`, `CLAUDE.md`, contribution docs.
4. Issue/spec artifacts when present: `siw/`, open TODO/FIXME markers, roadmap files.

Record a short list of **stated beliefs**: target user, problem being solved, non-goals, scale expectations, quality bars, revenue/adoption model if discernible. Where a belief is nowhere stated, record that absence — an unstated target user is itself inquiry material.

### 2. Gather reality signals

Collect cheap, factual signals about what the project *actually is*:

1. Shape: directory structure, dependency manifest, service/deployment topology from configs and CI workflows.
2. History: churn hotspots (`git log --stat` aggregates), reverted or abandoned work, files untouched for a long time that everything imports, long-lived TODOs with dates.
3. Effort allocation: where recent commits concentrate versus where the stated beliefs say value lies.
4. Instrumentation: whether the metrics the strategy claims to care about are actually measured anywhere (analytics calls, logging, dashboards-as-code).
5. Edges: what happens at the boundaries — auth, data deletion, migration, export, failure paths, rate limits — noting presence/absence, not quality.

Do not evaluate quality here. You are collecting facts for the lenses to cross-examine.

### 3. Apply the inquiry lenses

Read `references/inquiry-lenses.md`. Apply each lens against the stated beliefs and reality signals, generating raw candidate questions. Each candidate must record:

- the question, stated sharply enough that it could be assigned to someone
- the lens that produced it
- the evidence trigger: the specific belief, contradiction, absence, or history that prompted it
- the uncomfortable answer: what is true if the question resolves badly
- **answer location**: `repo`, `production`, `users/market`, or `team decision`

### 4. Probe the negative space deliberately

The lenses find questions from evidence that exists. Unknown unknowns hide where no evidence exists, so run one explicit pass on absences:

1. List capabilities, artifacts, and safeguards a project *of this stated kind* would typically have, and note which are missing. Anchor each absence to the stated beliefs — an absent thing is only interesting relative to what the project claims to be.
2. For 2–3 outsider personas that never appear in the repo's vocabulary (for example: an accountant, a data-protection regulator, a competitor's PM, a support agent at 2 a.m., an acquirer's due-diligence engineer), ask what each would demand to see first, and whether the repo could answer.

Convert notable absences into candidate questions with the same fields as step 3.

### 5. Filter — the anti-audit gate

Drop candidates that fail any of these:

1. **Audit leakage**: it names a defect, vulnerability, missing test, or style issue in what exists. Redirect the user to the appropriate review skill in the final summary instead of listing it.
2. **Decision-inert**: no plausible answer would change what anyone builds, buys, prices, staffs, or stops doing.
3. **Uninvestigable**: no concrete method could move confidence within reasonable effort. Rhetorical and philosophical questions die here.
4. **Already settled**: an accepted ADR, explicit non-goal, or documented decision answers it — unless a reality signal shows the decision has silently drifted, in which case the question becomes "the recorded decision and current reality disagree; which one is wrong?"
5. **Already on the radar**: an open issue, TODO, or roadmap entry already tracks it. Surprise is part of the value.

### 6. Rank and classify

Score surviving questions 1–5 on each of:

- **Leverage**: how much of the product or architecture is rebuilt/repriced/redirected if the uncomfortable answer is true.
- **Tractability**: how cheaply a real investigation could move confidence (a one-day production query scores high; a six-month longitudinal study scores low).
- **Blindness**: how far off the team's current radar it appears to be, judged from the absence of any related issue, ADR, TODO, or doc.

Rank by the product of the three. Assign stable IDs `SQ-001`, `SQ-002`, … after sorting.

Then run the **answer-location health check**: count questions by answer location. If more than half resolve inside `repo`, the run has drifted into audit territory — return to step 5 and re-filter, or generate further candidates from the outward-facing lenses (pre-mortem, boundary stress, incentive audit, outsider personas).

### 7. Write the report

1. Read `assets/report-template.md`.
2. Write to the output path (or reply inline with `--inline`), overwriting any previous report at that path. Include focus and date in the header so an overwritten report remains understandable.
3. Each ranked question becomes an investigation brief: question, why it matters, evidence trigger, uncomfortable answer, investigation method with rough effort, what answer would settle it, and answer location.
4. End each brief with an **investigation prompt**: a self-contained, copy-pasteable prompt that runs the investigation. Write it so it works without this report in context — restate the question, the evidence with concrete file paths or references, the method, the settling condition, and the expected deliverable. Match the prompt to the answer location:
   - `repo` — a prompt for a coding agent session in this repository, naming the files and history to examine.
   - `production` — a prompt describing the queries, metrics, or logs to pull and how to interpret the result either way.
   - `users/market` — a research or interview prompt (suitable for a deep-research run or as an interview guide), including who to ask and what answers would confirm or refute.
   - `team decision` — a framing prompt for a decision discussion: the options, what each commits the team to, and the cheapest test before committing.
5. Include the assumptions registry (stated and unstated beliefs the product currently rests on) and a short list of notable dropped candidates with one-line reasons, so the filtering is inspectable.

### 8. Summarize

Reply with:

- report path (or note that output was inline)
- the top 3 questions in one line each
- the single cheapest high-leverage investigation to start with
- the answer-location mix (e.g. "2 repo, 3 production, 4 users/market, 1 team decision")
- any audit-shaped items that were set aside, with the review skill they belong to

## Artifact Lifecycle

- **Produces/updates:** `STRATEGIC_INQUIRY.md` by default, or the path passed with `--output`. Working artifact; not intended to be committed.
- **Consumed by:** the user for prioritization; `/kramme:discovery:interview` to pursue a single question in depth; `/kramme:docs:adr` to record the decision once a question is settled; `/kramme:docs:feature-spec` or `/kramme:siw:init` when an investigation turns into build work.
- **Refresh trigger:** re-run after a strategy revision, a major architectural commitment, entering a new market or user segment, or when prior questions have been answered.
- **Retired by:** `/kramme:workflow-artifacts:cleanup` or manual deletion once the questions are tracked elsewhere.

## Discipline

- Every question must trace to specific evidence in this repo or product. Generic startup wisdom ("do you have product-market fit?") is banned unless the repo gives it teeth.
- State the uncomfortable answer explicitly. A question the team can read without wincing at any possible answer is decoration.
- Prefer questions that make two existing artifacts confront each other over questions invented from nothing.
- Do not answer the questions in the report beyond the evidence trigger. Answering them is the investigation's job, and premature answers anchor the reader.
- Do not fix, file, or implement anything. This skill produces questions; follow-up work belongs to the consuming skills above.
