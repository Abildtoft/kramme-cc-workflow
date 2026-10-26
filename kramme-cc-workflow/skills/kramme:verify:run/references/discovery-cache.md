# Discovery Cache

The cache saves the result of steps 1-3 (repository-root instruction files, CI fallback, and project-type detection) so a later call with the same inputs skips them. It never stores check results, affected sets, or anything else that depends on the diff.

## Helper

`"${CLAUDE_PLUGIN_ROOT}/skills/kramme:verify:run/scripts/discovery-cache.sh"` runs from anywhere inside the repository:

| Command | Result |
| --- | --- |
| `key` | Prints `{"enabled", "reason", "key", "path"}`. `enabled` is false, with a `reason`, when `.context/verify-run/` is not Git-ignored or `jq` is unavailable. |
| `read <key>` | Exit 0 prints a valid record. Exit 3 is a miss, including a stale key, a disabled cache, or no record. Exit 4 rejects the record (stderr names why); report it and treat it as a miss. |
| `write <key> <file>` | Validates `<file>` as `read` would and saves it as `.context/verify-run/discovery-<key>.json`. It exits 1 without saving when the cache is disabled, the key is stale, or the record is invalid. |

## Key Inputs

The key hashes a version line and a sorted list of:

- The content of the repository-root files steps 1-3 read: `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, `.claude/*.md`, `.github/workflows/*.yml` and `*.yaml`, `azure-pipelines.yml`, `Jenkinsfile`, `.circleci/config.yml`, `nx.json`, `package.json`, `pyproject.toml`, `pytest.ini`, `go.mod`, and `Cargo.toml`.
- The paths, not the content, of tracked or untracked non-ignored `project.json`, `*.csproj`, and `*.sln` files, which only decide the project type.
- The content of this skill's `SKILL.md`, `references/commands-by-project-type.md`, and the helper itself, named `skill:<path>`.

Editing, adding, or removing any of these changes the key, so the old record is never read again. Records are disposable; deleting `.context/verify-run/` only costs one fresh discovery.

## Record Format

```json
{
  "version": 1,
  "key": "<key from the helper>",
  "created": "2026-10-26T09:30:00Z",
  "project_type": "node",
  "tiers": {
    "fast": { "source": "AGENTS.md:42" },
    "full": { "source": null }
  },
  "base_branch": { "name": "develop", "source": "nx.json:3" },
  "checks": [
    {
      "category": "linting",
      "command": "npm run lint",
      "cwd": ".",
      "tiers": ["fast", "full"],
      "base_scoped": false,
      "side_effecting": false,
      "source": "AGENTS.md:44"
    }
  ],
  "skipped": ["E2E: no suite found in package.json scripts"]
}
```

- `tiers.fast.source` and `tiers.full.source` cite where the project documents each tier, or `null` when the step 4 defaults apply.
- `base_branch` is the base that step 5 items 2 and 3 found in a root instruction file or `nx.json`, or `null`. On a hit it sets `BASE_BRANCH_OVERRIDE` unless `--base` or a nested instruction file names one.
- `checks` lists every discovered check in step 8 order. `category` is one of `formatting`, `linting`, `type-checking`, `build`, `unit`, `component`, `integration`, or `e2e`. `cwd` is repository-relative without `..`. `tiers` holds `fast`, `full`, or both. `base_scoped` marks checks that take `$BASE_REF`; write the literal `$BASE_REF` placeholder in `command` and substitute this run's value. `side_effecting` marks integration or E2E suites that need prepared services.
- `source` is `path:line` in a content-hashed input. Defaults from `references/commands-by-project-type.md` cite `skill:references/commands-by-project-type.md:<line>`.
- `skipped` keeps discovery notes, such as ambiguous CI steps left out under step 2.

## Trust Rule

Save only commands found under steps 1-3's rules, from files the key hashes. When a command came from any other file, such as a document an instruction file links to, do not save the record: report `Discovery: fresh (not saved: <reason>)`. The helper rejects any `source` outside the hashed inputs, but it cannot tell whether a cited line supports the command, so cite the line the command actually came from.

## Still Done Every Run

A hit replaces only steps 1-3 and the static suite list from Test Suite Discovery. Every run still:

- Reads nested instruction files for the affected paths. When one names commands or a base, apply it on top of the cached record exactly as step 1 would.
- Resolves the base through the shared resolver (step 5) and checks reuse (step 6).
- Runs Nx affected discovery, target-existence checks, and Skill Security Scan Discovery, which depend on the diff.

`--force` skips `read`, runs steps 1-3 fresh, and saves the result with `write`, replacing a suspect record.
