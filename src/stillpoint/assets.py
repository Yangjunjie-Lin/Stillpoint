"""Image loading with graceful fallbacks."""

from __future__ import annotations

from dataclasses import dataclass, field
import tkinter as tk
from typing import Final

from PIL import Image, ImageTk

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
    canvas_width: int
    canvas_height: int
    background: ImageTk.PhotoImage | None = None
    players: dict[str, ImageTk.PhotoImage | None] = field(default_factory=dict)
    obstacles: dict[ObstacleBehavior, ImageTk.PhotoImage | None] = field(default_factory=dict)

    def load(self) -> "AssetCatalog":
        self.background = self._load_image(
            "background.png",
            (max(1, self.canvas_width * 2), max(1, self.canvas_height * 2)),
        )

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

    def _load_image(self, filename: str, size: tuple[int, int]) -> ImageTk.PhotoImage | None:
        try:
            image = Image.open(asset_path(filename)).convert("RGBA")
            image = image.resize(size, Image.Resampling.LANCZOS)
            return ImageTk.PhotoImage(image, master=self.root)
        except (FileNotFoundError, OSError, ValueError):
            return None
