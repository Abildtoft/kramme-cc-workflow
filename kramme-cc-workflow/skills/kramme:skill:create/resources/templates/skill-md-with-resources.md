---
name: kramme:{domain}:{action}
description: "{TODO: 1-2 sentences in third person. Include negative trigger. Max 1024 chars.}"
argument-hint: "{TODO: argument format or remove this line}"
disable-model-invocation: {true|false}
user-invocable: {true|false}
---

# {Skill Title}

{TODO: Purpose statement and scope boundaries.}

## Input Handling

- `$ARGUMENTS` may contain {TODO: describe expected input}.
- If no arguments provided, ask the user via AskUserQuestion.

## Process

### Step 1: {Name}

{TODO: High-level step description in third-person imperative.}

### Step 2: {Name}

Read the {reference name} from `resources/references/{file}.md`.

{TODO: How to use the loaded content.}

### Step 3: {Name}

{TODO: Step description.}

## Error Handling

- {TODO: Error scenario 1} — {recovery action}
- {TODO: Error scenario 2} — {recovery action}

## Output

{TODO: Describe expected output format or result.}
