# Reset Document Templates

## Empty Open Issues Overview

Replace `siw/OPEN_ISSUES_OVERVIEW.md` with:

```markdown
# Open Issues Overview

## General

**Parallelization:** Needs coordination

| # | Title | Status | Size | Priority | Mode | Related |
| --- | --- | --- | --- | --- | --- | --- |
| _None_ | _Use `/kramme:siw:issue-define` to create first issue (G-001)_ |  |  |  |  |  |

**Status Legend:** READY | IN PROGRESS | IN REVIEW | DONE

**Issue Naming:** `G-XXX` for general issues, `P1-XXX`, `P2-XXX` for phase-specific issues.

**Details:** See `siw/issues/ISSUE-{prefix}-XXX-*.md` files.
```

## Fresh LOG.md

Replace `siw/LOG.md` with:

```markdown
# LOG.md

## Current Progress

**Last Updated:** {current date} **Quick Summary:** Workflow reset. Ready for new issues.

### Project Status

- **Status:** Planning | **Current Phase:** Reset | **Overall Progress:** Fresh start

### Last Completed

- Workflow reset on {date}
- {If migration happened: "Migrated X decisions, X tasks to spec"}

### Next Steps

1. Define new issues with `/kramme:siw:issue-define`
2. Begin implementation with `/kramme:siw:issue-implement`
3. **Blockers:** None

---

## Decision Log

_Previous decisions migrated to {spec_filename}. New decisions will be documented here._

---

## Rejected Alternatives Summary

| Alternative | For | Why Rejected | Decision # |
| ----------- | --- | ------------ | ---------- |
| _None yet_  |     |              |            |

---

## Guiding Principles

{If migrated: "See {spec_filename} for established principles."} {If not migrated: "1. {To be defined during implementation}"}

## References

- Spec: `{spec_filename}`
- Issues: `siw/OPEN_ISSUES_OVERVIEW.md`
```
