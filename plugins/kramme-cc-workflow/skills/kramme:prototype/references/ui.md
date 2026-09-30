# UI Prototype

Use this branch when the question is about visual structure, information hierarchy, page layout, component direction, or interaction feel. A useful UI prototype shows meaningfully different variants in the real product context whenever possible.

## Process

1. State the UI question and variant count.
   - Default to three variants.
   - Cap at five variants unless the user gives a specific reason.
   - Define what decision the variants should make easier: layout, hierarchy, density, navigation, interaction model, or content treatment.

2. Prefer an existing host surface.
   - Mount variants inside the existing page, route, panel, or component when one exists.
   - Keep the host page's permissions, layout shell, navigation, and development-safe data context in place.
   - Create a new throwaway route only when there is no plausible existing host.
   - Stop and ask before mounting in an existing production route if the host project has no safe local, dev-only, internal-flagged, or otherwise non-production experiment convention.

3. Make variants genuinely different.
   - Vary layout, hierarchy, primary action placement, density, or flow.
   - Do not count color-only, copy-only, spacing-only, or card-grid-only tweaks as separate variants.
   - Use the project's existing styling system, component library, icons, and responsive conventions.

4. Add a temporary variant switcher.
   - Use a URL parameter such as `?variant=A` when the framework supports it.
   - Make the current variant visible.
   - Support a direct URL for each variant so feedback can name exactly what was reviewed.
   - Gate both the variant rendering path and prototype-only UI out of production builds when the host framework has an environment check.
   - Do not leave `?variant=` rendering reachable in production just because the switcher itself is hidden.

5. Keep mutations fake or isolated.
   - Prefer read-only prototypes.
   - If an interaction must mutate state, use in-memory or stubbed data.
   - Do not trigger real writes, external sends, billing actions, destructive operations, production analytics, or real customer-data access from a UI prototype.

6. Hand off with the URL and cleanup rule.
   - Give the user the route and variant keys.
   - Capture which variant or combination answered the question and why.
   - Delete all current-run prototype UI artifacts after the answer is captured, including winning and losing variants, switchers, `?variant=` rendering, prototype routes, and scratch data.
   - Ask before deleting or replacing any pre-existing or resumed prototype route, variant, switcher, command, or fixture store. If the user is unavailable, leave an exact cleanup note instead.
   - If the chosen direction should become production UI, stop with a handoff note. Rebuild it only after an explicit follow-up request using the normal implementation workflow.

## Anti-Patterns

- Shipping the prototype switcher or variant controls.
- Sharing so much layout code that variants stop testing different ideas.
- Creating an isolated empty route when the design depends on surrounding product context.
- Treating the chosen variant as production-ready without normal accessibility, responsiveness, error-state, and test work.
