# Packing Strategies

Three strategies for turning a list of needed artifacts into a context load plan. Pick one per task. Mixing strategies mid-task is usually a sign of drift — if you find yourself switching, re-run setup and commit to one.

## Brain Dump

Load everything the task might plausibly need at the start, then let the agent sift.

**When to choose:**

- The task shape is fuzzy — you don't yet know which file will be load-bearing.
- The cost of missing one file is high (e.g. the missing file is the one that encodes the invariant the task depends on).
- The relevant surface is small enough that "everything" still fits under ~2,000 lines.

**When not to choose:**

- The task is well-scoped and you can name the four L3 artifacts up front.
- The relevant surface is large and "everything" would blow past ~5,000 lines.

**Example:**

Debugging a test that fails intermittently. You don't yet know whether it's a race, a fixture, or a dependency. Load the test, the code under test, the fixture setup, and the most recent related failures in one pass, and let the agent correlate.

## Selective Include

Load only what the task explicitly demands. Nothing speculative.

**When to choose:**

- The task shape is tight — you can name the exact files and their roles.
- The attention budget is scarce (the conversation is already long, or the task requires careful reasoning over a specific contract).
- You are iterating on something previously loaded and only need the delta.

**When not to choose:**

- The task is exploratory or the file set is uncertain.
- Related files would materially change the implementation (e.g. an adjacent test encodes an edge case you'd otherwise miss).

**Example:**

Renaming a function and updating its two call sites. Load the function's file, the two call sites, and the type definition. Nothing else. A broader load dilutes attention without adding signal.

## Hierarchical Summary

Load a summary first, pull full content on demand.

**When to choose:**

- The change is wide but shallow — many files touched, each lightly.
- Full detail upfront would blow the attention budget, but a summary is enough to pick the next file to deep-read.
- The task is a refactor, migration, or audit across many similar units.

**When not to choose:**

- The task requires deep reasoning about one unit — summaries lose the details that matter.
- No summary exists and generating one would cost more than just loading the files.

**Example:**

Migrating 40 files from one logging library to another. Load a one-line summary per file (current logger usage), then deep-read the handful that use non-trivial patterns. The remaining 35 are mechanical and don't need full context.

## Choosing under uncertainty

If unsure, default to **Selective Include** and expand as needed. It keeps the attention budget tight and makes each subsequent addition a conscious choice. Brain Dump and Hierarchical Summary are specialized tools; reach for them when Selective Include is visibly failing (grep-loops, repeated re-asks, hallucinated paths).
