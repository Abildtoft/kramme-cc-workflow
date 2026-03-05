---
name: kramme:connect:migrate-store-ngrx
description: Use this Skill when working in the Connect monorepo and needing to migrate legacy CustomStore or FeatureStore implementations to NgRx ComponentStore.
disable-model-invocation: false
user-invocable: true
---

# Connect - Migrate Legacy Store to NgRx ComponentStore

## Instructions

**When to use this skill:**
- You're working in the Connect monorepo (`Connect/ng-app-monolith/`)
- You need to migrate a legacy `CustomStore` or `FeatureStore` to modern NgRx ComponentStore
- You see patterns like `addApiAction().withReducer()` or `addSocketAction().withReducer()`
- The store uses centralized NgRx Store with feature state slices

**Context:** Connect's frontend is migrating from a custom store abstraction built on top of NgRx Store to standalone NgRx ComponentStore services. This provides better encapsulation, simpler testing, and eliminates the need for actions/reducers/selectors boilerplate.

### Guideline Keywords

-   **ALWAYS** — Mandatory requirement, exceptions are very rare and must be explicitly approved
-   **NEVER** — Strong prohibition, exceptions are very rare and must be explicitly approved
-   **PREFER** — Strong recommendation, exceptions allowed with justification
-   **CAN** — Optional, developer's discretion
-   **NOTE** — Context, rationale, or clarification
-   **EXAMPLE** — Illustrative example

Strictness hierarchy: ALWAYS/NEVER > PREFER > CAN > NOTE/EXAMPLE

---

### Migration Checklist

#### 1. Store Structure Transformation

-   **ALWAYS** convert the store to a standalone service class extending `ComponentStore<StateInterface>`
-   **ALWAYS** use `providedIn: 'root'` for stores that need application-wide singleton behavior
-   **ALWAYS** define state as interface/type with `readonly` properties
-   **ALWAYS** extract `initialState` to a constant; use eager initialization in the constructor
-   **ALWAYS** end class names with a `Store` suffix
-   **ALWAYS** have file names for Component Stores include `.store.ts`
-   **PREFER** flat state structures to avoid nested objects in state

**EXAMPLE - Before (Legacy):**
```typescript
export const eventStore = new FeatureStore('event')
  .addApiAction('loadEvents')
  .withReducer((state, events) => ({ ...state, events }));
```

**EXAMPLE - After (ComponentStore):**
```typescript
interface EventStoreState {
  readonly events: Event[];
  readonly isLoading: boolean;
}

const initialState: EventStoreState = {
  events: [],
  isLoading: false,
};

@Injectable({ providedIn: 'root' })
export class EventStore extends ComponentStore<EventStoreState> {
  constructor() {
    super(initialState);
  }
}
```

#### 2. State Management Patterns

-   **ALWAYS** replace `addApiAction().withReducer()` patterns with ComponentStore updaters and effects
-   **ALWAYS** replace `addSocketAction().withReducer()` with updaters that accept observables
-   **ALWAYS** wire websocket observables directly to updaters in the constructor (no manual subscriptions needed)
-   **ALWAYS** use `tapResponse` from `@ngrx/operators` (not `@ngrx/component-store`) for effect error handling
-   **NOTE**: ComponentStore handles subscriptions automatically

**EXAMPLE - Replace API Actions with Effects:**
```typescript
// Legacy: addApiAction().withReducer()
// New: ComponentStore effect
readonly loadEvents = this.effect<void>(
  pipe(
    // switchMap: only the latest load matters
    switchMap(() =>
      this.#api.getEvents().pipe(
        tapResponse({
          next: (events) => this.setEvents(events),
          error: (error) => this.#errorHandler.handle(error),
        })
      )
    )
  )
);
```

