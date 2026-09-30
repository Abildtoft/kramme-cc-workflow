---
name: kramme:workflow:wizard
description: "Generates an interactive Bash wizard script for human-run manual procedures: third-party setup, one-off migrations, A-to-B state transitions, local environment values, and GitHub Actions secrets or variables. Use when the user wants a guided setup script that opens URLs, captures values, confirms irreversible steps, and writes local or CI config. Not for running the procedure yourself, ordinary shell automation, or long-lived application code."
argument-hint: "[procedure description or target script path]"
disable-model-invocation: true
user-invocable: true
---

# Workflow Wizard

Generate an interactive Bash wizard that guides a human through a manual procedure. The wizard opens URLs, gives concrete click/copy instructions, captures values, writes local environment-file entries through the template's `ENV_FILE`, sets GitHub Actions secrets or variables when appropriate, and confirms irreversible steps.

**Arguments:** "$ARGUMENTS"

**Resource paths:** Resolve `assets/...` and `references/...` relative to this `SKILL.md` file. Do not assume a host-specific plugin root environment variable.

## Workflow

### 1. Scope Before Asking Cold

Read the repository first and identify the manual procedure, expected target state, and values the wizard must capture.

For setup wizards, inspect:

- environment template files and documented required variables
- `README*` and setup docs
- `docker-compose*`, framework config, deployment config, and package scripts
- `.github/workflows/*`, especially `secrets.*` and `vars.*` references

For migrations or state transitions, inspect the current state, target state, irreversible operations, rollback notes, and validation commands.

Default target path:

- Use `.context/wizard-<slug>.sh` for one-off or ephemeral procedures.
- Use `scripts/<slug>-setup.sh` only when the user wants a repeatable setup path that should live in the repo.
- If the user supplied a script path, use that path after checking it does not overwrite unrelated work.

### 2. Confirm The Plan

Before writing the wizard, show the user the ordered stage list and ask for confirmation. For each stage, include:

- stage name
- URL, command, or external place the human visits
- exact value captured, if any
- whether the value is secret and must use hidden entry
- destination: local environment file, GitHub secret, GitHub variable, nowhere, or another explicit path
- whether an action is irreversible and needs a `confirm` gate

Proceed only after the user confirms or adjusts the stages.

### 3. Map The Human Journey

For every stage, write instructions a stranger could follow. Include the concrete navigation path, button labels, URL, command, or dashboard area.

If the current third-party UI, docs, or command syntax is unknown, verify it from official docs or ask the user. Do not invent click paths, secret names, or irreversible operations.

### 4. Author The Script

Copy `assets/template.sh` to the target path, then edit only the `STAGES` section below the marker.

Use one focused `stage` per human task. Set:

- `TOTAL_STAGES` to the number of `stage` calls
- `TOTAL_MINUTES` to an honest total estimate
- `banner` to a short title naming the procedure

Use the template helpers consistently:

- `say` for context
- `step` for human actions
- `open_url` before asking for values from a web page
- `ask` for visible public values
- `ask_secret` for tokens, passwords, API secrets, private keys, and webhooks
- `write_env` for every value persisted to the env file
- `set_secret` only for values actually referenced as `secrets.NAME` in CI
- `set_var` only for non-secret values referenced as `vars.NAME` in CI
- `pause` after pure manual actions
- `confirm` before irreversible or hard-to-undo changes

Keep stages short enough that the current screen contains everything the human needs. Do not modify the template library above the `STAGES` marker except to preserve upstream attribution if the template is refreshed.

### 5. Verify And Hand Off

Run static verification only:

```bash
bash -n <script>
command -v shellcheck >/dev/null 2>&1 && shellcheck <script>
chmod +x <script>
```

Do not run the wizard end-to-end yourself because it opens browsers and blocks for human input.

Trace the script statically before handoff:

- every scoped value is captured once
- every captured value lands in the planned destination
- every `ask_secret` value is never printed
- every `set_secret` and `set_var` name matches a CI reference or an explicitly requested target
- every irreversible action is behind `confirm`

Tell the user the exact command to run.

## Artifact Lifecycle

Generated wizard scripts are ephemeral by default. The producer is this skill, the consumer is the human who runs the script, the refresh trigger is rerunning this skill when the setup or migration changes, and the retirement path is deleting the script after successful one-off use.

When a wizard is intended as a repeatable setup path, place it under the repository's script convention, verify it, and link it from setup documentation so future humans run the script directly.

## Source Tracking

`references/sources.yaml` records the upstream wizard skill and template inspiration. Do not load it during normal use unless auditing or refreshing source attribution.
