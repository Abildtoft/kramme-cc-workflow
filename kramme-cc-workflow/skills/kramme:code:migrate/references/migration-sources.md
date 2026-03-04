# Migration Sources Reference

Official migration guide URLs and search strategies per framework.

## Angular
- **Update guide:** https://update.angular.dev/ (interactive, select versions)
- **CLI:** `ng update @angular/core @angular/cli`
- **Blog:** https://blog.angular.dev/
- **Search:** `angular {current} to {target} update guide site:angular.dev`

## React
- **Blog:** https://react.dev/blog (major versions have upgrade guides)
- **Codemods:** https://github.com/reactjs/react-codemod
- **Search:** `react {target} upgrade guide site:react.dev`

## Next.js
- **Guide:** https://nextjs.org/docs/upgrading
- **Codemods:** `npx @next/codemod@latest` (interactive)
- **Search:** `next.js {current} to {target} upgrade guide site:nextjs.org`

## Vue
- **Vue 2→3:** https://v3-migration.vuejs.org/
- **Compat build:** `@vue/compat` for incremental migration
- **Search:** `vue {current} to {target} migration guide site:vuejs.org`

## TypeScript
- **Release notes:** https://www.typescriptlang.org/docs/handbook/release-notes/overview.html
- **Per-version:** `https://www.typescriptlang.org/docs/handbook/release-notes/typescript-{target}.html`
- **Search:** `typescript {target} breaking changes site:typescriptlang.org`

## Node.js
- **Blog:** https://nodejs.org/en/blog
- **Changelog:** https://github.com/nodejs/node/blob/main/CHANGELOG.md
- **Search:** `node.js {current} to {target} migration breaking changes`

## Python
- **What's New:** `https://docs.python.org/3/whatsnew/{target}.html`
- **Tools:** `pyupgrade`, `ruff` version-specific rules
- **Search:** `python {current} to {target} migration guide site:docs.python.org`

## .NET
- **Guide:** `https://learn.microsoft.com/en-us/dotnet/core/compatibility/{target}`
- **Tool:** `dotnet tool install -g upgrade-assistant` → `upgrade-assistant upgrade <project>`
- **Search:** `.NET {current} to {target} migration guide site:learn.microsoft.com`

## Rust
- **Edition guide:** https://doc.rust-lang.org/edition-guide/
- **Migration:** `cargo fix --edition`
- **Search:** `rust {current} to {target} edition migration`

## Go
- **Release notes:** `https://go.dev/doc/go{target}`
- **Search:** `go {current} to {target} release notes site:go.dev`

## General Fallback

1. `{framework} {target} migration guide site:{official-domain}`
2. `{framework} v{target} release site:github.com`
3. `{framework} changelog breaking changes {target}`
4. `{framework} upgrade {current} to {target} guide {year}`
