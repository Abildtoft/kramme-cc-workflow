# Script Helper Library

This directory contains shared shell and Node helpers used by standalone
scripts in `kramme-cc-workflow/scripts/`. Keep script-specific policy in the calling
script; keep behavior shared by multiple scripts here.

## Files

| File | Responsibility |
| --- | --- |
| `shell-helpers.sh` | Provides required-argument validation, shell assignment quoting, JSON object emit/decode with a single Python guard, and timeout-wrapped command execution. |
| `skill-usage-cost.js` | Transcript indexing, per-session cost and token summaries, and rendering for `scripts/skill-usage.js cost`. |
| `skill-usage-hosts.js` | Host detection, plugin manifest version lookup, and Codex rollout parsing for `scripts/skill-usage.js`. |

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

Node scripts require helpers relative to their own file, for example
`require("./lib/skill-usage-hosts")`. Node helpers use only Node core modules
because they ship unchanged into the converted Codex plugin.

## Boundary Rules

- Shell helpers must not change shell options such as `errexit`, `nounset`, or
  `pipefail`; callers own those policies.
- Shell helpers must handle their own expected failure paths instead of relying on
  `set -e`.
- Keep command-line policy and user-facing success output in the calling
  script.

## Verification

Run shell lint after changing a shell helper:

```bash
make -C kramme-cc-workflow lint-shell
```

Run the focused tests and type check after changing `skill-usage-hosts.js`:

```bash
make -C kramme-cc-workflow test-node-file NODE_TEST_FILE=tests/node/skill-usage-hosts.test.js
make -C kramme-cc-workflow lint-js
```

Run the focused tests and type check after changing `skill-usage-cost.js`:

```bash
make -C kramme-cc-workflow test-node-file NODE_TEST_FILE=tests/node/skill-usage-cost.test.js
make -C kramme-cc-workflow lint-js
```
