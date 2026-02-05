# Code Removal Plan Template

Template for safely removing code from the codebase. Use this to document and track removals.

## Removal Priority Tiers

### P0 - Immediate Removal
Security vulnerabilities, blocking issues, or code that must be removed now.

### P1 - Current Sprint
Dead code, deprecated features, or cleanup that should happen this sprint.

### P2 - Backlog
Technical debt items that can be addressed when convenient.

---

## Safe Removal Template

For code that can be removed immediately:

```markdown
### [Component/Feature Name]

**Location:** `path/to/file.ts:123-145`

**Rationale:** [Why this should be removed]

**Evidence of Non-Usage:**
- [ ] No imports found (`grep -r "import.*ComponentName"`)
- [ ] No references found (`grep -r "ComponentName"`)
- [ ] No dynamic references (`grep -r "['\""]ComponentName['\""]"`)
- [ ] Feature flag disabled/removed
- [ ] Telemetry shows zero usage (if applicable)

**Impact Assessment:**
- Affected files: [list]
- Affected tests: [list]
- Breaking changes: [none/list]

**Deletion Steps:**
1. Remove [specific files/code blocks]
2. Update [imports/exports]
3. Remove [associated tests]
4. Update [documentation]

**Verification:**
- [ ] Build passes
- [ ] Tests pass
- [ ] No runtime errors
```

---

## Deferred Removal Template

For code that requires phased removal:

```markdown
### [Component/Feature Name]

**Location:** `path/to/file.ts:123-145`

**Reason for Deferral:** [Why this can't be removed immediately]

**Preconditions:**
- [ ] [Condition 1 that must be met]
- [ ] [Condition 2 that must be met]

**Breaking Changes:**
- [List breaking changes for consumers]

**Migration Guide:**
1. [Step 1 for consumers to migrate]
2. [Step 2 for consumers to migrate]

**Timeline:**
- Deprecation notice: [date]
- Migration deadline: [date]
- Removal target: [date]

**Owner:** [team/person responsible]

**Success Metrics:**
- Usage drops to [threshold]
- All consumers migrated

**Recovery Plan:**
If removal causes issues:
1. [Rollback step 1]
2. [Rollback step 2]
```

---

## Pre-Removal Checklist

Before removing any code:

- [ ] **Search codebase for all references** - Use `grep`, `rg`, or IDE search
- [ ] **Check for dynamic references** - String-based imports, reflection, eval
- [ ] **Verify no external consumers** - Public APIs, exported modules
- [ ] **Review telemetry** - Feature flags, analytics, error tracking
- [ ] **Check configuration files** - May reference code by string
- [ ] **Update tests** - Remove or update affected tests
- [ ] **Update documentation** - Remove references from docs
- [ ] **Notify stakeholders** - For shared code, inform other teams

---

## Common Removal Scenarios

### Unused Imports
```bash
# Find unused imports (TypeScript)
npx ts-prune

# Remove unused imports
npx eslint --fix --rule 'unused-imports/no-unused-imports: error'
```

### Dead Feature Flags
1. Confirm flag is permanently off
2. Remove flag checks and dead branches
3. Remove flag from configuration
4. Remove associated A/B test code

### Deprecated Functions
1. Add deprecation warnings (if not already present)
2. Migrate all internal callers
3. Wait for external migration period
4. Remove function and deprecation warnings

### Unused Dependencies
```bash
# Find unused dependencies
npx depcheck

# Remove from package.json
npm uninstall <package>
```

---

## Verification Checklist

After removal:

- [ ] Build passes locally
- [ ] All tests pass
- [ ] No TypeScript/lint errors
- [ ] Application starts without errors
- [ ] Critical paths still work (manual or automated check)
- [ ] No console errors in browser (for frontend)
- [ ] CI pipeline passes
