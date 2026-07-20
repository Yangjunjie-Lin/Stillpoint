from __future__ import annotations

import math

from stillpoint.models import Bullet, Item, ItemType, Obstacle, ObstacleBehavior, Vec2


def test_vec2_normalization() -> None:
    result = Vec2(3, 4).normalized()
    assert math.isclose(result.x, 0.6)
    assert math.isclose(result.y, 0.8)


def test_zero_vector_normalization_is_safe() -> None:
    assert Vec2(0, 0).normalized() == Vec2(0, 0)


def test_models_round_trip() -> None:
    obstacle = Obstacle(Vec2(10, 20), 2.5, ObstacleBehavior.CIRCLE, 1.2)
    item = Item(Vec2(30, 40), ItemType.PIERCE)
    bullet = Bullet(Vec2(1, 2), Vec2(3, 4), created_at=100.0, lifetime=2.0, piercing=True)

    assert Obstacle.from_dict(obstacle.to_dict()) == obstacle
    assert Item.from_dict(item.to_dict()) == item

    restored = Bullet.from_dict(bullet.to_dict(now=100.5), now=200.0)
    assert restored.position == bullet.position
    assert restored.velocity == bullet.velocity
    assert restored.piercing is True
    assert math.isclose(restored.lifetime, 1.5)