**EXAMPLE - Replace Socket Actions with Updaters:**
```typescript
// Wire websocket observables directly to updaters in constructor
constructor() {
  super(initialState);

  // Subscribe to websocket actions and wire to updaters
  this.addEvent(this.#wsService.action<Event>('AddEvent'));
  this.updateEvent(this.#wsService.action<Event>('UpdateEvent'));
  this.removeEvent(this.#wsService.action<{ id: string }>('RemoveEvent'));

  // Trigger load on websocket connection
  this.loadEvents(
    this.#wsService.connectionState$.pipe(
      filter((state) => state === 'Connected'),
      map(() => undefined)
    )
  );
}
```

#### 3. Replace `parseDates: true` with `parseObject` in the API Client

Legacy CustomStore actions configured with `parseDates: true` rely on a framework-level interceptor to convert ISO date strings to `Date` objects. When migrating to ComponentStore, move this responsibility to the API client.

-   **ALWAYS** replace `parseDates: true` by adding a `parseJsonResponse` helper to the API client file
-   **ALWAYS** apply the helper via `.pipe(map(response => parseJsonResponse(response)))` on each HTTP method
-   **NOTE**: Only move date parsing to the API client when the store is the sole consumer of those methods

**EXAMPLE - Before (Legacy):**
```typescript
export const loadEvents = eventStore
  .addApiAction('Event', 'Load')
  .configure({ parseDates: true })
  .withEffect(s => s.loadEvents)
  .withReducer();
```

**EXAMPLE - After (API Client):**
```typescript
import { coToDateOrNull } from '@consensus/co/util-date-times';
import { parseObject } from '@lib/helpers';
import { Observable, map } from 'rxjs';

/**
 * Convert ISO date-time string properties to Date.
 */
function parseJsonResponse<T>(response: T): T {
  return parseObject(response, (value: unknown) =>
    typeof value === 'string' ? coToDateOrNull(value) : null
  );
}

@Injectable({ providedIn: 'root' })
export class EventClient {
  readonly #http = inject(HttpClient);

  loadEvents(): Observable<Event[]> {
    return this.#http
      .get<Event[]>(`${this.#server}/api/events`)
      .pipe(map(response => parseJsonResponse(response)));
  }
}
```

#### 4. Replace `showErrors: true` with `CoSnackService`

Legacy CustomStore actions configured with `showErrors: true` display error snackbars automatically. In ComponentStore effects, handle this explicitly in the `tapResponse` error callback.

-   **ALWAYS** inject `CoSnackService` and `ErrorHandler` in the store
-   **ALWAYS** use `getErrorMessage(error)` from `@consensus/co/util-http-errors` to extract a user-friendly message
-   **ALWAYS** call both `this.#errorHandler.handleError(error)` (for logging) and `this.#snackService.error(...)` (for user notification) in error handlers

**EXAMPLE - Before (Legacy):**
```typescript
export const saveEvent = eventStore
  .addApiAction('Event', 'Save')
  .configure({ showErrors: true })
  .withEffect(s => s.saveEvent)
  .withReducer();
```

**EXAMPLE - After (ComponentStore):**
```typescript
import { ErrorHandler, inject } from '@angular/core';
import { CoSnackService } from '@consensus/co/ui-snackbars';
import { getErrorMessage } from '@consensus/co/util-http-errors';

// In the store class:
readonly #errorHandler = inject(ErrorHandler);
readonly #snackService = inject(CoSnackService);

readonly saveEvent = this.effect<SaveEventModel>(
  pipe(
    mergeMap(payload =>
      this.#client.saveEvent(payload).pipe(
        tapResponse({
          next: data => this.#updateEvent(data),
          error: (error: unknown) => {
            this.#errorHandler.handleError(error);
            this.#snackService.error(getErrorMessage(error));
          },
        })
      )
    )
  )
);
```

#### 5. Updaters (State Mutations)

