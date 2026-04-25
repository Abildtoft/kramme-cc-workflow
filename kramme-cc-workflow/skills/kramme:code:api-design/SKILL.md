---
name: kramme:code:api-design
description: "(experimental) Design stable APIs and module boundaries. Covers contract-first approach, Hyrum's Law, validation placement (at boundaries, not between internal functions), consistent error shapes with HTTP status mapping, naming conventions, and TypeScript patterns for interface stability. Use when adding HTTP endpoints, public modules, SDK surfaces, or any interface with external or cross-team callers. Includes a Design It Twice mode (opt-in via --design-twice or the phrase 'design it twice') that spawns parallel sub-agents to explore radically different shapes before committing to one."
argument-hint: "[--design-twice]"
disable-model-invocation: false
user-invocable: true
---

# API and Interface Design

Design stable APIs and module boundaries with a contract-first workflow. This is the procedural expression of the rule "the contract is the surface area you can never take back": decide the shape, validation points, error cases, and naming *before* you write the handler, so the interface does not have to be rediscovered or reshaped once callers exist.

## When to use

- Adding an HTTP endpoint, GraphQL mutation, or RPC surface that external or cross-team callers will hit.
- Exporting a new public module, package, or SDK function from a shared library.
- Changing the shape of an existing response, error, or input payload.
- Introducing a new resource, pagination scheme, or list endpoint.
- Any time you catch yourself sketching a handler before you have sketched the contract.

## Hyrum's Law

> "With a sufficient number of users of an API, all observable behaviors of your system will be depended on by somebody, regardless of what you promise in the contract."

Implication: every observable behavior is part of the contract — including bugs, timing quirks, ordering of fields, and undocumented side effects. You cannot "fix" an observable behavior later without breaking at least one caller. Design the contract now as if every incidental detail is permanent, because it is.

## The Rules

### Rule 0 — Simplicity First

Before sketching any type or route, emit a `SIMPLICITY CHECK` marker stating the smallest coherent interface that satisfies the requirement. Only expand beyond that if a concrete requirement forces it.

```
SIMPLICITY CHECK: <the smallest interface that meets the requirement>
```

If the interface you end up designing is not the smallest version, write a second line explaining what forced the expansion. If there is no forcing requirement, ship the smaller surface.

### Rule 1 — Contract first

Design the contract before the handler. The contract is: input type, output type, error cases, HTTP status mapping, and naming. Write it down — as a TypeScript type, an OpenAPI stub, a comment block, whatever the project reads — *before* writing implementation code.

Signs the contract is not first:
- You are typing a handler body and still deciding what fields go on the response.
- You are choosing a status code after observing what the code happens to throw.
- Input validation is being sprinkled in as you hit edge cases.

If any of these are happening, stop. Write the contract, then continue.

### Rule 2 — Validate at boundaries, not between internals

Validation belongs at the points where untrusted data enters your trusted code, and nowhere else.

- **YES, validate at**: API routes, form submissions, external service responses, environment-variable loading.
- **NO, do NOT validate between**: internal functions, utility functions, data sourced from your own database. Trust inside the boundary.
- **Third-party API responses** are untrusted data — always validate them, even if the integration has been stable.

Validating between internal functions duplicates work, hides the real boundary, and gives false confidence that unvalidated paths are safe. If you feel the urge to validate inside the boundary, the boundary is probably in the wrong place.

### Rule 3 — Consistent error shape

Every error returned from the API uses the same shape:

```ts
type APIError = {
  code: string;     // stable machine-readable identifier
  message: string;  // human-readable, safe to show to end-users
  details?: unknown; // optional structured context
};
```

HTTP status mapping:

| Status | Meaning |
|---|---|
| 400 | Invalid data |
| 401 | Not authenticated |
| 403 | Not authorized |
| 404 | Not found |
| 409 | Conflict |
| 422 | Validation failed |
| 500 | Server error (never expose internals) |

Never mix error shapes across endpoints — callers build parsing logic against the first shape they see, and Hyrum's Law nails that shape in place. Worked examples and full payloads are in `references/error-shapes.md`.

### Rule 4 — Naming conventions

Quick reference for REST/JSON surfaces:

- **Endpoints** — plural nouns, no verbs (`/tasks`, not `/createTask`).
- **Query params and response fields** — `camelCase`.
- **Booleans** — prefix with `is`, `has`, or `can` (`isArchived`, `hasPermission`).
- **Enum values** — `UPPER_SNAKE` (`STATUS_ACTIVE`, not `active` or `Active`).

Full table plus worked good/bad examples and per-ecosystem deviations (Python `snake_case`, Go `PascalCase` for exported fields) live in `references/naming-conventions.md`.

### Rule 5 — Pagination shape

List endpoints paginate. Always. Even the ones that "only return a few rows today." Fixed shape:

```ts
type PaginatedResponse<T> = {
  data: T[];
  pagination: {
    page: number;
    pageSize: number;
    totalItems: number;
    totalPages: number;
  };
};
```

Callers build pagination UI and prefetching logic against this shape. Adding pagination later is a breaking change; adding it now is free.

### Rule 6 — TypeScript patterns (applicable to TS projects)

Three patterns keep TypeScript interfaces stable under Hyrum's Law:

