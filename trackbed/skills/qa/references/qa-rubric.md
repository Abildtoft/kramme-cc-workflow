# QA Rubric

Defines what to verify at each level during QA testing.

## Route Checklist

For each route, verify:

1. **Page loads without errors** - no blank page, no stuck spinner, no crash
2. **Console is clean** - apply the clean-console standard below
3. **Network requests succeed** - use `references/network-triage.md`
4. **Key interactions work** - buttons respond, forms submit, navigation works
5. **Visual state is reasonable** - no overflow, no broken images, readable text
6. **Edge states** - empty states handled, error states if triggerable
7. **Accessibility ladder** - run the checks below

Prioritize test items by severity impact. Blockers first, then major, then minor.

## Clean-Console Standard

- Default: zero console errors, zero console warnings. Every error and every warning is a finding.
- `LEGACY_CONSOLE_MODE` true: zero console errors is still required; warnings demote to Info-level findings rather than Minor/Major.

## Accessibility Ladder

Run these checks for every tested route. Each failed check becomes a finding in the `Accessibility` category from `references/health-score-rubric.md`.

1. **Accessibility tree** - read the a11y tree; flag interactive elements without an accessible name (buttons, links, form controls).
2. **Heading hierarchy** - exactly one `h1`; heading levels do not skip.
3. **Focus order** - tab through the page; focus follows visual order and no focus traps.
4. **Color contrast** - sample primary text and interactive elements against WCAG AA (4.5:1 for body text, 3:1 for large text and UI components).
5. **Dynamic content announcement** - live regions, toasts, and modal open/close announce to assistive tech.

## Page Health

- Page loads completely without JavaScript errors
- No unhandled promise rejections in console
- No failed network requests (4xx, 5xx responses)
- Page renders meaningful content (not blank, not a spinner stuck indefinitely)
- No layout shifts after initial render
- Page title and meta are appropriate

## Interaction Health

- Forms submit successfully and provide feedback
- Buttons respond to clicks with visible state change
- Navigation links lead to expected destinations
- Dropdowns, modals, and overlays open and close correctly
- Input validation provides clear, immediate feedback
- Keyboard navigation works for primary flows

## Visual Health

- No content overflow or clipping
- Text is readable, with overlap avoided and intentional overflow handling
- Images load (no broken image placeholders)
- Responsive behavior is reasonable at the current viewport
- No elements positioned off-screen or hidden unexpectedly

## Data Health

- Correct data displayed for the context (not stale, not from wrong user/context)
- Updates reflect immediately or with clear indication of pending state
- Empty states are handled (not a blank page, but a meaningful message)
- Pagination, filtering, and sorting work correctly when applicable
- Form data persists appropriately across navigation

## Console and Network

- Console is clean: every error and every warning is a finding by default (warnings demote to Info only under `--legacy-console`).
- All API calls return expected status codes
- No CORS errors
- No mixed content warnings
- Response times are reasonable (note anything > 3 seconds)