-   **ALWAYS** use updaters to change state (not `setState` or `patchState`)
-   **ALWAYS** use `set` prefix for updaters that replace entire state slices
-   **ALWAYS** keep state transformations pure and predictable
-   **ALWAYS** replace `updateListItem` from `@lib/redux` with `Array.map` using a ternary expression
-   **NOTE**: Updaters can accept `PayloadType | Observable<PayloadType>` - wire observables directly

**EXAMPLE - Replace `updateListItem`:**
```typescript
// Legacy: updateListItem(state.events, x => x.id === data.id, data)
// New: Array.map with ternary
readonly #updateEvent = this.updater<Event>(
  (state, data): EventStoreState => ({
    ...state,
    events: state.events.map(x => (x.id === data.id ? data : x)),
  })
);
```

**EXAMPLE - Common updater patterns:**
```typescript
// Replace entire collection
readonly #setEvents = this.updater<Event[]>(
  (state, events): EventStoreState => ({
    ...state,
    events,
  })
);

// Add item to collection
readonly #addEvent = this.updater<Event>(
  (state, event): EventStoreState => ({
    ...state,
    events: [...state.events, event],
  })
);

// Update item in collection (replaces updateListItem)
readonly #updateEvent = this.updater<Event>(
  (state, updated): EventStoreState => ({
    ...state,
    events: state.events.map(e => (e.id === updated.id ? updated : e)),
  })
);

// Remove item from collection
readonly #removeEvent = this.updater<string>(
  (state, eventId): EventStoreState => ({
    ...state,
    events: state.events.filter(e => e.id !== eventId),
  })
);

// Replace boolean flag
readonly #setLoading = this.updater<boolean>(
  (state, isLoading): EventStoreState => ({
    ...state,
    isLoading,
  })
);
```

#### 6. Selectors (State Reads)

-   **ALWAYS** expose state via selectors, suffix static selectors with `$`
-   **ALWAYS** prefix parameterized selectors with `select`
-   **NEVER** use `ComponentStore.get()` — always read via selectors
-   **ALWAYS** do one-off reads in effects by composing with `withLatestFrom(...)`
-   **ALWAYS** compute derived state in selectors (do not store derived state)
-   **NEVER** use `tap`/`tapResponse` in selectors

**EXAMPLE:**
```typescript
// Replace legacy selectors with ComponentStore selectors
readonly events$ = this.select((state) => state.events);
readonly isLoading$ = this.select((state) => state.isLoading);

// Computed/derived state
readonly activeEvents$ = this.select(
  this.events$,
  (events) => events.filter((e) => e.isActive)
);
```

#### 7. Effects Best Practices

-   **ALWAYS** only use `tapResponse` nested in inner pipes (after the flattening operator)
-   **ALWAYS** use the RxJS `pipe` operator directly in effects: `this.effect<Type>(pipe(...))` instead of `this.effect<Type>((trigger$) => trigger$.pipe(...))`
-   **ALWAYS** default to `mergeMap` as the flattening operator in effects
-   **ALWAYS** evaluate whether a different flattening operator is more appropriate, and if so use it with a comment justifying the choice
    -   **EXAMPLE**: `// switchMap: only the latest load matters` when a new trigger should cancel the previous request
    -   **EXAMPLE**: `// concatMap: serialize deletes so each rollback snapshot is consistent` when ordering matters
-   **NEVER** subscribe directly to form controls or observables inside components; wire them into store effects
-   **NEVER** provide an empty observable (e.g., `this.effectName(of(undefined))`) when calling effects without arguments
    -   **NOTE**: The effect creates its own trigger observable internally; use `this.effectName()` instead
-   **ALWAYS** import `tapResponse` from `@ngrx/operators`, not `@ngrx/component-store`

**EXAMPLE - Correct import:**
```typescript
import { tapResponse } from '@ngrx/operators';
```

