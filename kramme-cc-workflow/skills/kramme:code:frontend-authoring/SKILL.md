---
name: kramme:code:frontend-authoring
description: "Build production-quality UI components with sound architecture, accessibility (WCAG 2.1 AA), and anti-AI-aesthetic defaults. Use when creating or modifying user-facing components. Covers component colocation, composition over configuration, state-management tier selection, accessibility patterns, and concrete replacements for AI-aesthetic defaults (purple gradients, rounded-2xl everywhere, oversized padding, shadow-heavy cards)."
disable-model-invocation: false
user-invocable: true
---

# Frontend Authoring

Build production-quality user interfaces that look engineer-crafted, not AI-generated. This is the author-time discipline that keeps "AI defaults" (purple gradients, `rounded-2xl` on every surface, oversized padding, stock card grids, shadow-heavy layouts) from being baked in and then flagged by review later. The goal: real design-system adherence, real accessibility, real interaction patterns — from the first draft.

## When to use

- Building new UI components or pages.
- Modifying existing user-facing interfaces.
- Implementing responsive layouts.
- Adding interactivity or client-side state.
- Fixing visual or UX issues.

## The authoring loop

Each user-facing change is one pass through this sequence:

1. **Simplicity check** — emit the `SIMPLICITY CHECK` marker (see below) stating the simplest UI that satisfies the requirement.
2. **Choose state tier** — apply the state decision ladder. Pick the lowest tier that works.
3. **Compose, don't configure** — small focused components that combine, not monolithic `<Thing config={...} />` props.
4. **Colocate** — put implementation, tests, hook, and component-local types in one folder.
5. **Anti-AI-aesthetic pass** — run the 9-row table in `references/ai-aesthetic-table.md` against your draft.
6. **Accessibility pass** — run `references/accessibility-checklist.md` against the component.
7. **Responsive pass** — verify at 320 / 768 / 1024 / 1440.
8. **Loading & transitions** — skeleton, empty, and error states present; optimistic updates rolled back on error.

