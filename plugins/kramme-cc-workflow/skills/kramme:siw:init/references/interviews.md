# Interview Templates

Load only the section for the phase currently being executed.

## Phase 2: Brief Interview

Use these questions when no imported or discovered content is available.

Ask the user directly in chat:
Question label: Project Context
Question: In one sentence, what are you building or working on?
Store the response as `project_description`.

Ask the user directly in chat:
Question label: Why Now
Question: Why does this work matter now, and what outcome matters most?
Store the response as `why_now`.

Ask the user directly in chat:
Question label: Non-Goals
Question: What should stay out of scope for this first pass?
Store the response as `out_of_scope_non_goals`.

Ask the user directly in chat:
Question label: Decision Scope
Question: What decisions should this spec lock down now, and what should be left to implementation?
Store the response as `decision_boundaries_notes`.

## Phase 2.5: Linked Source Confirmation

Use this question to decide whether linked files stay in place or move into `siw/`.

Ask the user directly in chat:
Question label: File Location
Question: Should these files be moved into the siw/ folder, or kept in their current location?
Suggested options:
- Keep in place — Files stay where they are; SIW spec links to current paths
- Move to siw/ — Move files into siw/ folder for co-location
- Copy to siw/ — Copy files to siw/ (creates duplicates - not recommended)
Before transferring each file for "Move to siw/" or "Copy to siw/", use this collision question when `[ -e "siw/{filename}" ]` succeeds:

Ask the user directly in chat:
Question label: Target File Exists
Question: siw/{filename} already exists. How should I proceed for this file?
Suggested options:
- Overwrite — Replace siw/{filename} with the incoming file
- Rename incoming — Keep siw/{filename} and write the new file as siw/{filename-stem}-imported{ext}
- Skip — Leave both files where they are and reference the original path
## Phase 2.6: Confirm Project Context

Use this question when linked files exist and no discovered content is available.

Ask the user directly in chat:
Question label: Project Context
Question: Based on the linked files, what is this project about? (One sentence summary)
## Phase 2.8: Work Context Selection

Use this question after reading `references/work-context-profiles.md` and auto-detecting the suggested profile.

Ask the user directly in chat:
Question label: Work Context
Question: What type of work is this? This adjusts how spec audits, product reviews, and phase generation behave.
Suggested options:
- {auto-detected profile} (Recommended) — {one-line description from profile}
- Production Feature — Full rigor across all quality dimensions
- Prototype / Spike — Focus on actionability and technical design; deprioritize completeness and testability
- Internal Tool — Focus on actionability and clarity; keep other dimensions at normal rigor
- Tech Debt / Refactor — Focus on technical design and testability; deprioritize scope
- Documentation / Process — Focus on clarity and completeness; skip technical design
Deduplicate the options. If the auto-detected profile is Production Feature, show one "Production Feature (Recommended)" option instead.

## Phase 3: Specification Document

Auto-detect the most appropriate spec filename from `project_description`:

- Keywords like `feature`, `add`, `implement`, `new` -> `FEATURE_SPECIFICATION.md`
- Keywords like `api`, `endpoint`, `service` -> `API_DESIGN.md`
- Keywords like `doc`, `documentation`, `guide` -> `DOCUMENTATION_SPEC.md`
- Keywords like `tutorial`, `learn`, `teach` -> `TUTORIAL_PLAN.md`
- Keywords like `system`, `architecture`, `design` -> `SYSTEM_DESIGN.md`
- Default fallback -> `PROJECT_PLAN.md`

Use this question to confirm the generated spec filename.

Ask the user directly in chat:
Question label: Specification Document
Question: I'll create a specification document. Which name fits best?
Suggested options:
- {detected_name} — Recommended based on your description
- FEATURE_SPECIFICATION.md — For feature implementations
- API_DESIGN.md — For API design work
- PROJECT_PLAN.md — For general projects
- Custom name — Enter your own filename
If "Custom name" is selected, ask the user directly in chat to get the filename.

## Phase 3.5: Supporting Specifications

Use this question to decide whether to create `siw/supporting-specs/`.

Ask the user directly in chat:
Question label: Supporting Specifications
Question: Will this project need detailed supporting specifications? (For large projects with separate data model, API, UI specs, etc.)
Suggested options:
- Yes - create supporting-specs folder — For complex projects with multiple spec domains
- No - single spec file is enough — For simpler projects