import asyncio

from app.catalog import NpcCatalogRepository
from app.repository import InMemoryRepository
from app.schemas import SyncRequest
from app.service import NpcCognitionService


def _event(npc: str = "base:wilderness/npc/dungeon_warden_0001") -> dict:
    return {
        "event_id": "encounter-aster_quiet_compass-1",
        "player_profile_id": "p",
        "world_save_id": "w",
        "npc_persistent_id": npc,
        "event_type": "encounter_discovered",
        "definition_id": "aster_quiet_compass",
        "content": "The player and Aster witnessed the quiet compass encounter.",
        "subject_node_ids": [
            "base:player/main",
            "base:wilderness/npc/dungeon_warden_0001",
            "encounter:aster_quiet_compass",
        ],
        "visibility": "witnessed",
    }


def test_hidden_encounter_rules_are_not_deployed_as_canonical_npc_knowledge():
    catalog = NpcCatalogRepository()
    hidden = catalog.hidden_encounter_ontology
    assert hidden["visibility"] == "server_hidden_until_discovery"
    assert {item["id"] for item in hidden["encounters"]} >= {
        "aster_quiet_compass",
        "moonleaf_hush",
        "fallen_star_lesson",
    }
    assert not any(
        node["node_type"] == "encounter" for node in catalog.world_ontology["nodes"]
    )
    assert not any(
        edge["predicate"] in {"INVOLVES", "DISCOVERED_IN", "MAY_REWARD"}
        for edge in catalog.world_ontology["edges"]
    )
    rendered = str(hidden)
    assert "trigger_chance" not in rendered
    assert "hidden_salt" not in rendered
    assert "reward_effects" not in rendered
    assert "minimum_level_hint" not in rendered


def test_witnessed_encounter_materializes_only_for_the_witnessing_npc():
    repository = InMemoryRepository()
    service = NpcCognitionService(repository=repository)
    npc = "base:wilderness/npc/dungeon_warden_0001"
    response = asyncio.run(
        service.sync(
            SyncRequest(
                player_profile_id="p",
                world_save_id="w",
                pending_event_outbox=[_event(npc)],
            )
        )
    )
    assert response.accepted_event_ids == ["encounter-aster_quiet_compass-1"]
    payload = service.graph_payload("p", "w", npc)
    nodes = {node["node_id"]: node for node in payload["nodes"]}
    edges = {
        (edge["subject_node_id"], edge["predicate"], edge["object_node_id"])
        for edge in payload["edges"]
    }
    assert nodes["encounter:aster_quiet_compass"]["visibility"] == "witnessed"
    assert (
        "encounter:aster_quiet_compass",
        "INVOLVES",
        "npc_definition:dungeon_warden",
    ) in edges
    assert (
        "encounter:aster_quiet_compass",
        "DISCOVERED_IN",
        "location:wardens_threshold",
    ) in edges
    assert (
        "encounter:aster_quiet_compass",
        "MAY_REWARD",
        "concept:reward_equipment",
    ) in edges
    other = service.graph_payload("p", "w", "base:town/npc/mira_0001")
    assert not any(
        node["node_id"] == "encounter:aster_quiet_compass" for node in other["nodes"]
    )
