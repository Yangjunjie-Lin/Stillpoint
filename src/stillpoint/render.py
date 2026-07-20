"""Canvas rendering for the Tkinter front end."""

from __future__ import annotations

import math
import tkinter as tk

from .assets import AssetCatalog
from .engine import GameState
from .models import ItemType, ObstacleBehavior, Vec2, WeaponType


ITEM_COLORS = {
    ItemType.SHIELD: "#40e96b",
    ItemType.SPEED: "#33d9ff",
    ItemType.POINTS: "#ff59df",
    ItemType.DOUBLE: "#ffab40",
    ItemType.PIERCE: "#ff4d5a",
    ItemType.LARGE: "#a96cff",
}
OBSTACLE_COLORS = {
    ObstacleBehavior.CHASE: "#ff4d5a",
    ObstacleBehavior.AVOID: "#ffd166",
    ObstacleBehavior.CIRCLE: "#ff8c42",
}


class GameRenderer:
    def __init__(self, canvas: tk.Canvas, assets: AssetCatalog, width: int, height: int) -> None:
        self.canvas = canvas
        self.assets = assets
        self.width = width
        self.height = height
        self.camera = Vec2(0, 0)

    def draw(self, state: GameState, now: float, diagnostics: bool, notice: str = "") -> None:
        self._update_camera(state)
        self.canvas.delete("all")
        self._background()
        self._visibility_ring(state)
        self._items(state)
        self._bullets(state)
        self._obstacles(state)
        self._player(state, now)
        self._hud(state, now, diagnostics, notice)

    def world_to_screen(self, position: Vec2) -> tuple[float, float]:
        return position.x - self.camera.x, position.y - self.camera.y

    def screen_to_world(self, x: float, y: float) -> Vec2:
        return Vec2(x + self.camera.x, y + self.camera.y)

    def _update_camera(self, state: GameState) -> None:
        max_x = max(0.0, state.world_size - self.width)
        max_y = max(0.0, state.world_size - self.height)
        self.camera.x = max(0.0, min(max_x, state.player.x - self.width / 2))
        self.camera.y = max(0.0, min(max_y, state.player.y - self.height / 2))

    def _visible(self, state: GameState, point: Vec2) -> bool:
        return state.player.distance_to(point) <= state.config.visible_radius

    def _background(self) -> None:
        image = self.assets.background
        if image is None:
            self.canvas.configure(bg="#05070b")
            for x in range(0, self.width, 80):
                self.canvas.create_line(x, 0, x, self.height, fill="#0c1420")
            for y in range(0, self.height, 80):
                self.canvas.create_line(0, y, self.width, y, fill="#0c1420")
            return
        x0 = int(-(self.camera.x % image.width()))
        y0 = int(-(self.camera.y % image.height()))
        for x in range(x0 - image.width(), self.width, image.width()):
            for y in range(y0 - image.height(), self.height, image.height()):
                self.canvas.create_image(x, y, image=image, anchor="nw")

    def _visibility_ring(self, state: GameState) -> None:
        x, y = self.world_to_screen(state.player)
        radius = state.config.visible_radius
        self.canvas.create_oval(x - radius, y - radius, x + radius, y + radius, outline="#30445f", width=2)

    def _items(self, state: GameState) -> None:
        radius = state.config.item_size / 2
        for item in state.items:
            if not self._visible(state, item.position):
                continue
            x, y = self.world_to_screen(item.position)
            self.canvas.create_oval(x - radius, y - radius, x + radius, y + radius, fill=ITEM_COLORS[item.item_type], outline="white")

    def _bullets(self, state: GameState) -> None:
        radius = state.bullet_size / 2
        for bullet in state.bullets:
            if not self._visible(state, bullet.position):
                continue
            x, y = self.world_to_screen(bullet.position)
            self.canvas.create_oval(x - radius, y - radius, x + radius, y + radius, fill="#ffe66d", outline="")

    def _obstacles(self, state: GameState) -> None:
        radius = state.config.obstacle_size / 2
        for obstacle in state.obstacles:
            if not self._visible(state, obstacle.position):
                continue
            x, y = self.world_to_screen(obstacle.position)
            image = self.assets.obstacles.get(obstacle.behavior)
            if image:
                self.canvas.create_image(x, y, image=image)
            else:
                self.canvas.create_rectangle(x - radius, y - radius, x + radius, y + radius, fill=OBSTACLE_COLORS[obstacle.behavior], outline="")

    def _player(self, state: GameState, now: float) -> None:
        x, y = self.world_to_screen(state.player)
        image = self.assets.players.get(state.direction)
        radius = state.config.player_size / 2
        if image:
            self.canvas.create_image(x, y, image=image)
        else:
            self.canvas.create_oval(x - radius, y - radius, x + radius, y + radius, fill="#e6edf7", outline="#6ee7ff", width=2)
        if state.effects.shielded(now):
            self.canvas.create_oval(x - radius - 6, y - radius - 6, x + radius + 6, y + radius + 6, outline="#40e96b", width=3)

    def _hud(self, state: GameState, now: float, diagnostics: bool, notice: str) -> None:
        self.canvas.create_text(20, 20, anchor="nw", fill="#f4f7fb", font=("Arial", 19, "bold"), text=f"Score  {state.total_score:,}")
        self.canvas.create_text(20, 50, anchor="nw", fill="#7f92ad", font=("Arial", 11), text=f"Combat {state.score:,}  •  Survival {int(state.survival_seconds):,}")
        effects: list[tuple[str, float, str]] = []
        if state.effects.god_mode:
            effects.append(("God mode", math.inf, "#ffe66d"))
        if state.effects.rapid_fire:
            effects.append(("Rapid fire", math.inf, "#ffe66d"))
        for label, until, color in (
            ("Shield", state.effects.shield_until, "#40e96b"),
            ("Speed", state.effects.speed_until, "#33d9ff"),
            ("Double score", state.effects.score_multiplier_until, "#ff59df"),
            ({WeaponType.DOUBLE: "Double shot", WeaponType.PIERCE: "Piercing", WeaponType.LARGE: "Large shot"}.get(state.effects.weapon, ""), state.effects.weapon_until, "#ffab40"),
        ):
            if label and (math.isinf(until) or until > now):
                effects.append((label, until, color))
        y = 90
        for label, until, color in effects:
            value = "ACTIVE" if math.isinf(until) else f"{max(0, until - now):.1f}s"
            self.canvas.create_text(20, y, anchor="nw", fill=color, font=("Arial", 11, "bold"), text=f"{label}: {value}")
            y += 22
        if diagnostics:
            self.canvas.create_text(20, self.height - 25, anchor="sw", fill="#8da2be", font=("Consolas", 10), text=f"position=({state.player.x:.0f}, {state.player.y:.0f})  enemies={len(state.obstacles)}  bullets={len(state.bullets)}  difficulty={state.difficulty_scale:.2f}")
        if notice:
            self.canvas.create_text(self.width / 2, 50, fill="#ffe66d", font=("Arial", 16, "bold"), text=notice)
