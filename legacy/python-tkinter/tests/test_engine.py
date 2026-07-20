from __future__ import annotations

import random

from stillpoint.config import GameConfig
from stillpoint.engine import GameState, direction_name
from stillpoint.models import ItemType, Vec2, WeaponType


def make_state() -> GameState:
    config = GameConfig(base_obstacle_count=0, initial_item_count=0)
    return GameState(config, 1000, 1000, "Tester", random.Random(7))


def test_direction_name_supports_diagonals() -> None:
    assert direction_name(Vec2(-1, -1).normalized()) == "up_left"
    assert direction_name(Vec2(1, 0).normalized()) == "right"


def test_shoot_respects_cooldown_and_direction() -> None:
    state = make_state()
    assert state.shoot(Vec2(state.player.x + 100, state.player.y), now=1.0)
    assert len(state.bullets) == 1
    assert state.bullets[0].velocity.x > 0
    assert not state.shoot(Vec2(state.player.x + 100, state.player.y), now=1.1)


def test_snapshot_round_trip_preserves_session() -> None:
    state = make_state()
    state.score = 120
    state.game_time = 10.0
    state.activate_item(ItemType.PIERCE, now=10.0)
    state.game_time = 11.0
    snapshot = state.to_snapshot()

    restored = make_state()
    restored.restore(snapshot)

    assert restored.score == 120
    assert restored.player_name == "Tester"
    assert restored.effects.weapon is WeaponType.PIERCE
    assert restored.effects.weapon_until == 18.0
    assert restored.game_time == 11.0
    assert restored.world_width == 1000
    assert restored.world_height == 1000
    assert "combat" in snapshot
    assert snapshot["version"] >= 3


def test_restore_accepts_legacy_square_world_size() -> None:
    state = make_state()
    snapshot = state.to_snapshot()
    snapshot.pop("world_width")
    snapshot.pop("world_height")
    snapshot["world_size"] = 1600

    restored = make_state()
    restored.restore(snapshot)
    assert restored.world_width == 1600
    assert restored.world_height == 1600
