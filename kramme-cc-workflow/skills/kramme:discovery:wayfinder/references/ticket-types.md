# Wayfinder Ticket Types

Every ticket asks one precise question that can be resolved in one agent session. Choose one type and one mode before creating the file.

## Modes

- **AFK:** An agent can resolve the ticket from available tools and sources without a live human judgment.
- **HITL:** A human must supply judgment, react to an artifact, perform an inaccessible action, or speak for their own priorities. Never simulate the human's contribution.

Default `research` to AFK, `prototype` and `grilling` to HITL, and choose `task` mode from the actual access requirement. Record a one-line HITL reason.

## Types

### research

Use for facts that must come from primary sources, official documentation, specifications, local source, or another source of truth. Invoke `/kramme:research` with the ticket's bounded question and save its cited Markdown result under the map's `evidence/` directory unless an existing convention is stronger.

Resolve only when the ticket records the source-backed answer, links the evidence artifact, and separates conflicts or gaps from decisions that still require a human.

### prototype

Use when a cheap, disposable artifact will make a behavior, interface, state model, data shape, or content direction concrete enough to judge. Invoke `/kramme:prototype`; do not turn the prototype into production implementation.

Resolve only after the human or named decision-maker reacts and the ticket records the resulting decision. Link the artifact or cleanup note, and follow the prototype skill's retirement rules.

### grilling

Use for a product, domain, scope, priority, or architecture judgment that must come from a human. Ask one question at a time, follow consequential branches, and keep the exchange bounded to the ticket's question. Use a discovery or ubiquitous-language skill only when it fits the specific uncertainty; do not launch a full planning workflow from the ticket.

Resolve only when the human has answered the decision-bearing question and confirmed or corrected the recorded answer. A grilling agent that answers its own human-facing questions has failed the ticket.

### task

Use only for prerequisite action that must happen before a decision can be made: provisioning safe test access, collecting a bounded dataset, enabling a sandbox, or performing another concrete unblocker. A task is not a delivery ticket for the destination.

Resolve when the prerequisite is complete and the ticket records the resulting safe facts. Record credential locations, never credential values. If the action would implement destination behavior, close or retype the ticket and hand the work to the normal implementation workflow after wayfinding.

Before mutating an external system, confirm that the exact action and target are already authorized by the user and ticket. Otherwise make the ticket HITL and request approval. Never use a Wayfinder task to purchase, deploy, change production data, or broaden access implicitly.

## Selection Order

Choose the first matching branch:

1. Missing external or source-of-truth facts -> `research`.
2. A concrete artifact is needed for informed reaction -> `prototype`.
3. Human judgment can answer the question directly -> `grilling`.
4. A non-decision prerequisite blocks one of the above -> `task`.

If none matches, sharpen the question or leave the area under **Not yet specified**. Do not create a generic catch-all ticket.

## Resolution Contract

Every resolved ticket records:

- a direct answer to its question;
- evidence or human confirmation;
- the decision and implications for the route;
- linked assets rather than pasted large artifacts;
- newly visible tickets, cleared fog, changed blockers, or scope changes;
- no secrets, raw private data, or sensitive logs.
