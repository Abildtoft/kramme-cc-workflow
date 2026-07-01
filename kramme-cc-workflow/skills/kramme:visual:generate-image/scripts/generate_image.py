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
        raise GenerationTimeoutError(
            f"generation request timed out after {timeout_seconds:g}s"
        )

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
                "Warning: image generation attempt "
                f"{attempt} failed: {error}; retrying...",
                file=sys.stderr,
            )
            if retry_delay_seconds > 0:
                sleep(retry_delay_seconds)

    raise RuntimeError("image generation retry loop exhausted unexpectedly")


def main():
    parser = argparse.ArgumentParser(
        description="Generate images using Nano Banana Pro (Gemini 3 Pro Image)"
    )
    parser.add_argument(
        "--prompt", "-p",
        required=True,
        help="Image description/prompt"
    )
    parser.add_argument(
        "--filename", "-f",
        required=True,
        help="Output filename (e.g., sunset-mountains.png)"
    )
    parser.add_argument(
        "--input-image", "-i",
        help="Optional input image path for editing/modification"
    )
    parser.add_argument(
        "--resolution", "-r",
        choices=["1K", "2K", "4K"],
        default="1K",
        help="Output resolution: 1K (default), 2K, or 4K"
    )
    parser.add_argument(
        "--api-key", "-k",
        help="Gemini API key (overrides GEMINI_API_KEY env var)"
    )

    args = parser.parse_args()

    try:
        timeout_seconds = positive_float_from_env(
            GENERATION_TIMEOUT_ENV,
            DEFAULT_GENERATION_TIMEOUT_SECONDS,
        )
        max_retries = nonnegative_int_from_env(
            GENERATION_MAX_RETRIES_ENV,
            DEFAULT_GENERATION_MAX_RETRIES,
        )
        retry_delay_seconds = nonnegative_float_from_env(
            GENERATION_RETRY_DELAY_ENV,
            DEFAULT_GENERATION_RETRY_DELAY_SECONDS,
        )
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    # Get API key
    api_key = get_api_key(args.api_key)
    if not api_key:
        print("Error: No API key provided.", file=sys.stderr)
        print("Please either:", file=sys.stderr)
        print("  1. Provide --api-key argument", file=sys.stderr)
        print("  2. Set GEMINI_API_KEY environment variable", file=sys.stderr)
        sys.exit(1)

    # Import here after checking API key to avoid slow import on error
    from google import genai
    from google.genai import types
    from PIL import Image as PILImage

    # Initialise client
    client = genai.Client(api_key=api_key)

    # Set up output path
    output_path = Path(args.filename)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Load input image if provided
    input_image = None
    output_resolution = args.resolution
    if args.input_image:
        try:
            input_image = PILImage.open(args.input_image)
            print(f"Loaded input image: {args.input_image}")

            # Auto-detect resolution if not explicitly set by user
            if args.resolution == "1K":  # Default value
                # Map input image size to resolution
                width, height = input_image.size
                max_dim = max(width, height)
                if max_dim >= 3000:
                    output_resolution = "4K"
                elif max_dim >= 1500:
                    output_resolution = "2K"
                else:
                    output_resolution = "1K"
                print(f"Auto-detected resolution: {output_resolution} (from input {width}x{height})")
        except Exception as e:
            print(f"Error loading input image: {e}", file=sys.stderr)
            sys.exit(1)

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
            timeout_seconds=timeout_seconds,
            max_retries=max_retries,
            retry_delay_seconds=retry_delay_seconds,
        )

        # Process response and convert to PNG
        image_saved = False
        for part in response.parts:
            if part.text is not None:
                print(f"Model response: {part.text}")
            elif part.inline_data is not None:
                # Convert inline data to PIL Image and save as PNG
                from io import BytesIO

                # inline_data.data is already bytes, not base64
                image_data = part.inline_data.data
                if isinstance(image_data, str):
                    # If it's a string, it might be base64
                    import base64
                    image_data = base64.b64decode(image_data)

                image = PILImage.open(BytesIO(image_data))

                # Ensure RGB mode for PNG (convert RGBA to RGB with white background if needed)
                if image.mode == 'RGBA':
                    rgb_image = PILImage.new('RGB', image.size, (255, 255, 255))
                    rgb_image.paste(image, mask=image.split()[3])
                    rgb_image.save(str(output_path), 'PNG')
                elif image.mode == 'RGB':
                    image.save(str(output_path), 'PNG')
                else:
                    image.convert('RGB').save(str(output_path), 'PNG')
                image_saved = True

        if image_saved:
            full_path = output_path.resolve()
            print(f"\nImage saved: {full_path}")
        else:
            print("Error: No image was generated in the response.", file=sys.stderr)
            sys.exit(1)

    except Exception as e:
        print(f"Error generating image: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
