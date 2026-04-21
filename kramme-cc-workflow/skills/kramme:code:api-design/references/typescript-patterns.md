# TypeScript patterns for interface stability

Reference material for Rule 6 of `kramme:code:api-design`. Three patterns that keep TypeScript contracts stable under Hyrum's Law: discriminated unions for variants, separate Input and Output types, and branded IDs.

## Discriminated unions for variants

A value that can be one of several shapes gets a tag field whose type is a literal string union. The compiler narrows the shape based on the tag.

```ts
type TaskResult =
  | { type: "success"; task: Task }
  | { type: "error"; error: APIError };

function render(result: TaskResult) {
  if (result.type === "success") {
    return result.task.title; // result.error is not accessible here
  }
  return result.error.message; // result.task is not accessible here
}
```

Why this matters for contract stability: a union without a tag forces callers to guess the shape from which fields happen to be present, which is Hyrum's Law bait — every caller guesses slightly differently, and every guess becomes a constraint. A tag makes the variant explicit and the narrowing mechanical.

Use this shape for:
- API results (`success` | `error`).
- Webhook payloads (`event.type` determines `event.data` shape).
- State machines (`"loading"` | `"loaded"` | `"error"`).
- Any response that returns different shapes based on a request parameter.

## Input / Output type separation

Do not reuse the read type as the write payload. The read type usually contains server-generated fields (IDs, timestamps, computed fields) that must not appear in the write payload.

```ts
// Output — what clients read
type Task = {
  id: TaskId;
  title: string;
  isArchived: boolean;
  createdAt: string;
  updatedAt: string;
};

// Input — what clients send when creating
type CreateTaskInput = {
  title: string;
};

// Input — what clients send when updating (partial)
type UpdateTaskInput = {
  title?: string;
  isArchived?: boolean;
};
```

The common mistake — `function createTask(task: Task)` — accepts server-generated fields from the client, which either silently ignores them (confusing) or accidentally lets the client set them (dangerous). Splitting the types forces the decision about each field explicitly.

## Branded types for IDs

A `TaskId` and a `UserId` are both strings at runtime but must not be interchangeable at compile time. Branding attaches a unique phantom type to a primitive so the compiler tracks which kind of string it is.

```ts
type TaskId = string & { readonly __brand: "TaskId" };
type UserId = string & { readonly __brand: "UserId" };

// Factory — the one place where a raw string becomes a TaskId
function taskId(raw: string): TaskId {
  // validate shape here if the ID format is known
  return raw as TaskId;
}

function getTask(id: TaskId): Task { /* ... */ }

const rawFromRequest: string = req.params.id;
// getTask(rawFromRequest);        // compile error — string is not TaskId
getTask(taskId(rawFromRequest));   // ok
```

Why brand: without branding, `getTask(userId)` compiles and fails at runtime (or worse, returns the wrong record). With branding, the compiler catches the swap at the call site. The runtime cost is zero — brands are erased.

Factory functions are the single choke point where a raw string becomes a typed ID. Put validation there if the ID has a known format (UUID, prefixed ID like `task_abc123`, etc.). Every other call site in the codebase either receives a `TaskId` from a trusted source (a factory, a database query, a typed response) or refuses to compile.

## Closing note

These three patterns exist for one reason: under Hyrum's Law, every observable detail of a contract becomes load-bearing. Discriminated unions keep variants explicit instead of implicit-by-field-presence. Input/Output separation prevents silently-accepted server fields from becoming part of the write contract. Branded IDs prevent string-typed fields from being swapped across resource boundaries, which is the single most common "looked-like-it-worked" bug in ID-heavy domains. Every one of these patterns moves a potential runtime surprise to compile time, before a caller has started depending on the accidental behavior.
