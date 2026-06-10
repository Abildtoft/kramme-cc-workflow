# Interview Templates

Load only the section for the phase currently being executed.

## Phase 2: Brief Interview

Use these questions when no imported or discovered content is available.

```yaml
header: "Project Context"
question: "In one sentence, what are you building or working on?"
freeform: true
```

Store the response as `project_description`.

```yaml
header: "Why Now"
question: "Why does this work matter now, and what outcome matters most?"
freeform: true
```

Store the response as `why_now`.

```yaml
header: "Non-Goals"
question: "What should stay out of scope for this first pass?"
freeform: true
```

Store the response as `out_of_scope_non_goals`.

```yaml
header: "Decision Scope"
question: "What decisions should this spec lock down now, and what should be left to implementation?"
freeform: true
```

Store the response as `decision_boundaries_notes`.

## Phase 2.5: Linked Source Confirmation

Use this question to decide whether linked files stay in place or move into `siw/`.

```yaml
header: "File Location"
question: "Should these files be moved into the siw/ folder, or kept in their current location?"
options:
  - label: "Keep in place"
    description: "Files stay where they are; SIW spec links to current paths"
  - label: "Move to siw/"
    description: "Move files into siw/ folder for co-location"
  - label: "Copy to siw/"
    description: "Copy files to siw/ (creates duplicates - not recommended)"
```

Before transferring each file for "Move to siw/" or "Copy to siw/", use this collision question when `[ -e "siw/{filename}" ]` succeeds:

```yaml
header: "Target File Exists"
question: "siw/{filename} already exists. How should I proceed for this file?"
options:
  - label: "Overwrite"
    description: "Replace siw/{filename} with the incoming file"
  - label: "Rename incoming"
    description: "Keep siw/{filename} and write the new file as siw/{filename-stem}-imported{ext}"
  - label: "Skip"
    description: "Leave both files where they are and reference the original path"
```

## Phase 2.6: Confirm Project Context

Use this question when linked files exist and no discovered content is available.

```yaml
header: "Project Context"
question: "Based on the linked files, what is this project about? (One sentence summary)"
freeform: true
defaultValue: "{inferred from file titles}"
```

## Phase 2.8: Work Context Selection

Use this question after reading `references/work-context-profiles.md` and auto-detecting the suggested profile.

```yaml
header: "Work Context"
question: "What type of work is this? This adjusts how spec audits, product reviews, and phase generation behave."
options:
  - label: "{auto-detected profile} (Recommended)"
    description: "{one-line description from profile}"
  - label: "Production Feature"
    description: "Full rigor across all quality dimensions"
  - label: "Prototype / Spike"
    description: "Focus on actionability and technical design; skip commercial viability"
  - label: "Internal Tool"
    description: "Focus on actionability and clarity; skip value proposition"
  - label: "Tech Debt / Refactor"
    description: "Focus on technical design and testability; skip value proposition and scope"
  - label: "Documentation / Process"
    description: "Focus on clarity and completeness; skip technical design"
```

Deduplicate the options. If the auto-detected profile is Production Feature, show one "Production Feature (Recommended)" option instead.

## Phase 3: Specification Document

Use this question to confirm the generated spec filename.

```yaml
header: "Specification Document"
question: "I'll create a specification document. Which name fits best?"
options:
  - label: "{detected_name}"
    description: "Recommended based on your description"
  - label: "FEATURE_SPECIFICATION.md"
    description: "For feature implementations"
  - label: "API_DESIGN.md"
    description: "For API design work"
  - label: "PROJECT_PLAN.md"
    description: "For general projects"
  - label: "Custom name"
    description: "Enter your own filename"
```

If "Custom name" is selected, use AskUserQuestion to get the filename.

## Phase 3.5: Supporting Specifications

Use this question to decide whether to create `siw/supporting-specs/`.

```yaml
header: "Supporting Specifications"
question: "Will this project need detailed supporting specifications? (For large projects with separate data model, API, UI specs, etc.)"
options:
  - label: "Yes - create supporting-specs folder"
    description: "For complex projects with multiple spec domains"
  - label: "No - single spec file is enough"
    description: "For simpler projects"
```
