---
name: kramme:code:refactor-pass
description: "Perform a refactor pass focused on simplicity after recent changes. Use when the user asks for a refactor/cleanup pass, simplification, or dead-code removal and expects build/tests to verify behavior."
disable-model-invocation: false
user-invocable: true
---

# Refactor Pass

Perform a refactor pass focused on simplicity after recent changes.

## Workflow

1. **Review the changes just made** and identify simplification opportunities.

2. **Apply refactors to:**
   - Remove dead code and dead paths.
   - Straighten logic flows.
   - Remove excessive parameters.
   - Remove premature optimization.

3. **Run build/tests to verify behavior.** Use the `kramme:verify:run` skill to run verification checks against the affected code.

4. **Identify optional abstractions or reusable patterns**; only suggest them if they clearly improve clarity and keep suggestions brief.
