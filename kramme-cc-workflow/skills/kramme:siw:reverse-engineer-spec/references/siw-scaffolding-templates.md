Create SIW-compatible scaffolding matching the structure from `kramme:siw:init`.

#### 4.4.1 Create siw/LOG.md

```markdown
# LOG.md

## Current Progress

**Last Updated:** {current date}
**Quick Summary:** Spec reverse-engineered from {source description}

### Project Status

- **Status:** Planning | **Current Phase:** Specification | **Overall Progress:** 0 tasks

### Last Completed

- Reverse-engineered specification from existing code

### Next Steps

1. Run `/kramme:siw:discovery` to fill open questions
2. Run `/kramme:siw:spec-audit` to validate spec quality
3. Run `/kramme:siw:generate-phases` to create issues
4. **Blockers:** None

---

## Decision Log

_Decisions will be documented here as they are made._

---

## Rejected Alternatives Summary

| Alternative | For | Why Rejected | Decision # |
|------------|-----|--------------|------------|
| _None yet_ | | | |

---

## Guiding Principles

1. {To be defined during implementation}

## References

- Spec: `siw/{spec_filename}`
- Issues: `siw/OPEN_ISSUES_OVERVIEW.md`
```

#### 4.4.2 Create siw/OPEN_ISSUES_OVERVIEW.md

```markdown
# Open Issues Overview

## General

**Parallelization:** Needs coordination

| # | Title | Status | Size | Priority | Related |
|---|-------|--------|------|----------|---------|
| _None_ | _Use `/kramme:siw:issue-define` to create first issue (G-001)_ | | | | |

**Status Legend:** READY | IN PROGRESS | IN REVIEW | DONE

**Issue Naming:** `G-XXX` for general issues, `P1-XXX`, `P2-XXX` for phase-specific issues.

**Details:** See `siw/issues/ISSUE-{prefix}-XXX-*.md` files.
```

#### 4.4.3 Create siw/issues/ directory

```bash
mkdir -p siw/issues
touch siw/issues/.gitkeep
```
