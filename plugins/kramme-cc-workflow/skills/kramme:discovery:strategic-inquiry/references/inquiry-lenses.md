# Inquiry Lenses

Nine lenses for generating strategic questions. Each lens states what it probes, which evidence feeds it, and the question shapes it produces. Apply every lens at least briefly; expect most lenses to yield one or two candidates and some to yield none for a given project. A lens that yields nothing is fine — a forced question is worse than no question.

Question shapes below use placeholders: replace them with the project's concrete artifacts, names, and evidence. Never emit a shape verbatim.

## 1. Assumption excavation

**Probes:** the implicit bets baked into architecture and product decisions — things treated as permanently true without anyone deciding so.

**Evidence:** single-tenant data models, hardcoded locales/currencies/timezones, one-platform UI, synchronous designs that assume small data, auth models that assume trusted users, pricing that assumes a cost structure, docs that assume a user skill level.

**Question shapes:**
- "X is built as if Y will stay true. What evidence do we have that Y holds today, and what early signal would tell us it stopped holding?"
- "Who decided Z, and was it a decision or an accident of the first implementation?"

Look especially for assumptions shared by *every* component — those are invisible to reviews because no single file is wrong.

## 2. Coherence cross-examination

**Probes:** contradictions between pairs of artifacts that are each individually defensible.

**Evidence pairs worth confronting:**
- stated strategy vs. where recent commits actually land
- README/marketing claims vs. what the code can actually do
- names vs. behavior (a `cache` that is actually the source of truth; a `draft` state that users treat as final)
- pricing/packaging vs. actual cost drivers in the architecture
- test suite emphasis vs. the risks the team says it worries about
- config defaults vs. documented recommendations
- non-goals in strategy docs vs. code that quietly implements them anyway

**Question shape:** "Artifact A says P; artifact B behaves as if not-P. Which one is wrong, and what has that disagreement already cost?"

## 3. Negative-space mapping

**Probes:** what a project of this stated kind would typically have but doesn't. Absence is evidence only relative to the stated beliefs.

**Evidence:** no data-deletion or export path in a product holding user data; no migration story for a system that claims durability; no rate limiting on a public API; no instrumentation for the metric the strategy calls primary; no offboarding flow; no failure runbook for the component everything depends on; no second example of an "extensible" abstraction.

**Question shape:** "For a product that claims to be X, there is no Y. Is that a conscious bet, a gap nobody owns, or a sign the product is not actually X?"

## 4. Pre-mortem

**Probes:** failure causes the team cannot see from inside, via prospective hindsight — assume failure has already happened and explain it.

**Method:** fix a horizon (12–24 months out). Assert: the project failed / was abandoned / was quietly replaced. Independently list the 5 most plausible causes, using the reality signals — not generic startup failure modes. Convert the 2–3 most plausible causes into present-tense investigations.

**Question shape:** "If this is dead in 18 months, the most likely cause given [evidence] is X. What could we check this month that would confirm or price that risk?"

## 5. Load-bearing decisions

**Probes:** decisions with maximal blast radius if wrong — the data model, the core dependency, the distribution channel, the definition of the target user — especially ones never recorded as decisions.

**Evidence:** the schema everything joins against, the framework or vendor imported everywhere, the single integration all revenue flows through, the persona all copy addresses.

**Question shapes:**
- "Everything downstream assumes decision D. What is the cheapest experiment that would test D directly, and why haven't we run it?"
- "If dependency/vendor/channel V disappeared or repriced next quarter, what is the actual exit path — and has anyone costed it?"

## 6. History interrogation

**Probes:** fossils of unresolved questions in the project's history.

**Evidence:** churn hotspots that get rewritten every quarter (a place the team keeps disagreeing with itself), reverted or abandoned branches/directions, TODOs old enough to have birthdays, dead feature flags, half-finished migrations, a v2 directory next to a v1 that never died.

**Question shape:** "Area A has been rewritten N times / abandoned mid-migration. What question was never answered that keeps forcing rework, and what would settle it for good?"

## 7. Boundary and stress probing

**Probes:** how the current design behaves when a boundary condition moves — not whether today's code is correct, but whether today's *shape* survives.

**Scenarios to walk:** 10× the load or data; zero growth for a year (does the cost structure survive?); the largest customer leaves or demands isolation; a key dependency dies or triples its price; a regulation reaches the product's data; a competitor ships the core feature for free; the team halves.

**Question shape:** "Under scenario S, the first thing to break given [architecture evidence] is X. Do we know that, and is the current bet on S not happening deliberate?"

Pick the 2–3 scenarios the evidence makes most plausible; do not enumerate all of them in the report.

## 8. Incentive and effort audit

**Probes:** whether effort, convenience, and design serve the stated value — or serve something else that nobody has admitted.

**Evidence:** commit concentration in areas the strategy calls secondary; abstractions that optimize developer convenience at user expense (or the reverse); metrics that measure activity rather than the claimed outcome; features that exist because they were interesting to build.

**Question shapes:**
- "N% of recent effort went to X while the strategy names Y as primary. Is the strategy stale, or is the effort misallocated?"
- "Who is the current design actually optimized for, and is that on purpose?"

## 9. Outsider personas

**Probes:** blind spots in vocabulary — a project cannot ask questions in words it never uses.

**Method:** choose 2–3 personas absent from the repo's vocabulary (grep for their terms first to confirm absence): an accountant, a data-protection regulator, an acquirer's due-diligence engineer, a competitor's PM, a support agent at 2 a.m., a user leaving for a rival, an operator paged during the outage. For each, ask: what would this person demand to see first, and could the repo or team answer today?

**Question shape:** "A [persona] would first ask Q. Nothing in the repo, docs, or history addresses Q. Can we answer it, and should the answer exist somewhere?"
