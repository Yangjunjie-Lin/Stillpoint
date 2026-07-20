"""Small domain models used by the game engine and persistence layer."""

from __future__ import annotations

from dataclasses import asdict, dataclass
from enum import StrEnum
import math
from typing import Any, Mapping


class ObstacleBehavior(StrEnum):
    CHASE = "chase"
    AVOID = "avoid"
    CIRCLE = "circle"


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
class Bullet:
    position: Vec2
    velocity: Vec2
    created_at: float
    lifetime: float = 2.0
    damage: int = 1
    piercing: bool = False

    def is_expired(self, now: float) -> bool:
        return now - self.created_at >= self.lifetime

    def to_dict(self, now: float) -> dict[str, Any]:
        return {
            "position": self.position.to_dict(),
            "velocity": self.velocity.to_dict(),
            "remaining_lifetime": max(0.0, self.lifetime - (now - self.created_at)),
            "damage": self.damage,
            "piercing": self.piercing,
        }

    @classmethod
    def from_dict(cls, data: Mapping[str, Any], now: float) -> "Bullet":
        remaining = max(0.0, float(data.get("remaining_lifetime", 0.0)))
        return cls(
            position=Vec2.from_dict(data["position"]),
            velocity=Vec2.from_dict(data["velocity"]),
            created_at=now,
            lifetime=remaining,
            damage=int(data.get("damage", 1)),
            piercing=bool(data.get("piercing", False)),
        )


@dataclass(slots=True)
class Obstacle:
    position: Vec2
    base_speed: float
    behavior: ObstacleBehavior
    angle: float

    def to_dict(self) -> dict[str, Any]:
        return {
            "position": self.position.to_dict(),
            "base_speed": self.base_speed,
            "behavior": self.behavior.value,
            "angle": self.angle,
        }

    @classmethod
    def from_dict(cls, data: Mapping[str, Any]) -> "Obstacle":
        return cls(
            position=Vec2.from_dict(data["position"]),
            base_speed=float(data["base_speed"]),
            behavior=ObstacleBehavior(str(data["behavior"])),
            angle=float(data.get("angle", 0.0)),
        )


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
