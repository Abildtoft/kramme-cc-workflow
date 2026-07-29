# Script Helper Library

This directory contains shared shell helpers used by standalone scripts in
`kramme-cc-workflow/scripts/`. Keep script-specific policy in the calling
script; keep behavior shared by multiple scripts here.

## Files

| File | Responsibility |
| --- | --- |
| `shell-helpers.sh` | Provides required-argument validation, shell assignment quoting, and timeout-wrapped command execution. |

## Usage

Resolve the library from the calling script's own location so sourcing works
regardless of the caller's current directory:

```bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=lib/shell-helpers.sh
source "$SCRIPT_DIR/lib/shell-helpers.sh"
```

Scripts in a subdirectory should adjust the source path from their own
`SCRIPT_DIR`, for example `"$SCRIPT_DIR/../lib/shell-helpers.sh"`.

## Boundary Rules

- Helpers must not change shell options such as `errexit`, `nounset`, or
  `pipefail`; callers own those policies.
- Helpers must handle their own expected failure paths instead of relying on
  `set -e`.
- Keep command-line policy and user-facing success output in the calling
  script.

## Verification

Run shell lint after changing this library:

```bash
make -C kramme-cc-workflow lint-shell
```
