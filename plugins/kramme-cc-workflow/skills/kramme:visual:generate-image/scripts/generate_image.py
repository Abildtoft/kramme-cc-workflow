#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "google-genai>=1.0.0",
#     "pillow>=10.0.0",
# ]
# ///
"""
Generate images using Google's Nano Banana Pro (Gemini 3 Pro Image) API.

Usage:
    uv run generate_image.py --prompt "your image description" --filename "output.png" [--resolution 1K|2K|4K] [--api-key KEY]
"""

from __future__ import annotations

import argparse
import os
import signal
import sys
import threading
import time
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path
from typing import Any


MODEL_NAME = "gemini-3-pro-image-preview"
GENERATION_TIMEOUT_ENV = "GENERATE_IMAGE_TIMEOUT_SECONDS"
GENERATION_MAX_RETRIES_ENV = "GENERATE_IMAGE_MAX_RETRIES"
GENERATION_RETRY_DELAY_ENV = "GENERATE_IMAGE_RETRY_DELAY_SECONDS"
DEFAULT_GENERATION_TIMEOUT_SECONDS = 120.0
DEFAULT_GENERATION_MAX_RETRIES = 2
DEFAULT_GENERATION_RETRY_DELAY_SECONDS = 1.0
RETRYABLE_STATUS_CODES = {408, 409, 425, 429, 500, 502, 503, 504}
RETRYABLE_CODE_NAMES = {
    "DEADLINE_EXCEEDED",
    "INTERNAL",
    "RESOURCE_EXHAUSTED",
    "SERVICE_UNAVAILABLE",
    "UNAVAILABLE",
}


class GenerationTimeoutError(TimeoutError):
    """Raised when a generation request exceeds the configured timeout."""


def get_api_key(provided_key: str | None) -> str | None:
    """Resolve the Gemini API key."""
    if provided_key:
        return provided_key
    return os.environ.get("GEMINI_API_KEY")


def positive_float_from_env(name: str, default: float) -> float:
    raw_value = os.environ.get(name)
    if raw_value is None or raw_value == "":
        return default

    try:
        value = float(raw_value)
    except ValueError as error:
        raise ValueError(f"{name} must be a positive number") from error

    if value <= 0:
        raise ValueError(f"{name} must be a positive number")
    return value


def nonnegative_float_from_env(name: str, default: float) -> float:
    raw_value = os.environ.get(name)
    if raw_value is None or raw_value == "":
        return default

    try:
        value = float(raw_value)
    except ValueError as error:
        raise ValueError(f"{name} must be a non-negative number") from error

    if value < 0:
        raise ValueError(f"{name} must be a non-negative number")
    return value


def nonnegative_int_from_env(name: str, default: int) -> int:
    raw_value = os.environ.get(name)
    if raw_value is None or raw_value == "":
        return default

    try:
        value = int(raw_value)
    except ValueError as error:
        raise ValueError(f"{name} must be a non-negative integer") from error

    if value < 0:
        raise ValueError(f"{name} must be a non-negative integer")
    return value


def call_with_timeout(callback: Callable[[], Any], timeout_seconds: float) -> Any:
    if (
        threading.current_thread() is not threading.main_thread()
        or not hasattr(signal, "SIGALRM")
        or not hasattr(signal, "setitimer")
    ):
        return callback()

    previous_handler = signal.getsignal(signal.SIGALRM)

    def raise_timeout(_signum: int, _frame: Any) -> None:
        raise GenerationTimeoutError(f"generation request timed out after {timeout_seconds:g}s")

    signal.signal(signal.SIGALRM, raise_timeout)
    signal.setitimer(signal.ITIMER_REAL, timeout_seconds)
    try:
        return callback()
    finally:
        signal.setitimer(signal.ITIMER_REAL, 0)
        signal.signal(signal.SIGALRM, previous_handler)