When you notice something out-of-scope (an adjacent component that's already using a bad default, a typo in a sibling file), emit `NOTICED BUT NOT TOUCHING` and move on. Do not silently fix adjacent code.

### Markers

```
SIMPLICITY CHECK: <one-line summary of the simplest UI that satisfies the requirement>
```

If the thing you end up building is not the simplest version, add a second line explaining what forced the expansion.

```
NOTICED BUT NOT TOUCHING: <what you saw>
Why skipping: <out-of-scope / unrelated / deferred>
```

## Component architecture

### Colocated folder

Keep everything for one component together:

```
src/components/
  TaskList/
    TaskList.tsx          # Component implementation
    TaskList.test.tsx     # Tests
    TaskList.stories.tsx  # Storybook stories (if using)
    use-task-list.ts      # Custom hook (if complex state)
    types.ts              # Component-specific types (if needed)
```

### Composition over configuration

Prefer small components that compose over one large component with many config props.

```tsx
// Good: composable
<Card>
  <CardHeader>
    <CardTitle>Tasks</CardTitle>
  </CardHeader>
  <CardBody>
    <TaskList tasks={tasks} />
  </CardBody>
</Card>

// Avoid: over-configured
<Card
  title="Tasks"
  headerVariant="large"
  bodyPadding="md"
  content={<TaskList tasks={tasks} />}
/>
```

### Keep components focused

One component, one responsibility. If a component renders both a filter bar and a list and a pagination control, split it.

```tsx
// Good: does one thing
export function TaskItem({ task, onToggle, onDelete }: TaskItemProps) {
  return (
    <li className="flex items-center gap-3 p-3">
      <Checkbox checked={task.done} onChange={() => onToggle(task.id)} />
      <span className={task.done ? 'line-through text-muted' : ''}>{task.title}</span>
      <Button variant="ghost" size="sm" onClick={() => onDelete(task.id)}>
        <TrashIcon />
      </Button>
    </li>
  );
}
```

### Separate data from presentation

Containers handle data shape, loading, error, empty. Presentational components take already-resolved props.

```tsx
// Container: handles data
export function TaskListContainer() {
  const { tasks, isLoading, error, refetch } = useTasks();

  if (isLoading) return <TaskListSkeleton />;
  if (error) return <ErrorState message="Failed to load tasks" retry={refetch} />;
  if (tasks.length === 0) return <EmptyState message="No tasks yet" />;

  return <TaskList tasks={tasks} />;
}

// Presentation: handles rendering
export function TaskList({ tasks }: { tasks: Task[] }) {
  return (
    <ul role="list" className="divide-y">
      {tasks.map(task => <TaskItem key={task.id} task={task} />)}
    </ul>
  );
}
```

## State decision ladder

Pick the simplest tier that satisfies the requirement. Only move up when the current tier can't express the need.

```
Local state (useState)           → Component-specific UI state
Lifted state                     → Shared between 2-3 sibling components
Context                          → Theme, auth, locale (read-heavy, write-rare)
URL state (searchParams)         → Filters, pagination, shareable UI state
Server state (React Query, SWR)  → Remote data with caching
Global store (Zustand, Redux)    → Complex client state shared app-wide
```

**Avoid prop drilling deeper than 3 levels.** If you are passing props through components that don't use them, introduce context or restructure the tree.

## Anti-AI-aesthetic pass

The single highest-leverage author-time check. Every UI draft must be reviewed against the 9-row anti-pattern table before it ships.

Read `references/ai-aesthetic-table.md` and confirm none of the 9 anti-patterns describe your draft. If one does, apply the production alternative in the same row before moving on.

Typical catches at this stage:

- Using a generic purple/indigo accent instead of the project palette.
- Applying `rounded-2xl` to every card, button, and input.
- Layering drop shadows to fake depth where hierarchy should carry the load.
- Oversized symmetric padding on every container.

## Spacing, typography, and color

### Spacing

Use the project's spacing scale. Do not invent off-scale values.

```css
/* Use the scale: 0.25rem increments (or whatever the project uses) */
/* Good */  padding: 1rem;      /* 16px */
/* Good */  gap: 0.75rem;       /* 12px */
/* Bad */   padding: 13px;      /* Not on any scale */
/* Bad */   margin-top: 2.3rem; /* Not on any scale */
```

### Typography

Respect the type hierarchy — don't skip levels, don't use heading styles for non-heading content.

```
h1    → Page title (one per page)
h2    → Section title
h3    → Subsection title
body  → Default text
small → Secondary / helper text
```

### Color

- Use semantic color tokens (`text-primary`, `bg-surface`, `border-default`), not raw hex values.
- Meet contrast: 4.5:1 for normal text, 3:1 for large text (≥18px, or ≥14px bold).
- Never convey information by color alone — pair with icons, text, or patterns.

## Accessibility pass (WCAG 2.1 AA)

Every component must meet the standards in `references/accessibility-checklist.md`. That file inlines the full checklist (keyboard, ARIA, focus, forms, images, motion) — do not defer to other skills or external docs.

The five load-bearing defaults:

1. **Keyboard**: prefer `<button>` over `<div role="button">`. If you must use a custom element, implement Enter + Space + focus ring.
2. **ARIA labels**: label interactive elements without visible text (`aria-label="Close dialog"` on an icon-only button).
3. **Focus management**: move focus into dialogs on open; return focus to trigger on close.
4. **Meaningful empty / error / loading states**: never ship a blank screen.
5. **Contrast**: 4.5:1 normal / 3:1 large — enforce at the token level, not per component.

See the full checklist in `references/accessibility-checklist.md` before marking the pass done.

## Responsive pass

Design mobile-first, then expand. Test at the four canonical breakpoints: **320px, 768px, 1024px, 1440px**.

```tsx
<div className="
  grid grid-cols-1   /* Mobile: single column */
  sm:grid-cols-2     /* Small:  2 columns */
  lg:grid-cols-3     /* Large:  3 columns */
  gap-4
">
```

At each breakpoint: does the layout reflow without horizontal scroll, overflow, or clipped content? If not, fix before moving on.

## Loading and transitions

### Skeletons, not spinners, for content

```tsx
function TaskListSkeleton() {
  return (
    <div className="space-y-3" aria-busy="true" aria-label="Loading tasks">
      {Array.from({ length: 3 }).map((_, i) => (
        <div key={i} className="h-12 bg-muted animate-pulse rounded" />
      ))}
    </div>
  );
}
```

### Optimistic updates with rollback

When a mutation has a clearly predictable outcome (toggle, like, delete), apply the change immediately and roll back on error.

```tsx
function useToggleTask() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: toggleTask,
    onMutate: async (taskId) => {
      await queryClient.cancelQueries({ queryKey: ['tasks'] });
      const previous = queryClient.getQueryData(['tasks']);

      queryClient.setQueryData(['tasks'], (old: Task[]) =>
        old.map(t => t.id === taskId ? { ...t, done: !t.done } : t)
      );

      return { previous };
    },
    onError: (_err, _taskId, context) => {
      queryClient.setQueryData(['tasks'], context?.previous);
    },
  });
}
```

## Authoring checklist (exit criterion)

Before marking a UI slice done, confirm every box:

- [ ] `SIMPLICITY CHECK` emitted and honored.
- [ ] State at the lowest tier that works.
- [ ] Composed from small focused components.
- [ ] Colocated folder layout.
- [ ] Anti-AI-aesthetic table run — no row describes the draft.
- [ ] Accessibility checklist run.
- [ ] Responsive at 320 / 768 / 1024 / 1440.
- [ ] Loading, empty, and error states all handled.
- [ ] No off-scale spacing, arbitrary px values, or inline styles.
- [ ] No `NOTICED BUT NOT TOUCHING` observations silently fixed.

If any box is unchecked, the slice is not done. Fix the gap or split the slice.

## Integration with other skills

- **Upstream**: can be invoked standalone, or after a planning step (`kramme:siw:generate-phases`) where a phase involves UI work.
- **Sibling authoring**: pairs with `kramme:code:incremental` — each UI slice obeys the six-rule increment loop; this skill adds the UI-specific passes on top.
- **Sibling authoring**: pair with `kramme:code:source-driven` when the UI slice depends on framework-specific APIs, component-library behavior, or recently changed browser/runtime semantics. This skill owns UI structure, accessibility, and visual defaults; `source-driven` owns official-doc grounding and citation.
- **Downstream reviewers**: `kramme:pr:ux-review`, the `kramme:a11y-auditor` agent, and the `kramme:deslop-reviewer` agent all check, post-hoc, for violations of the same defaults this skill prevents. If a reviewer flags one of the 9 AI-aesthetic patterns, the canonical fix lives in this skill's anti-pattern table.

---

## Common Rationalizations

These are the lies you will tell yourself to justify shipping AI-default UI. Each one has a correct response:

- *"Accessibility is a nice-to-have."* → It's a legal requirement in many jurisdictions and a baseline quality standard. Run the a11y checklist.
- *"We'll make it responsive later."* → Retrofitting responsive design is roughly 3× harder than building it from the start. Do the responsive pass now.
- *"The design isn't final, so I'll skip styling."* → Use the design-system defaults. Unstyled UI creates a broken first impression that drives review churn.
- *"This is just a prototype."* → Prototypes ship. Build the foundation right the first time.
- *"The AI aesthetic is fine for now."* → It signals low quality. Use the project's actual palette and radius tokens from the first draft.
- *"Purple is the brand color."* → Check the palette before assuming. AI defaults to purple independent of any brand; verify against the design system, not memory.
- *"One more `rounded-2xl` won't hurt."* → Consistent radius per surface tier is the point. Pick intentionally per tier.

## Red Flags

If you notice any of these in your draft, stop and re-author:

- Components with more than 200 lines (split them).
- Inline styles or arbitrary pixel values.
- Missing error state, loading state, or empty state.
- No keyboard navigation verification.
- Color as the sole indicator of state (red/green without text or icon).
- Generic "AI look" — purple gradients, oversized cards, stock card grids, heavy shadows.
- `any` typing on props or event handlers.
- Copy that reads as AI-generated (placeholder-flavored, generic, or context-free).

## Verification

Before declaring the UI slice done, self-check:

- Does the component render without console errors or warnings?
- Can you Tab through every interactive element and reach the same targets a mouse user can?
- Does a screen reader convey the content structure (landmarks, headings, labels)?
- Does the layout hold at 320 / 768 / 1024 / 1440 without horizontal scroll?
- Are loading, empty, and error states all handled (not blank screens)?
- Does the draft follow the project's spacing, color, and typography tokens — no off-scale values?
- Any axe-core / dev-tools a11y warnings?
- Would a reviewer running `kramme:pr:ux-review` or the `kramme:deslop-reviewer` agent flag any row of the anti-AI-aesthetic table?

If any answer is no, finish the gap before declaring done.
