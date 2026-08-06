from __future__ import annotations

import base64
import contextlib
import importlib.util
import io
import signal
import sys
import tempfile
import time
import types as module_types
import unittest
from pathlib import Path
from typing import Any
from unittest import mock

SCRIPT_PATH = (
    Path(__file__).resolve().parents[2] / "skills" / "kramme:visual:generate-image" / "scripts" / "generate_image.py"
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


class GenerateImageSettingsTest(unittest.TestCase):
    def test_load_generation_settings_uses_defaults_without_env(self) -> None:
        env_overrides = {
            generate_image.GENERATION_TIMEOUT_ENV: "",
            generate_image.GENERATION_MAX_RETRIES_ENV: "",
            generate_image.GENERATION_RETRY_DELAY_ENV: "",
        }
        with mock.patch.dict("os.environ", env_overrides):
            settings = generate_image.load_generation_settings()

        self.assertEqual(settings.timeout_seconds, generate_image.DEFAULT_GENERATION_TIMEOUT_SECONDS)
        self.assertEqual(settings.max_retries, generate_image.DEFAULT_GENERATION_MAX_RETRIES)
        self.assertEqual(settings.retry_delay_seconds, generate_image.DEFAULT_GENERATION_RETRY_DELAY_SECONDS)

    def test_load_generation_settings_rejects_invalid_timeout(self) -> None:
        with mock.patch.dict(
            "os.environ",
            {generate_image.GENERATION_TIMEOUT_ENV: "not-a-number"},
        ):
            with self.assertRaisesRegex(ValueError, "must be a positive number"):
                generate_image.load_generation_settings()


class FakeImage:
    def __init__(self, mode: str, size: tuple[int, int] = (10, 10)) -> None:
        self.mode = mode
        self.size = size
        self.paste_calls: list[FakeImage] = []
        self.convert_calls: list[str] = []
        self.save_calls: list[tuple[str, str]] = []

    def split(self) -> tuple[Any, ...]:
        return (None, None, None, self)

    def paste(self, source: FakeImage, mask: FakeImage) -> None:
        self.paste_calls.append(source)

    def convert(self, mode: str) -> FakeImage:
        self.convert_calls.append(mode)
        return FakeImage(mode, self.size)

    def save(self, path: str, image_format: str) -> None:
        self.save_calls.append((path, image_format))
        with open(path, "wb") as handle:
            handle.write(f"fake-{image_format.lower()}-bytes".encode())


class FakePILImageModule:
    INVALID_IMAGE_BYTES = b"__invalid_image__"

    def __init__(
        self,
        path_sizes: dict[str, tuple[int, int]] | None = None,
        image_mode: str = "RGB",
    ) -> None:
        self.path_sizes = path_sizes or {}
        self.image_mode = image_mode
        self.new_images: list[FakeImage] = []

    def open(self, source: Any) -> FakeImage:
        if hasattr(source, "read"):
            data = source.read()
            if data == self.INVALID_IMAGE_BYTES:
                raise ValueError("cannot identify image data")
            return FakeImage(self.image_mode)
        size = self.path_sizes.get(str(source), (10, 10))
        return FakeImage(self.image_mode, size)

    def new(self, mode: str, size: tuple[int, int], color: Any) -> FakeImage:
        created = FakeImage(mode, size)
        self.new_images.append(created)
        return created


class GenerateImageInputLoadTest(unittest.TestCase):
    def test_auto_detects_resolution_from_large_input_image(self) -> None:
        pil_module = FakePILImageModule(path_sizes={"input.png": (4000, 2000)})

        with contextlib.redirect_stdout(io.StringIO()):
            image, resolution = generate_image.load_input_image("input.png", "1K", pil_module)

        self.assertEqual(image.size, (4000, 2000))
        self.assertEqual(resolution, "4K")

    def test_auto_detects_resolution_from_medium_input_image(self) -> None:
        pil_module = FakePILImageModule(path_sizes={"input.png": (1600, 900)})

        with contextlib.redirect_stdout(io.StringIO()):
            _, resolution = generate_image.load_input_image("input.png", "1K", pil_module)

        self.assertEqual(resolution, "2K")

    def test_auto_detects_resolution_from_small_input_image(self) -> None:
        pil_module = FakePILImageModule(path_sizes={"input.png": (800, 600)})

        with contextlib.redirect_stdout(io.StringIO()):
            _, resolution = generate_image.load_input_image("input.png", "1K", pil_module)

        self.assertEqual(resolution, "1K")

    def test_preserves_explicit_resolution_for_small_input_image(self) -> None:
        pil_module = FakePILImageModule(path_sizes={"input.png": (800, 600)})

        with contextlib.redirect_stdout(io.StringIO()):
            _, resolution = generate_image.load_input_image("input.png", "4K", pil_module)

        self.assertEqual(resolution, "4K")


class GenerateImageResponseSaveTest(unittest.TestCase):
    def test_decode_response_image_accepts_raw_bytes(self) -> None:
        pil_module = FakePILImageModule()

        image = generate_image.decode_response_image(b"raw-bytes", pil_module)

        self.assertEqual(image.mode, "RGB")

    def test_decode_response_image_accepts_base64_string(self) -> None:
        pil_module = FakePILImageModule()
        encoded = base64.b64encode(b"raw-bytes").decode()

        image = generate_image.decode_response_image(encoded, pil_module)

        self.assertEqual(image.mode, "RGB")

    def test_decode_response_image_raises_on_invalid_data(self) -> None:
        pil_module = FakePILImageModule()

        with self.assertRaisesRegex(generate_image.ImageDecodeError, "cannot identify image data"):
            generate_image.decode_response_image(FakePILImageModule.INVALID_IMAGE_BYTES, pil_module)

    def test_decode_response_image_raises_on_invalid_base64_string(self) -> None:
        pil_module = FakePILImageModule()

        with self.assertRaises(generate_image.ImageDecodeError):
            generate_image.decode_response_image("not-valid-base64!!!", pil_module)

    def test_save_response_image_converts_rgba_onto_white_background(self) -> None:
        pil_module = FakePILImageModule()
        image = FakeImage("RGBA")

        with tempfile.TemporaryDirectory() as tmp_dir:
            output_path = Path(tmp_dir) / "out.png"
            generate_image.save_response_image(image, output_path, pil_module)

            self.assertEqual(len(pil_module.new_images), 1)
            background = pil_module.new_images[0]
            self.assertEqual(background.mode, "RGB")
            self.assertEqual(background.paste_calls, [image])
            self.assertEqual(background.save_calls, [(str(output_path), "PNG")])
            self.assertEqual(image.convert_calls, [])
            self.assertTrue(output_path.exists())

    def test_save_response_image_saves_rgb_directly_without_conversion(self) -> None:
        pil_module = FakePILImageModule()
        image = FakeImage("RGB")

        with tempfile.TemporaryDirectory() as tmp_dir:
            output_path = Path(tmp_dir) / "out.png"
            generate_image.save_response_image(image, output_path, pil_module)

            self.assertEqual(image.convert_calls, [])
            self.assertEqual(image.save_calls, [(str(output_path), "PNG")])
            self.assertEqual(pil_module.new_images, [])
            self.assertTrue(output_path.exists())

    def test_save_response_image_converts_other_modes_to_rgb(self) -> None:
        pil_module = FakePILImageModule()
        image = FakeImage("P")

        with tempfile.TemporaryDirectory() as tmp_dir:
            output_path = Path(tmp_dir) / "out.png"
            generate_image.save_response_image(image, output_path, pil_module)

            self.assertEqual(image.convert_calls, ["RGB"])
            self.assertEqual(pil_module.new_images, [])
            self.assertTrue(output_path.exists())

    def test_save_response_image_propagates_unwritable_destination(self) -> None:
        pil_module = FakePILImageModule()
        image = FakeImage("RGB")

        with tempfile.TemporaryDirectory() as tmp_dir:
            with self.assertRaises(OSError):
                generate_image.save_response_image(image, Path(tmp_dir), pil_module)

    def test_save_response_parts_reports_no_image_when_only_text(self) -> None:
        pil_module = FakePILImageModule()
        response = FakeResponse([FakePart(text="no image here")])

        with tempfile.TemporaryDirectory() as tmp_dir:
            output_path = Path(tmp_dir) / "out.png"
            with contextlib.redirect_stdout(io.StringIO()):
                image_saved = generate_image.save_response_parts(response, output_path, pil_module)

        self.assertFalse(image_saved)

    def test_save_response_parts_saves_generated_image(self) -> None:
        pil_module = FakePILImageModule()
        response = FakeResponse(
            [
                FakePart(text="a caption"),
                FakePart(inline_data=FakeInlineData(b"raw-bytes")),
            ]
        )

        with tempfile.TemporaryDirectory() as tmp_dir:
            output_path = Path(tmp_dir) / "out.png"
            with contextlib.redirect_stdout(io.StringIO()):
                image_saved = generate_image.save_response_parts(response, output_path, pil_module)

            self.assertTrue(image_saved)
            self.assertTrue(output_path.exists())


class FakePart:
    def __init__(self, *, text: str | None = None, inline_data: FakeInlineData | None = None) -> None:
        self.text = text
        self.inline_data = inline_data


class FakeInlineData:
    def __init__(self, data: Any) -> None:
        self.data = data


class FakeResponse:
    def __init__(self, parts: list[FakePart] | None) -> None:
        self.parts = parts


class GenerateImageMainTest(unittest.TestCase):
    def setUp(self) -> None:
        self._original_modules: dict[str, Any] = {}
        self.addCleanup(self._restore_modules)

    def _restore_modules(self) -> None:
        for name, previous in self._original_modules.items():
            if previous is None:
                sys.modules.pop(name, None)
            else:
                sys.modules[name] = previous

    def _install_fake_dependencies(
        self,
        outcomes: list[Any],
        *,
        path_sizes: dict[str, tuple[int, int]] | None = None,
    ) -> None:
        def client_factory(api_key: str | None = None) -> FakeClient:
            return FakeClient(list(outcomes))

        fake_genai_module = module_types.ModuleType("google.genai")
        fake_genai_module.Client = client_factory
        fake_genai_module.types = FakeTypes

        fake_google_module = module_types.ModuleType("google")
        fake_google_module.genai = fake_genai_module

        fake_pil_module = module_types.ModuleType("PIL")
        fake_pil_module.Image = FakePILImageModule(path_sizes=path_sizes)

        for name, module in (
            ("google", fake_google_module),
            ("google.genai", fake_genai_module),
            ("PIL", fake_pil_module),
        ):
            self._original_modules[name] = sys.modules.get(name)
            sys.modules[name] = module

    def _run_main(self, argv: list[str]) -> tuple[int, str, str]:
        stdout = io.StringIO()
        stderr = io.StringIO()
        original_argv = sys.argv
        sys.argv = ["generate_image.py", *argv]
        try:
            with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                exit_code = generate_image.main()
        finally:
            sys.argv = original_argv
        return exit_code, stdout.getvalue(), stderr.getvalue()

    def test_text_mode_generates_and_saves_image(self) -> None:
        response = FakeResponse(
            [
                FakePart(text="a caption"),
                FakePart(inline_data=FakeInlineData(b"raw-bytes")),
            ]
        )
        self._install_fake_dependencies([response])

        with tempfile.TemporaryDirectory() as tmp_dir:
            output_path = Path(tmp_dir) / "out" / "image.png"
            exit_code, stdout, stderr = self._run_main(
                [
                    "--prompt",
                    "a cat",
                    "--filename",
                    str(output_path),
                    "--api-key",
                    "test-key",
                ]
            )

            self.assertEqual(exit_code, 0, stderr)
            self.assertIn("Generating image with resolution 1K", stdout)
            self.assertIn("Model response: a caption", stdout)
            self.assertIn("Image saved:", stdout)
            self.assertTrue(output_path.exists())

    def test_image_mode_auto_detects_resolution(self) -> None:
        response = FakeResponse([FakePart(inline_data=FakeInlineData(b"raw-bytes"))])
        self._install_fake_dependencies([response], path_sizes={"input.png": (4000, 2000)})

        with tempfile.TemporaryDirectory() as tmp_dir:
            output_path = Path(tmp_dir) / "image.png"
            exit_code, stdout, stderr = self._run_main(
                [
                    "--prompt",
                    "edit this",
                    "--filename",
                    str(output_path),
                    "--input-image",
                    "input.png",
                    "--api-key",
                    "test-key",
                ]
            )

            self.assertEqual(exit_code, 0, stderr)
            self.assertIn("Auto-detected resolution: 4K (from input 4000x2000)", stdout)
            self.assertIn("Editing image with resolution 4K", stdout)

    def test_missing_api_key_fails_without_generating(self) -> None:
        self._install_fake_dependencies([])

        with tempfile.TemporaryDirectory() as tmp_dir:
            output_path = Path(tmp_dir) / "image.png"
            with mock.patch.dict("os.environ", {"GEMINI_API_KEY": ""}):
                exit_code, _stdout, stderr = self._run_main(
                    [
                        "--prompt",
                        "a cat",
                        "--filename",
                        str(output_path),
                    ]
                )

            self.assertEqual(exit_code, 1)
            self.assertIn("No API key provided", stderr)

    def test_mkdir_failure_reports_directory_error(self) -> None:
        self._install_fake_dependencies([FakeResponse([FakePart(inline_data=FakeInlineData(b"raw-bytes"))])])

        with tempfile.TemporaryDirectory() as tmp_dir:
            blocker_path = Path(tmp_dir) / "blocker"
            blocker_path.write_text("not a directory")
            output_path = blocker_path / "image.png"

            exit_code, _stdout, stderr = self._run_main(
                [
                    "--prompt",
                    "a cat",
                    "--filename",
                    str(output_path),
                    "--api-key",
                    "test-key",
                ]
            )

            self.assertEqual(exit_code, 1)
            self.assertIn("Error creating output directory:", stderr)

    def test_api_failure_reports_generation_error(self) -> None:
        self._install_fake_dependencies([ValueError("model rejected the request")])

        with tempfile.TemporaryDirectory() as tmp_dir:
            output_path = Path(tmp_dir) / "image.png"
            exit_code, _stdout, stderr = self._run_main(
                [
                    "--prompt",
                    "a cat",
                    "--filename",
                    str(output_path),
                    "--api-key",
                    "test-key",
                ]
            )

            self.assertEqual(exit_code, 1)
            self.assertIn("Error generating image: model rejected the request", stderr)

    def test_invalid_response_image_reports_decode_error(self) -> None:
        response = FakeResponse([FakePart(inline_data=FakeInlineData(FakePILImageModule.INVALID_IMAGE_BYTES))])
        self._install_fake_dependencies([response])

        with tempfile.TemporaryDirectory() as tmp_dir:
            output_path = Path(tmp_dir) / "image.png"
            exit_code, _stdout, stderr = self._run_main(
                [
                    "--prompt",
                    "a cat",
                    "--filename",
                    str(output_path),
                    "--api-key",
                    "test-key",
                ]
            )

            self.assertEqual(exit_code, 1)
            self.assertIn("Error decoding generated image:", stderr)

    def test_unwritable_output_reports_save_error(self) -> None:
        response = FakeResponse([FakePart(inline_data=FakeInlineData(b"raw-bytes"))])
        self._install_fake_dependencies([response])

        with tempfile.TemporaryDirectory() as tmp_dir:
            # A directory in place of the output file makes the save itself unwritable.
            output_path = Path(tmp_dir)
            exit_code, _stdout, stderr = self._run_main(
                [
                    "--prompt",
                    "a cat",
                    "--filename",
                    str(output_path),
                    "--api-key",
                    "test-key",
                ]
            )

            self.assertEqual(exit_code, 1)
            self.assertIn("Error saving image:", stderr)

    def test_no_image_in_response_reports_error(self) -> None:
        response = FakeResponse([FakePart(text="just talk, no picture")])
        self._install_fake_dependencies([response])

        with tempfile.TemporaryDirectory() as tmp_dir:
            output_path = Path(tmp_dir) / "image.png"
            exit_code, _stdout, stderr = self._run_main(
                [
                    "--prompt",
                    "a cat",
                    "--filename",
                    str(output_path),
                    "--api-key",
                    "test-key",
                ]
            )

            self.assertEqual(exit_code, 1)
            self.assertIn("No image was generated", stderr)

    def test_response_with_no_parts_reports_error_instead_of_crashing(self) -> None:
        # google-genai returns parts=None for a blocked/candidate-less response.
        response = FakeResponse(None)
        self._install_fake_dependencies([response])

        with tempfile.TemporaryDirectory() as tmp_dir:
            output_path = Path(tmp_dir) / "image.png"
            exit_code, _stdout, stderr = self._run_main(
                [
                    "--prompt",
                    "a cat",
                    "--filename",
                    str(output_path),
                    "--api-key",
                    "test-key",
                ]
            )

            self.assertEqual(exit_code, 1)
            self.assertIn("No image was generated", stderr)


if __name__ == "__main__":
    unittest.main()
