# Finding Severity

Rate every issue found with one of these levels:

- **Blocker**: Page crash, data loss, broken core flow, JavaScript error that prevents rendering, critical API failure that blocks functionality
- **Major**: Significant functionality broken, console errors on page load, form submission fails, navigation dead-ends, key feature not working
- **Minor**: Visual glitch, warning in console, slow response (> 3 seconds), minor layout issue, non-critical feature broken
- **Info**: Observation without clear user impact, optimization opportunity, deprecation warning, minor inconsistency

When assessing, consider:

- Does the issue affect the critical user path?
- Is the issue visible to users or only in developer tools?
- Does the issue block a workflow or is it cosmetic?
- Is this a regression in diff-aware mode or pre-existing?
