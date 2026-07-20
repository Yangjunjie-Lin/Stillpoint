"""World-map background scaling and camera clamping (no Tkinter)."""

from __future__ import annotations

from PIL import Image


FALLBACK_FILL = (5, 7, 11, 255)


def scale_background_to_world(
    image: Image.Image,
    world_width: int,
    world_height: int,
    mode: str = "cover",
) -> Image.Image:
    """Scale a source image to exactly ``(world_width, world_height)``.

    Modes:
    * ``cover`` – keep aspect ratio, scale up to cover, center-crop (default).
    * ``stretch`` – force-fit to world size (may distort).
    * ``contain`` – keep aspect ratio, letterbox with a dark fill.
    """
    if world_width < 1 or world_height < 1:
        raise ValueError("world dimensions must be positive")

    source = image.convert("RGBA")
    normalized = mode.lower().strip()
    if normalized == "stretch":
        return source.resize((world_width, world_height), Image.Resampling.LANCZOS)

    src_w, src_h = source.size
    if src_w < 1 or src_h < 1:
        raise ValueError("source image must have positive dimensions")

    if normalized == "contain":
        scale = min(world_width / src_w, world_height / src_h)
        new_w = max(1, round(src_w * scale))
        new_h = max(1, round(src_h * scale))
        resized = source.resize((new_w, new_h), Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (world_width, world_height), FALLBACK_FILL)
        canvas.paste(resized, ((world_width - new_w) // 2, (world_height - new_h) // 2), resized)
        return canvas

    # cover (default)
    scale = max(world_width / src_w, world_height / src_h)
    new_w = max(world_width, round(src_w * scale))
    new_h = max(world_height, round(src_h * scale))
    resized = source.resize((new_w, new_h), Image.Resampling.LANCZOS)
    left = max(0, (new_w - world_width) // 2)
    top = max(0, (new_h - world_height) // 2)
    return resized.crop((left, top, left + world_width, top + world_height))


def clamp_camera_to_world(
    focus_x: float,
    focus_y: float,
    world_width: float,
    world_height: float,
    view_width: float,
    view_height: float,
) -> tuple[float, float]:
    """Return camera top-left so the viewport stays over the world.

    When the viewport is larger than the world on an axis, the world is centered
    (camera may be negative). Otherwise the camera is clamped to valid bounds so
    the right/bottom edges never show empty space.
    """
    desired_x = focus_x - view_width / 2
    desired_y = focus_y - view_height / 2

    if view_width >= world_width:
        camera_x = (world_width - view_width) / 2
    else:
        camera_x = max(0.0, min(world_width - view_width, desired_x))

    if view_height >= world_height:
        camera_y = (world_height - view_height) / 2
    else:
        camera_y = max(0.0, min(world_height - view_height, desired_y))

    return camera_x, camera_y
