---
name: kramme:docs:add-greenfield-policy
description: "Add the Hard-Cut Greenfield Policy section to AGENTS.md or CLAUDE.md. Use when setting up a new greenfield project or adding the no-compatibility-code policy to an existing project. Not for editing or customizing the policy after it has been added."
disable-model-invocation: true
user-invocable: true
---

# Add Hard-Cut Greenfield Policy

Add the Hard-Cut Greenfield Policy section to the project's agent instructions file, placing it where agents will naturally find policy guidance. This policy establishes a default stance of deleting old-state compatibility code rather than carrying it forward.

## Workflow

1. **Confirm the project is greenfield** — This policy asserts the application has no external installed user base. Only proceed when that is true (a new project, or one with no released users). If the project already has users, stop and report that the policy does not apply.

2. **Locate target file** — Run from the project root so the lookups below resolve the correct files. Determine where to add the policy using this priority order:
   1. If `AGENTS.md` exists in the project root, use it.
   2. If `AGENTS.md` does not exist but `CLAUDE.md` does, use `CLAUDE.md`.
   3. If neither exists, create `AGENTS.md` in the project root.

   ```bash
   ls -la AGENTS.md CLAUDE.md 2> /dev/null
   ```

3. **Check for existing section** — Read the target file and search for the heading `## Hard-Cut Greenfield Policy`. If the section already exists, report that the policy is already present and stop. Do not duplicate it.

4. **Respect existing instruction structure** — If the target file has a policy or conventions section, place the policy where an agent would naturally find it. Otherwise append the policy section to the end of the target file. Keep the section short; link to detailed docs rather than inlining them.

5. **Add the policy section** — Add the following block. Include a blank line before the heading and a trailing newline after the block so it stays cleanly separated from surrounding content.

   ```markdown
   ## Hard-Cut Greenfield Policy

   - This application currently has no external installed user base; optimize for one canonical current-state implementation, not compatibility with historical local states.
   - Do not preserve or introduce compatibility bridges, migration shims, fallback paths, compat adapters, or dual behavior for old local states unless the user explicitly asks for that support.
   - Prefer:
     - one canonical current-state codepath
     - fail-fast diagnostics
     - explicit recovery steps
   - Over:
     - automatic migration
     - compatibility glue
     - silent fallbacks
     - "temporary" second paths
   - If temporary migration or compatibility code is introduced for debugging or a narrowly scoped transition, it must be called out in the same diff with:
     - why it exists
     - why the canonical path is insufficient
     - exact deletion criteria
     - the issue/ticket that tracks its removal
   - Default stance across the app: delete old-state compatibility code rather than carrying it forward.
   - Remove this section once the application has external users — it asserts a no-user-base premise that stops being true at that point.
   ```

   Retirement of the section is manual: no tooling removes it, so when the application gains external users the team deletes the section by hand per its own retirement line.

6. **Confirm result** — Report which file was modified (or created) and that the Hard-Cut Greenfield Policy section was added successfully.
