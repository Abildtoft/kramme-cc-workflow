# Argument Handling

Use this reference during Phase 1.5.

`$ARGUMENTS` contains any text the user provided after `/kramme:siw:init`. Use `resolved_arguments` as the effective Phase 1.5 input. If no Phase 1 branch already set `resolved_arguments`, default it to `$ARGUMENTS` now.

## Argument Parsing

Parse `resolved_arguments` to detect the input type:

1. **File path(s)**: contains `.md`, `.txt`, or other file extensions.
2. **Folder path**: a directory path, verified with `ls -d {path}`.
3. **discover / interview keyword**: starts with `discover` or `interview`.
4. **Empty**: no arguments provided.

If `resolved_arguments` is empty because the user ran plain `/kramme:siw:init`, but Phase 1 found only `siw/DISCOVERY_BRIEF.md`, treat that file as the single file-path input and follow Case 1.

## Case 1: File Path(s) Provided

If `resolved_arguments` contains file path(s):

1. Split arguments by spaces to get individual paths.
2. If exactly one provided path ends with `DISCOVERY_BRIEF.md`:
   - Verify the file exists with `ls {path}`.
   - Read the full file.
   - Follow `references/discovery-brief-import.md` to extract sections and map them into `discovered_content`.
   - Set `project_description` from the brief title or `What You Actually Want`.
   - Skip Phase 2 and continue to Phase 2.8.
3. For any other file paths provided:
   - Verify each file exists with `ls {path}`.
   - Read the first heading for title inference.
   - Read enough content to classify readiness without duplicating the source: objective/scope/success criteria, technical context/dependencies/planning detail, and blocking open questions.
   - Store only concise readiness notes as `linked_spec_readiness_context`; linked files remain the source of truth and their body content is not copied into the generated SIW spec.
   - If a file does not exist, warn and skip it.
4. Store file paths as `linked_spec_files`.
5. Extract a brief project name from file titles for `project_description`.
6. Continue to Phase 2.5.

## Case 2: Folder Path Provided

If `resolved_arguments` is a directory, verified with `ls -d`, scan for relevant specification files:

```bash
find {folder} -maxdepth 2 -type f \( -name "*.md" -o -name "*.txt" \) 2> /dev/null
```

Present found files to the user. If `AUTO_MODE=true`, select **All files** automatically. Otherwise use AskUserQuestion:

```yaml
header: "Select Source Files"
question: "Found these files in {folder}. Which should I use as linked sources?"
multiSelect: true
options:
  - "{file1}"
  - "{file2}"
  - "All files"
  - "None - start fresh"
```

If "None - start fresh" is selected, set `resolved_arguments` empty and continue to Phase 2.

If "All files" or specific files are selected:

- Store selected paths as `linked_spec_files`.
- For each selected file, read the first heading for title inference and enough content to classify readiness without duplicating the source.
- Store concise readiness notes as `linked_spec_readiness_context`.
- Continue to Phase 2.5.

## Case 3: discover / interview Mode

If `resolved_arguments` starts with `discover` or `interview`:

1. Extract optional topic from the remaining input:
   - `discover authentication system` -> topic = "authentication system"
   - `discover` alone -> ask for topic
2. If no topic is provided and `AUTO_MODE=true`, stop with `MISSING REQUIREMENT: discovery topic required for --auto`.
3. If no topic is provided and `AUTO_MODE=false`, use AskUserQuestion:

   ```yaml
   header: "Discovery Topic"
   question: "What topic should we explore? Describe what you're building or the problem you're solving."
   freeform: true
   ```

4. Do not run the legacy inline interview path.
5. Before launching discovery, re-run the `permanent-spec find` from Phase 1 to check for permanent SIW spec files left in `siw/`.
6. If permanent spec files still exist, do not run greenfield discovery. If `AUTO_MODE=true`, stop with `MISSING REQUIREMENT: permanent SIW spec files already exist; rerun without --auto to choose whether to use them`. Otherwise use AskUserQuestion:

   ```yaml
   header: "Existing Spec Files Found"
   question: "Permanent SIW spec files still exist in siw/. A fresh discovery run would treat this as refinement, not a new project. How should I proceed?"
   options:
     - label: "Use existing specs"
       description: "Treat the existing spec files as linked sources instead of running discovery"
     - label: "Abort"
       description: "Stop so I can archive or remove the old spec files before running fresh discovery"
   ```

7. If "Use existing specs":
   - Store the detected paths as `linked_spec_files`.
   - Read the first heading from each file to infer titles.
   - Read enough content to classify readiness without duplicating the source.
   - Store concise readiness notes as `linked_spec_readiness_context`.
   - Set `project_description` from those titles.
   - Continue to Phase 2.5.
8. If "Abort", stop without changing files.
9. If no permanent spec files exist, read `references/greenfield-discovery-handoff.md` and follow it to run the greenfield discovery handoff. That handoff must produce `siw/DISCOVERY_BRIEF.md` before returning here.
10. Set `resolved_arguments=siw/DISCOVERY_BRIEF.md`.
11. Follow `references/discovery-brief-import.md` to populate `discovered_content`.
12. Skip Phase 2 and continue to Phase 2.8.

## Case 4: No Arguments

Continue to Phase 2 for the structured brief interview: overview, why-now, non-goals, and decision boundaries.
