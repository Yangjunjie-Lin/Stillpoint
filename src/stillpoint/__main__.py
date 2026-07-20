"""Command-line entry point for ``python -m stillpoint``."""

from .menu import MainMenu


def main() -> None:
    MainMenu().run()


if __name__ == "__main__":
    main()
