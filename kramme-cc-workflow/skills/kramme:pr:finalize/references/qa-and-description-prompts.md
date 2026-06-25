# QA and Description Prompts

Use this during Step 9 and Step 13.

## Step 9: QA Testing

If `AUTO_MODE=true`, skip the prompt and run diff-aware QA:

```yaml
skill: "kramme:qa", args: "{APP_URL} diff-aware --base {BASE_BRANCH}"
```

Otherwise confirm with the user:

```yaml
header: "QA Testing"
question: "Run QA testing against {APP_URL}? A browser MCP enables live checks; otherwise QA falls back to code-only analysis."
options:
  - label: "Run QA quick"
    description: "Quick smoke test of changed UI areas"
  - label: "Run QA diff-aware"
    description: "Thorough test focused on changed files and their impact"
  - label: "Skip QA"
    description: "Skip QA testing for now"
multiSelect: false
```

- If "Skip QA": record as skipped and continue.
- If "Run QA quick":

  ```text
  skill: "kramme:qa", args: "{APP_URL} quick"
  ```

- If "Run QA diff-aware":

  ```text
  skill: "kramme:qa", args: "{APP_URL} diff-aware --base {BASE_BRANCH}"
  ```

Parse QA results for blockers, major issues, and minor issues.

## Step 13: PR Description

If verdict is **READY** or **READY WITH CAVEATS** and `AUTO_MODE=true`, run:

```yaml
skill: "kramme:pr:generate-description", args: "--auto --base {BASE_BRANCH}"
```

Otherwise ask:

```yaml
header: "PR Description"
question: "Generate or update PR description now?"
options:
  - label: "Generate and update"
    description: "Generate description and update the existing PR (if one exists)"
  - label: "Generate for review"
    description: "Generate description for review before applying"
  - label: "Skip"
    description: "Skip description generation"
multiSelect: false
```

- If "Skip": done.
- If "Generate and update", run the sub-skill's direct-update path so it handles backup creation and `--body-file` application:

  ```yaml
  skill: "kramme:pr:generate-description", args: "--auto --base {BASE_BRANCH}"
  ```

  If no PR exists or the generated body has a blocking missing requirement, the sub-skill will fall back to copy-paste output instead of publishing.
- If "Generate for review":

  ```text
  skill: "kramme:pr:generate-description", args: "--base {BASE_BRANCH}"
  ```

- If the skill errors out, report the error but do not fail the overall assessment.
