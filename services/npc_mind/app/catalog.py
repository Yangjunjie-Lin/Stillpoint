from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass(frozen=True, slots=True)
class NpcProfile:
    npc_definition_id: str
    catalog_revision: str
    payload: dict[str, Any]
    world_ontology: dict[str, Any]


class NpcCatalogRepository:
    """Read-only, server-owned NPC identity and cognition catalog."""

    def __init__(self, path: str | Path | None = None) -> None:
        self.path = Path(path) if path else Path(__file__).parents[1] / "catalog" / "generated_npc_catalog.json"
        document = json.loads(self.path.read_text(encoding="utf-8"))
        revision = f"{document.get('game_version', 'unknown')}:{document.get('catalog_version', 0)}"
        self.catalog_revision = revision
        self.world_ontology = dict(document.get("world_ontology", {}))
        self._profiles: dict[str, NpcProfile] = {}
        for raw in document.get("npcs", []):
            definition_id = str(raw.get("definition_id", "")).strip()
            if definition_id:
                payload = dict(raw)
                payload.setdefault(
                    "response_constraints",
                    [
                        constraint
                        for skill in payload.get("cognitive_skills", [])
                        for constraint in skill.get("response_constraints", [])
                    ],
                )
                self._profiles[definition_id] = NpcProfile(
                    definition_id, revision, payload, self.world_ontology
                )

    def get_profile(self, npc_definition_id: str) -> NpcProfile:
        profile = self._profiles.get(npc_definition_id)
        if profile is None:
            raise ValueError("unknown_npc_definition")
        return profile
