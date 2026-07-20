"""Combat, experience, and HUD helper tests."""

from __future__ import annotations

import random

from stillpoint.combat import (
    calculate_damage,
    experience_ratio,
    experience_required_for_level,
    health_ratio,
)
from stillpoint.config import GameConfig
from stillpoint.engine import GameState
from stillpoint.models import Bullet, Obstacle, ObstacleBehavior, Vec2, WeaponType


def make_state(**config_overrides: object) -> GameState:
    config = GameConfig(base_obstacle_count=0, initial_item_count=0, **config_overrides)  # type: ignore[arg-type]
    return GameState(config, 1000, 1000, "Tester", random.Random(7))


def make_enemy(state: GameState, *, health: float = 30, damage: float = 10) -> Obstacle:
    enemy = state.create_enemy(ObstacleBehavior.CHASE, Vec2(state.player.x + 40, state.player.y))
    enemy.max_health = health
    enemy.current_health = health
    enemy.attack_damage = damage
    enemy.experience_reward = 12
    enemy.score_reward = 20
    state.obstacles.append(enemy)
    return enemy


# --- Player health -----------------------------------------------------------------


def test_player_takes_damage() -> None:
    state = make_state()
    before = state.combat.current_health
    dealt = state.apply_player_damage(15, now=1.0)
    assert dealt == 15
    assert state.combat.current_health == before - 15


def test_defense_reduces_damage() -> None:
    state = make_state()
    state.combat.defense = 5
    dealt = state.apply_player_damage(15, now=1.0)
    assert dealt == 10
    assert calculate_damage(15, 5, minimum_damage=1) == 10


def test_damage_never_below_minimum() -> None:
    assert calculate_damage(3, defense=100, minimum_damage=1) == 1
    state = make_state()
    state.combat.defense = 999
    dealt = state.apply_player_damage(5, now=1.0)
    assert dealt == state.config.minimum_damage


def test_shield_blocks_collision_damage() -> None:
    state = make_state()
    state.effects.shield_until = 10.0
    before = state.combat.current_health
    assert state.apply_player_damage(40, now=5.0) == 0
    assert state.combat.current_health == before


def test_invulnerability_prevents_repeat_hits() -> None:
    state = make_state()
    state.apply_player_damage(10, now=1.0)
    mid = state.combat.current_health
    assert state.apply_player_damage(10, now=1.2) == 0
    assert state.combat.current_health == mid
    assert state.apply_player_damage(10, now=1.0 + state.config.player_hit_invulnerability + 0.01) > 0


def test_player_dies_at_zero_health() -> None:
    state = make_state()
    state.combat.current_health = 5
    state.apply_player_damage(50, now=1.0)
    assert state.combat.current_health == 0
    assert state.combat.is_dead
    assert state.combat.death_recorded


def test_death_is_not_recorded_twice() -> None:
    state = make_state()
    state.combat.current_health = 0
    assert state.mark_dead() is True
    assert state.mark_dead() is False
    score_before = state.score
    assert state.apply_player_damage(99, now=2.0) == 0
    assert state.score == score_before


# --- Enemy health ------------------------------------------------------------------


def test_bullet_damages_enemy_without_instant_kill() -> None:
    state = make_state()
    enemy = make_enemy(state, health=40)
    state.damage_enemy(enemy, 12, now=1.0)
    assert enemy.current_health == 28
    assert enemy in state.obstacles


def test_enemy_survives_partial_damage() -> None:
    state = make_state()
    enemy = make_enemy(state, health=50)
    state.damage_enemy(enemy, 10, now=1.0)
    assert len(state.obstacles) == 1
    assert enemy.current_health == 40


def test_enemy_removed_at_zero_health() -> None:
    state = make_state()
    enemy = make_enemy(state, health=10)
    state.damage_enemy(enemy, 10, now=1.0)
    assert enemy not in state.obstacles


def test_enemy_defeat_settles_score_and_xp_once() -> None:
    state = make_state()
    enemy = make_enemy(state, health=5)
    enemy.score_reward = 20
    enemy.experience_reward = 12
    state.damage_enemy(enemy, 5, now=1.0)
    assert state.combat.enemies_defeated == 1
    assert state.score == 20
    assert state.combat.total_experience == 12
    assert state.defeat_enemy(enemy, now=1.1) is None


def test_piercing_bullet_does_not_rehit_same_enemy() -> None:
    state = make_state()
    enemy = make_enemy(state, health=100)
    bullet = Bullet(
        position=Vec2(enemy.position.x, enemy.position.y),
        velocity=Vec2(0, 0),
        created_at=0.0,
        damage=10,
        piercing=True,
    )
    state.bullets = [bullet]
    state._move_bullets(delta=0.0, now=1.0)
    assert enemy.current_health == 90
    assert enemy.enemy_id in bullet.hit_enemy_ids
    state._move_bullets(delta=0.0, now=1.05)
    assert enemy.current_health == 90


# --- Level / experience ------------------------------------------------------------


