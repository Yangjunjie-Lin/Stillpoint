"""Canvas rendering for the Tkinter front end."""

from __future__ import annotations

import math
import tkinter as tk

from .assets import AssetCatalog
from .background import clamp_camera_to_world
from .combat import experience_ratio, health_ratio
from .engine import GameState
from .models import ItemType, Obstacle, ObstacleBehavior, Vec2, WeaponType


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
        self._display_health: float | None = None

    def draw(self, state: GameState, now: float, diagnostics: bool, notice: str = "") -> None:
        self._update_camera(state)
        self._smooth_health(state)
        self.canvas.delete("all")
        self._background()
        self._visibility_ring(state)
        self._items(state)
        self._bullets(state)
        self._obstacles(state, now)
        self._player(state, now)
        self._floating_texts(state, now)
        self._hud(state, now, diagnostics, notice)
        self._level_up_banner(state, now)

    def world_to_screen(self, position: Vec2) -> tuple[float, float]:
        return position.x - self.camera.x, position.y - self.camera.y

    def screen_to_world(self, x: float, y: float) -> Vec2:
        return Vec2(x + self.camera.x, y + self.camera.y)

    def _update_camera(self, state: GameState) -> None:
        self.camera.x, self.camera.y = clamp_camera_to_world(
            state.player.x,
            state.player.y,
            state.world_width,
            state.world_height,
            float(self.width),
            float(self.height),
        )

    def _smooth_health(self, state: GameState) -> None:
        target = max(0.0, state.combat.current_health)
        if self._display_health is None:
            self._display_health = target
            return
        # Visual-only lerp; combat uses real current_health.
        self._display_health += (target - self._display_health) * 0.35
        if abs(self._display_health - target) < 0.05:
            self._display_health = target

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
        self.canvas.create_image(-self.camera.x, -self.camera.y, image=image, anchor="nw")

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
            self.canvas.create_oval(
                x - radius, y - radius, x + radius, y + radius, fill=ITEM_COLORS[item.item_type], outline="white"
            )

    def _bullets(self, state: GameState) -> None:
        radius = state.bullet_size / 2
        for bullet in state.bullets:
            if not self._visible(state, bullet.position):
                continue
            x, y = self.world_to_screen(bullet.position)
            self.canvas.create_oval(x - radius, y - radius, x + radius, y + radius, fill="#ffe66d", outline="")

    def _obstacles(self, state: GameState, now: float) -> None:
        radius = state.config.obstacle_size / 2
        for obstacle in state.obstacles:
            if not self._visible(state, obstacle.position):
                continue
            x, y = self.world_to_screen(obstacle.position)
            flashing = now < obstacle.hit_flash_until
            image = self.assets.obstacles.get(obstacle.behavior)
            if image and not flashing:
                self.canvas.create_image(x, y, image=image)
            else:
                fill = "#ffffff" if flashing else OBSTACLE_COLORS[obstacle.behavior]
                self.canvas.create_rectangle(
                    x - radius, y - radius, x + radius, y + radius, fill=fill, outline="#ffecec" if flashing else ""
                )
            self._enemy_health_bar(state, obstacle, x, y, radius, now)

    def _enemy_health_bar(
        self,
        state: GameState,
        obstacle: Obstacle,
        screen_x: float,
        screen_y: float,
        radius: float,
        now: float,
    ) -> None:
        ratio = health_ratio(obstacle.current_health, obstacle.max_health)
        show = ratio < 0.999 or now < obstacle.health_bar_visible_until
        if not show:
            return
        width = float(state.config.enemy_health_bar_width)
        height = float(state.config.enemy_health_bar_height)
        left = screen_x - width / 2
        top = screen_y - radius - 12
        fill_width = max(0.0, width * ratio)
        self.canvas.create_rectangle(left, top, left + width, top + height, fill="#1a1f2b", outline="#0b0f17")
        if fill_width > 0:
            color = "#40e96b" if ratio > 0.5 else "#ffd166" if ratio > 0.25 else "#ff4d5a"
            self.canvas.create_rectangle(left, top, left + fill_width, top + height, fill=color, outline="")

    def _player(self, state: GameState, now: float) -> None:
        x, y = self.world_to_screen(state.player)
        image = self.assets.players.get(state.direction)
        radius = state.config.player_size / 2
        invulnerable = now < state.combat.invulnerability_until
        flashing = now < state.combat.hit_flash_until
        blink_hidden = invulnerable and int(now * 12) % 2 == 0 and not flashing
        if not blink_hidden:
            if image and not flashing:
                self.canvas.create_image(x, y, image=image)
            else:
                fill = "#ff8a8a" if flashing else "#e6edf7"
                outline = "#ff4d5a" if flashing else "#6ee7ff"
                self.canvas.create_oval(
                    x - radius, y - radius, x + radius, y + radius, fill=fill, outline=outline, width=2
                )
        if flashing:
            self.canvas.create_oval(
                x - radius - 4, y - radius - 4, x + radius + 4, y + radius + 4, outline="#ff4d5a", width=3
            )
        if state.effects.shielded(now):
            self.canvas.create_oval(
                x - radius - 6, y - radius - 6, x + radius + 6, y + radius + 6, outline="#40e96b", width=3
            )

    def _floating_texts(self, state: GameState, now: float) -> None:
        for item in state.floating_texts:
            if item.is_expired(now):
                continue
            progress = (now - item.created_at) / max(0.001, item.lifetime)
            x, y = self.world_to_screen(item.position)
            self.canvas.create_text(x, y - progress * 28, fill=item.color, font=("Arial", 12, "bold"), text=item.text)

    def _hud(self, state: GameState, now: float, diagnostics: bool, notice: str) -> None:
        self.canvas.create_text(
            20, 20, anchor="nw", fill="#f4f7fb", font=("Arial", 19, "bold"), text=f"Score  {state.total_score:,}"
        )
        self.canvas.create_text(
            20,
            50,
            anchor="nw",
            fill="#7f92ad",
            font=("Arial", 11),
            text=f"Combat {state.score:,}  •  Survival {int(state.survival_seconds):,}",
        )
        self._draw_player_bars(state, now)
        effects: list[tuple[str, float, str]] = []
        if state.effects.god_mode:
            effects.append(("God mode", math.inf, "#ffe66d"))
        if state.effects.rapid_fire:
            effects.append(("Rapid fire", math.inf, "#ffe66d"))
        for label, until, color in (
            ("Shield", state.effects.shield_until, "#40e96b"),
            ("Speed", state.effects.speed_until, "#33d9ff"),
            ("Double score", state.effects.score_multiplier_until, "#ff59df"),
            (
                {
                    WeaponType.DOUBLE: "Double shot",
                    WeaponType.PIERCE: "Piercing",
                    WeaponType.LARGE: "Large shot",
                }.get(state.effects.weapon, ""),
                state.effects.weapon_until,
                "#ffab40",
            ),
        ):
            if label and (math.isinf(until) or until > now):
                effects.append((label, until, color))
        y = 168
        for label, until, color in effects:
            value = "ACTIVE" if math.isinf(until) else f"{max(0, until - now):.1f}s"
            self.canvas.create_text(20, y, anchor="nw", fill=color, font=("Arial", 11, "bold"), text=f"{label}: {value}")
            y += 22
        if diagnostics:
            self.canvas.create_text(
                20,
                self.height - 25,
                anchor="sw",
                fill="#8da2be",
                font=("Consolas", 10),
                text=(
                    f"position=({state.player.x:.0f}, {state.player.y:.0f})  "
                    f"enemies={len(state.obstacles)}  bullets={len(state.bullets)}  "
                    f"difficulty={state.difficulty_scale:.2f}  lv={state.combat.level}"
                ),
            )
        if notice:
            self.canvas.create_text(self.width / 2, 50, fill="#ffe66d", font=("Arial", 16, "bold"), text=notice)

    def _draw_player_bars(self, state: GameState, now: float) -> None:
        display_hp = self._display_health if self._display_health is not None else state.combat.current_health
        display_hp = max(0.0, display_hp)
        ratio = health_ratio(display_hp, state.combat.max_health)
        low = ratio <= 0.25
        warn = low and int(now * 4) % 2 == 0
        bar_x, bar_y, bar_w, bar_h = 20, 78, 220, 14
        hp_color = "#ff4d5a" if low else "#40e96b"
        outline = "#ff4d5a" if warn else "#243044"
        self.canvas.create_text(
            bar_x,
            bar_y - 16,
            anchor="nw",
            fill="#ff8a8a" if warn else "#f4f7fb",
            font=("Arial", 11, "bold"),
            text=f"HP  {int(display_hp)} / {int(state.combat.max_health)}",
        )
        self.canvas.create_rectangle(bar_x, bar_y, bar_x + bar_w, bar_y + bar_h, fill="#121826", outline=outline, width=2)
        fill_w = max(0.0, bar_w * ratio)
        if fill_w > 0:
            self.canvas.create_rectangle(bar_x, bar_y, bar_x + fill_w, bar_y + bar_h, fill=hp_color, outline="")

        exp_ratio = experience_ratio(state.combat.current_experience, state.combat.experience_to_next_level)
        exp_y = bar_y + 28
        self.canvas.create_text(
            bar_x,
            exp_y - 16,
            anchor="nw",
            fill="#c7d2fe",
            font=("Arial", 11, "bold"),
            text=(
                f"LV. {state.combat.level}   "
                f"EXP {state.combat.current_experience} / {state.combat.experience_to_next_level}"
            ),
        )
        self.canvas.create_rectangle(bar_x, exp_y, bar_x + bar_w, exp_y + 10, fill="#121826", outline="#243044")
        exp_w = max(0.0, bar_w * exp_ratio)
        if exp_w > 0:
            self.canvas.create_rectangle(bar_x, exp_y, bar_x + exp_w, exp_y + 10, fill="#7c9cff", outline="")

    def _level_up_banner(self, state: GameState, now: float) -> None:
        if now >= state.combat.level_up_effect_until:
            return
        remaining = state.combat.level_up_effect_until - now
        pulse = 1.0 + 0.08 * math.sin(remaining * 10)
        self.canvas.create_text(
            self.width / 2,
            self.height * 0.28,
            fill="#ffe66d",
            font=("Arial", int(28 * pulse), "bold"),
            text="LEVEL UP!",
        )
        self.canvas.create_text(
            self.width / 2,
            self.height * 0.28 + 36,
            fill="#f4f7fb",
            font=("Arial", 18, "bold"),
            text=f"Level {state.combat.last_level_gained}",
        )
