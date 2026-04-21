# Naming conventions

Reference material for Rule 4 of `kramme:code:api-design`. The default conventions assume a JSON-over-HTTP surface with JavaScript or TypeScript callers. Per-ecosystem deviations are noted at the end.

## Default table

| Element | Convention | Good | Bad |
|---|---|---|---|
| REST endpoints | Plural nouns, no verbs | `/tasks`, `/tasks/:id`, `/teams/:teamId/tasks` | `/createTask`, `/getTaskById`, `/task`, `/deleteAllTasks` |
| Query params | `camelCase` | `?assigneeId=abc&dueBefore=...` | `?assignee_id=abc`, `?DueBefore=...`, `?due-before=...` |
| Response fields | `camelCase` | `{ "createdAt": "...", "assigneeId": "..." }` | `{ "created_at": "...", "AssigneeId": "..." }` |
| Boolean prefixes | `is` / `has` / `can` | `isArchived`, `hasPermission`, `canEdit` | `archived`, `permission`, `editable`, `edit` |
| Enum values | `UPPER_SNAKE` | `"STATUS_ACTIVE"`, `"PRIORITY_HIGH"` | `"active"`, `"Active"`, `"statusActive"`, `"status-active"` |

## Why these specifically

- **Plural nouns in URLs**: the URL names a collection; the HTTP method names the action. Putting verbs in the URL duplicates the method and forces hyphenation or casing decisions that never agree. `POST /tasks` creates; `GET /tasks` lists; `DELETE /tasks/:id` deletes. The path stays stable as methods evolve.
- **camelCase for params and fields**: matches idiomatic JavaScript/TypeScript property access without mapping layers. Consumers can `response.data.assigneeId` directly.
- **`is` / `has` / `can` on booleans**: makes the field self-describing at the call site. `if (user.archived)` reads like a noun ("the user's archived"); `if (user.isArchived)` reads like a predicate.
- **`UPPER_SNAKE` enum values**: distinguishes enum values from user-entered strings and object keys at a glance. Also resists accidental i18n — an `UPPER_SNAKE` value is obviously a code, not display copy.

## Boolean nuance

Pick the prefix that matches the semantic:

- `is` — state: `isArchived`, `isDraft`, `isCurrentUser`.
- `has` — possession: `hasUnreadMessages`, `hasBillingAccount`.
- `can` — permission or ability: `canEdit`, `canDelete`, `canInviteMembers`.

Avoid `shouldX` on response fields — "should" belongs in the UI layer's decision logic, not in the data contract. The API returns facts; the client decides what *should* happen.

## Per-ecosystem deviations

The default table assumes the dominant case: JSON over HTTP, JS/TS callers. Other ecosystems have their own idioms — when the caller language is fixed and consistent, align with the language's expectations instead.

- **Python**: `snake_case` for fields and params. If the API serves a Python client library, ship `snake_case` fields; the mapping-to-JS tax lives in the small number of JS callers, not the many Python callers.
- **Go**: exported struct fields are `PascalCase` in source, typically serialized to `camelCase` or `snake_case` via struct tags. The on-wire convention is a separate decision from the Go source convention.
- **Ruby / Rails**: `snake_case` throughout. Same principle as Python.
- **Java / Kotlin**: `camelCase` on the wire is standard; matches JSON conventions in those ecosystems.

The load-bearing rule is not "always camelCase." It is: **pick one convention per API and apply it consistently to every endpoint.** Mixing is the expensive mistake, not the specific choice.

## Edge cases

- **Acronyms in names**: treat them as words. `userId` not `userID`; `htmlContent` not `HTMLContent`; `apiKey` not `APIKey`. The consistent rule is "first letter of each word is uppercase *except* the first word" — acronyms follow the same rule, or the casing logic gets special cases.
- **Timestamps**: `createdAt` / `updatedAt` / `deletedAt`. ISO-8601 strings on the wire. Suffix `At` for instants, `On` for dates without time (`startOn` for a calendar date).
- **IDs**: `taskId` not `task_id`, `taskID`, or just `id` (when inside a nested object that already names the resource, bare `id` is fine).
- **Nullable vs omitted**: decide and stay consistent. `"archivedAt": null` vs. field absent — both are valid; mixing them breaks parsers that distinguish missing keys from null values.
