from __future__ import annotations

import contextlib
import importlib.util
import io
import signal
import sys
import time
import unittest
from pathlib import Path
from typing import Any


SCRIPT_PATH = (
    Path(__file__).resolve().parents[2]
    / "skills"
    / "kramme:visual:generate-image"
    / "scripts"
    / "generate_image.py"
)
SPEC = importlib.util.spec_from_file_location("generate_image", SCRIPT_PATH)
assert SPEC is not None
assert SPEC.loader is not None
generate_image = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = generate_image
SPEC.loader.exec_module(generate_image)


class FakeTypes:
    class ImageConfig:
        def __init__(self, **kwargs: Any) -> None:
            self.kwargs = kwargs

    class GenerateContentConfig:
        def __init__(self, **kwargs: Any) -> None:
            self.kwargs = kwargs


class FakeModels:
    def __init__(self, outcomes: list[Any]) -> None:
        self.outcomes = outcomes
        self.calls: list[dict[str, Any]] = []

    def generate_content(self, **kwargs: Any) -> Any:
        self.calls.append(kwargs)
        outcome = self.outcomes.pop(0)
        if isinstance(outcome, Exception):
            raise outcome
        return outcome


class FakeClient:
    def __init__(self, outcomes: list[Any]) -> None:
        self.models = FakeModels(outcomes)


class GenerateImageNetworkBoundsTest(unittest.TestCase):
    def test_retries_retryable_generation_errors(self) -> None:
        response = object()
        client = FakeClient([TimeoutError("temporary timeout"), response])
        sleeps: list[float] = []

        with contextlib.redirect_stderr(io.StringIO()):
            result = generate_image.generate_content_with_retries(
                client,
                FakeTypes,
                "prompt",
                "1K",
                timeout_seconds=5,
                max_retries=1,
                retry_delay_seconds=0.25,
                sleep=sleeps.append,
            )

        self.assertIs(result, response)
        self.assertEqual(len(client.models.calls), 2)
        self.assertEqual(sleeps, [0.25])
        self.assertEqual(
            client.models.calls[0]["model"],
            generate_image.MODEL_NAME,
        )

    def test_does_not_retry_non_retryable_generation_errors(self) -> None:
        client = FakeClient([ValueError("bad request")])

        with self.assertRaisesRegex(ValueError, "bad request"):
            generate_image.generate_content_with_retries(
                client,
                FakeTypes,
                "prompt",
                "1K",
                timeout_seconds=5,
                max_retries=3,
                retry_delay_seconds=0,
                sleep=lambda _seconds: None,
            )

        self.assertEqual(len(client.models.calls), 1)

    def test_call_with_timeout_raises_bounded_error(self) -> None:
        if not hasattr(signal, "SIGALRM") or not hasattr(signal, "setitimer"):
            self.skipTest("signal timers are not available")

        with self.assertRaisesRegex(
            generate_image.GenerationTimeoutError,
            "generation request timed out after 0.01s",
        ):
            generate_image.call_with_timeout(lambda: time.sleep(1), 0.01)


if __name__ == "__main__":
    unittest.main()
