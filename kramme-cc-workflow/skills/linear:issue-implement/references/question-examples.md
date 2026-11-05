# Clarifying Question Examples

Use these as patterns for AskUserQuestion prompts when requirements or implementation choices are unclear.

```yaml
header: "Implementation Scope"
question: "The issue mentions {feature}. Should this include {related functionality} or just the core feature?"
options:
  - label: "Core feature only"
    description: "Minimal implementation as described"
  - label: "Include {related functionality}"
    description: "Broader scope with additional features"
```

```yaml
header: "Technical Approach"
question: "I found two patterns in the codebase for similar features. Which approach should we follow?"
options:
  - label: "Pattern A - {description}"
    description: "Used in {files}"
  - label: "Pattern B - {description}"
    description: "Used in {files}"
```

```yaml
header: "Testing Requirements"
question: "What level of test coverage is expected?"
options:
  - label: "Unit tests only"
    description: "Test individual functions/methods"
  - label: "Unit + integration tests"
    description: "Also test component interactions"
  - label: "Full coverage including E2E"
    description: "Complete test suite"
```
