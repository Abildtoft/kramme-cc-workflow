# AI Slop Patterns

Reference for detecting AI-generated code patterns ("slop") that reduce code quality.

## 1. Unnecessary Comments

Comments that describe what the code already says:

```typescript
// BAD - Comment describes obvious code
// Get the user by ID from the database
const user = await db.getUserById(id);
// Check if user exists
if (!user) {
  // Throw error if not found
  throw new NotFoundError('User not found');
}

// GOOD - No redundant comments needed
const user = await db.getUserById(id);
if (!user) {
  throw new NotFoundError('User not found');
}
```

**Signs:**
- Comments that repeat the code
- JSDoc with trivial descriptions
- Inconsistent comment style vs. rest of file

## 2. Defensive Overkill

Unnecessary validation on trusted inputs:

```typescript
// BAD - Input is already validated by the type system and caller
function processValidatedInput(input: ValidatedInput) {
  if (!input) throw new Error('Input required');
  if (typeof input.value !== 'string') throw new Error('Invalid type');
  // ...
}

// GOOD - Trust the type system
function processValidatedInput(input: ValidatedInput) {
  // ValidatedInput guarantees these properties exist
  // ...
}
```

**Signs:**
- Try-catch around code that cannot throw
- Null checks on guaranteed non-null values
- Type guards on already-typed values
- Multiple layers of the same defensive check

## 3. Type Workarounds

Casts to silence errors instead of fixing them:

```typescript
// BAD - Using any to bypass type safety
const data = response.body as any;
const items = (data as unknown as ItemList).items;

// GOOD - Define proper types
interface ApiResponse {
  body: ItemList;
}
const items = response.body.items;
```

**Signs:**
- `any` casts without justification
- `// @ts-ignore` or `// @ts-expect-error`
- `as unknown as X` chains
- Overly broad types when specific types exist

## 4. Style Inconsistencies

Code that doesn't match the file's established patterns:

**Signs:**
- Different naming conventions than surrounding code
- Different error handling patterns
- Inconsistent async/await vs promises
- Different formatting or structure

## 5. Over-Engineering

Abstractions for things that don't need them:

```typescript
// BAD - Unnecessary abstraction for one-time use
const userNameGetter = createPropertyGetter<User, 'name'>('name');
const userName = userNameGetter(user);

// GOOD - Just access the property
const userName = user.name;
```

**Signs:**
- Abstractions for single use cases
- Generic solutions for specific problems
- Configuration for things that won't change
- Wrapper functions that add no value

## 6. Verbose Alternatives

Long-form code where concise patterns are standard:

```typescript
// BAD - Verbose when destructuring is idiomatic
const name = props.name;
const age = props.age;
const email = props.email;

// GOOD - Use destructuring
const { name, age, email } = props;
```

**Signs:**
- Multiple lines where concise patterns exist
- Explicit type annotations where inference is standard
- Long-form syntax when shorthand is idiomatic

## 7. Excessive Logging

Debug statements that shouldn't be in production:

```typescript
// BAD - Debug logging in production code
console.log('Processing user:', user);
console.log('Result:', result);

// GOOD - Use proper logging infrastructure
logger.debug('Processing user', { userId: user.id });
```

**Signs:**
- `console.log` in production code
- Verbose logging that clutters output
- Logging sensitive data or large objects

## 8. Copy-Paste Artifacts

Evidence of copying without cleaning up:

**Signs:**
- Nearly identical code blocks with minor variations
- Inconsistent variable names from copy errors
- Commented-out alternative implementations
- TODO comments referencing AI interactions

---

## Detection Guidelines

1. **Context matters** - A pattern that's slop in one codebase might be standard in another
2. **Compare to existing style** - The file's existing patterns are the source of truth
3. **Don't over-flag** - Focus on clear patterns, not borderline cases
4. **Preserve legitimate code** - Some situations genuinely need extra caution
