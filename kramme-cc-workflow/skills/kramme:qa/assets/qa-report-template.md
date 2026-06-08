# QA Report

**Mode:** {quick | diff-aware | targeted} **URL:** {tested URL} **Date:** {timestamp} **Duration:** {elapsed time} **Browser MCP:** {claude-in-chrome | chrome-devtools | playwright | code-only} **Framework:** {detected framework or "not detected"} **Routes Tested:** {N} **Health Score:** {HEALTH_SCORE}/100 ({HEALTH_LABEL})

## Tested Scope

- {route 1}: {description}
- {route 2}: {description}

## Journey Matrix (diff-aware only)

| Route / Screen | Journey | Changed Files | State / Data Setup | Expected Behavior | Evidence | Result | Follow-up |
| --- | --- | --- | --- | --- | --- | --- | --- |
| {route or screen} | {user task} | {files} | {state} | {expected result} | {screenshot, console/network note, a11y note, code-only note, or skipped reason} | pass / fail / blocked / skipped / code-only | QA-NNN / issue / none |

## Findings ({N} total)

### QA-NNN: {title}

**Severity:** Blocker | Major | Minor | Info **Category:** Console | Network | Visual | Functional | Data | Interaction | Content | Accessibility **Route:** {URL path} **Console:** {relevant console output or "clean"} **Network:** {relevant network issues or "all OK"}

**Repro Steps:**

1. Navigate to {url}
2. {action}
3. {observation}

**Expected:** {what should happen} **Actual:** {what happened}

**Recommended Fix:** {suggestion}

---

## Health Score Breakdown

| Category           | Score                  | Weight | Findings    |
| ------------------ | ---------------------- | ------ | ----------- |
| Console            | {N}/100                | 15%    | {count}     |
| Network            | {N}/100                | 10%    | {count}     |
| Visual             | {N}/100                | 10%    | {count}     |
| Functional         | {N}/100                | 25%    | {count}     |
| Data               | {N}/100                | 10%    | {count}     |
| Interaction        | {N}/100                | 10%    | {count}     |
| Content            | {N}/100                | 10%    | {count}     |
| Accessibility      | {N}/100                | 10%    | {count}     |
| **Weighted Total** | **{HEALTH_SCORE}/100** |        | **{total}** |

## Summary

- Blockers: {N}
- Major: {N}
- Minor: {N}
- Info: {N}

## Recommendation

{ready / not ready / ready with caveats — with explanation}

QA default flow does not auto-fix or auto-commit findings. Use the follow-up references above to route fixes.

**To resolve blockers, fix the issues and re-run:** `/kramme:qa <url>`
