"""Tkinter game session controller for Stillpoint."""

from __future__ import annotations

import time
import tkinter as tk
from tkinter import messagebox
from typing import TYPE_CHECKING, Any

from .assets import AssetCatalog
from .config import GameConfig
from .engine import GameState
from .render import GameRenderer
from .storage import GameStorage, StorageError

if TYPE_CHECKING:
    from .menu import MainMenu


CHEAT_CODES = {
    "immortal": "godmode",
    "flash": "rapidfire",
    "allitems": "powerup",
    "rich": "points",
    "sonic": "speedup",
}


class GameWindow:
    """Own one game session while sharing the application's Tk main loop."""

    def __init__(
        self,
        menu: "MainMenu",
        root: tk.Toplevel,
        player_name: str,
        config: GameConfig,
        storage: GameStorage,
    ) -> None:
        self.menu = menu
        self.root = root
        self.config = config
        self.storage = storage
        self.root.title(config.title)
        self.root.attributes("-fullscreen", True)
        self.root.protocol("WM_DELETE_WINDOW", self.quit_to_menu)
        self.width = max(800, root.winfo_screenwidth())
        self.height = max(600, root.winfo_screenheight())
        self.canvas = tk.Canvas(root, width=self.width, height=self.height, bg="#05070b", highlightthickness=0, cursor="crosshair")
        self.canvas.pack(fill=tk.BOTH, expand=True)
        world_width, world_height = self._resolve_world_size(self.width, self.height)
        self.assets = AssetCatalog(
            root,
            config.player_size,
            config.obstacle_size,
            world_width,
            world_height,
            config.background_scale_mode,
        ).load()
        self.renderer = GameRenderer(self.canvas, self.assets, self.width, self.height)
        self.state = GameState(config, float(world_width), float(world_height), player_name)
        self.running = True
        self.paused = False
        self.boss_mode = False
        self.diagnostics = False
        self.pressed: set[str] = set()
        self.pause_window: tk.Toplevel | None = None
        self.boss_window: tk.Toplevel | None = None
        self.last_frame_at = time.monotonic()
        self.last_autosave_at = self.last_frame_at
        self.notice = ""
        self.notice_until = 0.0
        self.cheat_input = ""
        self._bind()
        self._offer_resume()

    def _resolve_world_size(self, view_width: int, view_height: int) -> tuple[int, int]:
        world_width = max(self.config.base_world_width, view_width * 2)
        world_height = max(self.config.base_world_height, view_height * 2)
        return world_width, world_height

    def _sync_viewport(self, view_width: int, view_height: int) -> None:
        """Update view size and grow/rebuild the world background when needed."""
        if view_width < 2 or view_height < 2:
            return
        self.width = view_width
        self.height = view_height
        self.renderer.width = view_width
        self.renderer.height = view_height
        needed_w, needed_h = self._resolve_world_size(view_width, view_height)
        grew = needed_w > self.state.world_width or needed_h > self.state.world_height
        if grew:
            self.state.world_width = float(max(self.state.world_width, needed_w))
            self.state.world_height = float(max(self.state.world_height, needed_h))
        if grew or self.assets.world_width != int(self.state.world_width) or self.assets.world_height != int(
            self.state.world_height
        ):
            self.assets.rebuild_world_background(
                int(self.state.world_width),
                int(self.state.world_height),
                self.config.background_scale_mode,
            )

    def _bind(self) -> None:
        self.root.bind("<KeyPress>", self._key_press)
        self.root.bind("<KeyRelease>", self._key_release)
        self.canvas.bind("<Button-1>", self._shoot)
        self.canvas.bind("<Configure>", self._on_canvas_configure)
        self.root.bind("<Escape>", self._toggle_pause)
        self.root.bind("<F10>", self._toggle_diagnostics)
        self.root.bind("<F11>", self._toggle_fullscreen)
        self.root.bind("b", self._toggle_boss)
        self.root.focus_force()

    def _on_canvas_configure(self, event: tk.Event[Any]) -> None:
        if event.widget is not self.canvas:
            return
        if event.width == self.width and event.height == self.height:
            return
        self._sync_viewport(int(event.width), int(event.height))

    def start(self) -> None:
        self.last_frame_at = time.monotonic()
        self.root.after(self.config.frame_delay_ms, self._tick)

    def _offer_resume(self) -> None:
        snapshot = self.storage.load_autosave(self.config.autosave_max_age_seconds)
        if not snapshot:
            return
        if messagebox.askyesno("Resume game", "A recent autosave was found. Resume it?", parent=self.root):
            try:
                self.state.restore(snapshot)
                self.assets.rebuild_world_background(
                    int(self.state.world_width),
                    int(self.state.world_height),
                    self.config.background_scale_mode,
                )
                self._show_notice("Autosave restored")
            except (KeyError, TypeError, ValueError):
                self.storage.clear_autosave()
                self._show_notice("Invalid autosave discarded")
        else:
            self.storage.clear_autosave()

    def _key_press(self, event: tk.Event[Any]) -> None:
        key = str(event.keysym).lower()
        if key in {"w", "a", "s", "d"}:
            self.pressed.add(key)
        if len(key) == 1 and key.isalpha():
            self.cheat_input = (self.cheat_input + key)[-20:]
            for phrase, action in CHEAT_CODES.items():
                if self.cheat_input.endswith(phrase):
                    self.cheat_input = ""
                    self._show_notice(self.state.apply_cheat(action, self.state.game_time))
                    break

    def _key_release(self, event: tk.Event[Any]) -> None:
        self.pressed.discard(str(event.keysym).lower())

    def _shoot(self, event: tk.Event[Any]) -> None:
        if self.paused or self.boss_mode:
            return
        target = self.renderer.screen_to_world(float(event.x), float(event.y))
        self.state.shoot(target, self.state.game_time)

    def _tick(self) -> None:
        if not self.running or not self.root.winfo_exists():
            return
        now = time.monotonic()
        delta = min(0.05, max(0.0, now - self.last_frame_at))
        self.last_frame_at = now
        if not self.paused and not self.boss_mode:
            if not self.state.tick(delta, now, self.pressed):
                self._game_over()
                return
            if now - self.last_autosave_at >= self.config.autosave_interval_seconds:
                self._save()
                self.last_autosave_at = now
        notice = self.notice if now < self.notice_until else ""
        self.renderer.draw(self.state, self.state.game_time, self.diagnostics, notice)
        self.root.after(self.config.frame_delay_ms, self._tick)

    def _save(self) -> None:
        try:
            self.storage.save_autosave(self.state.to_snapshot(self.state.game_time))
        except StorageError:
            self._show_notice("Autosave failed")

    def _toggle_fullscreen(self, _event: tk.Event[Any] | None = None) -> None:
        self.root.attributes("-fullscreen", not bool(self.root.attributes("-fullscreen")))
        self.root.update_idletasks()
        self._sync_viewport(max(2, self.canvas.winfo_width()), max(2, self.canvas.winfo_height()))

    def _toggle_diagnostics(self, _event: tk.Event[Any] | None = None) -> None:
        self.diagnostics = not self.diagnostics

    def _toggle_pause(self, _event: tk.Event[Any] | None = None) -> None:
        if self.boss_mode:
            return
        self.paused = not self.paused
        if self.paused:
            self._save()
            self._pause_dialog()
        elif self.pause_window:
            self.pause_window.destroy()
            self.pause_window = None
            self.last_frame_at = time.monotonic()

    def _pause_dialog(self) -> None:
        if self.pause_window and self.pause_window.winfo_exists():
            return
        window = tk.Toplevel(self.root)
        self.pause_window = window
        window.title("Paused")
        window.geometry("340x370")
        window.transient(self.root)
        window.configure(bg="#0b0f17")
        window.protocol("WM_DELETE_WINDOW", lambda: None)
        tk.Label(window, text="PAUSED", font=("Arial", 26, "bold"), fg="#f4f7fb", bg="#0b0f17").pack(pady=(38, 25))
        for label, command in (
            ("Continue", self._toggle_pause),
            ("Restart", self._restart),
            ("Exit to menu", self.quit_to_menu),
        ):
            tk.Button(window, text=label, command=command, width=20, height=2, bg="#172033", fg="#f4f7fb", relief=tk.FLAT).pack(pady=8)
        window.grab_set()
        window.focus_force()

    def _toggle_boss(self, _event: tk.Event[Any] | None = None) -> None:
        if self.boss_mode:
            if self.boss_window:
                self.boss_window.destroy()
                self.boss_window = None
            self.boss_mode = False
            self.last_frame_at = time.monotonic()
            return
        self.boss_mode = True
        self._save()
        window = tk.Toplevel(self.root)
        self.boss_window = window
        window.attributes("-fullscreen", True)
        window.configure(bg="white")
        window.protocol("WM_DELETE_WINDOW", lambda: None)
        window.bind("b", self._toggle_boss)
        tk.Label(window, text="Annual Financial Report", font=("Arial", 25, "bold"), bg="white").pack(pady=35)
        table = tk.Frame(window, bg="white")
        table.pack()
        rows = [
            ("Quarter", "Revenue", "Expenses", "Profit", "Growth"),
            ("Q1", "$150,000", "$90,000", "$60,000", "+15%"),
            ("Q2", "$180,000", "$100,000", "$80,000", "+20%"),
            ("Q3", "$165,000", "$95,000", "$70,000", "+18%"),
            ("Q4", "$200,000", "$110,000", "$90,000", "+22%"),
        ]
        for row, values in enumerate(rows):
            for column, value in enumerate(values):
                tk.Label(table, text=value, width=16, height=2, relief=tk.SOLID, borderwidth=1, bg="#e5e7eb" if row == 0 else "white", font=("Arial", 12, "bold" if row == 0 else "normal")).grid(row=row, column=column)
        window.focus_force()

    def _restart(self) -> None:
        name = self.state.player_name
        self._close_auxiliary()
        self.running = False
        self.root.destroy()
        self.menu.start_game(name)

    def _show_notice(self, text: str) -> None:
        self.notice = text
        self.notice_until = time.monotonic() + 2

    def _game_over(self) -> None:
        if not self.running:
            return
        self.running = False
        self.state.mark_dead()
        score = self.state.total_score
        combat = self.state.combat
        try:
            self.storage.record_score(self.state.player_name, score)
            self.storage.mark_game_over()
        except StorageError:
            pass
        self.renderer.draw(self.state, self.state.game_time, self.diagnostics)
        cx, cy = self.width / 2, self.height / 2
        self.canvas.create_rectangle(cx - 320, cy - 150, cx + 320, cy + 150, fill="#05070b", outline="#ff4d5a", width=3)
        self.canvas.create_text(cx, cy - 100, text="GAME OVER", fill="#ff4d5a", font=("Arial", 36, "bold"))
        lines = (
            f"Final Score  {score:,}",
            f"Level Reached  {combat.level}",
            f"Enemies Defeated  {combat.enemies_defeated}",
            f"Survival Time  {int(self.state.survival_seconds)}s",
        )
        for index, line in enumerate(lines):
            self.canvas.create_text(cx, cy - 40 + index * 32, text=line, fill="#f4f7fb", font=("Arial", 18))
        self.root.after(2800, self._finish_game_over)

    def _finish_game_over(self) -> None:
        if self.root.winfo_exists():
            self.menu.show_leaderboard()
            self.quit_to_menu()

    def _close_auxiliary(self) -> None:
        for window in (self.pause_window, self.boss_window):
            if window and window.winfo_exists():
                window.destroy()

    def quit_to_menu(self) -> None:
        if not self.running and not self.root.winfo_exists():
            return
        if self.running:
            self._save()
        self.running = False
        self._close_auxiliary()
        if self.root.winfo_exists():
            self.root.destroy()
        self.menu.return_to_menu()
