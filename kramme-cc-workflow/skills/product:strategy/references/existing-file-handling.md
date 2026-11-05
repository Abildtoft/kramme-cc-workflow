# Existing File Handling

Rules for a `STRATEGY.md` that is not in template shape, and for creating `STRATEGY.md` when the repository already has another product-direction doc.

## Shared STRATEGY.md (update mode)

A file whose `##` headings are not all template headings was written by a person or another tool, and other readers may depend on its structure. Treat it as shared:

- Find where the file already covers each strategy topic (target problem, approach, users, metrics, active tracks, milestones, non-goals), whatever the heading, including topics covered only in running prose.
- Make the smallest change that records the update, inside the file's own headings and order. Extend the section that already covers a topic rather than adding a second heading for it.
- Never move, reword, or shorten content this skill did not write.
- Ask before adding frontmatter or new sections. Other product skills read `last_updated` frontmatter to judge staleness, so name that trade-off when asking.

## Existing product doc (create mode)

When no `STRATEGY.md` exists but a root-level product-direction doc does, such as `PRODUCT.md`, `VISION.md`, or a doc the README links to as the product direction:

- Draft from it. Attribute each borrowed claim to its source file and mark it `UNVERIFIED:` until the user confirms it.
- Ask whether to merge that content into the new `STRATEGY.md`, or keep the old doc as the home for those topics and link to it from `STRATEGY.md`.
- Never modify or delete the old doc. After a merge, point out that it now duplicates `STRATEGY.md` and let the user decide whether to remove it.
