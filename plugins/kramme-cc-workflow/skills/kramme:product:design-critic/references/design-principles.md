# Design Principles

Reusable design canons, mental models, and anti-patterns for product design critique.

## Canons

- **Fitts's Law** — Interactive targets should be large and close to where the cursor already is. Primary actions deserve the most accessible placement.
- **Hick's Law** — Decision time increases with the number of choices. Reduce options to reduce friction.
- **Jakob's Law** — Users spend most of their time on other products. Prefer familiar patterns over novel ones unless novelty solves a real problem.
- **Miller's Law** — Working memory holds roughly 7 items. Chunk information and limit simultaneous demands on attention.
- **Tesler's Law (Conservation of Complexity)** — Every system has irreducible complexity. The question is who bears it: the user or the system.

## Mental Models

- **Object-action model** — Users think in terms of "thing I'm looking at" then "what I can do to it." Designs that reverse this (action-first, object-second) feel disorienting.
- **Progressive disclosure** — Show the most important information first, reveal detail on demand. Prevents cognitive overload without hiding capability.
- **Spatial consistency** — Elements that appear in the same place across views build muscle memory. Moving elements between states breaks trust.
- **Direct manipulation** — Users prefer to act on the object itself rather than through indirect controls. Inline editing beats modal forms when the context supports it.

## Anti-Patterns

- **Feature soup** — Every feature is equally prominent; nothing is the hero. The interface looks busy but communicates nothing about priority.
- **Mystery meat navigation** — Labels or icons that require hovering or guessing. The user cannot scan for what they need.
- **Premature abstraction** — Dashboards, settings pages, and admin panels that solve every possible future need rather than the current job.
- **Notification spam** — Every event triggers a visible alert. Users learn to ignore all of them, including the important ones.
- **Confirmation theater** — "Are you sure?" dialogs that appear so often they become reflexive click-throughs, providing no actual safety.
- **Zombie states** — UI elements that look interactive but do nothing, or that persist after their purpose has passed.
- **Copy-paste hierarchy** — Every section has the same heading size, card style, and spacing. Nothing signals what matters more.
