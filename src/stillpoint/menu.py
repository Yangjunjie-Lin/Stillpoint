"""Main menu and lightweight non-gameplay windows."""

from __future__ import annotations

import tkinter as tk
from tkinter import simpledialog

from .config import DEFAULT_CONFIG, GameConfig
from .game import GameWindow
from .storage import GameStorage


RULES = """CONTROLS
W / A / S / D    Move
Left click       Shoot toward cursor
ESC              Pause
B                Boss screen
F10              Diagnostics
F11              Toggle fullscreen

POWER-UPS
Green            Shield for 10 seconds
Cyan             Speed boost for 5 seconds
Pink             Double score for 8 seconds
Orange           Double shot for 8 seconds
Red              Piercing shot for 8 seconds
Purple           Large shot for 8 seconds

SCORING
Collect power-up  10 points
Destroy enemy     20 points
Survival           1 point per second

Survive the pressure at the still point of the swarm.
"""


class MainMenu:
    def __init__(
        self,
        config: GameConfig = DEFAULT_CONFIG,
        storage: GameStorage | None = None,
    ) -> None:
        self.config = config
        self.storage = storage or GameStorage(leaderboard_size=config.leaderboard_size)
        self.root = tk.Tk()
        self.root.title(config.title)
        self.root.attributes("-fullscreen", True)
        self.root.configure(bg="#05070b")
        self.root.bind("<F11>", self._toggle_fullscreen)
        self.root.bind("<Escape>", self._toggle_fullscreen)
        self.active_game: GameWindow | None = None
        self._build()

    def _build(self) -> None:
        frame = tk.Frame(self.root, bg="#05070b")
        frame.pack(expand=True)

        tk.Label(
            frame,
            text="STILLPOINT",
            font=("Arial", 52, "bold"),
            fg="#f4f7fb",
            bg="#05070b",
        ).pack(pady=(0, 6))
        tk.Label(
            frame,
            text="Hold the center. Break the swarm.",
            font=("Arial", 14),
            fg="#7f92ad",
            bg="#05070b",
        ).pack(pady=(0, 42))

        for label, command in (
            ("Start game", self.start_game),
            ("How to play", self.show_rules),
            ("Leaderboard", self.show_leaderboard),
            ("Exit", self.root.destroy),
        ):
            tk.Button(
                frame,
                text=label,
                command=command,
                width=26,
                height=2,
                font=("Arial", 13, "bold"),
                bg="#172033",
                fg="#f4f7fb",
                activebackground="#263451",
                activeforeground="white",
                relief=tk.FLAT,
                cursor="hand2",
            ).pack(pady=9)

    def _toggle_fullscreen(self, _event: tk.Event[object] | None = None) -> None:
        current = bool(self.root.attributes("-fullscreen"))
        self.root.attributes("-fullscreen", not current)

    def start_game(self, prefilled_name: str | None = None) -> None:
        name = prefilled_name or simpledialog.askstring(
            "Player name",
            "Enter your name:",
            parent=self.root,
        )
        if not name or not name.strip():
            return

        self.root.withdraw()
        game_root = tk.Toplevel(self.root)
        self.active_game = GameWindow(
            menu=self,
            root=game_root,
            player_name=name.strip()[:24],
            config=self.config,
            storage=self.storage,
        )
        self.active_game.start()

    def show_rules(self) -> None:
        window = tk.Toplevel(self.root)
        window.title("How to play")
        window.geometry("560x650")
        window.configure(bg="#0b0f17")
        window.transient(self.root)

        tk.Label(
            window,
            text="HOW TO PLAY",
            font=("Arial", 24, "bold"),
            fg="#f4f7fb",
            bg="#0b0f17",
        ).pack(pady=(28, 18))
        tk.Label(
            window,
            text=RULES,
            justify=tk.LEFT,
            anchor="nw",
            font=("Consolas", 12),
            fg="#c8d2df",
            bg="#0b0f17",
            padx=30,
            pady=10,
        ).pack(fill=tk.BOTH, expand=True)

    def show_leaderboard(self) -> None:
        window = tk.Toplevel(self.root)
        window.title("Leaderboard")
        window.geometry("460x560")
        window.configure(bg="#0b0f17")
        window.transient(self.root)

        tk.Label(
            window,
            text="LEADERBOARD",
            font=("Arial", 24, "bold"),
            fg="#f4f7fb",
            bg="#0b0f17",
        ).pack(pady=(28, 22))

        entries = self.storage.load_leaderboard()
        table = tk.Frame(window, bg="#0b0f17")
        table.pack(fill=tk.BOTH, expand=True, padx=32)
        for column, title in enumerate(("Rank", "Player", "Score")):
            tk.Label(
                table,
                text=title,
                font=("Arial", 12, "bold"),
                fg="#7f92ad",
                bg="#0b0f17",
                width=(7, 20, 10)[column],
                anchor=("center", "w", "e")[column],
            ).grid(row=0, column=column, pady=(0, 12))

        if not entries:
            tk.Label(
                table,
                text="No scores yet.",
                font=("Arial", 13),
                fg="#7f92ad",
                bg="#0b0f17",
            ).grid(row=1, column=0, columnspan=3, pady=50)
        else:
            for row, entry in enumerate(entries, start=1):
                values = (f"#{row}", entry.name, f"{entry.score:,}")
                for column, value in enumerate(values):
                    tk.Label(
                        table,
                        text=value,
                        font=("Arial", 12),
                        fg="#f4f7fb",
                        bg="#0b0f17",
                        width=(7, 20, 10)[column],
                        anchor=("center", "w", "e")[column],
                    ).grid(row=row, column=column, pady=7)

    def return_to_menu(self) -> None:
        self.active_game = None
        if self.root.winfo_exists():
            self.root.deiconify()
            self.root.focus_force()

    def run(self) -> None:
        self.root.mainloop()