def retryable_error_code(error: Exception) -> str | int | None:
    status_code = getattr(error, "status_code", None)
    if isinstance(status_code, int):
        return status_code

    code = getattr(error, "code", None)
    if callable(code):
        try:
            code = code()
        except Exception:
            code = None
    if isinstance(code, (int, str)):
        return code

    return None


def is_retryable_generation_error(error: Exception) -> bool:
    if isinstance(error, (TimeoutError, ConnectionError)):
        return True

    code = retryable_error_code(error)
    if isinstance(code, int):
        return code in RETRYABLE_STATUS_CODES
    if isinstance(code, str):
        return code.upper() in RETRYABLE_CODE_NAMES

    error_name = error.__class__.__name__.lower()
    return "timeout" in error_name or "temporar" in error_name


def generate_content_once(
    client: Any,
    genai_types: Any,
    contents: Any,
    output_resolution: str,
) -> Any:
    return client.models.generate_content(
        model=MODEL_NAME,
        contents=contents,
        config=genai_types.GenerateContentConfig(
            response_modalities=["TEXT", "IMAGE"],
            image_config=genai_types.ImageConfig(image_size=output_resolution),
        ),
    )


def generate_content_with_retries(
    client: Any,
    genai_types: Any,
    contents: Any,
    output_resolution: str,
    *,
    timeout_seconds: float,
    max_retries: int,
    retry_delay_seconds: float,
    sleep: Callable[[float], None] = time.sleep,
) -> Any:
    max_attempts = max_retries + 1

    for attempt in range(1, max_attempts + 1):
        try:
            return call_with_timeout(
                lambda: generate_content_once(
                    client,
                    genai_types,
                    contents,
                    output_resolution,
                ),
                timeout_seconds,
            )
        except Exception as error:
            if attempt >= max_attempts or not is_retryable_generation_error(error):
                raise

            print(
                f"Warning: image generation attempt {attempt} failed: {error}; retrying...",
                file=sys.stderr,
            )
            if retry_delay_seconds > 0:
                sleep(retry_delay_seconds)

    raise RuntimeError("image generation retry loop exhausted unexpectedly")


@dataclass
class GenerationSettings:
    timeout_seconds: float
    max_retries: int
    retry_delay_seconds: float


class ImageDecodeError(Exception):
    """Raised when generated inline image data cannot be decoded."""


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Generate images using Nano Banana Pro (Gemini 3 Pro Image)")
    parser.add_argument("--prompt", "-p", required=True, help="Image description/prompt")
    parser.add_argument("--filename", "-f", required=True, help="Output filename (e.g., sunset-mountains.png)")
    parser.add_argument("--input-image", "-i", help="Optional input image path for editing/modification")
    parser.add_argument(
        "--resolution",
        "-r",
        choices=["1K", "2K", "4K"],
        default="1K",
        help="Output resolution: 1K (default), 2K, or 4K",
    )
    parser.add_argument("--api-key", "-k", help="Gemini API key (overrides GEMINI_API_KEY env var)")
    return parser


def load_generation_settings() -> GenerationSettings:
    """Resolve timeout/retry settings from the environment, raising ValueError on bad input."""
    return GenerationSettings(
        timeout_seconds=positive_float_from_env(
            GENERATION_TIMEOUT_ENV,
            DEFAULT_GENERATION_TIMEOUT_SECONDS,
        ),
        max_retries=nonnegative_int_from_env(
            GENERATION_MAX_RETRIES_ENV,
            DEFAULT_GENERATION_MAX_RETRIES,
        ),
        retry_delay_seconds=nonnegative_float_from_env(
            GENERATION_RETRY_DELAY_ENV,
            DEFAULT_GENERATION_RETRY_DELAY_SECONDS,
        ),
    )


