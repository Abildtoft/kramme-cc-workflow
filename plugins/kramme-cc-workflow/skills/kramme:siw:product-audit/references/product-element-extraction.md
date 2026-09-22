# Product Element Extraction

Use this during Step 2.3 to identify and summarize product-relevant sections across every audited spec file.

| Element | What to look for |
| --- | --- |
| Target User | Who is the user? Persona, role, segment, or archetype |
| Problem Statement | What problem is being solved? Current pain, unmet need |
| Proposed Solution | What is being built? Core approach, key decisions |
| Business Reason / Why Now | Why this matters now, what business outcome or urgency exists |
| User Flows | How does the user interact? Steps, entry points, transitions |
| User States | What states can the user be in? Empty, error, loading, success, edge |
| Critical Moments | First use, error recovery, data loss, permission change, upgrade |
| Scope | What is in and out? Boundaries, explicit exclusions |
| Non-Goals | What is explicitly deferred, declined, or left for later |
| Success Criteria | How is success measured? Metrics, definitions of done |
| Phases / Milestones | How is delivery sequenced? What ships first? |
| Strategy Alignment | Whether the spec aligns with repo-root `STRATEGY.md` target users, active tracks, metrics, and non-goals |
| Pulse Signals | Whether recent `docs/pulse-reports/` evidence supports or challenges the spec's priorities |

For each element, capture:

- **source_file**: Which spec file
- **source_section**: Heading hierarchy
- **content_summary**: Brief description of what the section contains
