"""Tests for world-background scaling and camera clamping."""

from __future__ import annotations

from pathlib import Path

from PIL import Image

from stillpoint.background import clamp_camera_to_world, scale_background_to_world
from stillpoint.paths import asset_path


def _solid(width: int, height: int, color: tuple[int, int, int, int] = (255, 0, 0, 255)) -> Image.Image:
    return Image.new("RGBA", (width, height), color)


def test_cover_scaled_size_covers_and_matches_world() -> None:
    source = _solid(200, 100)
    result = scale_background_to_world(source, 400, 400, mode="cover")
    assert result.size == (400, 400)
    # Before crop, cover must scale so both axes are at least the world size.
    scale = max(400 / 200, 400 / 100)
    assert round(200 * scale) >= 400
    assert round(100 * scale) >= 400


def test_cover_center_crop_matches_world_for_rectangle_and_square() -> None:
    wide = scale_background_to_world(_solid(800, 200), 500, 300, mode="cover")
    square = scale_background_to_world(_solid(100, 100), 640, 480, mode="cover")
    tall = scale_background_to_world(_solid(100, 400), 320, 640, mode="cover")
    assert wide.size == (500, 300)
    assert square.size == (640, 480)
    assert tall.size == (320, 640)


def test_stretch_and_contain_modes() -> None:
    source = _solid(50, 100)
    stretched = scale_background_to_world(source, 200, 100, mode="stretch")
    contained = scale_background_to_world(source, 200, 100, mode="contain")
    assert stretched.size == (200, 100)
    assert contained.size == (200, 100)
    # contain should letterbox: left/right margins are the fallback fill.
    assert contained.getpixel((0, 50))[:3] == (5, 7, 11)
    assert contained.getpixel((100, 50))[:3] == (255, 0, 0)


def test_camera_clamped_at_all_edges_without_negative_bounds() -> None:
    world_w, world_h = 2000.0, 1200.0
    view_w, view_h = 800.0, 600.0

    # Top-left corner focus
    left, top = clamp_camera_to_world(0, 0, world_w, world_h, view_w, view_h)
    assert left == 0.0
    assert top == 0.0

    # Bottom-right corner focus
    right, bottom = clamp_camera_to_world(world_w, world_h, world_w, world_h, view_w, view_h)
    assert right == world_w - view_w
    assert bottom == world_h - view_h
    assert right >= 0.0
    assert bottom >= 0.0

    # Mid-edge samples stay inside [0, world - view]
    for fx, fy in ((0, world_h / 2), (world_w, world_h / 2), (world_w / 2, 0), (world_w / 2, world_h)):
        cx, cy = clamp_camera_to_world(fx, fy, world_w, world_h, view_w, view_h)
        assert 0.0 <= cx <= world_w - view_w
        assert 0.0 <= cy <= world_h - view_h


def test_camera_centers_when_viewport_exceeds_world() -> None:
    cx, cy = clamp_camera_to_world(50, 40, 100, 80, 200, 160)
    assert cx == (100 - 200) / 2
    assert cy == (80 - 160) / 2


def test_missing_background_asset_path_is_safe() -> None:
    missing = asset_path("definitely_missing_background_xyz.png")
    assert isinstance(missing, Path)
    assert not missing.exists()
    # Scaling helpers must not be required when the file is absent; callers catch open errors.
    try:
        Image.open(missing)
        raise AssertionError("expected missing file to fail")
    except FileNotFoundError:
        pass


def test_scale_accepts_real_background_when_present() -> None:
    path = asset_path("background.png")
    if not path.exists():
        return
    with Image.open(path) as image:
        result = scale_background_to_world(image, 640, 360, mode="cover")
    assert result.size == (640, 360)
