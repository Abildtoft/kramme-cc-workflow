# Hard-Cut Greenfield Policy Insertion

Follow every guard before inserting the policy:

1. Confirm the project has no external installed user base. Proceed only for a new project or one with no released users. If the project already has users, stop and report that the policy does not apply.
2. Resolve the project root before inspecting or creating instruction files, and run every remaining target-file lookup from that root. Do not treat a package or other nested working directory as the project root.
3. From the project root, resolve the target file with the host skill's **Before Writing** rules.
4. Read the target file and search for the heading `## Hard-Cut Greenfield Policy`. If it already exists, report that the policy is present and stop. Do not duplicate it.
5. Place the policy in an existing policy or conventions section where agents will naturally find it. If no such section exists, append it to the end of the file.
6. Include a blank line before the heading and a trailing newline after the block so it remains separated from surrounding content. Insert the following block verbatim:

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

Retirement is manual: when the application gains external users, delete the section by hand as its final bullet requires.

After insertion, report which file was modified or created and confirm that the section was added.
