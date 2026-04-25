---
name: kramme:docs:ubiquitous-language
description: "Extract a DDD-style ubiquitous language glossary from the current conversation, flagging ambiguities and proposing canonical terms. Saves to UBIQUITOUS_LANGUAGE.md at the project root. Use when the user wants to define domain terms, build a glossary, harden terminology, or mentions 'ubiquitous language' or 'DDD'. Not for general programming concepts (array, function, endpoint), code-level type/class glossaries, or per-feature naming inside a single module."
disable-model-invocation: false
user-invocable: true
---

# Ubiquitous Language

Extract a project's domain vocabulary into a single canonical glossary at `UBIQUITOUS_LANGUAGE.md`. Flag overloaded terms (one word, two concepts) and synonyms (two words, one concept). Pick canonicals; list rejected aliases.

## When to use

A glossary pass is warranted when **any** of these are true:

- The conversation has surfaced 5+ domain-relevant nouns or verbs that the team uses without a shared definition.
- The same word has been used for two different concepts in the conversation (e.g. "account" as a billing entity AND as a login identity).
- Two different words have been used for the same concept (e.g. "user" and "customer" referring to the same actor).
- The user explicitly asks for a glossary, domain terms, or mentions "ubiquitous language" / "DDD".

Route elsewhere if:

- **Deep adaptive requirements interview** → use `/kramme:discovery:interview`. This skill captures vocabulary; it does not interview.
- **Single-feature scope and naming** → use `/kramme:docs:feature-spec`. That skill names a feature; this one names the domain.
- **Code-level type or class glossary** → not this skill. Glossary is for domain experts, not engineers reading source.

## Pre-flight: detect existing glossary

Before drafting, check whether the project already has a glossary at the repo root.

1. Read `UBIQUITOUS_LANGUAGE.md` if it exists.
2. If it exists, treat it as the merge target — do not overwrite it. Identify:
   - Subdomain section names already in use.
   - Term entries already canonicalized (these are committed; do not rename them silently).
   - Aliases already listed as "to avoid" (preserve them).
3. If `GLOSSARY.md` exists instead, emit a `CONFUSION` marker and ask the user whether to migrate it to `UBIQUITOUS_LANGUAGE.md` or keep the existing filename.

If no glossary exists, create `UBIQUITOUS_LANGUAGE.md` at the repo root.

## Output format

The glossary file uses this template. Subdomain sections are optional — use one when terms cluster, omit when the project is small enough that one table suffices.

```markdown
# Ubiquitous Language

> Canonical domain vocabulary for this project. Use these terms in code, docs, specs, and conversation. Re-generate or extend with `/kramme:docs:ubiquitous-language`.

## <Subdomain name>

| Term | Definition | Aliases to avoid |
|---|---|---|
| **CanonicalTerm** | One sentence describing what it means in this domain. | `synonym1`, `synonym2` |

## Relationships

- **Term A** has many **Term B**.
- **Term C** is a kind of **Term D**.
- **Term E** triggers **Term F**.

## Example dialogue

> **Domain expert:** When a customer places an order, …
>
> **Engineer:** So the Order is created with a draft status until …
>
> *(3–5 exchanges using ≥3 canonical terms)*

## Flagged ambiguities

- **"account"** — used for both the billing entity and the login identity.
  - **Resolution:** canonical `BillingAccount` for the billing entity; canonical `UserIdentity` for the login. Update call sites incrementally.
- **"user" vs "customer"** — both used for the same actor.
  - **Resolution:** canonical `Customer`. Drop "user" except in the auth context where it refers to a `UserIdentity`.
```

## Rules

1. **Be opinionated.** When two words refer to one concept, pick a canonical and list the others as aliases-to-avoid. Do not list both as equal.
2. **Flag conflicts explicitly.** Every overloaded term goes into the "Flagged ambiguities" section with a proposed resolution.
3. **Domain relevance only.** A term belongs only if it carries project-specific meaning. "Order" in a commerce app belongs; "function" never does.
4. **One-sentence definitions.** If you cannot define it in one sentence, the concept is too coarse — split it.
5. **Show relationships when natural.** Cardinality (`has many`, `is a kind of`, `triggers`) is more useful than prose.
6. **Skip generic programming concepts.** No `function`, `array`, `endpoint`, `database`, `request`, `response` — unless the project gives them a domain-specific meaning.
7. **Cluster into subdomain tables when it helps.** A 30-term flat table is unreadable; 3 sections of 10 terms each is scannable. Use one table when the project is small.
8. **Always include an example dialogue.** Use ≥3 canonical terms. The dialogue is the test that the vocabulary holds together.

## Markers

Emit these markers as you draft. They are non-optional when the condition applies.

