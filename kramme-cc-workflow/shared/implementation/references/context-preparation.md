# Prepare Implementation Context

Once the workflow establishes task scope, follow applicable repository guidance and reuse relevant context already loaded. Keep preparation within that scope; treat unrelated rules-file repairs as a separate user request.

Before editing, load the following where relevant:

- The affected source files and nearby dependencies that explain the current behavior.
- The closest tests, fixtures, and verification commands for that behavior.
- One existing implementation pattern when the change needs a local convention to follow.
- The types, interfaces, or schemas that constrain the affected inputs and outputs.

For focused changes, read the affected sections with paths and enough surrounding code to interpret them. For broad changes, inventory and summarize the relevant modules first, then inspect full detail where it affects implementation or verification.

Before adding a new exported name or file, search the repository's contents and file paths for that name. Agents find code by text search, and a name that is already defined elsewhere makes every later search for it return the unrelated definitions too. When the search finds other definitions, add the domain term the change is about: `validateDeliveryConfig`, not another `validateConfig`. Keep a name that a framework or an implemented interface requires, or that callers always qualify with a module name, as with Go's `stripe.NewClient`.

Expand context when a concrete dependency or unresolved question calls for it; avoid loading unrelated files or repeating satisfied preparation.
