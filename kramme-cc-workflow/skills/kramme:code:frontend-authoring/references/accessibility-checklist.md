# Accessibility checklist (WCAG 2.1 AA)

This checklist is inlined here on purpose. It is self-contained and does not reference any other skill, agent, or repo-level doc. Every component authored under `kramme:code:frontend-authoring` must satisfy these bars before the accessibility pass is marked done.

## Semantic HTML

- [ ] Heading hierarchy correct: `h1` > `h2` > `h3`, no skipped levels.
- [ ] Landmark elements used where applicable: `nav`, `main`, `aside`, `header`, `footer` — not generic `div`.
- [ ] Lists use `ul` / `ol` / `li`, not styled `div`s.
- [ ] Data tables use `th`, `scope`, and `caption`.
- [ ] Buttons are `<button>` (not `<div onClick>`); links are `<a href>`.

## Keyboard navigation

Every interactive element must be reachable and operable with the keyboard alone.

```tsx
// Good: natively focusable
<button onClick={handleClick}>Click me</button>

// Bad: not focusable
<div onClick={handleClick}>Click me</div>

// Acceptable (but prefer <button>): manually focusable with correct keyboard handlers
<div
  role="button"
  tabIndex={0}
  onClick={handleClick}
  onKeyDown={(e) => {
    if (e.key === 'Enter') handleClick();
    if (e.key === ' ') e.preventDefault();
  }}
  onKeyUp={(e) => {
    if (e.key === ' ') handleClick();
  }}
>
  Click me
</div>
```

- [ ] All interactive elements reachable via Tab.
- [ ] Custom widgets implement expected keyboard patterns: arrow keys for tabs/menus, Escape to close overlays, Enter/Space for activation.
- [ ] No keyboard traps. Focus can always escape (except intentional modal focus traps that provide Escape).
- [ ] No `tabindex` > 0. Use `tabindex="-1"` only for programmatic focus, and not on naturally focusable elements.

## ARIA labels

Label interactive elements that lack visible text. Do not add redundant ARIA (e.g., `role="button"` on a `<button>`).

```tsx
// Icon-only control: label it
<button aria-label="Close dialog"><XIcon /></button>

// Form input with visible label: use htmlFor/id
<label htmlFor="email">Email</label>
<input id="email" type="email" />

// No visible label: aria-label
<input aria-label="Search tasks" type="search" />
```

- [ ] Custom widgets have appropriate `role` (`dialog`, `tablist`, `menu`, `alertdialog`, etc.).
- [ ] `aria-label` or `aria-labelledby` on elements without visible text labels.
- [ ] `aria-describedby` links inputs to error messages and help text.
- [ ] `aria-expanded`, `aria-selected`, `aria-checked` present on stateful controls.
- [ ] `aria-live` regions for dynamic content updates (toasts, notifications, loading announcements).
- [ ] `aria-hidden="true"` on decorative elements.
- [ ] No redundant ARIA on elements that already have semantic meaning.

## Focus management

Focus must move predictably as content changes.

```tsx
// Move focus when a dialog opens; return on close
function Dialog({ isOpen, onClose }: DialogProps) {
  const closeRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    if (isOpen) closeRef.current?.focus();
  }, [isOpen]);

  return (
    <dialog open={isOpen}>
      <button ref={closeRef} onClick={onClose}>Close</button>
      {/* dialog content */}
    </dialog>
  );
}
```

- [ ] Modal dialogs trap focus. Focus does not escape to background elements.
- [ ] Focus returns to the trigger element when an overlay/dialog closes.
- [ ] Visible focus indicators present. Never `outline: none` without a replacement ring.
- [ ] Focus moves logically after content updates (new sections, route changes, async results).

## Forms

- [ ] Every input has an associated `<label>` (via `for`/`id` or wrapping).
- [ ] Required fields indicated with `required` or `aria-required="true"`.
- [ ] Error messages associated via `aria-describedby`.
- [ ] Form errors announced to screen readers (`aria-live` or focus management).
- [ ] Related inputs grouped with `fieldset` + `legend` (radio groups, address blocks).

## Color and contrast

- [ ] Normal text: 4.5:1 contrast minimum against its background.
- [ ] Large text (≥18px, or ≥14px bold): 3:1 contrast minimum.
- [ ] UI components and graphical objects: 3:1 against adjacent colors.
- [ ] Information never conveyed by color alone — pair with icon, text, or pattern.

## Images and media

- [ ] Meaningful images have descriptive `alt` text.
- [ ] Decorative images use `alt=""` or `aria-hidden="true"`.
- [ ] SVG icons have `aria-label` or `<title>`, or are hidden if decorative.
- [ ] Video/audio has captions or transcripts when content is informational.

## Meaningful empty / error / loading states

Do not ship blank screens.

```tsx
function TaskList({ tasks }: { tasks: Task[] }) {
  if (tasks.length === 0) {
    return (
      <div role="status" className="text-center py-12">
        <TasksEmptyIcon className="mx-auto h-12 w-12 text-muted" />
        <h3 className="mt-2 text-sm font-medium">No tasks</h3>
        <p className="mt-1 text-sm text-muted">Get started by creating a new task.</p>
        <Button className="mt-4" onClick={onCreateTask}>Create Task</Button>
      </div>
    );
  }

  return <ul role="list">...</ul>;
}
```

- [ ] Empty state: explains the state and offers a next action.
- [ ] Error state: explains the failure and offers retry where applicable.
- [ ] Loading state: uses skeleton or progress indicator with `aria-busy="true"` and an `aria-label`.

## Motion

- [ ] Animations respect `prefers-reduced-motion` media query.
- [ ] No auto-playing animations that cannot be paused.
- [ ] No flashing content more than 3 times per second.

## Final sweep

- [ ] Component renders with no console errors or warnings.
- [ ] axe-core / browser a11y dev tools report no violations.
- [ ] Tab through the component: every interactive element is reachable.
- [ ] Screen reader sweep: labels, landmarks, and structure are conveyed correctly.

If any box is unchecked, the accessibility pass is not done.
