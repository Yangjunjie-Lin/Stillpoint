"""Headless gameplay state and update rules."""

from __future__ import annotations

from dataclasses import dataclass, field
import math
import random
from typing import Any, Mapping
from uuid import uuid4

from .combat import (
    calculate_damage,
    difficulty_level_from_scale,
    experience_required_for_config,
)
from .config import ENEMY_ARCHETYPES, SAVE_VERSION, GameConfig
from .models import (
    Bullet,
    EnemyDefeated,
    EnemyTier,
    FloatingText,
    Item,
    ItemType,
    Obstacle,
    ObstacleBehavior,
    PlayerCombat,
    Vec2,
    WeaponType,
)


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
    world_width: float
    world_height: float
    player_name: str
    rng: random.Random = field(default_factory=random.Random)
    player: Vec2 = field(init=False)
    combat: PlayerCombat = field(init=False)
    velocity: Vec2 = field(default_factory=lambda: Vec2(0.0, 0.0))
    direction: str = "up"
    bullets: list[Bullet] = field(default_factory=list)
    obstacles: list[Obstacle] = field(default_factory=list)
    items: list[Item] = field(default_factory=list)
    floating_texts: list[FloatingText] = field(default_factory=list)
    effects: Effects = field(default_factory=Effects)
    score: int = 0
    survival_seconds: float = 0.0
    difficulty_scale: float = 1.0
    game_time: float = 0.0
    last_shot_at: float = -1_000.0
    last_item_spawn_at: float = 0.0

    def __post_init__(self) -> None:
        self.player = Vec2(self.world_width / 2, self.world_height / 2)
        self.combat = self._default_combat()
        self.ensure_population()
        for _ in range(self.config.initial_item_count):
            self.spawn_item()

    def _default_combat(self) -> PlayerCombat:
        level = 1
        return PlayerCombat(
            max_health=self.config.player_base_max_health,
            current_health=self.config.player_base_max_health,
            defense=self.config.player_base_defense,
            level=level,
            current_experience=0,
            experience_to_next_level=experience_required_for_config(level, self.config),
            total_experience=0,
            bullet_damage=self.config.player_base_bullet_damage,
            last_level_gained=level,
        )

    @property
    def total_score(self) -> int:
        return self.score + int(self.survival_seconds)

    @property
    def difficulty_level(self) -> int:
        return difficulty_level_from_scale(self.difficulty_scale, self.config.score_threshold)

    def tick(self, delta: float, now: float, pressed: set[str]) -> bool:
        """Advance one frame and return whether the player is still alive.

        ``now`` is accepted for call-site compatibility; combat timers use
        ``game_time``, which only advances while ``tick`` runs (paused sessions freeze).
        """
        del now  # wall-clock must not drive combat while paused
        if self.combat.is_dead:
            return False
        self.game_time += max(0.0, delta)
        clock = self.game_time
        self.effects.update(clock)
        self._move_player(delta, pressed, clock)
        self._move_obstacles(delta)
        self._move_bullets(delta, clock)
        self._resolve_player_collisions(clock)
        self._collect_items(clock)
        self._prune_floating_texts(clock)
        self.survival_seconds += delta
        self.difficulty_scale = 1.0 + (self.total_score // self.config.score_threshold) * 0.1
        self.ensure_population()
        if clock - self.last_item_spawn_at >= self.config.item_spawn_interval_seconds:
            self.spawn_item()
            self.last_item_spawn_at = clock
        return not self.combat.is_dead

    def shoot(self, target: Vec2, now: float) -> bool:
        if self.combat.is_dead:
            return False
        cooldown = self._current_shooting_cooldown(now)
        if now - self.last_shot_at < cooldown:
            return False
        direction = Vec2(target.x - self.player.x, target.y - self.player.y).normalized()
        if direction == Vec2(0.0, 0.0):
            return False
        self.last_shot_at = now
        velocity = Vec2(direction.x * self.config.bullet_speed * 60, direction.y * self.config.bullet_speed * 60)
        piercing = self.effects.weapon is WeaponType.PIERCE
        damage = self.combat.bullet_damage
        if self.effects.weapon is WeaponType.LARGE:
            damage *= 1.5
        offsets = (-10.0, 10.0) if self.effects.weapon is WeaponType.DOUBLE else (0.0,)
        perpendicular = Vec2(-direction.y, direction.x)
        for offset in offsets:
            origin = Vec2(
                self.player.x + perpendicular.x * offset,
                self.player.y + perpendicular.y * offset,
            )
            self.bullets.append(
                Bullet(origin, velocity, now, damage=damage, piercing=piercing),
            )
        return True

    def _current_shooting_cooldown(self, now: float) -> float:
        if self.effects.rapid_fire:
            return 0.05
        reduced = self.config.shooting_cooldown - self.combat.cooldown_reduction
        return max(self.config.min_shooting_cooldown, reduced)

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
        self.player.x = clamp(self.player.x + self.velocity.x * speed * delta, 0, self.world_width)
        self.player.y = clamp(self.player.y + self.velocity.y * speed * delta, 0, self.world_height)

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
            obstacle.position.x = clamp(obstacle.position.x + movement.x * speed, 0, self.world_width)
            obstacle.position.y = clamp(obstacle.position.y + movement.y * speed, 0, self.world_height)

    def _move_bullets(self, delta: float, now: float) -> None:
        survivors: list[Bullet] = []
        radius = (self.config.obstacle_size + self.bullet_size) / 2
        for bullet in self.bullets:
            bullet.position.x += bullet.velocity.x * delta
            bullet.position.y += bullet.velocity.y * delta
            consumed = False
            for obstacle in self.obstacles[:]:
                if obstacle.enemy_id in bullet.hit_enemy_ids:
                    continue
                if bullet.position.distance_to(obstacle.position) >= radius:
                    continue
                self.damage_enemy(obstacle, bullet.damage, now)
                bullet.hit_enemy_ids.add(obstacle.enemy_id)
                if not bullet.piercing:
                    consumed = True
                    break
            in_world = (
                0 <= bullet.position.x <= self.world_width and 0 <= bullet.position.y <= self.world_height
            )
            if not bullet.is_expired(now) and in_world and not consumed:
                survivors.append(bullet)
        self.bullets = survivors

    def damage_enemy(self, enemy: Obstacle, amount: float, now: float) -> float:
        if enemy.current_health <= 0:
            return 0.0
        dealt = max(0.0, float(amount))
        enemy.current_health = max(0.0, enemy.current_health - dealt)
        enemy.hit_flash_until = now + self.config.enemy_hit_flash_duration
        enemy.health_bar_visible_until = now + self.config.enemy_health_bar_duration
        if dealt > 0:
            self._spawn_floating_text(enemy.position, f"-{int(dealt)}", "#ffe66d", now)
        if enemy.current_health <= 0:
            self.defeat_enemy(enemy, now)
        return dealt

    def defeat_enemy(self, enemy: Obstacle, now: float) -> EnemyDefeated | None:
        if enemy not in self.obstacles:
            return None
        self.obstacles.remove(enemy)
        event = EnemyDefeated(
            enemy_id=enemy.enemy_id,
            score_reward=enemy.score_reward,
            experience_reward=enemy.experience_reward,
            behavior=enemy.behavior.value,
            tier=enemy.tier.value,
        )
        self.combat.enemies_defeated += 1
        self.score += event.score_reward * self.effects.score_multiplier(now)
        self.grant_experience(event.experience_reward, now)
        return event

    def grant_experience(self, amount: int, now: float) -> int:
        gained = max(0, int(amount))
        if gained == 0 or self.combat.is_dead:
            return 0
        self.combat.current_experience += gained
        self.combat.total_experience += gained
        levels = 0
        while self.combat.current_experience >= self.combat.experience_to_next_level:
            self.combat.current_experience -= self.combat.experience_to_next_level
            self._apply_level_up(now)
            levels += 1
        return levels

    def _apply_level_up(self, now: float) -> None:
        self.combat.level += 1
        self.combat.last_level_gained = self.combat.level
        self.combat.experience_to_next_level = experience_required_for_config(self.combat.level, self.config)
        self.combat.max_health += self.config.health_gain_per_level
        self.combat.current_health = min(
            self.combat.max_health,
            self.combat.current_health + self.config.health_restore_on_level_up,
        )
        self.combat.bullet_damage += self.config.damage_gain_per_level
        self.combat.cooldown_reduction = min(
            self.config.max_cooldown_reduction,
            self.combat.cooldown_reduction + self.config.cooldown_reduction_per_level,
        )
        self.combat.level_up_effect_until = now + self.config.level_up_effect_duration

    def apply_player_damage(self, incoming_damage: float, now: float, source: Vec2 | None = None) -> float:
        if self.combat.is_dead:
            return 0.0
        if self.effects.shielded(now):
            return 0.0
        if now < self.combat.invulnerability_until:
            return 0.0
        dealt = calculate_damage(incoming_damage, self.combat.defense, self.config.minimum_damage)
        self.combat.current_health = max(0.0, self.combat.current_health - dealt)
        self.combat.invulnerability_until = now + self.config.player_hit_invulnerability
        self.combat.hit_flash_until = now + self.config.player_hit_flash_duration
        origin = source or self.player
        self._spawn_floating_text(origin, f"-{int(dealt)}", "#ff4d5a", now)
        if self.combat.current_health <= 0:
            self.combat.current_health = 0.0
            self.mark_dead()
        return dealt

    def mark_dead(self) -> bool:
        """Record death once. Returns True if this call newly recorded death."""
        if self.combat.death_recorded:
            return False
        self.combat.death_recorded = True
        self.combat.current_health = 0.0
        return True

    def _resolve_player_collisions(self, now: float) -> None:
        if self.combat.is_dead:
            return
        radius = (self.config.player_size + self.config.obstacle_size) / 2
        for obstacle in self.obstacles:
            if self.player.distance_to(obstacle.position) < radius:
                self.apply_player_damage(obstacle.attack_damage, now, source=self.player)
                if self.combat.is_dead:
                    return

    def _spawn_floating_text(self, position: Vec2, text: str, color: str, now: float) -> None:
        self.floating_texts.append(
            FloatingText(
                position=Vec2(position.x, position.y - 18),
                text=text,
                color=color,
                created_at=now,
                lifetime=self.config.floating_text_lifetime,
            )
        )

    def _prune_floating_texts(self, now: float) -> None:
        self.floating_texts = [item for item in self.floating_texts if not item.is_expired(now)]

    @property
    def bullet_size(self) -> int:
        return self.config.bullet_size * 2 if self.effects.weapon is WeaponType.LARGE else self.config.bullet_size

    def ensure_population(self) -> None:
        target = min(self.config.max_obstacle_count, int(self.config.base_obstacle_count * self.difficulty_scale))
        while len(self.obstacles) < target:
            self.spawn_obstacle()

    def create_enemy(
        self,
        behavior: ObstacleBehavior,
        position: Vec2,
        difficulty_scale: float | None = None,
        *,
        base_speed: float | None = None,
        angle: float | None = None,
        tier: EnemyTier = EnemyTier.NORMAL,
    ) -> Obstacle:
        """Factory: bake difficulty into enemy stats once at spawn time."""
        scale = self.difficulty_scale if difficulty_scale is None else difficulty_scale
        tier_level = difficulty_level_from_scale(scale, self.config.score_threshold)
        archetype = ENEMY_ARCHETYPES.get(behavior.value, ENEMY_ARCHETYPES["chase"])
        health_mult = 1.0 + tier_level * self.config.enemy_health_difficulty_factor
        damage_mult = 1.0 + tier_level * self.config.enemy_damage_difficulty_factor
        reward_mult = 1.0 + tier_level * self.config.enemy_reward_difficulty_factor
        max_health = float(archetype["max_health"]) * health_mult
        return Obstacle(
            position=position,
            base_speed=self.rng.uniform(1.0, 3.0) if base_speed is None else base_speed,
            behavior=behavior,
            angle=self.rng.uniform(0, math.tau) if angle is None else angle,
            enemy_id=uuid4().hex,
            max_health=max_health,
            current_health=max_health,
            attack_damage=float(archetype["attack_damage"]) * damage_mult,
            experience_reward=max(1, int(int(archetype["experience_reward"]) * reward_mult)),
            score_reward=max(1, int(int(archetype["score_reward"]) * reward_mult)),
            tier=tier,
        )

    def spawn_obstacle(self) -> None:
        point = Vec2(self.player.x, self.player.y)
        for _ in range(100):
            point = Vec2(self.rng.uniform(0, self.world_width), self.rng.uniform(0, self.world_height))
            if point.distance_to(self.player) > 350:
                break
        behavior = self.rng.choice(list(ObstacleBehavior))
        self.obstacles.append(self.create_enemy(behavior, point))

    def spawn_item(self) -> None:
        self.items.append(
            Item(
                Vec2(self.rng.uniform(0, self.world_width), self.rng.uniform(0, self.world_height)),
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

    def to_snapshot(self, now: float | None = None) -> dict[str, Any]:
        clock = self.game_time if now is None else float(now)
        return {
            "version": SAVE_VERSION,
            "player_name": self.player_name,
            "world_width": self.world_width,
            "world_height": self.world_height,
            # Legacy square-map field for older readers.
            "world_size": max(self.world_width, self.world_height),
            "player": self.player.to_dict(),
            "combat": self.combat.to_dict(clock),
            "velocity": self.velocity.to_dict(),
            "direction": self.direction,
            "score": self.score,
            "survival_seconds": self.survival_seconds,
            "difficulty_scale": self.difficulty_scale,
            "game_time": clock,
            "obstacles": [item.to_dict(clock) for item in self.obstacles],
            "items": [item.to_dict() for item in self.items],
            "bullets": [item.to_dict(clock) for item in self.bullets],
            "floating_texts": [item.to_dict(clock) for item in self.floating_texts],
            "effects": {
                "shield_remaining": remaining(self.effects.shield_until, clock),
                "speed_remaining": remaining(self.effects.speed_until, clock),
                "score_remaining": remaining(self.effects.score_multiplier_until, clock),
                "weapon_remaining": remaining(self.effects.weapon_until, clock),
                "weapon": self.effects.weapon.value,
                "god_mode": self.effects.god_mode,
                "rapid_fire": self.effects.rapid_fire,
            },
        }

    def restore(self, data: Mapping[str, Any], now: float | None = None) -> None:
        self.player_name = str(data.get("player_name", self.player_name))[:24]
        if "world_width" in data and "world_height" in data:
            self.world_width = max(float(data["world_width"]), 800)
            self.world_height = max(float(data["world_height"]), 800)
        else:
            size = max(float(data.get("world_size", max(self.world_width, self.world_height))), 800)
            self.world_width = size
            self.world_height = size
        self.player = Vec2.from_dict(data["player"])
        self.score = int(data.get("score", 0))
        self.survival_seconds = float(data.get("survival_seconds", 0))
        self.difficulty_scale = float(data.get("difficulty_scale", 1))
        if "game_time" in data:
            self.game_time = max(0.0, float(data["game_time"]))
        elif now is not None:
            self.game_time = max(0.0, float(now))
        clock = self.game_time
        defaults = self._default_combat()
        try:
            self.combat = PlayerCombat.from_dict(data.get("combat"), clock, defaults)
        except (KeyError, TypeError, ValueError):
            self.combat = defaults
        self.velocity = Vec2.from_dict(data.get("velocity", {"x": 0, "y": 0}))
        self.direction = str(data.get("direction", "up"))
        self.obstacles = []
        for item in data.get("obstacles", []):
            if not isinstance(item, Mapping):
                continue
            try:
                self.obstacles.append(Obstacle.from_dict(item, clock))
            except (KeyError, TypeError, ValueError):
                continue
        self.items = []
        for item in data.get("items", []):
            if not isinstance(item, Mapping):
                continue
            try:
                self.items.append(Item.from_dict(item))
            except (KeyError, TypeError, ValueError):
                continue
        self.bullets = []
        for item in data.get("bullets", []):
            if not isinstance(item, Mapping):
                continue
            try:
                self.bullets.append(Bullet.from_dict(item, clock))
            except (KeyError, TypeError, ValueError):
                continue
        self.floating_texts = []
        for item in data.get("floating_texts", []):
            if not isinstance(item, Mapping):
                continue
            try:
                self.floating_texts.append(FloatingText.from_dict(item, clock))
            except (KeyError, TypeError, ValueError):
                continue
        effects = data.get("effects", {})
        if not isinstance(effects, Mapping):
            effects = {}
        self.effects.shield_until = deadline(effects.get("shield_remaining", 0), clock)
        self.effects.speed_until = deadline(effects.get("speed_remaining", 0), clock)
        self.effects.score_multiplier_until = deadline(effects.get("score_remaining", 0), clock)
        self.effects.weapon_until = deadline(effects.get("weapon_remaining", 0), clock)
        try:
            self.effects.weapon = WeaponType(str(effects.get("weapon", "normal")))
        except ValueError:
            self.effects.weapon = WeaponType.NORMAL
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
