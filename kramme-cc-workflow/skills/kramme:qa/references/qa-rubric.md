# QA Rubric

Defines what to verify at each level during QA testing.

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
- Text is readable (no overlapping, no truncation without indication)
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

- No errors in console (warnings are noted but not blockers)
- All API calls return expected status codes
- No CORS errors
- No mixed content warnings
- Response times are reasonable (note anything > 3 seconds)
