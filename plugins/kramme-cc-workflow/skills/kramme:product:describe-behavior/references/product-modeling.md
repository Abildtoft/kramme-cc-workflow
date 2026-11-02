# Product Modeling Guide

Use this guide to choose a stable document model before drafting behavior. Select only dimensions that users can observe or that materially change an observable result.

## The five decisions

1. **Surface boundary:** name one product surface, role, and configuration. Split materially different admin/user, mobile/desktop, authenticated/anonymous, or customized/default experiences unless the variation can stay readable in one corpus.
2. **Unit of behavior:** choose the smallest user-meaningful capability that owns a coherent outcome. Examples include completing checkout, drawing a shape, running a command, or sending and revising a message. Avoid mirroring packages or components.
3. **Lifecycle:** name the recurring states a user crosses, such as ready, active, awaiting result, completed, cancelled, and failed. A product may use different names, but comparable documents should use the same lifecycle where it fits.
4. **Variant and interruption axes:** choose conditions that alter the path: role, input method, flags, permissions, network state, existing data, cancellation, focus loss, retries, undo, or process interruption.
5. **Cross-cutting concerns:** choose a consistent review order for concerns that touch many behaviors, such as accessibility, persistence, authorization, privacy, latency feedback, offline behavior, localization, and destructive-action recovery.

## Common surface mappings

### Graphical application

- Unit: user goal or interaction, not screen component.
- Lifecycle: discover/enter, manipulate, preview, commit, cancel or recover.
- Evidence: event handlers, state machines/reducers, rendered output, persistence, end-to-end tests.
- Frequent interrupts: escape/cancel, focus loss, navigation, undo/redo, network loss, permission changes.

### Form or task-based web application

- Unit: end-to-end task across the routes needed to complete it.
- Lifecycle: view, edit, validate, submit, await, succeed or recover.
- Evidence: route/action handlers, schemas, server errors, loading/empty states, integration tests.
- Frequent variants: role, prior data, validation state, concurrent edits, device width, network response.

### Command-line product

- Unit: command or coherent subcommand outcome.
- Lifecycle: parse, validate, execute, emit/write, exit or interrupt.
- Evidence: command definitions, defaults, stdout/stderr, exit codes, filesystem effects, CLI tests.
- Frequent variants: flags, environment, current directory, TTY/non-TTY, signals, partial files, permissions.

### Conversational or agent product

- Unit: user turn or multi-turn job with one outcome.
- Lifecycle: accept input, queue/plan, stream or call tools, complete, cancel, retry or recover.
- Evidence: message state, tool policy, streaming transitions, persisted history, safety and integration tests.
- Frequent variants: attachments, tool availability, role, model/provider failure, cancellation, reconnect, retry.

### Developer-facing service

- Unit: caller-visible operation or workflow, not internal endpoint implementation.
- Lifecycle: authenticate, validate, accept, process, respond, retry or compensate.
- Evidence: public contracts, handlers, error mapping, idempotency behavior, integration/contract tests.
- Frequent variants: authorization, version, quotas, retries, partial failure, asynchronous completion.

## Ownership test

A document owns a behavior when it can answer all three questions without reaching into another feature's internals:

1. What user goal begins here?
2. Which visible state transitions belong here?
3. Where does the user land when this behavior completes, cancels, or fails?

If two proposed documents own the same transition, merge them or nominate one owner and make the other link to it. If a document contains several unrelated outcomes, split it.
