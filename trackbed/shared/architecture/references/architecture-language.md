# Architectural Language

A controlled vocabulary for module depth, interfaces, seams, and locality. Use these terms — exactly these — whenever a finding, score, review, or design comparison is about structure or coupling. Symptomatic categories (naming, duplication, dead code) keep their existing language; the glossary is mandatory only for depth, seam, and locality claims.

## Glossary

| Term | Definition | Avoid |
| --- | --- | --- |
| **Module** | Any unit with an interface and an implementation, at any scale: a function, a class, a package, or a slice that spans several layers. | "Component", "service" — both overloaded with framework-specific meanings. |
| **Interface** | Everything a caller must know to use the module correctly: types and signatures, plus invariants, call-order constraints, error modes, required configuration, and performance expectations. | "API" — too general, also implies HTTP; "signature" — covers only the type-level part. |
| **Implementation** | Everything the interface hides. Internal data structures, helper functions, and any complexity that doesn't escape. | "Internals" is fine; "private code" is fine. |
| **Depth** | How much behavior a caller can use per unit of interface it has to learn. A deep module offers a lot behind a small interface; a shallow module's interface is nearly as complicated as what it hides. | Ranking depth by implementation size — a longer implementation is not deeper if callers still need to know its details. "Abstraction level" implies a hierarchy of layers, which depth does not. |
| **Seam** | The place where a module's interface sits: where behavior can change without editing the callers. Whether anything actually varies there is a separate question, answered by the adapter-count rule. | "Boundary" — overloaded with DDD bounded context; "layer" — implies vertical hierarchy. |
| **Adapter** | A specific implementation that satisfies an interface in order to plug into a seam. | "Driver", "plugin" — used inconsistently in different ecosystems. |
| **Leverage** | What callers gain from a module: the amount of caller code or behavior that benefits from it. High leverage: many callers, or one caller with high complexity behind the interface. Low leverage: a wrapper used by one caller that adds no hiding. | "Reuse" — implies copy-paste avoidance, which is a weaker test than leverage. |
| **Locality** | What maintainers gain from a module: whether the code that changes together lives together. High-locality designs let one change, fix, or test land in one place; low-locality designs force ripple edits across many files. | "Cohesion" is fine but vaguer; "encapsulation" describes the hiding, not the geographic property. |
| **Deepening** | A refactor that gathers behavior scattered across shallow modules or their callers behind one smaller interface. | "Consolidation" alone — merging files does not deepen anything unless the interface callers learn gets smaller. |
| **Internal import** | A caller that imports another module's implementation files instead of going through its public entry point. | "Deep import" — collides with "deep module", where "deep" is praise. |
| **Interface impact** | Whether a change adds a module's interface (`new`), alters an existing one (`changed`), or touches only code behind an unchanged interface (`implementation-only`). Interface changes need a person's judgment; implementation-only changes can rest on tests at the interface. | — |

## Principles

1. **Depth is a property of the interface, not of the implementation.** A module whose one call does substantial work for every caller is deep. A module whose six methods each forward to a single call is shallow, however long its files are.
2. **The deletion test.** Mentally delete the module and inline its body at every call site. If the resulting code is roughly the same total complexity (or simpler), the module was a pass-through and adding it was negative leverage. If the resulting code blows up — multiple call sites each carrying the now-duplicated complexity — the module was hiding real depth.
3. **The interface is the test surface.** Callers and tests should cross the same seam. If a module's tests have to reach past its interface, or read like the implementation written twice, the module has the wrong shape.
4. **One adapter = hypothetical seam, two adapters = real seam.** A seam with one implementation is just indirection awaiting a fictional second use case. Do not introduce an interface for "testability" or "future flexibility" alone — wait for the second adapter to exist before paying the indirection cost.
5. **Internal seams stay internal.** A deep module may split its implementation into small parts, with internal seams its own tests use. Those parts are implementation, not interface; do not export them just because a test wants to reach them.
6. **Locality beats reuse.** When in doubt, keep the change-together code together. Premature extraction harms locality and rarely earns its leverage back.
7. **Replace, don't layer, when migrating tests.** When a refactor moves logic to a new interface, delete the old shallow-module unit tests once interface-level tests cover the same behavior. Running both is duplication; if the old test has to change when the implementation changes, it was testing past the interface.

## Patterns

### Shallow modules — inline or remove

- A wrapper that forwards to one call and fails the deletion test.
- A seam with one adapter, introduced for "testability" or "future flexibility".

### Deepening candidates — gather behind one interface

- **One concept, many files.** Understanding or changing a single concept means visiting many small modules, and the same files keep changing together across commits.
- **Leaks across a seam.** Callers use internal imports, or must know a module's implementation details, call-order rules, or intermediate data to use it correctly.
- **Helpers extracted only for testability.** Pure functions were split out so they could be unit-tested, while the bugs live in how callers combine them and nothing tests the behavior at the module's interface.

## Worked example: shallow wrapper

**Before** (`src/orders/save.ts`):

```ts
// Calls db.orders.insert and translates a DB error into an OrderSaveError.
export async function saveOrder(o: Order) {
  try {
    return await db.orders.insert(o);
  } catch (e) {
    throw new OrderSaveError("save failed", { cause: e });
  }
}
```

Used by one caller (`src/orders/checkout.ts`).

**Deletion test:** inline `saveOrder` at the single call site. Result: 4 lines instead of a function call. Same complexity. The module hid nothing the caller couldn't carry directly.

**Adapter count:** zero alternative DB backends; the interface has one adapter. By the adapter-count rule, this is a hypothetical seam, not a real one.

**Finding text:**

> `src/orders/save.ts:1-10` — **shallow wrapper** (depth/seam category, severity: low). `saveOrder` adds a layer over `db.orders.insert` without hiding meaningful complexity.
>
> - Deletion test: inlining at the 1 call site removes 4 lines and increases nothing.
> - Adapter count: 1 (no alternate DB path exists).
> - Suggested fix: inline at the call site; let the caller catch and translate the error directly.

**After** (inlined):

```ts
// in checkout.ts
try {
  await db.orders.insert(o);
} catch (e) {
  throw new OrderSaveError("save failed", { cause: e });
}
```

Net: −1 export, −1 file in the import graph, same caller complexity. Depth restored to where it belongs (zero, because there was none).

## How to apply in findings

A finding about depth, seams, or locality must include:

- The relevant glossary term (e.g., "shallow wrapper", "speculative seam", "internal import", "deepening candidate").
- A one-line **deletion test** result for a module that exists.
- An **adapter count** when claiming a seam is speculative.

A **deepening candidate** proposes a module that does not exist yet, so it carries these fields instead of a deletion test:

- **Evidence** of scattering: how often the files changed together, or the files one ordinary change has to touch.
- **Proposed interface**: a short sketch of what callers would call, named in the project's domain terms.
- **What moves behind it**: the files, helpers, or caller logic that become implementation.
- **Tests**: which tests move to the new interface, and which old tests on the shallow pieces get deleted under principle 7.
- **Benefit**: the locality or leverage gained, stated concretely.

A finding that does not satisfy these tests is not yet a finding — read more, or drop it.