def test_killing_enemy_grants_experience() -> None:
    state = make_state()
    enemy = make_enemy(state, health=1)
    enemy.experience_reward = 15
    state.damage_enemy(enemy, 1, now=1.0)
    assert state.combat.total_experience == 15
    assert state.combat.current_experience == 15


def test_level_up_at_threshold() -> None:
    state = make_state()
    needed = state.combat.experience_to_next_level
    levels = state.grant_experience(needed, now=1.0)
    assert levels == 1
    assert state.combat.level == 2


def test_large_xp_grant_can_multi_level() -> None:
    state = make_state()
    huge = state.combat.experience_to_next_level
    huge += experience_required_for_level(2)
    huge += experience_required_for_level(3)
    levels = state.grant_experience(huge, now=1.0)
    assert levels >= 3
    assert state.combat.level >= 4


def test_remaining_experience_kept_after_level_up() -> None:
    state = make_state()
    threshold = state.combat.experience_to_next_level
    state.grant_experience(threshold + 17, now=1.0)
    assert state.combat.level == 2
    assert state.combat.current_experience == 17


def test_level_up_increases_max_health() -> None:
    state = make_state()
    before = state.combat.max_health
    state.grant_experience(state.combat.experience_to_next_level, now=1.0)
    assert state.combat.max_health == before + state.config.health_gain_per_level


def test_level_up_heal_does_not_exceed_max() -> None:
    state = make_state()
    state.combat.current_health = state.combat.max_health - 5
    state.grant_experience(state.combat.experience_to_next_level, now=1.0)
    assert state.combat.current_health <= state.combat.max_health
    assert state.combat.current_health == state.combat.max_health


def test_experience_requirement_increases_with_level() -> None:
    assert experience_required_for_level(1) < experience_required_for_level(2)
    assert experience_required_for_level(5) < experience_required_for_level(10)


def test_invalid_level_input_is_sanitized() -> None:
    assert experience_required_for_level(0) == experience_required_for_level(1)
    assert experience_required_for_level(-3) == experience_required_for_level(1)


# --- HUD helpers -------------------------------------------------------------------


def test_health_ratio_clamped() -> None:
    assert health_ratio(50, 100) == 0.5
    assert health_ratio(-10, 100) == 0.0
    assert health_ratio(200, 100) == 1.0


def test_experience_ratio_clamped() -> None:
    assert experience_ratio(50, 100) == 0.5
    assert experience_ratio(-5, 100) == 0.0
    assert experience_ratio(150, 100) == 1.0


def test_zero_max_health_does_not_divide_by_zero() -> None:
    assert health_ratio(10, 0) == 0.0
    assert experience_ratio(10, 0) == 0.0


# --- Save compatibility ------------------------------------------------------------


def test_snapshot_restores_combat_fields() -> None:
    state = make_state()
    state.combat.current_health = 55
    state.combat.level = 3
    state.combat.current_experience = 40
    state.combat.total_experience = 300
    state.combat.enemies_defeated = 9
    state.game_time = 10.0
    snapshot = state.to_snapshot()

    restored = make_state()
    restored.restore(snapshot)
    assert restored.combat.current_health == 55
    assert restored.combat.level == 3
    assert restored.combat.current_experience == 40
    assert restored.combat.total_experience == 300
    assert restored.combat.enemies_defeated == 9


def test_legacy_snapshot_without_combat_loads_safely() -> None:
    state = make_state()
    snapshot = state.to_snapshot()
    snapshot.pop("combat")
    snapshot["version"] = 2
    restored = make_state()
    restored.restore(snapshot)
    assert restored.combat.level == 1
    assert restored.combat.current_health == restored.combat.max_health
    assert restored.player_name == "Tester"


def test_corrupt_obstacle_entries_are_skipped() -> None:
    state = make_state()
    snapshot = state.to_snapshot()
    snapshot["obstacles"] = [{"bad": True}, "nope"]
    restored = make_state()
    restored.restore(snapshot)
    # ensure_population may refill, but restore itself must not crash
    assert restored.combat.level >= 1


def test_enemy_stats_baked_at_spawn_not_every_frame() -> None:
    state = make_state()
    state.difficulty_scale = 1.0 + 5 * 0.1
    enemy = state.create_enemy(ObstacleBehavior.CIRCLE, Vec2(10, 10))
    health = enemy.max_health
    state.obstacles.append(enemy)
    state.tick(0.016, now=1.0, pressed=set())
    state.tick(0.016, now=1.032, pressed=set())
    assert enemy.max_health == health


def test_god_mode_blocks_damage() -> None:
    state = make_state()
    state.effects.god_mode = True
    before = state.combat.current_health
    assert state.apply_player_damage(50, now=1.0) == 0
    assert state.combat.current_health == before


def test_shoot_uses_player_bullet_damage() -> None:
    state = make_state()
    state.combat.bullet_damage = 18
    assert state.shoot(Vec2(state.player.x + 50, state.player.y), now=1.0)
    assert state.bullets[0].damage == 18
    state.effects.weapon = WeaponType.LARGE
    state.effects.weapon_until = 99
    assert state.shoot(Vec2(state.player.x + 50, state.player.y), now=3.0)
    assert state.bullets[-1].damage == 18 * 1.5
