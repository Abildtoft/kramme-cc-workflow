# Spec Migration Templates

Resolve `{date}` placeholders with today's date (`date +%Y-%m-%d`). Derive `{date range}` from the earliest and latest entries in the LOG's Current Progress section.

Before appending, scan the spec for an existing heading or row that matches the entry being added: same Decision number/title, same principle text, or same rejected approach. If found, skip that entry rather than duplicating it.

## Decisions

Add to or create `## Design Decisions`:

```markdown
## Design Decisions

### Decision #1: {title}

**Date:** {date} | **Category:** {category}

**Problem:** {problem}

**Decision:** {decision}

**Rationale:** {rationale}

**Alternatives Rejected:** {alternatives}
```

## Completed Tasks Summary

Add to `## Implementation Notes` or `## Completed Work`:

```markdown
## Implementation Notes

### Completed ({date range})

- {task 1}: {brief description of what was done}
- {task 2}: {brief description}
```

## Guiding Principles

Add to `## Guiding Principles` or `## Constraints`:

```markdown
## Guiding Principles

1. {principle 1}
2. {principle 2}
```

## Rejected Alternatives

Add to `## Design Decisions` or `## Rejected Approaches`:

```markdown
## Rejected Approaches

| Approach     | Purpose   | Why Rejected |
| ------------ | --------- | ------------ |
| {approach 1} | {purpose} | {reason}     |
```

