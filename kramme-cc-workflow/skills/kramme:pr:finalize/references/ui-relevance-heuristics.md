# UI Relevance Heuristics

File patterns that indicate UI-relevant changes. Used to determine whether UX review and QA testing are applicable.

## File Extension Patterns

### Components
- `*.tsx`, `*.jsx` — React components
- `*.vue` — Vue components
- `*.svelte` — Svelte components
- `*.component.ts`, `*.component.html` — Angular components

### Templates
- `*.html` — HTML templates
- `*.hbs` — Handlebars templates
- `*.ejs` — EJS templates
- `*.pug` — Pug templates

### Styles
- `*.css`, `*.scss`, `*.sass`, `*.less` — Stylesheets
- `*.styled.ts`, `*.styled.js` — Styled components
- `*.module.css`, `*.module.scss` — CSS modules

### Configuration
- `tailwind.config.*` — Tailwind configuration
- `theme.*` — Theme files
- `**/design-tokens/**` — Design token files

## Directory Patterns

Files in these directories are considered UI-relevant regardless of extension:
- `pages/`, `views/`, `screens/` — Page/view files
- `routes/`, `app/` — Route definitions
- `components/`, `widgets/` — UI components
- `layouts/`, `templates/` — Layout files
- `styles/`, `css/` — Style directories
- `public/`, `static/`, `assets/` — Static assets (only if SVG or image files changed)

## Detection Logic

A change is considered UI-relevant if ANY changed file matches the extension patterns above or resides in a UI-relevant directory.

When no UI-relevant files are found, UX review and QA testing are skipped with a note explaining why.
