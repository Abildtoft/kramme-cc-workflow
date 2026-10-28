from __future__ import annotations

from dataclasses import replace
from typing import Any

from .strings import is_empty_value


def readme_summaries_configured(config: dict[str, Any]) -> bool:
    return "summaries" in config


def apply_readme_summaries(
    label: str,
    component_type: str,
    references: dict[str, Any],
    config: dict[str, Any],
    failures: list[str],
) -> dict[str, Any]:
    """Swap each component's README description for its configured summary.

    The README shows a short human summary while the full routing description
    stays in the component source. Without a ``summaries`` object, the README
    keeps the full source description.
    """
    if not readme_summaries_configured(config):
        return references
    summaries = config["summaries"]
    if not isinstance(summaries, dict):
        failures.append(f"{label}: summaries must be an object keyed by {component_type} name")
        return references
    max_chars = config.get("max_summary_chars", 0)
    if not isinstance(max_chars, int) or isinstance(max_chars, bool) or max_chars < 0:
        failures.append(f"{label}: max_summary_chars must be a non-negative integer")
        max_chars = 0

    for name in sorted(set(summaries) - set(references)):
        failures.append(f"{label}: summaries names unknown {component_type} {name!r}")

    summarized: dict[str, Any] = {}
    for name, reference in references.items():
        summary = summaries.get(name)
        if not isinstance(summary, str) or is_empty_value(summary):
            failures.append(f"{label}: summaries is missing {component_type} {name!r}")
            summarized[name] = reference
            continue
        if max_chars and len(summary) > max_chars:
            failures.append(f"{label}: summary for {name!r} is {len(summary)} chars, exceeds {max_chars}")
        summarized[name] = replace(reference, description=summary)
    return summarized
