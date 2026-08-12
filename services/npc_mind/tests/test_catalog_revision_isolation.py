from __future__ import annotations

import json

from app.catalog import NpcCatalogRepository


def test_pet_catalog_revision_does_not_redeploy_npc_profiles(tmp_path) -> None:
    npc_path = tmp_path / "npc.json"
    pet_path = tmp_path / "pet.json"
    npc_path.write_text(
        json.dumps(
            {
                "game_version": "0.8.0",
                "catalog_version": 7,
                "npcs": [{"definition_id": "base:npc/test"}],
            }
        ),
        encoding="utf-8",
    )
    pet_path.write_text(
        json.dumps(
            {
                "game_version": "0.8.0",
                "catalog_version": 11,
                "pets": [{"definition_id": "pet:test"}],
            }
        ),
        encoding="utf-8",
    )

    catalog = NpcCatalogRepository(npc_path, pet_path)

    assert catalog.catalog_revision == "0.8.0:7"
    assert catalog.get_profile("base:npc/test").catalog_revision == "0.8.0:7"
    assert catalog.get_profile("pet:test").catalog_revision == "0.8.0:companions:11"
