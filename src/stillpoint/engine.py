"""Headless gameplay state and update rules."""

from __future__ import annotations

from dataclasses import dataclass, field
import math
import random
import time
from typing import Any, Mapping

from .config import GameConfig
from .models import Bullet, Item, ItemType, Obstacle, ObstacleBehavior, Vec2, WeaponType


@dataclass(slots=True)
class Effects:
    shield_until: float = 0.0
    speed_until: float = 0.0
    score_multiplier_until: float = 0.0
    weapon_until: float = 0.0
    weapon: WeaponType = WeaponType.NORMAL
    god_mode: bool = False
    rapid_fire: bool = False

    def update(self, now: float) -> None:
        if now >= self.weapon_until:
            self.weapon = WeaponType.NORMAL

    def shielded(self, now: float) -> bool:
        return self.god_mode or now < self.shield_until

    def speed_multiplier(self, now: float) -> float:
        return 1.5 if now < self.speed_until else 1.0

    def score_multiplier(self, now: float) -> int:
        return 2 if now < self.score_multiplier_until else 1


@dataclass(slots=True)
class GameState:
    """Mutable session state with no dependency on Tkinter."""

    config: GameConfig
    world_size: float
    player_name: str
    rng: random.Random = field(default_factory=random.Random)
    player: Vec2 = field(init=False)
    velocity: Vec2 = field(default_factory=lambda: Vec2(0.0, 0.0))
    direction: str = "up"
    bullets: list[Bullet] = field(default_factory=list)
    obstacles: list[Obstacle] = field(default_factory=list)
    items: list[Item] = field(default_factory=list)
    effects: Effects = field(default_factory=Effects)
    score: int = 0
    survival_seconds: float = 0.0
    difficulty_scale: float = 1.0
    last_shot_at: float = 0.0
    last_item_spawn_at: float = field(default_factory=time.monotonic)

    def __post_init__(self) -> None:
        self.player = Vec2(self.world_size / 2, self.world_size / 2)
        self.ensure_population()
        for _ in range(self.config.initial_item_count):
            self.spawn_item()

    @property
    def total_score(self) -> int:
        return self.score + int(self.survival_seconds)

    def tick(self, delta: float, now: float, pressed: set[str]) -> bool:
        """Advance one frame and return whether the player survived it."""
        self.effects.update(now)
        self._move_player(delta, pressed, now)
        self._move_obstacles(delta)
        self._move_bullets(delta, now)
        self._collect_items(now)
        self.survival_seconds += delta
        self.difficulty_scale = 1.0 + (self.total_score // self.config.score_threshold) * 0.1
        self.ensure_population()
        if now - self.last_item_spawn_at >= self.config.item_spawn_interval_seconds:
            self.spawn_item()
            self.last_item_spawn_at = now
        return not self.player_collision(now)

    def shoot(self, target: Vec2, now: float) -> bool:
        cooldown = 0.05 if self.effects.rapid_fire else self.config.shooting_cooldown
        if now - self.last_shot_at < cooldown:
            return False
        direction = Vec2(target.x - self.player.x, target.y - self.player.y).normalized()
        if direction == Vec2(0.0, 0.0):
            return False
        self.last_shot_at = now
        velocity = Vec2(direction.x * self.config.bullet_speed * 60, direction.y * self.config.bullet_speed * 60)
        piercing = self.effects.weapon is WeaponType.PIERCE
        offsets = (-10.0, 10.0) if self.effects.weapon is WeaponType.DOUBLE else (0.0,)
        perpendicular = Vec2(-direction.y, direction.x)
        for offset in offsets:
            origin = Vec2(
                self.player.x + perpendicular.x * offset,
                self.player.y + perpendicular.y * offset,
            )
            self.bullets.append(Bullet(origin, velocity, now, piercing=piercing))
        return True

    def apply_cheat(self, action: str, now: float) -> str:
        if action == "godmode":
            self.effects.god_mode = not self.effects.god_mode
            return f"God mode: {'ON' if self.effects.god_mode else 'OFF'}"
        if action == "rapidfire":
            self.effects.rapid_fire = not self.effects.rapid_fire
            return f"Rapid fire: {'ON' if self.effects.rapid_fire else 'OFF'}"
        if action == "powerup":
            self.effects.shield_until = math.inf
            self.effects.speed_until = math.inf
            self.effects.score_multiplier_until = math.inf
            self.effects.weapon = WeaponType.DOUBLE
            self.effects.weapon_until = math.inf
            return "All power-ups activated"
        if action == "points":
            self.score += 1000
            return "+1000 points"
        if action == "speedup":
            self.effects.speed_until = math.inf
            return "Speed boost activated"
        return ""

    def _move_player(self, delta: float, pressed: set[str], now: float) -> None:
        x_axis = float("d" in pressed) - float("a" in pressed)
        y_axis = float("s" in pressed) - float("w" in pressed)
        desired = Vec2(x_axis, y_axis).normalized()
        if desired != Vec2(0.0, 0.0):
            self.velocity.x += desired.x * self.config.acceleration * 60 * delta
            self.velocity.y += desired.y * self.config.acceleration * 60 * delta
            self.direction = direction_name(desired)
        else:
            damping = self.config.friction ** (delta * 60)
            self.velocity.x *= damping
            self.velocity.y *= damping

        magnitude = math.hypot(self.velocity.x, self.velocity.y)
        if magnitude > 1.0:
            self.velocity.x /= magnitude
            self.velocity.y /= magnitude
        speed = self.config.base_speed * 60 * self.effects.speed_multiplier(now)
        self.player.x = clamp(self.player.x + self.velocity.x * speed * delta, 0, self.world_size)
        self.player.y = clamp(self.player.y + self.velocity.y * speed * delta, 0, self.world_size)

    def _move_obstacles(self, delta: float) -> None:
        for obstacle in self.obstacles:
            offset = Vec2(self.player.x - obstacle.position.x, self.player.y - obstacle.position.y)
            distance = max(0.001, math.hypot(offset.x, offset.y))
            direction = Vec2(offset.x / distance, offset.y / distance)
            speed = obstacle.base_speed * min(2.0, self.difficulty_scale) * 60 * delta
            if obstacle.behavior is ObstacleBehavior.CHASE:
                movement = direction
            elif obstacle.behavior is ObstacleBehavior.AVOID:
                movement = Vec2(-direction.x, -direction.y) if distance < 430 else direction
            else:
                obstacle.angle += 1.2 * delta
                tangent = Vec2(-direction.y, direction.x)
                radial = 0.4 if distance > 180 else -0.2
                movement = Vec2(tangent.x + direction.x * radial, tangent.y + direction.y * radial).normalized()
            obstacle.position.x = clamp(obstacle.position.x + movement.x * speed, 0, self.world_size)
            obstacle.position.y = clamp(obstacle.position.y + movement.y * speed, 0, self.world_size)

    def _move_bullets(self, delta: float, now: float) -> None:
        survivors: list[Bullet] = []
        radius = (self.config.obstacle_size + self.bullet_size) / 2
        for bullet in self.bullets:
            bullet.position.x += bullet.velocity.x * delta
            bullet.position.y += bullet.velocity.y * delta
            hit = False
            for obstacle in self.obstacles[:]:
                if bullet.position.distance_to(obstacle.position) < radius:
                    self.obstacles.remove(obstacle)
                    self.score += 20 * self.effects.score_multiplier(now)
                    hit = True
                    if not bullet.piercing:
                        break
            in_world = 0 <= bullet.position.x <= self.world_size and 0 <= bullet.position.y <= self.world_size
            if not bullet.is_expired(now) and in_world and (not hit or bullet.piercing):
                survivors.append(bullet)
        self.bullets = survivors

    @property
    def bullet_size(self) -> int:
        return self.config.bullet_size * 2 if self.effects.weapon is WeaponType.LARGE else self.config.bullet_size

    def ensure_population(self) -> None:
        target = min(self.config.max_obstacle_count, int(self.config.base_obstacle_count * self.difficulty_scale))
        while len(self.obstacles) < target:
            self.spawn_obstacle()

    def spawn_obstacle(self) -> None:
        for _ in range(100):
            point = Vec2(self.rng.uniform(0, self.world_size), self.rng.uniform(0, self.world_size))
            if point.distance_to(self.player) > 350:
                break
        self.obstacles.append(
            Obstacle(
                position=point,
                base_speed=self.rng.uniform(1.0, 3.0),
                behavior=self.rng.choice(list(ObstacleBehavior)),
                angle=self.rng.uniform(0, math.tau),
            )
        )

    def spawn_item(self) -> None:
        self.items.append(
            Item(
                Vec2(self.rng.uniform(0, self.world_size), self.rng.uniform(0, self.world_size)),
                self.rng.choice(list(ItemType)),
            )
        )

    def _collect_items(self, now: float) -> None:
        radius = (self.config.player_size + self.config.item_size) / 2
        collected = [item for item in self.items if item.position.distance_to(self.player) < radius]
        for item in collected:
            self.activate_item(item.item_type, now)
            self.score += 10 * self.effects.score_multiplier(now)
            self.items.remove(item)

    def activate_item(self, item_type: ItemType, now: float) -> None:
        if item_type is ItemType.SHIELD:
            self.effects.shield_until = now + 10
        elif item_type is ItemType.SPEED:
            self.effects.speed_until = now + 5
        elif item_type is ItemType.POINTS:
            self.effects.score_multiplier_until = now + 8
        else:
            self.effects.weapon = WeaponType(item_type.value)
            self.effects.weapon_until = now + 8

    def player_collision(self, now: float) -> bool:
        if self.effects.shielded(now):
            return False
        radius = (self.config.player_size + self.config.obstacle_size) / 2
        return any(self.player.distance_to(obstacle.position) < radius for obstacle in self.obstacles)

    def to_snapshot(self, now: float) -> dict[str, Any]:
        return {
            "version": 2,
            "player_name": self.player_name,
            "world_size": self.world_size,
            "player": self.player.to_dict(),
            "velocity": self.velocity.to_dict(),
            "direction": self.direction,
            "score": self.score,
            "survival_seconds": self.survival_seconds,
            "difficulty_scale": self.difficulty_scale,
            "obstacles": [item.to_dict() for item in self.obstacles],
            "items": [item.to_dict() for item in self.items],
            "bullets": [item.to_dict(now) for item in self.bullets],
            "effects": {
                "shield_remaining": remaining(self.effects.shield_until, now),
                "speed_remaining": remaining(self.effects.speed_until, now),
                "score_remaining": remaining(self.effects.score_multiplier_until, now),
                "weapon_remaining": remaining(self.effects.weapon_until, now),
                "weapon": self.effects.weapon.value,
                "god_mode": self.effects.god_mode,
                "rapid_fire": self.effects.rapid_fire,
            },
        }

    def restore(self, data: Mapping[str, Any], now: float) -> None:
        self.player_name = str(data.get("player_name", self.player_name))[:24]
        self.world_size = max(float(data.get("world_size", self.world_size)), 800)
        self.player = Vec2.from_dict(data["player"])
        self.velocity = Vec2.from_dict(data.get("velocity", {"x": 0, "y": 0}))
        self.direction = str(data.get("direction", "up"))
        self.score = int(data.get("score", 0))
        self.survival_seconds = float(data.get("survival_seconds", 0))
        self.difficulty_scale = float(data.get("difficulty_scale", 1))
        self.obstacles = [Obstacle.from_dict(item) for item in data.get("obstacles", [])]
        self.items = [Item.from_dict(item) for item in data.get("items", [])]
        self.bullets = [Bullet.from_dict(item, now) for item in data.get("bullets", [])]
        effects = data.get("effects", {})
        self.effects.shield_until = deadline(effects.get("shield_remaining", 0), now)
        self.effects.speed_until = deadline(effects.get("speed_remaining", 0), now)
        self.effects.score_multiplier_until = deadline(effects.get("score_remaining", 0), now)
        self.effects.weapon_until = deadline(effects.get("weapon_remaining", 0), now)
        self.effects.weapon = WeaponType(str(effects.get("weapon", "normal")))
        self.effects.god_mode = bool(effects.get("god_mode", False))
        self.effects.rapid_fire = bool(effects.get("rapid_fire", False))
        self.ensure_population()


def clamp(value: float, lower: float, upper: float) -> float:
    return max(lower, min(upper, value))


def direction_name(vector: Vec2) -> str:
    horizontal = "left" if vector.x < -0.25 else "right" if vector.x > 0.25 else ""
    vertical = "up" if vector.y < -0.25 else "down" if vector.y > 0.25 else ""
    return "_".join(part for part in (vertical, horizontal) if part) or "up"


def remaining(deadline_value: float, now: float) -> float:
    if math.isinf(deadline_value):
        return math.inf
    return max(0.0, deadline_value - now)


def deadline(remaining_value: object, now: float) -> float:
    value = float(remaining_value)
    return math.inf if math.isinf(value) else now + max(0.0, value)
