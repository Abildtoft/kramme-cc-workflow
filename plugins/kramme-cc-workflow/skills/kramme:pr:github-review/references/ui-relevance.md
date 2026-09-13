# UI relevance classification

Read this reference only when `CODE_ONLY` is false and the changed files need classification.

UI relevance path contract: `ui-relevance-path-contract-v1`

A file is UI-relevant when it matches any category:

- **Components**: `*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.astro`, `*.mdx`, `*.component.ts`, `*.component.html`
- **Templates**: `*.html`, `*.htm`, `*.hbs`, `*.ejs`, `*.pug`
- **Styles**: `*.css`, `*.scss`, `*.sass`, `*.less`, `*.styl`, `*.styled.ts`, `*.styled.js`, `*.module.css`, `*.module.scss`
- **Configuration**: `tailwind.config.*`, `theme.*`, and files under `design-tokens/`
- **Views and routes**: files under `pages/`, `views/`, `screens/`, `routes/`, or `app/`
- **UI directories**: files under `component/`, `components/`, `ui/`, `widgets/`, `layouts/`, or `templates/`
- **Style directories**: files under `styles/` or `css/`
- **Static assets**: image files under `public/`, `static/`, or `assets/` (`*.svg`, `*.png`, `*.jpg`, `*.jpeg`, `*.gif`, `*.webp`, `*.avif`, `*.ico`)

Use this classifier against each newline-delimited path in `CHANGED_FILES`:

```bash
is_ui_relevant_path() {
  local path
  path=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')

  case "$path" in
    *.tsx | *.jsx | *.vue | *.svelte | *.astro | *.mdx | *.component.ts | *.component.html) return 0 ;;
    *.html | *.htm | *.hbs | *.ejs | *.pug) return 0 ;;
    *.css | *.scss | *.sass | *.less | *.styl | *.styled.ts | *.styled.js | *.module.css | *.module.scss) return 0 ;;
    tailwind.config.* | */tailwind.config.* | theme.* | */theme.* | design-tokens/* | */design-tokens/*) return 0 ;;
    pages/* | */pages/* | views/* | */views/* | screens/* | */screens/* | routes/* | */routes/* | app/* | */app/*) return 0 ;;
    component/* | */component/* | components/* | */components/* | ui/* | */ui/* | widgets/* | */widgets/* | layouts/* | */layouts/* | templates/* | */templates/*) return 0 ;;
    styles/* | */styles/* | css/* | */css/*) return 0 ;;
    public/*.svg | public/*.png | public/*.jpg | public/*.jpeg | public/*.gif | public/*.webp | public/*.avif | public/*.ico) return 0 ;;
    static/*.svg | static/*.png | static/*.jpg | static/*.jpeg | static/*.gif | static/*.webp | static/*.avif | static/*.ico) return 0 ;;
    assets/*.svg | assets/*.png | assets/*.jpg | assets/*.jpeg | assets/*.gif | assets/*.webp | assets/*.avif | assets/*.ico) return 0 ;;
    */public/*.svg | */public/*.png | */public/*.jpg | */public/*.jpeg | */public/*.gif | */public/*.webp | */public/*.avif | */public/*.ico) return 0 ;;
    */static/*.svg | */static/*.png | */static/*.jpg | */static/*.jpeg | */static/*.gif | */static/*.webp | */static/*.avif | */static/*.ico) return 0 ;;
    */assets/*.svg | */assets/*.png | */assets/*.jpg | */assets/*.jpeg | */assets/*.gif | */assets/*.webp | */assets/*.avif | */assets/*.ico) return 0 ;;
  esac
  return 1
}

RUN_UI=false
while IFS= read -r changed_file; do
  if is_ui_relevant_path "$changed_file"; then
    RUN_UI=true
    break
  fi
done <<< "$CHANGED_FILES"
```
