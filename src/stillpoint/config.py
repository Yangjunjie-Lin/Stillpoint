"""Central configuration for Stillpoint."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Final, Mapping


BACKGROUND_SCALE_MODE = "cover"
SAVE_VERSION = 3

# Player combat baselines (session combat level starts at 1 each run).
PLAYER_BASE_MAX_HEALTH = 100.0
PLAYER_BASE_DEFENSE = 0.0
PLAYER_BASE_BULLET_DAMAGE = 12.0
PLAYER_HIT_INVULNERABILITY = 0.75
PLAYER_HIT_FLASH_DURATION = 0.25
MINIMUM_DAMAGE = 1.0

# Session combat-level progression (not permanent account level).
EXPERIENCE_BASE = 100.0
EXPERIENCE_EXPONENT = 1.35
HEALTH_GAIN_PER_LEVEL = 10.0
HEALTH_RESTORE_ON_LEVEL_UP = 20.0
DAMAGE_GAIN_PER_LEVEL = 1.0
COOLDOWN_REDUCTION_PER_LEVEL = 0.02
MAX_COOLDOWN_REDUCTION = 0.25
MIN_SHOOTING_COOLDOWN = 0.18
LEVEL_UP_EFFECT_DURATION = 2.0

# Enemy HUD
ENEMY_HEALTH_BAR_DURATION = 3.0
ENEMY_HEALTH_BAR_WIDTH = 40
ENEMY_HEALTH_BAR_HEIGHT = 5
ENEMY_HIT_FLASH_DURATION = 0.18
FLOATING_TEXT_LIFETIME = 0.85

# Difficulty scaling applied once at enemy spawn (not every frame).
ENEMY_HEALTH_DIFFICULTY_FACTOR = 0.12
ENEMY_DAMAGE_DIFFICULTY_FACTOR = 0.08
ENEMY_REWARD_DIFFICULTY_FACTOR = 0.05

ENEMY_ARCHETYPES: Final[Mapping[str, Mapping[str, float | int]]] = {
    "chase": {
        "max_health": 30,
        "attack_damage": 10,
        "experience_reward": 12,
        "score_reward": 20,
    },
    "avoid": {
        "max_health": 20,
        "attack_damage": 6,
        "experience_reward": 8,
        "score_reward": 15,
    },
    "circle": {
        "max_health": 45,
        "attack_damage": 15,
        "experience_reward": 18,
        "score_reward": 30,
    },
}


@dataclass(frozen=True, slots=True)
class GameConfig:
    """Tunable gameplay and rendering values."""

    title: str = "Stillpoint"
    frame_delay_ms: int = 16
    base_world_width: int = 2400
    base_world_height: int = 2400
    background_scale_mode: str = BACKGROUND_SCALE_MODE
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

    # Combat
    player_base_max_health: float = PLAYER_BASE_MAX_HEALTH
    player_base_defense: float = PLAYER_BASE_DEFENSE
    player_base_bullet_damage: float = PLAYER_BASE_BULLET_DAMAGE
    player_hit_invulnerability: float = PLAYER_HIT_INVULNERABILITY
    player_hit_flash_duration: float = PLAYER_HIT_FLASH_DURATION
    minimum_damage: float = MINIMUM_DAMAGE
    experience_base: float = EXPERIENCE_BASE
    experience_exponent: float = EXPERIENCE_EXPONENT
    health_gain_per_level: float = HEALTH_GAIN_PER_LEVEL
    health_restore_on_level_up: float = HEALTH_RESTORE_ON_LEVEL_UP
    damage_gain_per_level: float = DAMAGE_GAIN_PER_LEVEL
    cooldown_reduction_per_level: float = COOLDOWN_REDUCTION_PER_LEVEL
    max_cooldown_reduction: float = MAX_COOLDOWN_REDUCTION
    min_shooting_cooldown: float = MIN_SHOOTING_COOLDOWN
    level_up_effect_duration: float = LEVEL_UP_EFFECT_DURATION
    enemy_health_bar_duration: float = ENEMY_HEALTH_BAR_DURATION
    enemy_health_bar_width: int = ENEMY_HEALTH_BAR_WIDTH
    enemy_health_bar_height: int = ENEMY_HEALTH_BAR_HEIGHT
    enemy_hit_flash_duration: float = ENEMY_HIT_FLASH_DURATION
    floating_text_lifetime: float = FLOATING_TEXT_LIFETIME
    enemy_health_difficulty_factor: float = ENEMY_HEALTH_DIFFICULTY_FACTOR
    enemy_damage_difficulty_factor: float = ENEMY_DAMAGE_DIFFICULTY_FACTOR
    enemy_reward_difficulty_factor: float = ENEMY_REWARD_DIFFICULTY_FACTOR


DEFAULT_CONFIG = GameConfig()
