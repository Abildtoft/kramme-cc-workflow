# Framework-Specific QA Hints

Common issues to check based on the detected framework. Detect the framework from `package.json` dependencies or project structure.

## Next.js

- **Hydration errors**: Check console for `Hydration failed`, `Text content did not match`, `Expected server HTML to contain`. These indicate SSR/client mismatch.
- **Data fetching**: Monitor `_next/data` requests in network — 404s indicate broken data fetching or stale build.
- **Client-side navigation**: Test by clicking links (not just navigating via URL) to catch client-side routing issues.
- **Layout shift**: Watch for CLS on pages with dynamic content or async data loading.
- **Image optimization**: Check for `next/image` warnings in console and broken image fallbacks.

## React (Vite / CRA)

- **Stale state**: Navigate away and back — does data refresh or show stale values?
- **History handling**: Test browser back/forward — does the app handle history correctly?
- **Error boundaries**: Trigger errors (invalid data, broken API) — does the app crash or show a fallback?
- **Key warnings**: Check console for `Each child in a list should have a unique "key" prop`.

## Angular

- **Zone.js errors**: Check console for `Error: ExpressionChangedAfterItHasBeenChecked` and similar zone-related errors.
- **Lazy loading**: Verify lazy-loaded routes load correctly, especially on first navigation.
- **Form validation**: Angular reactive forms can silently fail — test with empty, partial, and invalid data.
- **Change detection**: After interactions, verify the UI updates (not stuck with stale bindings).

## Vue / Nuxt

- **Reactivity warnings**: Check console for `[Vue warn]` messages indicating reactivity issues.
- **SSR hydration** (Nuxt): Same as Next.js — check for hydration mismatch warnings.
- **Teleport issues**: Modals and dropdowns using `<Teleport>` can render outside expected containers.
- **Transition bugs**: Page transitions can mask broken navigation — check the final state, not just the animation.

## Svelte / SvelteKit

- **SSR mismatches**: Similar to Next.js and Nuxt — check console for hydration warnings.
- **Load function errors**: Failed `load` functions can leave pages in a broken state without clear error UI.
- **Form actions**: Test SvelteKit form actions with both JS enabled and disabled.

## Rails (with Hotwire/Turbo)

- **Turbo frame errors**: Check console for frame-related errors when navigating within frames.
- **CSRF token**: Verify forms include CSRF token — missing tokens cause silent 422 errors.
- **Flash messages**: Check that flash messages appear and dismiss correctly after actions.
- **N+1 warnings**: In development mode, check console for N+1 query warnings.
- **Turbo stream updates**: After form submissions, verify the page updates without full reload.

## WordPress

- **Plugin conflicts**: JS errors from different plugins competing for the same DOM elements.
- **REST API**: Test `/wp-json/` endpoints — 403s may indicate permission issues.
- **Mixed content**: Common with WP — check for HTTP resources loaded on HTTPS pages.
- **Admin bar**: Verify it doesn't overlap content for logged-in users.

## General SPA (any framework)

- **Client-side routing**: Use `links` or `snapshot -i` to find navigation items — `links` misses client-side routes.
- **Memory leaks**: After extended interaction (navigate many pages, open/close modals), check if the app slows down.
- **Offline behavior**: If the app has a service worker, test with network throttling.
- **Deep linking**: Navigate directly to a deep URL (not from homepage) — does it work or require homepage context?
