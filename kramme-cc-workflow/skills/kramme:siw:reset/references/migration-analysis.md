# Migration Analysis

Read this file from Steps 2 and 3 in `SKILL.md`.

## Extract Migration Candidates

Read `siw/LOG.md` and extract content that may be worth preserving in the spec.

### Decision Log Entries

Look for the `## Decision Log` section and extract all decisions:

- Decision number and title
- Problem statement
- Decision made
- Rationale
- Impact/files affected

### Completed Tasks

From `## Current Progress` section:

- Tasks marked as completed
- Implementation details worth preserving
- Any notes about how things were implemented

### Guiding Principles

If `## Guiding Principles` section exists:

- Principles that emerged during implementation
- Constraints discovered

### Rejected Alternatives

From `## Rejected Alternatives Summary`:

- Important alternatives that were considered
- Reasons for rejection that will be valuable later

## Present Migration Candidates

If any content was found, present it to the user:

```text
siw/LOG.md Analysis Complete

Found the following content that could be migrated to the spec:

Decisions (X found):
- Decision #1: {title} - {brief summary}
- Decision #2: {title} - {brief summary}
...

Completed Tasks (X found):
- Task 1.1: {title}
- Task 1.2: {title}
...

Guiding Principles (X found):
- {principle 1}
- {principle 2}
...

Rejected Alternatives (X found):
- {alternative 1} for {purpose}
...
```

Use `AskUserQuestion`:

```yaml
header: "Migrate Content to Spec"
question: "Which content should be migrated to the specification file before resetting?"
multiSelect: true
options:
  - label: "All decisions"
    description: "Add all Decision Log entries to spec's Design Decisions section"
  - label: "Completed tasks summary"
    description: "Add summary of completed work to spec"
  - label: "Guiding principles"
    description: "Add discovered principles to spec"
  - label: "Rejected alternatives"
    description: "Add rejected alternatives for future reference"
```

If the user selects nothing, treat that as "skip migration" and proceed to Step 4. Log content will be lost on the `LOG.md` reset if the user confirms.
