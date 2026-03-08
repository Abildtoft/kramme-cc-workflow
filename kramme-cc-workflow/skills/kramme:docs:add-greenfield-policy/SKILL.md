---
name: kramme:docs:add-greenfield-policy
description: "Append the Hard-Cut Greenfield Policy section to AGENTS.md or CLAUDE.md. Use when setting up a new greenfield project or adding the no-compatibility-code policy to an existing project. Not for editing or customizing the policy after it has been added."
disable-model-invocation: true
user-invocable: true
---

# Add Hard-Cut Greenfield Policy

Append the Hard-Cut Greenfield Policy section to the project's agent instructions file. This policy establishes a default stance of deleting old-state compatibility code rather than carrying it forward.

## Workflow

1. **Locate target file** — Determine where to append the policy using this priority order:
   1. If `AGENTS.md` exists in the project root, use it.
   2. If `AGENTS.md` does not exist but `CLAUDE.md` does, use `CLAUDE.md`.
   3. If neither exists, create `AGENTS.md` in the project root.

   ```bash
   ls -la AGENTS.md CLAUDE.md 2>/dev/null
   ```

2. **Check for existing section** — Read the target file and search for the heading `## Hard-Cut Greenfield Policy`. If the section already exists, report that the policy is already present and stop. Do not duplicate it.

3. **Append the policy section** — Add the following block to the end of the target file. Include a blank line before the heading to ensure proper markdown separation from preceding content.

   ~~~markdown

   ## Hard-Cut Greenfield Policy

   - This application currently has no external installed user base; optimize for one canonical current-state implementation, not compatibility with historical local states.
   - Do not preserve or introduce compatibility bridges, migration shims, fallback paths, compact adapters, or dual behavior for old local states unless the user explicitly asks for that support.
   - Prefer:
     - one canonical current-state codepath
     - fail-fast diagnostics
     - explicit recovery steps
     over:
     - automatic migration
     - compatibility glue
     - silent fallbacks
     - "temporary" second paths
   - If temporary migration or compatibility code is introduced for debugging or a narrowly scoped transition, it must be called out in the same diff with:
     - why it exists
     - why the canonical path is insufficient
     - exact deletion criteria
     - the ADO/task that tracks its removal
   - Default stance across the app: delete old-state compatibility code rather than carrying it forward.
   ~~~

4. **Confirm result** — Report which file was modified (or created) and that the Hard-Cut Greenfield Policy section was added successfully.