def load_input_image(path: str, requested_resolution: str, pil_image_module: Any) -> tuple[Any, str]:
    """Load an input image, auto-detecting resolution when the caller left it at the default."""
    image = pil_image_module.open(path)
    print(f"Loaded input image: {path}")

    resolution = requested_resolution
    if requested_resolution == "1K":  # Default value
        width, height = image.size
        max_dim = max(width, height)
        if max_dim >= 3000:
            resolution = "4K"
        elif max_dim >= 1500:
            resolution = "2K"
        else:
            resolution = "1K"
        print(f"Auto-detected resolution: {resolution} (from input {width}x{height})")
    return image, resolution


def decode_response_image(image_data: Any, pil_image_module: Any) -> Any:
    from io import BytesIO

    try:
        # inline_data.data is normally bytes; base64-decode it if it arrived as a string.
        if isinstance(image_data, str):
            import base64

            image_data = base64.b64decode(image_data)
        return pil_image_module.open(BytesIO(image_data))
    except Exception as error:
        raise ImageDecodeError(str(error)) from error


def save_response_image(image: Any, output_path: Path, pil_image_module: Any) -> None:
    # Ensure RGB mode for PNG (convert RGBA to RGB with white background if needed).
    if image.mode == "RGBA":
        rgb_image = pil_image_module.new("RGB", image.size, (255, 255, 255))
        rgb_image.paste(image, mask=image.split()[3])
        rgb_image.save(str(output_path), "PNG")
    elif image.mode == "RGB":
        image.save(str(output_path), "PNG")
    else:
        image.convert("RGB").save(str(output_path), "PNG")


def save_response_parts(response: Any, output_path: Path, pil_image_module: Any) -> bool:
    """Print model text parts and save any generated image; return whether an image was saved."""
    image_saved = False
    for part in response.parts or []:
        if part.text is not None:
            print(f"Model response: {part.text}")
        elif part.inline_data is not None:
            image = decode_response_image(part.inline_data.data, pil_image_module)
            save_response_image(image, output_path, pil_image_module)
            image_saved = True
    return image_saved


def main() -> int:
    args = build_arg_parser().parse_args()

    try:
        settings = load_generation_settings()
    except ValueError as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1

    api_key = get_api_key(args.api_key)
    if not api_key:
        print("Error: No API key provided.", file=sys.stderr)
        print("Please either:", file=sys.stderr)
        print("  1. Provide --api-key argument", file=sys.stderr)
        print("  2. Set GEMINI_API_KEY environment variable", file=sys.stderr)
        return 1

    # Import here after checking API key to avoid slow import on error
    from google import genai
    from google.genai import types
    from PIL import Image as PILImage

    client = genai.Client(api_key=api_key)
    output_path = Path(args.filename)

    try:
        output_path.parent.mkdir(parents=True, exist_ok=True)
    except OSError as error:
        print(f"Error creating output directory: {error}", file=sys.stderr)
        return 1

    input_image = None
    output_resolution = args.resolution
    if args.input_image:
        try:
            input_image, output_resolution = load_input_image(args.input_image, args.resolution, PILImage)
        except Exception as error:
            print(f"Error loading input image: {error}", file=sys.stderr)
            return 1

    # Build contents (image first if editing, prompt only if generating)
    if input_image:
        contents = [input_image, args.prompt]
        print(f"Editing image with resolution {output_resolution}...")
    else:
        contents = args.prompt
        print(f"Generating image with resolution {output_resolution}...")

    try:
        response = generate_content_with_retries(
            client,
            types,
            contents,
            output_resolution,
            timeout_seconds=settings.timeout_seconds,
            max_retries=settings.max_retries,
            retry_delay_seconds=settings.retry_delay_seconds,
        )
    except Exception as error:
        print(f"Error generating image: {error}", file=sys.stderr)
        return 1

    try:
        image_saved = save_response_parts(response, output_path, PILImage)
    except ImageDecodeError as error:
        print(f"Error decoding generated image: {error}", file=sys.stderr)
        return 1
    except OSError as error:
        print(f"Error saving image: {error}", file=sys.stderr)
        return 1

    if not image_saved:
        print("Error: No image was generated in the response.", file=sys.stderr)
        return 1

    print(f"\nImage saved: {output_path.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
