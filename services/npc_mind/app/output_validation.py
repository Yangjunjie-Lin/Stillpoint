from __future__ import annotations

from typing import Any

from .schemas import NpcGenerationResult


def validate_structured_output(value: Any, max_output_chars: int = 12000) -> NpcGenerationResult:
    """Validate model output and keep gameplay state out of the result path."""
    result = (
        value
        if isinstance(value, NpcGenerationResult)
        else NpcGenerationResult.model_validate(value)
    )
    if len(result.reply_text) > max_output_chars:
        raise ValueError("output_too_long")
    # 0.8.0 exposes proposed intents for audit only; deterministic gameplay
    # validators can be added later without granting the model authority.
    return result
