# Architectural Language

A controlled vocabulary for talking about depth, seams, and indirection. Use these terms — exactly these — when a finding is about structure or coupling. Symptomatic categories (naming, duplication, dead code) keep their existing language; the glossary is mandatory only for findings tagged depth/seam.

## Glossary

| Term | Definition | Avoid |
|---|---|---|
| **Module** | A unit that hides a chunk of complexity behind a smaller interface than the complexity it contains. The unit-of-encapsulation. | "Component", "service" — both overloaded with framework-specific meanings. |
| **Interface** | The public surface of a module: types, methods, invariants, error modes. What callers depend on. | "API" — too general, also implies HTTP. |
| **Implementation** | Everything the interface hides. Internal data structures, helper functions, and any complexity that doesn't escape. | "Internals" is fine; "private code" is fine. |
| **Depth** | The ratio of implementation complexity to interface surface. Deep modules hide a lot behind a small surface; shallow modules hide little, often less than the interface itself adds. | "Abstraction level" — implies a hierarchy of layers, which depth does not. |
| **Seam** | A place in the code where behavior intentionally varies — different implementations plug into the same interface. A real seam has 2+ implementations in active use. | "Boundary" — overloaded with DDD bounded context; "layer" — implies vertical hierarchy. |
| **Adapter** | A specific implementation that satisfies an interface in order to plug into a seam. | "Driver", "plugin" — used inconsistently in different ecosystems. |
| **Leverage** | The amount of caller code or behavior that benefits from a module's existence. High leverage: many callers, or one caller with high complexity behind the interface. Low leverage: a wrapper used by one caller that adds no hiding. | "Reuse" — implies copy-paste avoidance, which is a weaker test than leverage. |
| **Locality** | Whether the code that changes together lives together. High-locality designs let one feature change live in one place; low-locality designs force ripple edits across many files for one change. | "Cohesion" is fine but vaguer; "encapsulation" describes the hiding, not the geographic property. |

## Principles

1. **Depth is a property of the interface, not of the implementation.** A 200-line module behind a 1-method interface is deep. A 20-line module behind a 6-method interface is shallow even if the implementation is small.
2. **The deletion test.** Mentally delete the module and inline its body at every call site. If the resulting code is roughly the same total complexity (or simpler), the module was a pass-through and adding it was negative leverage. If the resulting code blows up — multiple call sites each carrying the now-duplicated complexity — the module was hiding real depth.
3. **The interface is the test surface.** The interface defines what's verifiable from the outside. If the test for the module looks like the implementation written twice, the interface is too thin; the module is shallow.
4. **One adapter = hypothetical seam, two adapters = real seam.** A seam with one implementation is just indirection awaiting a fictional second use case. Do not introduce an interface for "testability" or "future flexibility" alone — wait for the second adapter to exist before paying the indirection cost.
5. **Locality beats reuse.** When in doubt, keep the change-together code together. Premature extraction harms locality and rarely earns its leverage back.

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

**Finding text** (the format Phase 4 emits):

> `src/orders/save.ts:1-10` — **shallow wrapper** (depth/seam category, severity: low). `saveOrder` adds a layer over `db.orders.insert` without hiding meaningful complexity.
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

A finding tagged Structural or Coupling must include:
- The relevant glossary term (e.g., "shallow wrapper", "speculative seam", "low-leverage adapter").
- A one-line **deletion test** result.
- An **adapter count** when claiming a seam is speculative.

A finding that does not satisfy the deletion test or adapter-count rule is not yet a finding — read more, or drop it.
