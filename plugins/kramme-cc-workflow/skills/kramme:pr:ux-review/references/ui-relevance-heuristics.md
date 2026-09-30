# UI Relevance Heuristics

Canonical path contract for deciding whether UX review and diff-aware QA are applicable.

UI relevance path contract: `ui-relevance-path-contract-v1`

## Path Rules

A change is UI-relevant when any changed file matches one of these categories:

- **Components**: `*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.astro`, `*.mdx`, `*.component.ts`, `*.component.html`
- **Templates**: `*.html`, `*.htm`, `*.hbs`, `*.ejs`, `*.pug`
- **Styles**: `*.css`, `*.scss`, `*.sass`, `*.less`, `*.styl`, `*.styled.ts`, `*.styled.js`, `*.module.css`, `*.module.scss`
- **Configuration**: `tailwind.config.*`, `theme.*`, files under `design-tokens/`
- **View and route directories**: files under `pages/`, `views/`, `screens/`, `routes/`, or `app/`
- **UI component directories**: files under `component/`, `components/`, `ui/`, `widgets/`, `layouts/`, or `templates/`
- **Style directories**: files under `styles/` or `css/`
- **Static asset directories**: image or SVG files under `public/`, `static/`, or `assets/` (`*.svg`, `*.png`, `*.jpg`, `*.jpeg`, `*.gif`, `*.webp`, `*.avif`, `*.ico`)

When no UI-relevant files are found, UX review and diff-aware QA are skipped with a note explaining why.

## Fixture Matrix

| Path | Expected | Rule |
| --- | --- | --- |
| `src/components/Button.tsx` | UI | Component extension and component directory |
| `app/dashboard/page.tsx` | UI | Route directory |
| `src/templates/card.hbs` | UI | Template extension |
| `src/styles/global.css` | UI | Style extension and style directory |
| `src/App.TSX` | UI | Component extension, matched case-insensitively |
| `src/Page.astro` | UI | Astro component/page extension |
| `docs/component.mdx` | UI | MDX component documentation extension |
| `public/index.htm` | UI | HTML template extension |
| `src/styles/theme.styl` | UI | Stylus style extension |
| `src/ui/Button.ts` | UI | UI directory |
| `src/component/Button.ts` | UI | Singular component directory |
| `theme.colors.ts` | UI | Theme configuration file |
| `tailwind.config.ts` | UI | Tailwind configuration file |
| `packages/ui/design-tokens/colors.json` | UI | Design token directory |
| `public/logo.svg` | UI | Static image asset |
| `public/Logo.SVG` | UI | Static image asset, matched case-insensitively |
| `static/hero.webp` | UI | Static image asset |
| `src/assets/data.json` | Non-UI | Static asset directory with non-image data |
| `src/server/user.ts` | Non-UI | Backend code outside UI paths |
| `docs/button-guidelines.md` | Non-UI | Documentation-only path |
| `package.json` | Non-UI | Package metadata only |
