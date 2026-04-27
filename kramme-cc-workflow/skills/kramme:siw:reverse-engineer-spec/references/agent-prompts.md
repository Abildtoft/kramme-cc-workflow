Each agent receives its file list and a focused analysis prompt.

**Agent A: Core Implementation**

```
Analyze these files that form the core implementation of a feature.

Files: {file_list}

For each file, report:
1. **Purpose**: What this file does (1 sentence)
2. **Key exports**: Functions, classes, types exported
3. **Data flow**: What data comes in, what goes out
4. **Dependencies**: What this file imports/depends on
5. **Connections**: How it relates to other files in this group

After individual analysis, synthesize:
- **Problem being solved**: What user/business need does this code address?
- **Solution approach**: What architectural pattern or strategy is used?
- **Key abstractions**: What are the main concepts/entities?
- **Data model**: What are the core data structures?

{If branch diff mode, also provide:}
For files with diffs available, read the actual diff to understand what changed vs what existed before.
```

**Agent B: Integration Points**

```
Analyze these files that were modified to integrate a feature into an existing codebase.

Files: {file_list}

For each file, report:
1. **What changed**: Key modifications (not formatting/imports)
2. **Why (inferred)**: What the changes achieve
3. **API surface**: Any new/changed public APIs, routes, exports
4. **Breaking changes**: Anything that changes existing behavior

Synthesize:
- **Integration strategy**: How does the new code connect to existing code?
- **Touched boundaries**: What system boundaries were crossed?
- **Side effects**: Any changes to existing behavior?
```

**Agent C: Tests**

```
Analyze these test files to extract the product requirements they encode.

Files: {file_list}

For each test file, report:
1. **What it tests**: Module/component under test
2. **Key assertions**: What behaviors are validated
3. **Edge cases**: What boundary conditions are covered
4. **Missing coverage**: Obvious gaps (inferred from test structure)

Synthesize:
- **Product requirements**: What user-facing behaviors do these tests guarantee?
- **Acceptance criteria**: What conditions must hold for this feature to work?
- **Test coverage map**: Which components have tests, which don't?
```

**Agent D: Configuration & Infrastructure (if launched)**

```
Analyze these configuration and infrastructure files.

Files: {file_list}

For each file, report:
1. **Purpose**: What this config controls
2. **Key settings**: Important values and what they affect
3. **Feature flags**: Any gating mechanisms
4. **Environment concerns**: Different behavior per environment

Synthesize:
- **Rollout strategy**: How is this feature gated or rolled out?
- **Dependencies**: External services, packages, or tools required
- **Environment matrix**: What varies across environments?
```
