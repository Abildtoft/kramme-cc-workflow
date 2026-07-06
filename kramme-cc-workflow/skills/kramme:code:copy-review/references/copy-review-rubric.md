# Copy Review Rubric

This is the shared rubric for copy-review entry points and the `kramme:copy-reviewer` agent. Use it to decide whether UI text earns its place. Entry-point skills still decide scope: PR review evaluates changed UI copy, while codebase audit evaluates all UI copy in the requested scope.

Canonical owner: `kramme:code:copy-review`. Other copy-review entry points carry an identical local mirror so each installed skill can read a skill-local resource.

## Review Goal

Find visible UI text that duplicates what the interface already communicates through structure, icons, positioning, input type, visual hierarchy, or interaction patterns.

Evaluate copy necessity only. Do not review grammar, tone, brand voice, missing copy, visual hierarchy, or broader UX quality.

## UI-Relevant File Rules

Review files likely to contain visible UI text or translations for visible UI text:

- **Components:** `*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.component.ts`, `*.component.html`
- **Templates:** `*.html`, `*.hbs`, `*.ejs`, `*.pug`
- **Views/Pages:** files in `pages/`, `views/`, `screens/`, `routes/`, `app/` directories
- **i18n/translations:** `*.json` files in `locales/`, `i18n/`, `translations/` directories

Skip `node_modules`, `dist`, build artifacts, generated files, lock files, vendored code, and files whose text is not rendered in the UI.

## Modes

### PR Mode

Focus only on text redundancy introduced by the current review scope. Every finding must reference a file and line affected by the committed PR diff, staged changes, unstaged changes, or untracked files under review. Do not flag pre-existing issues.

### Audit Mode

Scan the provided codebase scope and flag redundant text regardless of when it was introduced. Every finding must reference a concrete file and line.

## Analysis Process

1. Read applicable project instruction files and nearby UI patterns to identify the UI stack, component library, design system, terminology conventions, target audience, and content strategy.
2. Identify visible text content: labels, descriptions, placeholders, helper text, tooltips, headings, button text, empty state text, confirmation dialog text, instructional text, and translations that render as visible text.
3. For each text element, identify what the UI already communicates through icons, input types, surrounding context, page title, section structure, interaction patterns, or visual hierarchy.
4. Apply the redundancy categories below.
5. Exclude text that has an accessibility, legal, onboarding, or documented content-strategy purpose.
6. Rate each finding with confidence and severity.

## Redundancy Categories

### 1. Label-Icon Duplication

A label restates what an adjacent recognizable icon already communicates.

Check for:

- Button with recognizable icon plus text label saying the same thing, such as trash icon plus "Delete".
- Navigation items where the icon is universally understood, such as house icon plus "Home".
- Toolbar actions where the icons are standard, such as pencil plus "Edit" or plus icon plus "Add".

Do not flag ambiguous, custom, or unfamiliar icons.

### 2. Label-Description Echo

A description or helper text restates the label using different words.

Check for:

- Field label "Email" with description "Enter your email address".
- Setting label "Notifications" with description "Configure your notification preferences".
- Field label "Name" with helper text "Please enter your name".

### 3. Placeholder-Label Mirror

Placeholder text repeats the field label verbatim or with trivial variation.

Check for:

- Label "Email" with placeholder "Email" or "Enter email".
- Label "Search" with placeholder "Search...".
- Label "Password" with placeholder "Enter password".

Do not flag placeholders that provide format guidance the label does not, such as label "Phone" with placeholder "+1 (555) 123-4567".

### 4. Obvious Helper Text

Helper text states what is self-evident from the input type, format, or local context.

Check for:

- "Select a date" below a date picker.
- "Choose an option" below a dropdown.
- "Type to search" in a search input with a magnifying glass icon.
- "Upload a file" next to a file upload button.

### 5. Self-Evident Tooltips

Tooltips describe controls whose purpose is already clear from icon, label, or position.

Check for:

- Tooltip "Search" on a search input with a magnifying glass icon and "Search" placeholder.
- Tooltip "Close" on an X button in a dialog corner.
- Tooltip "Save" on a clearly labeled "Save" button.

Do not flag tooltips that add information beyond the visible label, such as a keyboard shortcut.

### 6. Heading-Context Duplication

A heading repeats parent page, tab, breadcrumb, or section context.

Check for:

- "Settings" page with a top-level "Settings" heading.
- "Profile" tab containing a "Profile" section heading.
- "Dashboard" page starting with a "Dashboard" heading.
- Nested headings that repeat the parent context, such as "Account Settings" inside "Account Settings".

### 7. Verbose Confirmation Copy

Confirmation dialogs over-explain an action the user just intentionally triggered.

Check for:

- "Are you sure you want to save? This will save your changes to the server."
- "You are about to create a new item. A new item will be added to your list."
- Confirmation text that merely rephrases the button the user clicked.

Do not flag confirmations that communicate non-obvious consequences, counts, permanence, or recovery limits.

### 8. Redundant Instructional Text

Instructions explain a flow that the UI already enforces or makes obvious.

Check for:

- "Click the button below to continue" above one prominent "Continue" button.
- "Fill in the form fields below" at the top of a form.
- "Select an option from the list" above a radio group.
- Wizard text explaining step order when the UI enforces the sequence.

### 9. Overly Specific Button Labels

Button labels over-describe the action when surrounding context makes it obvious.

Check for:

- "Save Profile Settings" when the whole page is the profile settings form and there is one save action.
- "Create New Project" on a dialog titled "New Project".
- "Delete Selected Items" when selected items are visible and there is only one destructive action available.

### 10. Obvious Empty State Text

Empty state messages merely restate that data is absent.

Check for:

- "No items" or "No results found" when the layout and a visible add action already communicate the state.
- "You have no notifications" where the empty surface communicates the absence.
- "No data to display" as the only empty state content.

Do not flag empty states that provide actionable guidance, explain why data is missing, or help first-time users understand the feature.

## Exclusions

Do not flag:

- First-time or onboarding text that helps unfamiliar users learn the system.
- Legal, compliance, consent, security, or policy text.
- Accessibility text, including aria-only labels, screen-reader-only text, and alt text.
- Missing copy or weak copy quality. Those belong to UX or product review.
- Visual hierarchy, competing CTAs, or layout clutter.
- Text required by documented project conventions or a consistent content strategy.

When in doubt, do not flag. It is better to miss a borderline case than to recommend removing text that serves a purpose.

## Confidence and Severity

Report findings only at confidence 75 or higher unless an invoking skill sets a higher threshold.

- **Critical:** confidence 90 or higher and high user impact. Text actively creates confusion by contradicting or competing with what the UI already communicates, or significantly degrades scannability of a high-traffic surface.
- **Important:** confidence 80 or higher, or medium user impact. Clear redundancy adds visual noise or cognitive load without informational value.
- **Suggestion:** confidence 75 or higher. Borderline redundancy where removal could help but may reduce clarity for some users.

## Finding Format

Use this structure for each finding before the invoking skill aggregates it into its final report:

```markdown
### COPY-NNN: {Brief title}

**Severity:** Critical | Important | Suggestion
**Category:** {one of the rubric categories}
**File:** `path/to/file.tsx:42`
**Confidence:** {0-100}
**User Impact:** High | Medium | Low

**Issue:** {what text exists and what visual element, context, or interaction pattern already communicates without it}

**Recommendation:**
{what to remove or simplify, with before/after code when useful}
```
