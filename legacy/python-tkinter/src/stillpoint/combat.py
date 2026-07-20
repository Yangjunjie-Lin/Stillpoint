"""Pure combat helpers shared by the engine and tests (no UI deps)."""

from __future__ import annotations

from .config import EXPERIENCE_BASE, EXPERIENCE_EXPONENT, GameConfig


def calculate_damage(
    incoming_damage: float,
    defense: float,
    minimum_damage: float = 1.0,
) -> float:
    """Apply flat defense. Future % mitigation can replace this without touching callers."""
    return max(float(minimum_damage), float(incoming_damage) - float(defense))


def health_ratio(current_health: float, max_health: float) -> float:
    if max_health <= 0:
        return 0.0
    return max(0.0, min(1.0, float(current_health) / float(max_health)))


def experience_ratio(current_experience: int | float, experience_to_next_level: int | float) -> float:
    if experience_to_next_level <= 0:
        return 0.0
    return max(0.0, min(1.0, float(current_experience) / float(experience_to_next_level)))


def experience_required_for_level(
    level: int,
    *,
    base: float = EXPERIENCE_BASE,
    exponent: float = EXPERIENCE_EXPONENT,
) -> int:
    """XP threshold to advance from ``level`` to ``level + 1`` (session combat level)."""
    safe_level = max(1, int(level))
    return max(1, int(base * (safe_level**exponent)))


def experience_required_for_config(level: int, config: GameConfig) -> int:
    return experience_required_for_level(
        level,
        base=config.experience_base,
        exponent=config.experience_exponent,
    )


def difficulty_level_from_scale(difficulty_scale: float, score_threshold: int) -> int:
    """Integer difficulty tier derived from the existing score-based scale."""
    # difficulty_scale = 1.0 + tier * 0.1
    if score_threshold <= 0:
        return 0
    return max(0, int(round((float(difficulty_scale) - 1.0) / 0.1)))