**EXAMPLE - Default: `mergeMap` (no comment needed):**
```typescript
readonly saveEvent = this.effect<SaveEventModel>(
  pipe(
    mergeMap(payload =>
      this.#client.saveEvent(payload).pipe(
        tapResponse({
          next: data => this.#updateEvent(data),
          error: (error: unknown) => {
            this.#errorHandler.handleError(error);
            this.#snackService.error(getErrorMessage(error));
          },
        })
      )
    )
  )
);
```

**EXAMPLE - `switchMap` with justification comment:**
```typescript
readonly loadEvents = this.effect<void>(
  pipe(
    // switchMap: only the latest load matters
    switchMap(() =>
      this.#client.loadEvents().pipe(
        tapResponse({
          next: data => this.#setEvents(data),
          error: (error: unknown) => {
            this.#errorHandler.handleError(error);
            this.#snackService.error(getErrorMessage(error));
          },
        })
      )
    )
  )
);
```

**EXAMPLE - Optimistic delete with `concatMap` and justification comment:**
```typescript
readonly deleteAnswer = this.effect<string>(
  pipe(
    withLatestFrom(this.answers$),
    tap(([answerId]) => this.#removeAnswer(answerId)),
    // concatMap: serialize deletes so each rollback snapshot is consistent
    concatMap(([answerId, answersBefore]) =>
      this.#client.deleteAnswer(answerId).pipe(
        tapResponse({
          next: () => {
            // Already removed optimistically
          },
          error: (error: unknown) => {
            this.#setAnswers(answersBefore);
            this.#errorHandler.handleError(error);
            this.#snackService.error(getErrorMessage(error));
          },
        })
      )
    )
  )
);
```

#### 8. Websocket Integration

-   **ALWAYS** inject `ConnectSharedDataAccessWebsocketService` in the store, not in a separate service
-   **ALWAYS** wire websocket action observables directly to updaters in the constructor
-   **ALWAYS** wire connection state to load effects using `filter` and `map`
-   **NEVER** use `takeUntilDestroyed` for root-provided stores
    -   **NOTE**: ComponentStore handles cleanup automatically for root stores

**EXAMPLE:**
```typescript
readonly #wsService = inject(ConnectSharedDataAccessWebsocketService);

constructor() {
  super(initialState);

  // Wire websocket actions directly
  this.addItem(this.#wsService.action<Item>('AddItem'));
  this.updateItem(this.#wsService.action<Item>('UpdateItem'));

  // Trigger load on connection
  this.loadItems(
    this.#wsService.connectionState$.pipe(
      filter((state) => state === 'Connected'),
      map(() => undefined)
    )
  );
}
```

#### 9. Update Consumers

-   **ALWAYS** use the `inject()` function instead of constructor injection
-   **ALWAYS** place all `inject()` calls first in the class as readonly fields
-   **ALWAYS** use ECMAScript `#privateField` syntax for private members
-   **NEVER** use the `public` or `private` keywords in TypeScript

**EXAMPLE - Components Before:**
```typescript
readonly events$ = this.#store.select(eventSelectors.selectEvents);

ngOnInit() {
  this.#store.dispatch(eventActions.loadEvents());
}
```

**EXAMPLE - Components After:**
```typescript
readonly #eventStore = inject(EventStore);
readonly events$ = this.#eventStore.events$;

ngOnInit() {
  this.#eventStore.loadEvents();
}
```

**EXAMPLE - Services Before:**
```typescript
this.#store.dispatch(eventActions.updateEvent({ event }));
```

**EXAMPLE - Services After:**
```typescript
this.#eventStore.saveEvent(event);
```

#### 10. Consumer Interaction Patterns

Three patterns emerge for how components interact with ComponentStore effects:

##### Fire-and-forget (most common)

Call the effect method directly. The store handles state updates internally. Use for loads, updates, completion actions, and deletes.

```typescript
// Load data
this.#eventStore.loadEvents();

// Update an entity
this.#eventStore.completeInterview({ ...formValue, id: interviewId, result });

// Delete (store handles optimistic removal + rollback internally)
this.#eventStore.deleteAnswer(answerId);
// Immediately update component-local state
this.answer = null;
```

