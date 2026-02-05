# Code Quality Checklist

Reference checklist for code quality reviews. Covers error handling, performance, and boundary conditions.

---

## Error Handling

### Core Principles

1. **Silent failures are unacceptable** - Any error without proper logging and user feedback is a critical defect
2. **Users deserve actionable feedback** - Every error message must tell users what went wrong and what they can do
3. **Fallbacks must be explicit and justified** - Falling back without user awareness is hiding problems
4. **Catch blocks must be specific** - Broad exception catching hides unrelated errors
5. **Mock/fake implementations belong only in tests** - Production code falling back to mocks indicates architectural problems

### Anti-Patterns to Flag

- **Swallowed Exceptions** - Empty catch blocks or catch with only logging
- **Overly Broad Catch** - Catching `Exception`/`Error` base class instead of specific types
- **Information Leakage** - Stack traces or internal details exposed to users
- **Missing Error Handling** - No try-catch around fallible operations (I/O, network, parsing)
- **Async Error Handling** - Unhandled promise rejections, missing `.catch()`, no error boundary

### Hidden Failure Patterns

- Empty catch blocks (absolutely forbidden)
- Catch blocks that only log and continue
- Returning null/undefined/default values on error without logging
- Using optional chaining (?.) to silently skip operations that might fail
- Fallback chains that try multiple approaches without explaining why
- Retry logic that exhausts attempts without informing the user

### Scrutinize Each Error Handler

**Logging Quality:**
- Is the error logged with appropriate severity?
- Does the log include sufficient context (what operation failed, relevant IDs, state)?
- Is there an error ID for tracking (e.g., Sentry)?
- Would this log help someone debug the issue 6 months from now?

**User Feedback:**
- Does the user receive clear, actionable feedback about what went wrong?
- Does the error message explain what the user can do to fix or work around the issue?
- Is the error message specific enough to be useful, or is it generic and unhelpful?
- Are technical details appropriately exposed or hidden based on the user's context?

**Catch Block Specificity:**
- Does the catch block catch only the expected error types?
- Could this catch block accidentally suppress unrelated errors?
- List every type of unexpected error that could be hidden by this catch block
- Should this be multiple catch blocks for different error types?

**Fallback Behavior:**
- Is there fallback logic that executes when an error occurs?
- Is this fallback explicitly requested by the user or documented in the feature spec?
- Does the fallback behavior mask the underlying problem?
- Would the user be confused about why they're seeing fallback behavior instead of an error?
- Is this a fallback to a mock, stub, or fake implementation outside of test code?

**Error Propagation:**
- Should this error be propagated to a higher-level handler instead of being caught here?
- Is the error being swallowed when it should bubble up?
- Does catching here prevent proper cleanup or resource management?

### Error Message Quality

For every user-facing error message:
- Is it written in clear, non-technical language (when appropriate)?
- Does it explain what went wrong in terms the user understands?
- Does it provide actionable next steps?
- Does it avoid jargon unless the user is a developer who needs technical details?
- Is it specific enough to distinguish this error from similar errors?
- Does it include relevant context (file names, operation names, etc.)?

### Questions to Ask

- "What happens when this operation fails?"
- "Will the caller know something went wrong?"
- "Is there enough context to debug this error?"

---

## Performance & Caching

### Algorithmic Complexity

- Identify time complexity (Big O notation) for all algorithms
- Flag any O(n²) or worse patterns without clear justification
- Consider best, average, and worst-case scenarios
- Analyze space complexity and memory allocation patterns
- Project performance at 10x, 100x, and 1000x current data volumes

### CPU-Intensive Operations

- **Hot Path Expenses** - Regex compilation, JSON parsing, crypto in loops
- **Blocking Main Thread** - Sync I/O, heavy computation without worker/async
- **Unnecessary Recomputation** - Same calculation done multiple times
- **Missing Memoization** - Pure functions called repeatedly with same inputs

### Database & I/O

- **N+1 Queries** - Loop that makes a query per item instead of batch
- **Missing Indexes** - Queries on unindexed columns
- **Over-Fetching** - SELECT * when only few columns needed
- **No Pagination** - Loading entire dataset into memory
- **Missing includes/joins** - Extra queries that could be avoided with eager loading
- Analyze query execution plans when possible

### Memory Management

- **Unbounded Collections** - Arrays/maps that grow without limit
- **Large Object Retention** - Holding references preventing GC
- **String Concatenation in Loops** - Use StringBuilder/join instead
- **Loading Large Files** - Use streaming instead of reading entire file
- Identify potential memory leaks
- Verify proper cleanup and garbage collection
- Monitor for memory bloat in long-running processes

### Caching

- **Missing Cache** - Repeated API calls, DB queries, computations uncached
- **No TTL** - Stale data served indefinitely
- **No Invalidation** - Data updated but cache not cleared
- **Key Collisions** - Insufficient cache key uniqueness
- **Global User Data** - User-specific data cached globally (security issue)
- Recommend appropriate caching layers (application, database, CDN)
- Consider cache hit rates and warming strategies

### Network Optimization

- Minimize API round trips
- Recommend request batching where appropriate
- Analyze payload sizes
- Check for unnecessary data fetching
- Optimize for mobile and low-bandwidth scenarios

### Frontend Performance

- Analyze bundle size impact of new code
- Check for render-blocking resources
- Identify opportunities for lazy loading
- Verify efficient DOM manipulation
- Monitor JavaScript execution time

### Performance Benchmarks

Enforce these standards:
- No algorithms worse than O(n log n) without explicit justification
- All database queries must use appropriate indexes
- Memory usage must be bounded and predictable
- API response times must stay under 200ms for standard operations
- Bundle size increases should remain under 5KB per feature
- Background jobs should process items in batches when dealing with collections

### Questions to Ask

- "What's the time complexity of this operation?"
- "How does this behave with 10x/100x data?"
- "Is this result cacheable? Should it be?"
- "Can this be batched instead of one-by-one?"

---

## Boundary Conditions

### Null/Undefined Handling

- **Missing Null Checks** - Accessing properties on potentially null objects
- **Truthy/Falsy Confusion** - `if (value)` when `0` or `""` are valid
- **Optional Chaining Overuse** - `a?.b?.c?.d` hiding structural issues
- **Null vs Undefined Inconsistency** - Mixed usage without clear convention

### Empty Collections

- **Empty Array Not Handled** - Code assumes array has items
- **Empty Object Edge Case** - `for...in` or `Object.keys` on empty object
- **First/Last Element Access** - `arr[0]` or `arr[arr.length-1]` without length check

### Numeric Boundaries

- **Division by Zero** - Missing check before division
- **Integer Overflow** - Large numbers exceeding safe integer range
- **Floating Point Comparison** - Using `===` instead of epsilon comparison
- **Negative Values** - Index or count that shouldn't be negative
- **Off-by-One Errors** - Loop bounds, array slicing, pagination

### String Boundaries

- **Empty String** - Not handled as edge case
- **Whitespace-Only String** - Passes truthy check but is effectively empty
- **Very Long Strings** - No length limits causing memory/display issues
- **Unicode Edge Cases** - Emoji, RTL text, combining characters

### Questions to Ask

- "What if this is null/undefined?"
- "What if this collection is empty?"
- "What's the valid range for this number?"
- "What happens at the boundaries (0, -1, MAX_INT)?"