### MISSING REQUIREMENT

Gate drafting if no domain-relevant terms have surfaced in the conversation yet.

```
MISSING REQUIREMENT: no domain-relevant nouns surfaced in the conversation
Cannot draft a glossary from generic programming vocabulary alone. Ask the
user for 3–5 example domain terms or describe the project's subject area.
```

### CONFUSION

When subdomain split is unclear or two existing files conflict.

```
CONFUSION: terms cluster around both "billing" and "subscription" — these
may be one subdomain or two depending on whether subscriptions exist outside
billing. Ask the user before splitting.
```

### NOTICED BUT NOT TOUCHING

Use when domain terms appear in the codebase or docs but were not surfaced in the current conversation. Do not silently expand scope.

```
NOTICED BUT NOT TOUCHING: src/inventory/ uses "SKU", "Variant", "Bundle"
that are not in the current conversation
Why skipping: out of scope for this glossary pass; flag for a follow-up run
```

### ASK FIRST

These are Tier-2 changes — ask the user before proceeding:

- Renaming a canonical that already lives in the existing `UBIQUITOUS_LANGUAGE.md`.
- Migrating an existing `GLOSSARY.md` to the canonical filename.
- Splitting one existing subdomain section into two.

```
ASK FIRST: existing glossary canonicalizes "Account" for the billing entity.
The current conversation suggests renaming it to "BillingAccount" for clarity.
Confirm before changing committed canonicals?
```

## Re-running

When invoked again in the same conversation (or against an existing glossary):

1. **Read the existing file first.** Treat every committed canonical as load-bearing — do not rename without `ASK FIRST`.
2. **Detect the existing format.** If the project uses different table columns or section headings, match them rather than overwriting.
3. **State the merge plan before writing.** Emit a brief diff: which terms are being added, which definitions are being updated, which ambiguities are newly flagged.
4. **Update definitions only when understanding evolved.** A definition rewrite needs a one-line justification in the merge plan.
5. **Re-flag ambiguities.** New conflicts go in "Flagged ambiguities" alongside any unresolved earlier ones.
6. **Rewrite the example dialogue.** Always regenerate the dialogue so it exercises the current canonical set, including any newly added terms.

Never overwrite blindly. If the merge would drop committed terms, emit `ASK FIRST`.

## Common Rationalizations

These are the lies you will tell yourself to skip or distort the glossary. Each has a correct response:

- *"These terms are obvious — everyone knows what 'order' means."* → Then write the one-sentence definition. If it takes three sentences or contradicts how someone else used it, the term was not as obvious as you thought.
- *"We can capture this in code comments / type names."* → Code comments are read by engineers; the glossary is read by domain experts and new hires. Different audience, different artifact.
- *"There's no real conflict — 'user' and 'customer' are basically the same."* → Then pick one. If you cannot pick one, you have a conflict.
- *"I'll add every noun from the conversation to be thorough."* → Domain relevance only. Generic programming nouns rot the glossary and train readers to skim it.
- *"Let me just overwrite the existing file with my fresher version."* → Read-then-merge. Committed canonicals are decisions; treat them like ADRs.

## Red Flags

Rejection criteria. If any of these are true, revert and re-plan:

- **Silent overwrite of an existing `UBIQUITOUS_LANGUAGE.md`** without a stated merge plan.
- **Renaming a committed canonical** without `ASK FIRST`.
- **Generic programming concepts** (function, array, endpoint, request, response, database) appearing in any term table.
- **No "Flagged ambiguities" section** when the conversation clearly contained overloaded or synonymous terms.
- **Multi-sentence definitions.** If the term needs more than one sentence, split the concept.
- **Example dialogue uses fewer than 3 canonical terms** or uses aliases-to-avoid.
- **Term table with no relationships and no subdomain grouping** when 15+ terms are present — the reader has no orientation.

## Verification

Before declaring the glossary done, self-check:

- [ ] File written to `UBIQUITOUS_LANGUAGE.md` at the repo root (not a subdirectory).
- [ ] Every term has a one-sentence definition.
- [ ] Every term in "Aliases to avoid" appears nowhere else in the file as a canonical.
- [ ] Every flagged ambiguity carries a proposed resolution (not "TBD").
- [ ] Example dialogue uses ≥3 canonical terms and uses zero aliases-to-avoid.
- [ ] No generic programming concepts in any term table.
- [ ] If a previous glossary existed, its committed canonicals are preserved or changed only via `ASK FIRST`.
- [ ] Subdomain sections used when 15+ terms are present; flat table acceptable below that.
- [ ] Relationships section names cardinality (e.g. `has many`, `is a kind of`), not free-form prose.

If any box is unchecked, finish the gap or revert before declaring done.
