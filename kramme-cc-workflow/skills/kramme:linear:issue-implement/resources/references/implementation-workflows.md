# Implementation Workflows

Three workflow options based on user's selected approach.

## Guided Implementation (Option 1)

**Goal:** Create detailed plan, implement with user verification at each step.

1. **Create Implementation Plan**

   - Break requirements into discrete tasks
   - Identify dependencies between tasks
   - Consider using Structured Implementation Workflow (SIW) for complex issues - use `/kramme:siw:init` to set up

2. **Create Todo List**

   Use TodoWrite with tasks from the plan:

   ```
   - Analyze existing patterns for {feature area}
   - Implement {task 1 from requirements}
   - Add tests for {task 1}
   - Implement {task 2 from requirements}
   - ...
   - Run verification (kramme:verify:run)
   ```

3. **Begin Implementation**
   - Work through tasks one at a time
   - **ALWAYS** ask user to review after completing each task
   - Update todo list as tasks complete

## Context Setup Only (Option 2)

**Goal:** Prepare everything, let user drive implementation.

1. **Create Minimal Context**

   - Branch is already created (Step 2)
   - Create todo list from extracted requirements

2. **Use TodoWrite for Requirements**

   Create tasks from acceptance criteria:

   ```
   - [ ] {Acceptance criterion 1}
   - [ ] {Acceptance criterion 2}
   - [ ] {Requirement from description}
   - [ ] Verify implementation meets requirements
   - [ ] Run verification checks
   ```

3. **Provide Starting Points**

   ```
   Context is set up. Here's where to start:

   Branch: {branchName}
   Linear Issue: {url}

   Likely affected areas based on requirements:
   - {file/module 1} - {why}
   - {file/module 2} - {why}

   Similar implementations to reference:
   - {existing feature 1} - {relevance}

   Ready when you want to begin. Just tell me what to work on.
   ```

## Autonomous Implementation (Option 3)

**Goal:** Complete implementation with minimal interaction, verify at end.

1. **Deep Codebase Analysis**

   - Search for related files using Glob and Grep
   - Read similar implementations for patterns
   - Identify all files that need modification
   - Understand testing patterns in the codebase

2. **Create Comprehensive Plan**

   - Use TodoWrite with detailed task breakdown
   - Include exploration, implementation, testing, and verification

3. **Implement Iteratively**

   - Work through all tasks
   - Make implementation decisions based on existing patterns
   - Run tests after each significant change
   - Document decisions in commit messages

4. **Verification Phase**

   - Invoke `kramme:verify:run` skill for full verification
   - Fix any issues found
   - Ensure all acceptance criteria are met

5. **Present Results**

   ```
   Implementation Complete

   Linear Issue: {identifier}
   Branch: {branchName}

   Changes Made:
   - {summary of changes}

   Files Modified:
   - {list of key files}

   Verification Results:
   - Tests: {status}
   - Lint: {status}
   - Build: {status}

   Acceptance Criteria:
   - [x] {criterion 1}
   - [x] {criterion 2}

   Ready for your review. Run `/kramme:pr:create` when ready to submit.
   ```
