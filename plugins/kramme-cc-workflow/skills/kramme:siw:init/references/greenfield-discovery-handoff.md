# Greenfield Discovery Handoff

Use this reference from `kramme:siw:init` Case 3 so the handoff contract stays local to the `kramme:siw:init` skill folder.

Apply it only when:

- `resolved_arguments` starts with `discover` or `interview`
- No permanent SIW spec files remain in `siw/`

## Procedure

1. Extract the optional topic from `resolved_arguments` after the leading `discover` / `interview` keyword.
2. If no topic is present, ask the Discovery Topic question from `references/argument-handling.md`.
3. Invoke `kramme:discovery:interview` through the skill invocation with exactly `--siw <topic>` and state that the call comes from the `kramme:siw:init` discover handoff, so its SIW mode runs Greenfield discovery and skips its plan-mode offer and next-command suggestion. Never pass `--apply`. If the runtime cannot invoke the skill, stop and tell the user to run `$kramme:discovery:interview --siw <topic>` and then `$kramme:siw:init siw/DISCOVERY_BRIEF.md`.
4. Wait for that run to complete and verify it created `siw/DISCOVERY_BRIEF.md`.
5. Return to `kramme:siw:init`, set `resolved_arguments=siw/DISCOVERY_BRIEF.md`, and continue with `references/discovery-brief-import.md`.
6. If the discovery run does not create `siw/DISCOVERY_BRIEF.md`, stop without creating SIW workflow files.