- **Discriminated unions** for variants — `type Result = { type: "success"; value: T } | { type: "error"; error: APIError }`.
- **Input / Output type separation** — `CreateTaskInput` is not `Task`. Do not reuse the read type as the write payload.
- **Branded types for IDs** — `type TaskId = string & { readonly __brand: 'TaskId' }`.

Code examples and factory patterns live in `references/typescript-patterns.md`. Non-TS projects can skip this rule, but the underlying intent (don't conflate read and write shapes; don't let raw strings flow where a typed ID is expected) applies everywhere.

### Rule 7 — Noticed but not touching

When you notice an adjacent endpoint with an inconsistent shape, a sibling that uses a different error format, or a neighboring module that missed pagination, emit a `NOTICED BUT NOT TOUCHING` marker and move on. Do not silently reshape the adjacent surface during this design.

```
NOTICED BUT NOT TOUCHING: <what you saw>
Why skipping: <out-of-scope / unrelated / deferred>
```

The reason: reshaping adjacent contracts is itself a breaking change, and it deserves its own design pass — not a drive-by edit during work on a different surface.

## REST patterns

- **Resource design** — nouns, hierarchy via paths (`/teams/:teamId/tasks`, not `/getTasksForTeam`).
- **Filtering** — via query params (`/tasks?status=OPEN&assignee=abc`).
- **Partial update** — `PATCH` with only the changed fields.
- **Full replacement** — `PUT` with the complete resource.

## Design It Twice mode

The first interface that comes to mind is rarely the best. Design It Twice spawns parallel sub-agents to draft radically different shapes for the same problem, then compares them in the open before any single design is locked in.

**When this mode applies** — opt-in only. Trigger on `--design-twice`, on the user phrase "design it twice" or "show me alternatives". For high-leverage surfaces (SDK, cross-team contract) where the obvious shape feels suspiciously obvious, ask before entering this mode. Do not enter it by default; the cost of multiplication is wasted on low-stakes interfaces.

**How it works** — frame the problem (not the interface), spawn 3+ parallel sub-agents each pinned to a different constraint (minimize methods / maximize flexibility / optimize common case / ports & adapters), present each design in full sequentially, then compare in prose by depth, locality, and seam placement. End with a single recommendation: pick one, hybridize and explain the borrow, or redesign because the framing was wrong. See `references/design-it-twice.md` for the full process, prompt template, and comparison rubric.

**Relationship to the rules** — Design It Twice is upstream of Rule 0–7. Once a design is picked, every rule above applies to that design. The mode does not loosen any rule; it raises the chance the picked design is worth applying them to.

## Integration with other skills

- **Upstream**: `kramme:siw:generate-phases` — when a planned phase introduces a new interface, run this skill first to lock the contract before slicing begins.
- **Companion**: `kramme:code:incremental` — once the contract is locked, the implementation is sliced through the incremental loop. Each slice conforms to the contract rather than rediscovering it.
- **Downstream review**: the `kramme:injection-reviewer` and `kramme:auth-reviewer` agents verify the validation and authorization boundaries set here. A contract that declares its validation boundary makes these reviews mechanical.

---

## Common Rationalizations

These are the lies you will tell yourself to justify shipping an unstable contract:

- *"I'll validate in the service layer, it's cleaner."* → No. Validate at the boundary. The service layer is internal; pushing validation there hides the real edge of trust.
- *"This endpoint is internal, no pagination needed."* → Internal today, public tomorrow. Add pagination now; adding it later is a breaking change.
- *"The client doesn't care about the error shape, they just check the status code."* → Until one of them doesn't. Then the inconsistent shape becomes load-bearing for exactly one caller, and you cannot fix it.
- *"I'll rename this field before anyone uses it."* → There is no "before anyone uses it." The first caller is faster than you think.
- *"These two endpoints are similar enough to share the same response type."* → Reusing a read type as a write payload is the most common source of accidentally public fields. Split them.
- *"We can tighten the validation later."* → Loosening is cheap; tightening is a breaking change. Start strict.
- *"I'll add the status code to the error body so clients can read it there."* → Redundant state. The status code is on the response already. Two sources of truth drift.

## Red Flags

If you notice any of these in your own design, stop and redesign:

- Verbs in REST URLs (`/api/createTask`, `/deleteUser`).
- Mixed error formats across endpoints in the same service.
- List endpoints without pagination.
- Third-party API responses flowing into business logic without validation.
- The response type is the exact same type used as the input — no Input/Output separation.
- Internal field names leaking into the response (`user_internal_id`, `debug_payload`).
- Status code and response shape inconsistent — 200 with an `error` field, 400 with no error at all.
- A field whose meaning depends on another field's value, without a discriminated-union tag to make it safe.
- Adjacent endpoints in the same module use different shape conventions, and this design adds a third.

## Verification

Before declaring the contract done, self-check every item:

- Does the endpoint follow the resource-noun naming rule (plural, no verbs)?
- Do all error responses use the `APIError` shape with a correct HTTP status from the table?
- Do list endpoints return the pagination envelope?
- Are all untrusted inputs validated exactly at the boundary — and no inputs validated redundantly between internals?
- Do public types have separate Input and Output variants where the read shape differs from the write shape?
- For any ID type used in multiple modules, is it branded (TS) or otherwise distinct from a raw string?
- Is there a `NOTICED BUT NOT TOUCHING` entry for every inconsistency in adjacent code that this design did not fix?

If any answer is no, close the gap before handing off to implementation.
