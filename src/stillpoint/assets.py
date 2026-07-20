"""Image loading with graceful fallbacks."""

from __future__ import annotations

from dataclasses import dataclass, field
import tkinter as tk
from typing import Final

from PIL import Image, ImageTk

from .background import scale_background_to_world
from .config import BACKGROUND_SCALE_MODE
from .models import ObstacleBehavior
from .paths import asset_path


DIRECTIONS: Final[tuple[str, ...]] = (
    "up",
    "down",
    "left",
    "right",
    "up_left",
    "up_right",
    "down_left",
    "down_right",
)


@dataclass(slots=True)
class AssetCatalog:
    root: tk.Misc
    player_size: int
    obstacle_size: int
    world_width: int
    world_height: int
    scale_mode: str = BACKGROUND_SCALE_MODE
    background: ImageTk.PhotoImage | None = None
    players: dict[str, ImageTk.PhotoImage | None] = field(default_factory=dict)
    obstacles: dict[ObstacleBehavior, ImageTk.PhotoImage | None] = field(default_factory=dict)
    _raw_background: Image.Image | None = field(default=None, repr=False)
    _world_background: Image.Image | None = field(default=None, repr=False)

    def load(self) -> "AssetCatalog":
        self._raw_background = self._open_rgba("background.png")
        self.rebuild_world_background(self.world_width, self.world_height, self.scale_mode)

        fallback = self._load_image("player_up.png", (self.player_size, self.player_size))
        for direction in DIRECTIONS:
            image = self._load_image(
                f"player_{direction}.png",
                (self.player_size, self.player_size),
            )
            self.players[direction] = image or fallback

        for behavior in ObstacleBehavior:
            self.obstacles[behavior] = self._load_image(
                f"obstacle_{behavior.value}.png",
                (self.obstacle_size, self.obstacle_size),
            )
        return self

    def rebuild_world_background(
        self,
        world_width: int,
        world_height: int,
        scale_mode: str | None = None,
    ) -> None:
        """Rescale the cached source image to the current world size (not per-frame)."""
        self.world_width = max(1, int(world_width))
        self.world_height = max(1, int(world_height))
        if scale_mode is not None:
            self.scale_mode = scale_mode
        if self._raw_background is None:
            self._world_background = None
            self.background = None
            return
        try:
            scaled = scale_background_to_world(
                self._raw_background,
                self.world_width,
                self.world_height,
                self.scale_mode,
            )
        except (OSError, ValueError):
            self._world_background = None
            self.background = None
            return
        self._world_background = scaled
        self.background = ImageTk.PhotoImage(scaled, master=self.root)

    def _open_rgba(self, filename: str) -> Image.Image | None:
        try:
            return Image.open(asset_path(filename)).convert("RGBA")
        except (FileNotFoundError, OSError, ValueError):
            return None

    def _load_image(self, filename: str, size: tuple[int, int]) -> ImageTk.PhotoImage | None:
        try:
            image = Image.open(asset_path(filename)).convert("RGBA")
            image = image.resize(size, Image.Resampling.LANCZOS)
            return ImageTk.PhotoImage(image, master=self.root)
        except (FileNotFoundError, OSError, ValueError):
            return None
