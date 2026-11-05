#!/usr/bin/env python3
"""Shared shell/git parser entry point for safety hooks.

The parser itself lives in the `command_safety` package next to this file;
this module stays a thin entry point so both supported invocations keep
working: `python3 -m git_command_parser <mode> ...`, which is what
`safety-hook-parser.sh` runs, and `python3 hooks/lib/git_command_parser.py
<mode> ...` for direct callers.

Each route finds `command_safety` in this directory a different way, and only
the module form survives safe-path mode. The hook route relies on the
explicit `PYTHONPATH=.` that
`safety-hook-parser.sh` sets, which also pins the import against a hostile
entry inherited from the environment. The direct script path relies on Python
prepending the script's own directory to `sys.path`, so it does not work under
`PYTHONSAFEPATH=1` or `python3 -P`; safe-path callers must use the module form.
Do not add a `sys.path` bootstrap here to paper over that -- it would put back
the script directory those callers deliberately asked Python to withhold,
revoking the guarantee they opted into.

See README.md#git-command-parser-mode-contracts for the mode contracts and the
package responsibility map.
"""

from __future__ import annotations

import sys

from command_safety.cli import main

if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
