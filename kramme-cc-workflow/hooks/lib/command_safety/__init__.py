"""Command-safety parser package.

Import the module that owns the behavior you need rather than this package:
`structs` holds the shared value-object base, `syntax` and `vocabulary` the
shared shell and option primitives, `prefix` and `lexer` the shared
command-prefix and tokenization layers, and `noninteractive`, `rm_rf`, and
`commit` one policy mode each. `cli` dispatches the modes. See README.md in
the parent directory for the responsibility map.

This module imports and re-exports nothing on purpose: the shim's
`from command_safety.cli import main` executes it first, so anything added
here is loaded by every gate, including the modes that gate will not run.
"""
