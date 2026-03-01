# Common Breaking Change Patterns

Frequently encountered breaking change patterns across frameworks.

## 1. API Renaming

**What:** Function, class, or method renamed.
**Detect:** Grep for the old name.
**Fix:** Find-and-replace old name → new name. Check imports too.
**Example:** React `componentWillMount` → `UNSAFE_componentWillMount` → removed.

## 2. Import Path Changes

**What:** Module moved to a different package or path.
**Detect:** Grep for the old import path.
**Fix:** Update import statements to new paths.
**Example:** `@angular/http` → `@angular/common/http`.

## 3. Configuration Format Changes

**What:** Config file format or schema changed.
**Detect:** Read the old config file, compare against new schema docs.
**Fix:** Rewrite config to new format, often manually.
**Example:** `webpack.config.js` → `vite.config.ts`, Jest `globals` → `@jest/globals`.

## 4. Removed Features

**What:** Feature or API removed entirely with no direct replacement.
**Detect:** Grep for removed API names.
**Fix:** Rewrite using recommended alternative approach.
**Example:** React class component `mixins` → composition, hooks.

## 5. Default Behavior Changes

**What:** Existing API's default behavior changed (opt-in → opt-out or vice versa).
**Detect:** Hard to grep — look for the API name and check if explicit flags are needed.
**Fix:** Add explicit opt-in/out flags where defaults changed.
**Example:** Next.js `<Link>` no longer requires `<a>` child.

## 6. Type Signature Changes

**What:** Function parameter types, return types, or generic constraints changed.
**Detect:** TypeScript compiler errors after updating. Grep for the function name.
**Fix:** Update call sites and type annotations.
**Example:** Stricter TypeScript `strict` mode defaults.

## 7. CJS → ESM Migration

**What:** Package switches from CommonJS to ES Modules.
**Detect:** `require()` calls to the updated package fail.
**Fix:** Convert `require()` to `import`, update `package.json` `type` field, rename `.js` to `.mjs` if needed.
**Example:** Many packages now ship ESM-only (chalk, etc.).

## 8. Runtime Requirement Changes

**What:** Minimum Node.js, Python, or runtime version bumped.
**Detect:** Check `engines` field in `package.json`, or framework docs.
**Fix:** Update runtime version in `.nvmrc`, CI config, deploy config.
**Example:** Angular 19 requires Node 18.19+.

## 9. Peer Dependency Conflicts

**What:** Updated package requires different peer dependency versions than other packages.
**Detect:** Install errors listing peer dependency conflicts.
**Fix:** Update conflicting packages together, or use `--legacy-peer-deps` temporarily.
**Example:** Updating React 18 → 19 may conflict with older `react-dom` or third-party components.

## 10. Build Output Changes

**What:** Build output format, directory structure, or file names changed.
**Detect:** Build succeeds but deployment or imports fail.
**Fix:** Update references to build output paths in CI, deploy scripts, or downstream imports.
**Example:** Vite `dist/` structure differs from Webpack `build/`.
