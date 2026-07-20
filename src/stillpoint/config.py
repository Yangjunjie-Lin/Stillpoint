"""Central configuration for Stillpoint."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class GameConfig:
    """Tunable gameplay and rendering values."""

    title: str = "Stillpoint"
    frame_delay_ms: int = 16
    base_map_size: int = 2400
    player_size: int = 40
    obstacle_size: int = 40
    item_size: int = 20
    visible_radius: int = 320
    base_speed: float = 7.0
    acceleration: float = 0.45
    friction: float = 0.84
    bullet_speed: float = 15.0
    bullet_size: int = 6
    shooting_cooldown: float = 0.5
    base_obstacle_count: int = 10
    max_obstacle_count: int = 60
    score_threshold: int = 200
    item_spawn_interval_seconds: float = 4.0
    initial_item_count: int = 10
    autosave_interval_seconds: float = 30.0
    autosave_max_age_seconds: float = 86_400.0
    leaderboard_size: int = 10


DEFAULT_CONFIG = GameConfig()
