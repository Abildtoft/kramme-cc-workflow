#!/usr/bin/env bash
#
# Measure the parallel process-level overhead of the hooks registered for Bash.
# This excludes Claude Code's hook dispatcher and the user's command itself.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

exec python3 - "$SCRIPT_DIR" "$@" << 'PY'
from __future__ import annotations

import argparse
import json
import os
import platform
import shutil
import statistics
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path


HOOKS = (
    ("block-rm-rf", "block-rm-rf.sh"),
    ("confirm-review-responses", "confirm-review-responses.sh"),
    ("noninteractive-git", "noninteractive-git.sh"),
)
COMMANDS = (
    ("trivial", "echo hi"),
    ("git", "git status --short"),
)


def positive_int(value: str) -> int:
    parsed = int(value)
    if parsed < 1:
        raise argparse.ArgumentTypeError("must be at least 1")
    return parsed


def nonnegative_int(value: str) -> int:
    parsed = int(value)
    if parsed < 0:
        raise argparse.ArgumentTypeError("must be at least 0")
    return parsed


def parse_args(arguments: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Benchmark the process-level overhead of Bash-matched hooks."
    )
    parser.add_argument(
        "--iterations",
        type=positive_int,
        default=30,
        help="measured samples per arm and command shape (default: 30)",
    )
    parser.add_argument(
        "--warmups",
        type=nonnegative_int,
        default=3,
        help="unmeasured warmup samples per arm and command shape (default: 3)",
    )
    return parser.parse_args(arguments)


def require_commands() -> None:
    missing = [name for name in ("bash", "jq", "python3") if shutil.which(name) is None]
    if missing:
        raise SystemExit(f"required command(s) not found: {', '.join(missing)}")


def median_ms(samples_ns: list[int]) -> float:
    return statistics.median(samples_ns) / 1_000_000


def run_process(command: list[str], *, payload: bytes | None, env: dict[str, str]) -> int:
    started_ns = time.perf_counter_ns()
    completed = subprocess.run(
        command,
        input=payload,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        cwd=env["CLAUDE_PLUGIN_ROOT"],
        env=env,
        check=False,
    )
    elapsed_ns = time.perf_counter_ns() - started_ns
    if completed.returncode != 0:
        diagnostic = completed.stderr.decode("utf-8", errors="replace").strip()
        raise RuntimeError(
            f"{' '.join(command)} exited {completed.returncode}: {diagnostic}"
        )
    return elapsed_ns


def run_parallel_set(
    hook_paths: tuple[Path, ...], *, payload: bytes, env: dict[str, str]
) -> int:
    started_ns = time.perf_counter_ns()
    with ThreadPoolExecutor(max_workers=len(hook_paths)) as executor:
        futures = [
            executor.submit(
                run_process,
                ["bash", str(hook_path)],
                payload=payload,
                env=env,
            )
            for hook_path in hook_paths
        ]
        for future in futures:
            future.result()
    return time.perf_counter_ns() - started_ns


def benchmark_python_startup(
    iterations: int, warmups: int, env: dict[str, str]
) -> list[int]:
    for _ in range(warmups):
        run_process(["python3", "-c", "pass"], payload=None, env=env)
    return [
        run_process(["python3", "-c", "pass"], payload=None, env=env)
        for _ in range(iterations)
    ]


