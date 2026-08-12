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
    hidden_encounter_ontology: dict[str, Any]

    @property
    def entity_kind(self) -> str:
        return str(self.payload.get("entity_kind", "npc"))

    @property
    def definition_node_id(self) -> str:
        return f"{self.entity_kind}_definition:{self.npc_definition_id}"

    def instance_node_id(self, persistent_id: str) -> str:
        return f"{self.entity_kind}_instance:{persistent_id}"


class NpcCatalogRepository:
    """Read-only, server-owned NPC identity and cognition catalog."""

    def __init__(
        self,
        path: str | Path | None = None,
        companion_path: str | Path | None = None,
    ) -> None:
        self.path = Path(path) if path else Path(__file__).parents[1] / "catalog" / "generated_npc_catalog.json"
        document = json.loads(self.path.read_text(encoding="utf-8"))
        companion_document = self._load_companion_catalog(companion_path, path is None)
        revision = f"{document.get('game_version', 'unknown')}:{document.get('catalog_version', 0)}"
        companion_revision = (
            f"{companion_document.get('game_version', 'unknown')}"
            f":companions:{companion_document.get('catalog_version', 0)}"
            if companion_document
            else revision
        )
        self.catalog_revision = revision
        self.world_ontology = dict(document.get("world_ontology", {}))
        self.hidden_encounter_ontology = dict(document.get("hidden_encounter_ontology", {}))
        self.relation_action_catalog = dict(document.get("relation_action_catalog", {}))
        self._profiles: dict[str, NpcProfile] = {}
        raw_profiles = [
            (raw, "npc", revision) for raw in document.get("npcs", [])
        ] + [
            (raw, "pet", companion_revision) for raw in companion_document.get("pets", [])
        ]
        for raw, entity_kind, profile_revision in raw_profiles:
            definition_id = str(raw.get("definition_id", "")).strip()
            if definition_id:
                payload = dict(raw)
                payload["entity_kind"] = entity_kind
                payload.setdefault(
                    "response_constraints",
                    [
                        constraint
                        for skill in payload.get("cognitive_skills", [])
                        for constraint in skill.get("response_constraints", [])
                    ],
                )
                self._profiles[definition_id] = NpcProfile(
                    definition_id,
                    profile_revision,
                    payload,
                    self.world_ontology,
                    self.hidden_encounter_ontology,
                )

    def _load_companion_catalog(
        self,
        companion_path: str | Path | None,
        use_default: bool,
    ) -> dict[str, Any]:
        if companion_path is None and not use_default:
            return {}
        resolved = (
            Path(companion_path)
            if companion_path is not None
            else Path(__file__).parents[1] / "catalog" / "generated_pet_catalog.json"
        )
        if not resolved.exists():
            return {}
        document = json.loads(resolved.read_text(encoding="utf-8-sig"))
        if not isinstance(document, dict):
            raise ValueError("invalid_pet_catalog")
        return document

    def get_profile(self, npc_definition_id: str) -> NpcProfile:
        profile = self._profiles.get(npc_definition_id)
        if profile is None:
            raise ValueError("unknown_npc_definition")
        return profile