##### Fire + watch selector (when the consumer needs the created entity)

Call the effect, then use `firstValueFrom` with a selector to detect the new entity in state. Use when the consumer needs the created entity's ID (e.g., to navigate or update local state).

```typescript
// Snapshot existing IDs before the create
const existingIds = new Set(
  (await firstValueFrom(this.interviews$)).map(i => i.id)
);

// Fire the effect
this.#certStore.createInterview({
  participantUserId: userId,
  questionnaireId,
});

// Wait for the store to receive the created entity
const interview = await firstValueFrom(
  this.interviews$.pipe(
    map(interviews => interviews.find(i => !existingIds.has(i.id))),
    filter(Boolean)
  )
);

// Now use the entity (e.g., navigate)
this.#router.navigate(['interviews', interview.id], {
  relativeTo: this.#route,
});
```

##### Fire + optimistic local update (updates with local component state)

Call the effect, then immediately update component-local state. The store handles its own state via updaters; the component mirrors the change locally to keep its bindings in sync without waiting for a round-trip.

```typescript
// Fire the effect
this.#certStore.updateAnswer({ ...this.answer, ...data });

// Optimistically update the component-local reference
this.answer = { ...this.answer, ...data };
```

#### 11. Clean Up Legacy Code

-   **ALWAYS** remove store registration from feature store config (e.g., `provide-event-store.ts`)
-   **ALWAYS** remove state slice from feature state interface
-   **ALWAYS** remove reducer mappings
-   **ALWAYS** remove legacy action exports (unless maintaining backward compatibility)
-   **ALWAYS** remove legacy selector exports (unless maintaining backward compatibility)
-   **ALWAYS** remove `Store` injection from components/services only using this store
-   **ALWAYS** update tests to use ComponentStore directly

---

### Critical Rules

#### Encapsulation

-   **ALWAYS** use subclassed services (not components) for stores
-   **ALWAYS** place the subclassed store in a separate file in the same folder as the component
-   **ALWAYS** use only inherited members inside the store; expose public state via selectors

#### Lifecycle

-   **NEVER** use lifecycle hooks (`OnStoreInit`, `OnStateInit`)
-   **NEVER** use `provideComponentStore`; prefer standard providers

#### What NOT to Do

-   **NEVER** use `takeUntilDestroyed` for root-provided stores
    -   **NOTE**: ComponentStore handles cleanup automatically; only needed for component-scoped stores
-   **NEVER** use `ComponentStore.get()`
    -   **ALWAYS** read state through selectors; use `withLatestFrom()` in effects for one-off reads
-   **NEVER** create manual subscriptions
    -   **ALWAYS** wire observables directly to updaters/effects; let ComponentStore manage subscriptions
-   **NEVER** import `tapResponse` from `@ngrx/component-store`
    -   **ALWAYS** import from `@ngrx/operators`: `import { tapResponse } from '@ngrx/operators';`
-   **NEVER** provide empty observables to effects
    -   **EXAMPLE**: Use `this.loadEvents()` not `this.loadEvents(of(undefined))`
-   **NEVER** keep legacy action/selector exports unless explicitly maintaining backward compatibility
-   **NEVER** register ComponentStores in feature store configurations

---

### File Organization

-   **ALWAYS** follow the library naming pattern: `libs/<product>/<application>/<domain>/<type>-<name>`
    -   **NOTE**: Product: `academy`, `coaching`, `connect`, `shared`
    -   **NOTE**: Application: `cms`, `shared`, `ufa` (User-Facing Application)
    -   **NOTE**: Type: `data-access`, `feature`, `ui`, etc.

**EXAMPLE:**
```
libs/connect/ufa/events/
├── data-access-event/
│   └── src/
│       ├── lib/
│       │   └── event.store.ts          # New ComponentStore
│       └── index.ts                     # Export store
└── feature-events/
    └── src/
        └── lib/
            └── event-list/
                └── event-list.component.ts  # Inject and use store
```

