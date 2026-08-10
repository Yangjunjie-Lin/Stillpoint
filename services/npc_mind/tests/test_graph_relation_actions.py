import asyncio

from app.graph import EDGE_TYPES
from app.graph_actions import select_context_motion
from app.repository import InMemoryRepository
from app.schemas import NpcGenerationRequest
from app.service import NpcCognitionService


def _request(text: str = "Where is your house?") -> NpcGenerationRequest:
    return NpcGenerationRequest(
        request_id=f"relation-action-{abs(hash(text))}",
        player_profile_id="player",
        world_save_id="save",
        npc_definition_id="mira",
        npc_persistent_id="base:town/npc/mira",
        session_id="relation-actions",
        text=text,
    )


def test_every_graph_predicate_has_an_authored_relation_category():
    service = NpcCognitionService(repository=InMemoryRepository())
    categories = service.catalog.relation_action_catalog["predicate_categories"]
    assert EDGE_TYPES <= set(categories)


def test_graph_payload_contains_renderer_ready_categories_actions_and_mermaid():
    repository = InMemoryRepository()
    service = NpcCognitionService(repository=repository)
    repository.deploy_profile(
        service.catalog.get_profile("mira"), "player", "save", "base:town/npc/mira"
    )

    payload = service.graph_payload("player", "save", "base:town/npc/mira")
    works_at = next(edge for edge in payload["edges"] if edge["predicate"] == "WORKS_AT")
    assert works_at["relation_category"] == "vocation"
    assert "work" in {
        action["motion_state"] for action in works_at["reusable_actions"]
    }
    assert payload["visualization"]["layout"] == "left_to_right"
    assert "flowchart LR" in payload["visualization"]["mermaid"]
    assert "Mira's Apothecary" in payload["visualization"]["mermaid"]
    assert payload["visualization"]["legend"]


def test_visible_spatial_graph_selects_reusable_point_action():
    service = NpcCognitionService(repository=InMemoryRepository())
    response = asyncio.run(service.handle_turn(_request()))
    assert response.animation_id == "point"


def test_requested_unknown_animation_is_rejected_to_safe_talk():
    service = NpcCognitionService(repository=InMemoryRepository())
    assert (
        select_context_motion(
            "hello", [], service.catalog.relation_action_catalog, "execute_wallet_transfer"
        )
        == "talk"
    )
