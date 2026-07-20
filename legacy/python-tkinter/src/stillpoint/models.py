"""Small domain models used by the game engine and persistence layer."""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from enum import StrEnum
import math
from typing import Any, Mapping
from uuid import uuid4


class ObstacleBehavior(StrEnum):
    CHASE = "chase"
    AVOID = "avoid"
    CIRCLE = "circle"


class EnemyTier(StrEnum):
    """Reserved for future elite/boss content; all current enemies are NORMAL."""

    NORMAL = "normal"
    ELITE = "elite"
    BOSS = "boss"


class ItemType(StrEnum):
    SHIELD = "shield"
    SPEED = "speed"
    POINTS = "points"
    DOUBLE = "double"
    PIERCE = "pierce"
    LARGE = "large"


class WeaponType(StrEnum):
    NORMAL = "normal"
    DOUBLE = "double"
    PIERCE = "pierce"
    LARGE = "large"


@dataclass(slots=True)
class Vec2:
    x: float
    y: float

    def distance_to(self, other: "Vec2") -> float:
        return math.hypot(self.x - other.x, self.y - other.y)

    def normalized(self) -> "Vec2":
        length = math.hypot(self.x, self.y)
        if length == 0:
            return Vec2(0.0, 0.0)
        return Vec2(self.x / length, self.y / length)

    def to_dict(self) -> dict[str, float]:
        return {"x": self.x, "y": self.y}

    @classmethod
    def from_dict(cls, data: Mapping[str, Any]) -> "Vec2":
        return cls(float(data["x"]), float(data["y"]))


@dataclass(slots=True)
class PlayerCombat:
    """Per-run combat progression (session combat level, not permanent profile level)."""

    max_health: float
    current_health: float
    defense: float = 0.0
    invulnerability_until: float = 0.0
    level: int = 1
    current_experience: int = 0
    experience_to_next_level: int = 100
    total_experience: int = 0
    enemies_defeated: int = 0
    bullet_damage: float = 12.0
    cooldown_reduction: float = 0.0
    hit_flash_until: float = 0.0
    level_up_effect_until: float = 0.0
    last_level_gained: int = 1
    death_recorded: bool = False

    @property
    def is_dead(self) -> bool:
        return self.current_health <= 0 or self.death_recorded

    def to_dict(self, now: float) -> dict[str, Any]:
        return {
            "max_health": self.max_health,
            "current_health": self.current_health,
            "defense": self.defense,
            "invulnerability_remaining": _remaining(self.invulnerability_until, now),
            "level": self.level,
            "current_experience": self.current_experience,
            "experience_to_next_level": self.experience_to_next_level,
            "total_experience": self.total_experience,
            "enemies_defeated": self.enemies_defeated,
            "bullet_damage": self.bullet_damage,
            "cooldown_reduction": self.cooldown_reduction,
            "hit_flash_remaining": _remaining(self.hit_flash_until, now),
            "level_up_effect_remaining": _remaining(self.level_up_effect_until, now),
            "last_level_gained": self.last_level_gained,
            "death_recorded": self.death_recorded,
        }

    @classmethod
    def from_dict(cls, data: Mapping[str, Any] | None, now: float, defaults: "PlayerCombat") -> "PlayerCombat":
        payload = data if isinstance(data, Mapping) else {}
        return cls(
            max_health=float(payload.get("max_health", defaults.max_health)),
            current_health=float(payload.get("current_health", defaults.current_health)),
            defense=float(payload.get("defense", defaults.defense)),
            invulnerability_until=_deadline(payload.get("invulnerability_remaining", 0), now),
            level=max(1, int(payload.get("level", defaults.level))),
            current_experience=max(0, int(payload.get("current_experience", defaults.current_experience))),
            experience_to_next_level=max(
                1, int(payload.get("experience_to_next_level", defaults.experience_to_next_level))
            ),
            total_experience=max(0, int(payload.get("total_experience", defaults.total_experience))),
            enemies_defeated=max(0, int(payload.get("enemies_defeated", defaults.enemies_defeated))),
            bullet_damage=float(payload.get("bullet_damage", defaults.bullet_damage)),
            cooldown_reduction=float(payload.get("cooldown_reduction", defaults.cooldown_reduction)),
            hit_flash_until=_deadline(payload.get("hit_flash_remaining", 0), now),
            level_up_effect_until=_deadline(payload.get("level_up_effect_remaining", 0), now),
            last_level_gained=int(payload.get("last_level_gained", defaults.last_level_gained)),
            death_recorded=bool(payload.get("death_recorded", False)),
        )


@dataclass(slots=True)
class FloatingText:
    position: Vec2
    text: str
    color: str
    created_at: float
    lifetime: float = 0.85

    def is_expired(self, now: float) -> bool:
        return now - self.created_at >= self.lifetime

    def to_dict(self, now: float) -> dict[str, Any]:
        return {
            "position": self.position.to_dict(),
            "text": self.text,
            "color": self.color,
            "remaining_lifetime": max(0.0, self.lifetime - (now - self.created_at)),
        }

    @classmethod
    def from_dict(cls, data: Mapping[str, Any], now: float) -> "FloatingText":
        remaining = max(0.0, float(data.get("remaining_lifetime", 0.0)))
        return cls(
            position=Vec2.from_dict(data["position"]),
            text=str(data.get("text", "")),
            color=str(data.get("color", "#ffffff")),
            created_at=now,
            lifetime=remaining,
        )


