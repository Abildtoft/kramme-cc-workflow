---
name: example:release-note
description: "Drafts concise release note copy from a provided changelog and product context. Use when a user asks for release note wording, not for deployment, PR creation, or publishing."
argument-hint: "[changelog-path]"
disable-model-invocation: false
user-invocable: true
---

# Draft Release Note

Create release note copy from a local changelog or pasted notes. This skill only
drafts text; it does not publish, commit, push, or call external services.

## Workflow

1. Resolve the changelog path or pasted notes.
2. Read only the changelog and `references/style-guide.md` when tone guidance is
   needed.
3. Identify the audience, shipped behavior, customer-visible changes, and known
   limitations.
4. Draft a short release note with a title, one-paragraph summary, and bullets.
5. If the input is missing or ambiguous, ask for the missing changelog or target
   audience before drafting.

## Output

Return markdown release note copy and list any assumptions. Do not create files
unless the user explicitly asks for a saved artifact path.
