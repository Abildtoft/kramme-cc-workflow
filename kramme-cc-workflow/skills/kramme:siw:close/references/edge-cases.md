# Edge Cases

## No Spec File Found

```yaml
header: "No Specification Found"
question: "No specification file was found in siw/ after excluding temporary SIW files. Cannot generate meaningful documentation. How should I proceed?"
options:
  - label: "Remove SIW files only"
    description: "Delete temporary files without generating documentation (same as /kramme:siw:remove)"
  - label: "Abort"
    description: "Cancel"
```

## Linked External Specifications

If the spec has a `## Linked Specifications` section referencing files outside `siw/`:

- Include the linked file references in the documentation README
- Do NOT delete linked files (they are outside `siw/`)
- Note them in the README under a "Related Documentation" section

## No Decisions in LOG.md

If LOG.md has no Decision Log entries:

- `decisions.md` will contain only the note: "No formal design decisions were recorded during this project."
- README.md "Key Decisions" section replaced with: "No formal decisions were recorded. See the architecture documentation for technical details."