@dataclass(slots=True)
class EnemyDefeated:
    """Domain event emitted when an enemy is removed after its health reaches zero."""

    enemy_id: str
    score_reward: int
    experience_reward: int
    behavior: str
    tier: str = EnemyTier.NORMAL.value


@dataclass(slots=True)
class Bullet:
    position: Vec2
    velocity: Vec2
    created_at: float
    lifetime: float = 2.0
    damage: float = 12.0
    piercing: bool = False
    hit_enemy_ids: set[str] = field(default_factory=set)

    def is_expired(self, now: float) -> bool:
        return now - self.created_at >= self.lifetime

    def to_dict(self, now: float) -> dict[str, Any]:
        return {
            "position": self.position.to_dict(),
            "velocity": self.velocity.to_dict(),
            "remaining_lifetime": max(0.0, self.lifetime - (now - self.created_at)),
            "damage": self.damage,
            "piercing": self.piercing,
            "hit_enemy_ids": sorted(self.hit_enemy_ids),
        }

    @classmethod
    def from_dict(cls, data: Mapping[str, Any], now: float) -> "Bullet":
        remaining = max(0.0, float(data.get("remaining_lifetime", 0.0)))
        raw_hits = data.get("hit_enemy_ids", [])
        hits = {str(item) for item in raw_hits} if isinstance(raw_hits, list) else set()
        return cls(
            position=Vec2.from_dict(data["position"]),
            velocity=Vec2.from_dict(data["velocity"]),
            created_at=now,
            lifetime=remaining,
            damage=float(data.get("damage", 1)),
            piercing=bool(data.get("piercing", False)),
            hit_enemy_ids=hits,
        )


@dataclass(slots=True)
class Obstacle:
    """Enemy entity (historical name kept for save/API compatibility)."""

    position: Vec2
    base_speed: float
    behavior: ObstacleBehavior
    angle: float
    enemy_id: str = field(default_factory=lambda: uuid4().hex)
    max_health: float = 30.0
    current_health: float = 30.0
    attack_damage: float = 10.0
    experience_reward: int = 12
    score_reward: int = 20
    hit_flash_until: float = 0.0
    health_bar_visible_until: float = 0.0
    tier: EnemyTier = EnemyTier.NORMAL

    def to_dict(self, now: float = 0.0) -> dict[str, Any]:
        return {
            "position": self.position.to_dict(),
            "base_speed": self.base_speed,
            "behavior": self.behavior.value,
            "angle": self.angle,
            "enemy_id": self.enemy_id,
            "max_health": self.max_health,
            "current_health": self.current_health,
            "attack_damage": self.attack_damage,
            "experience_reward": self.experience_reward,
            "score_reward": self.score_reward,
            "hit_flash_remaining": _remaining(self.hit_flash_until, now),
            "health_bar_visible_remaining": _remaining(self.health_bar_visible_until, now),
            "tier": self.tier.value,
        }

    @classmethod
    def from_dict(cls, data: Mapping[str, Any], now: float = 0.0) -> "Obstacle":
        max_health = float(data.get("max_health", 30.0))
        current = float(data.get("current_health", max_health))
        tier_raw = str(data.get("tier", EnemyTier.NORMAL.value))
        try:
            tier = EnemyTier(tier_raw)
        except ValueError:
            tier = EnemyTier.NORMAL
        return cls(
            position=Vec2.from_dict(data["position"]),
            base_speed=float(data["base_speed"]),
            behavior=ObstacleBehavior(str(data["behavior"])),
            angle=float(data.get("angle", 0.0)),
            enemy_id=str(data.get("enemy_id") or uuid4().hex),
            max_health=max_health,
            current_health=current,
            attack_damage=float(data.get("attack_damage", 10.0)),
            experience_reward=int(data.get("experience_reward", 12)),
            score_reward=int(data.get("score_reward", 20)),
            hit_flash_until=_deadline(data.get("hit_flash_remaining", 0), now),
            health_bar_visible_until=_deadline(data.get("health_bar_visible_remaining", 0), now),
            tier=tier,
        )


# Future-facing alias; current code continues to use Obstacle.
Enemy = Obstacle


@dataclass(slots=True)
class Item:
    position: Vec2
    item_type: ItemType

    def to_dict(self) -> dict[str, Any]:
        return {
            "position": self.position.to_dict(),
            "item_type": self.item_type.value,
        }

    @classmethod
    def from_dict(cls, data: Mapping[str, Any]) -> "Item":
        return cls(
            position=Vec2.from_dict(data["position"]),
            item_type=ItemType(str(data["item_type"])),
        )


@dataclass(order=True, slots=True)
class LeaderboardEntry:
    score: int
    name: str

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: Mapping[str, Any]) -> "LeaderboardEntry":
        return cls(score=int(data["score"]), name=str(data["name"]))


def _remaining(deadline_value: float, now: float) -> float:
    if math.isinf(deadline_value):
        return math.inf
    return max(0.0, deadline_value - now)


def _deadline(remaining_value: object, now: float) -> float:
    value = float(remaining_value)
    return math.inf if math.isinf(value) else now + max(0.0, value)
