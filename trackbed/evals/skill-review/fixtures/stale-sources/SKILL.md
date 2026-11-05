---
name: example:ops-runbook
description: "Runs an incident checklist adapted from an external operations runbook."
argument-hint: "[incident-notes]"
disable-model-invocation: false
user-invocable: true
---

# Incident Checklist

Use this adapted checklist to structure incident triage notes. The workflow is
based on a public operations runbook and keeps attribution in
`references/sources.yaml`.

## Workflow

1. Read the incident notes.
2. Classify the severity, affected systems, customer impact, and owner.
3. Draft a mitigation checklist.
4. Summarize follow-up tasks and unanswered questions.