def benchmark_command(
    command: str,
    *,
    hook_paths: tuple[Path, ...],
    enabled_env: dict[str, str],
    disabled_env: dict[str, str],
    iterations: int,
    warmups: int,
) -> tuple[list[int], list[int], dict[str, list[int]]]:
    payload = json.dumps(
        {"tool_name": "Bash", "tool_input": {"command": command}},
        separators=(",", ":"),
    ).encode()

    for _ in range(warmups):
        run_parallel_set(hook_paths, payload=payload, env=enabled_env)
        run_parallel_set(hook_paths, payload=payload, env=disabled_env)

    enabled_samples: list[int] = []
    disabled_samples: list[int] = []
    for index in range(iterations):
        arms = (
            (("enabled", enabled_env), ("disabled", disabled_env))
            if index % 2 == 0
            else (("disabled", disabled_env), ("enabled", enabled_env))
        )
        for arm_name, arm_env in arms:
            elapsed_ns = run_parallel_set(hook_paths, payload=payload, env=arm_env)
            if arm_name == "enabled":
                enabled_samples.append(elapsed_ns)
            else:
                disabled_samples.append(elapsed_ns)

    hook_samples: dict[str, list[int]] = {}
    for (hook_name, _), hook_path in zip(HOOKS, hook_paths, strict=True):
        for _ in range(warmups):
            run_process(["bash", str(hook_path)], payload=payload, env=enabled_env)
        hook_samples[hook_name] = [
            run_process(["bash", str(hook_path)], payload=payload, env=enabled_env)
            for _ in range(iterations)
        ]

    return enabled_samples, disabled_samples, hook_samples


def main() -> int:
    args = parse_args(sys.argv[2:])
    require_commands()

    script_dir = Path(sys.argv[1]).resolve()
    plugin_root = script_dir.parent
    hook_paths = tuple(plugin_root / "hooks" / filename for _, filename in HOOKS)
    missing_hooks = [str(path) for path in hook_paths if not path.is_file()]
    if missing_hooks:
        raise SystemExit(f"hook file(s) not found: {', '.join(missing_hooks)}")

    base_env = os.environ.copy()
    base_env["CLAUDE_PLUGIN_ROOT"] = str(plugin_root)

    print("Bash hook invocation overhead benchmark")
    print(f"Date (UTC): {time.strftime('%Y-%m-%d', time.gmtime())}")
    print(f"Platform: {platform.platform()}")
    print(f"Machine: {platform.machine()}")
    print(f"Python: {platform.python_version()}")
    print(f"Iterations: {args.iterations} (warmups: {args.warmups})")
    print(
        "Scope: parallel hook processes only; excludes hook dispatch and the user command"
    )

    with tempfile.TemporaryDirectory(prefix="hook-overhead-benchmark-") as temp_dir:
        temp_path = Path(temp_dir)
        enabled_state = temp_path / "enabled.json"
        disabled_state = temp_path / "disabled.json"
        enabled_state.write_text('{"disabled":[]}\n', encoding="utf-8")
        disabled_state.write_text(
            json.dumps({"disabled": [name for name, _ in HOOKS]}) + "\n",
            encoding="utf-8",
        )

        enabled_env = base_env | {"KRAMME_HOOK_STATE_FILE": str(enabled_state)}
        disabled_env = base_env | {"KRAMME_HOOK_STATE_FILE": str(disabled_state)}

        startup_samples = benchmark_python_startup(
            args.iterations, args.warmups, base_env
        )
        print(f"Bare Python startup median: {median_ms(startup_samples):.3f} ms")

        for label, command in COMMANDS:
            enabled, disabled, hook_samples = benchmark_command(
                command,
                hook_paths=hook_paths,
                enabled_env=enabled_env,
                disabled_env=disabled_env,
                iterations=args.iterations,
                warmups=args.warmups,
            )
            paired_overhead = [
                enabled_ns - disabled_ns
                for enabled_ns, disabled_ns in zip(enabled, disabled, strict=True)
            ]

            print()
            print(f"Command ({label}): {command}")
            print(f"  Enabled parallel set median: {median_ms(enabled):.3f} ms")
            print(f"  Disabled parallel set median: {median_ms(disabled):.3f} ms")
            print(
                "  Added gating overhead median (paired): "
                f"{median_ms(paired_overhead):.3f} ms"
            )
            print("  Enabled per-hook medians:")
            for hook_name, _ in HOOKS:
                print(
                    f"    {hook_name}: {median_ms(hook_samples[hook_name]):.3f} ms"
                )

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as error:
        print(f"benchmark failed: {error}", file=sys.stderr)
        raise SystemExit(1) from error
PY
