# Fowler Smell Baseline

Use this baseline as a shared vocabulary for maintainability findings in `code`, `refactor`, and `simplify` review dimensions. These are judgement-call heuristics, not hard violations.

## Rules

- Apply documented repo standards first. If a local standard intentionally permits a pattern, suppress the smell.
- Apply the codebase calibration rule from `SKILL.md` before reporting a smell. Nearby practice, framework guarantees, generated code, and existing conventions matter.
- Report a smell only with concrete diff evidence: name the smell, cite the changed location, and explain why it matters in this change.
- Keep tooling-enforced issues out of smell findings. If formatting, linting, type checks, or tests already own the concern, do not duplicate it.
- Prefer advisory Suggestions unless the smell creates a concrete correctness, security, error-handling, test, or contract risk.
- Do not use smell names as broad refactor mandates. Recommend the smallest change that removes the pressure in the reviewed diff.

## Baseline Smells

### Mysterious Name

A changed name hides the thing's purpose, role, or domain meaning.

Minimal fix: rename the function, variable, type, file, or property so a nearby reader can predict its job. If no accurate name is available, call out the underlying design ambiguity instead of inventing a polished label.

Watch for: generic names, misleading domain terms, abbreviations not used nearby, and names that only make sense after reading the implementation.

### Duplicated Code

The diff repeats the same logic shape in more than one place.

Minimal fix: reuse an existing helper or extract the shared behavior only when both call sites genuinely need the same rule. If the repeated lines are similar by accident but encode different concepts, keep them separate and explain why no finding is needed.

Watch for: copied conditionals, repeated mapping logic, matching validation branches, and repeated setup/teardown code introduced by the change.

### Feature Envy

A function or method spends more effort inspecting another object, module, or data structure than working with its own responsibilities.

Minimal fix: move the behavior closer to the data it depends on, or introduce a focused method on the owning abstraction. Keep the caller responsible only for orchestration.

Watch for: repeated access to another object's fields, utility functions that know too much about one model, and components reconstructing another layer's rules.

### Data Clumps

The same set of values travels together through multiple functions, props, constructors, or records.

Minimal fix: introduce or reuse a named type/value object only when the grouped values represent one concept. Avoid bundling unrelated parameters just to reduce argument count.

Watch for: recurring parameter groups, prop bundles, parallel arrays, and repeated destructuring of the same value set.

### Primitive Obsession

The change uses raw strings, numbers, booleans, or unstructured maps for a meaningful domain concept.

Minimal fix: use an existing domain type or add a small type/enum/parser at the boundary where it protects real invariants. Do not add wrappers for throwaway local values.

Watch for: stringly typed statuses, booleans that encode multi-state behavior, raw IDs mixed across domains, and numeric values without units.

### Repeated Switches

The same conditional dispatch on the same concept appears in multiple changed locations.

Minimal fix: centralize the dispatch in one map, table, strategy, or polymorphic boundary that fits the local codebase. Keep a single switch when it is the clearest local representation.

Watch for: duplicate `switch` statements, repeated `if`/`else` ladders, and matching status/type branching across sibling files.

### Shotgun Surgery

One logical change requires scattered edits across many unrelated files.

Minimal fix: move the change-prone rule, constant, mapping, or behavior into one cohesive owner. If the scatter is caused by an intentionally explicit API or generated surface, note that and skip the smell.

Watch for: the same concept edited in many files, wide fan-out from a small requirement, and repeated follow-up edits needed whenever the concept changes again.

### Divergent Change

One file or module is changed for several unrelated reasons.

Minimal fix: split responsibilities so unrelated reasons to change live in separate modules, functions, or components. Avoid splitting merely because a file is long if the responsibilities are cohesive.

Watch for: feature logic, formatting, data access, copy, and unrelated cleanup all landing in the same unit.

### Speculative Generality

The diff adds abstraction, configuration, parameters, hooks, or extension points for needs that are not present.

Minimal fix: inline the abstraction, remove unused options, or defer the extension point until a second real use exists. Keep generality only when an existing local pattern or current requirement proves it useful.

Watch for: one-use interfaces, unused parameters, future-proof branches, plugin points without callers, and generic names around a single concrete case.

### Message Chains

Changed code reaches through a long chain of calls or properties and depends on another object's internal navigation.

Minimal fix: expose a focused method or selector on the first stable owner, or reuse an existing accessor that hides the traversal.

Watch for: deep property chains, chained getters, repeated null-safe navigation, and callers assembling knowledge from several nested structures.

### Middle Man

A changed function, component, class, or module mostly forwards calls without adding meaningful policy, naming, boundary, or lifecycle value.

Minimal fix: remove the forwarding layer and call the real target directly, unless the layer preserves a stable public API, isolates a dependency, or carries important domain language.

Watch for: wrappers with no transformation, components that only pass props through, and service methods that mirror another service one-for-one.

### Refused Bequest

A subtype, subclass, or interface implementer must ignore, reject, or override much of the contract it inherits.

Minimal fix: replace inheritance with composition, split the contract, or move shared behavior into a smaller abstraction.

Watch for: no-op overrides, unsupported inherited methods, implementers that throw for contract members, and base-class assumptions that a new subtype cannot honor.
