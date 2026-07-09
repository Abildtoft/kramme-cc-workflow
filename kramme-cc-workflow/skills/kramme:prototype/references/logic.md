# Logic Prototype

Use this branch when the question is about state transitions, business rules, data shape, or API feel. The best logic prototype is a small runnable harness that lets the user push the idea through uncomfortable cases and see state change immediately.

## Process

1. Write the question at the top of the prototype.
   - Include the state model or API surface being tested.
   - Include the edge cases the prototype must make easy to trigger.
   - Keep the note short enough that it stays useful when the prototype is deleted or handed off.

2. Match the host runtime.
   - Use the language, task runner, and module style already present in the project.
   - If there is no obvious runtime, ask the user before adding one.
   - Keep the runnable command close to the prototype note or registered in the existing task runner.

3. Separate the portable idea from the throwaway harness.
   - Put the model under a small pure interface: reducer, explicit state machine, plain functions, or a minimal module/class surface.
   - Keep terminal prompts, printing, local input handling, and demo fixtures in the harness.
   - Let the harness call the model; do not let the model depend on terminal behavior.

4. Build the smallest interactive harness.
   - Initialize one in-memory state object.
   - Offer only the actions needed to test the question.
   - Re-render or print the complete relevant state after each action.
   - Keep the whole frame or output compact enough to compare states quickly.

5. Make the run path obvious.
   - Prefer an existing command shape such as `pnpm run prototype:<name>`, `make prototype-<name>`, `just prototype-<name>`, or a direct language command already common in the repo.
   - Avoid hidden setup steps.
   - Do not add tests, durable fixtures, generic libraries, or broad abstractions for the harness.

6. Capture the answer before cleanup.
   - Record the decision the prototype supports.
   - If the model is useful, stop with a production handoff note. Absorb it into production-quality code only after an explicit follow-up request, with normal review, tests, and error handling.
   - Delete all current-run prototype artifacts after the answer is captured, including the harness, model module, command wiring, demo fixtures, and scratch storage.
   - Ask before deleting or replacing any pre-existing or resumed prototype file, command, fixture store, or scratch storage. If the user is unavailable, leave an exact cleanup note instead.

## Anti-Patterns

- Wiring the prototype to production databases, queues, webhooks, or customer data.
- Treating the harness as reusable app architecture.
- Testing cases unrelated to the stated question.
- Keeping a runnable prototype around after the decision has moved into implementation.
