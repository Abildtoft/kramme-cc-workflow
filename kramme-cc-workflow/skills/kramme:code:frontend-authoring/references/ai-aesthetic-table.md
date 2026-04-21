# The "AI Aesthetic" anti-pattern table

The single highest-leverage author-time check. AI-generated UI has recognizable defaults; avoiding them is the difference between "looks like a template" and "looks production-quality."

Run this table against every UI draft before moving on. If a row describes your draft, apply the production alternative in the same row.

| Anti-pattern | Why it reads as AI | Production alternative |
|---|---|---|
| Purple/indigo everything | Models default to visually "safe" palettes, making every app look identical. | Use the project's actual color palette. Neutral surfaces by default; accent used sparingly and intentionally. |
| Excessive gradients | Gradients compensate for weak hierarchy. They add visual noise and clash with most design systems. | Solid surfaces + type + spacing. If the design system specifies a gradient, use the exact token. |
| `rounded-2xl` on every surface | Maximum rounding signals "friendly" but ignores the hierarchy of corner radii in real designs. Visual noise. | Intentional radius per surface tier. One value for cards, one for inputs, one for buttons — from the design system. |
| Generic hero sections | Template-driven layout with no connection to the actual content or user need. Reads as placeholder. | Content-driven opening. Start from the actual content and its priority; lay out around that. |
| Lorem-ipsum-style copy | Placeholder text hides layout problems that real content reveals (length, wrapping, overflow). Reads as AI-generated. | Specific, voice-appropriate copy. If real copy is unavailable, use realistic-length placeholders, not lorem ipsum. |
| Oversized padding everywhere | Equal generous padding destroys visual hierarchy and wastes screen space. Inflates the UI. | Calibrated spacing to density. Dense lists get tight spacing; top-level sections get generous spacing. |
| Stock card grids | Uniform grids treat everything as equal priority. Ignores information priority and scanning patterns. | Hierarchy via size, weight, and position. The most important item is visually distinguished, not just gridded. |
| Shadow-heavy design | Layered shadows replace hierarchy with depth and slow rendering on low-end devices. | Use depth sparingly; hierarchy first. Flat or single subtle shadow unless the design system specifies layered elevation. |
| Color-only state indication | Models often stop at a red/green visual cue, which reads as inaccessible mockup thinking rather than production UI. The meaning disappears for color-blind users and in non-visual contexts. | Pair color with text, iconography, or pattern so status survives without color. Prefer explicit labels like `Error`, `Warning`, `Success`, or `Paused`, and ensure the token set still meets contrast requirements. |

## Why verbatim per row matters

Each row encodes three things:

1. **The tell** — the specific visual signature that marks the draft as AI.
2. **The cause** — the model-behavior or template-behavior that produces it.
3. **The fix** — the production alternative, stated concretely enough to apply without re-reading the design system from scratch.

Removing the "why" column turns the table into style advice. Keeping the "why" lets you judge edge cases — e.g., when `rounded-2xl` is actually the right radius tier for a specific surface — instead of mechanically rejecting any use.

## Applying the table

1. Read the full table before starting the anti-aesthetic pass.
2. For each row, ask: "does this describe my draft?" If yes, apply the alternative before moving on.
3. If the design system genuinely specifies a pattern that matches a row (e.g., brand accent actually is indigo, radius scale actually tops out at `2xl`), note that as `SIMPLICITY CHECK` context and continue — the row is about AI defaults, not about any use of the visual.
4. When reviewing PRs, use the row numbers as shorthand: "AI-aesthetic row 3 (rounded-2xl on every surface)" is enough context for a reviewer to find the issue.