---

### Testing ComponentStores

-   **ALWAYS** use TestBed to configure the component store and its dependencies
-   **ALWAYS** test selectors by subscribing and verifying emitted values
-   **ALWAYS** test updaters by calling them and verifying state changes via selectors
-   **ALWAYS** test effects by triggering them and verifying side effects
-   **ALWAYS** use `{ provide: Service, useValue: mockService }` to mock dependencies
-   **ALWAYS** use `jest.spyOn()` to verify side effects
-   **CAN** use `patchState` with `// eslint-disable-next-line no-restricted-syntax` for test setup only
-   **ALWAYS** include the class name in `describe()` blocks: `describe(MyStore.name, () => ...)`
-   **ALWAYS** write test descriptions that clearly state expected behavior: `it('should...')`

**EXAMPLE:**
```typescript
describe(EventStore.name, () => {
  let store: EventStore;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        EventStore,
        { provide: ApiService, useValue: mockApiService },
      ],
    });
    store = TestBed.inject(EventStore);
  });

  it('should load events', (done) => {
    // Test selectors by subscribing
    store.events$.pipe(skip(1)).subscribe((events) => {
      expect(events).toEqual(mockEvents);
      done();
    });

    // Trigger effect
    store.loadEvents();
  });
});
```

---

### Quick Reference: Member Order

-   **ALWAYS** order members in ComponentStore classes consistently:

1. Injected dependencies (`inject()`)
2. Selectors (`readonly prop$ = this.select(...)`)
3. Constructor (wire websockets, connection triggers)
4. Effects (`readonly effectName = this.effect(...)`)
5. Updaters (`readonly setX = this.updater(...)`)
6. Private helpers

---

### Additional Best Practices from AGENTS.md

-   **ALWAYS** check AGENTS.md for for the latest definite best practices

#### TypeScript

-   **ALWAYS** prefer type inference when the type is obvious
-   **ALWAYS** avoid the `any` type; use `unknown` when type is uncertain
-   **ALWAYS** use ECMAScript `#privateField` syntax for encapsulation
-   **NEVER** use the `public` or `private` keywords in TypeScript class members

#### Angular Components Using Stores

-   **ALWAYS** set `changeDetection: ChangeDetectionStrategy.OnPush` in `@Component` decorator
-   **ALWAYS** use separate HTML files (do NOT use inline templates)
-   **ALWAYS** place all `inject()` calls first in the class as readonly fields
-   **ALWAYS** place `@Input` and `@Output` properties second in the class

#### Templates

-   **ALWAYS** use native control flow (`@if`, `@for`, `@switch`) instead of `*ngIf`, `*ngFor`, `*ngSwitch`
-   **ALWAYS** use the `*ngrxLet` directive or `ngrxPush` pipe to handle Observables
    -   **ALWAYS** prefer the `ngrxPush` pipe over `async` for one-off async bindings in templates
    -   **PREFER** not using `*ngrxLet` or `ngrxPush` multiple times for the same Observable; instead assign it to a template variable using `@let`

#### Services & Dependency Injection

-   **ALWAYS** use the `inject()` function instead of constructor injection
-   **ALWAYS** place all `inject()` calls first as private readonly fields
-   **ALWAYS** use the `providedIn: 'root'` option for singleton services
-   **ALWAYS** use `@Component.providers` for component-level stores

---

### Before Submitting Code Review

-   **ALWAYS** ensure all affected tests pass locally
-   **ALWAYS** run formatting: `yarn run format` (from `Connect/ng-app-monolith`)
-   **ALWAYS** run linting: `yarn exec nx affected --targets=lint,test --skip-nx-cache`
-   **ALWAYS** verify no linting errors are present
-   **ALWAYS** ensure code follows established patterns as outlined in AGENTS.md

## Examples

See Instructions Section for code examples.
