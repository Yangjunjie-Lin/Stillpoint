"""Reject backend source, credentials, and test/tool paths in a Godot export."""

from __future__ import annotations

import argparse
from pathlib import Path


FORBIDDEN = (
    b"OPENAI_API_KEY",
    b"NPC_MIND_SIGNING_KEY",
    b"Authorization: Bearer",
    b"services/npc_mind",
    b"res://services/npc_mind",
    b"res://tests/",
    b"res://tools/",
    b"postgresql://",
    b"postgresql+psycopg://",
    b"/.env",
    b"\\.env",
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifact", type=Path)
    args = parser.parse_args()
    data = args.artifact.read_bytes()
    findings = [pattern.decode("ascii") for pattern in FORBIDDEN if pattern in data]
    if findings:
        print(f"Export scan FAILED for {args.artifact}:")
        for finding in findings:
            print(f"- {finding}")
        return 1
    print(f"Export scan OK for {args.artifact} ({len(data)} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
