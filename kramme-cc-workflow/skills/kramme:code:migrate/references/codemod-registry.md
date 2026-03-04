# Codemod Registry

Known codemod tools and automated migration utilities.

## General-Purpose Tools

### jscodeshift
- **Install:** `npm install -g jscodeshift`
- **Usage:** `jscodeshift -t <transform.js> <path>`
- **What:** AST-based JavaScript/TypeScript transformations
- **Used by:** React codemods, many community codemods

### grit
- **Install:** `curl -fsSL https://docs.grit.io/install | bash`
- **Usage:** `grit apply <pattern>`
- **What:** Pattern-based code transformations using GritQL

### ast-grep
- **Install:** `npm install -g @ast-grep/cli`
- **Usage:** `ast-grep --pattern '<old>' --rewrite '<new>' <path>`
- **What:** Structural search and replace across languages

### comby
- **Install:** `brew install comby` or `pip install comby`
- **Usage:** `comby '<old>' '<new>' -d <path>`
- **What:** Structural code search and replace

## Framework-Specific

### Angular (ng update)
- **Usage:** `ng update @angular/core @angular/cli`
- **What:** Runs Angular-specific schematics for version migrations
- **Transforms:** config files, deprecated API usage, template syntax

### React Codemods
- **Repo:** https://github.com/reactjs/react-codemod
- **Usage:** `npx react-codemod <codemod-name> <path>`
- **Key codemods:** `rename-unsafe-lifecycles`, `update-react-imports`, `error-boundaries`

### Next.js Codemods
- **Usage:** `npx @next/codemod@latest` (interactive) or `npx @next/codemod <name> <path>`
- **Key codemods:** `app-dir-relative-links`, `next-image-to-legacy-image`, `new-link`

### Vue Codemods
- **Repo:** https://github.com/vuejs/vue-codemod
- **Usage:** `npx vue-codemod <path> -t <transform>`
- **What:** Vue 2 → Vue 3 transformations

### pyupgrade
- **Install:** `pip install pyupgrade`
- **Usage:** `pyupgrade --py{version}-plus <file>`
- **What:** Upgrades Python syntax to newer version patterns

### cargo fix
- **Usage:** `cargo fix --edition`
- **What:** Applies Rust edition migration fixes automatically

### .NET Upgrade Assistant
- **Install:** `dotnet tool install -g upgrade-assistant`
- **Usage:** `upgrade-assistant upgrade <project>`
- **What:** Upgrades .NET project files, NuGet packages, and code patterns
