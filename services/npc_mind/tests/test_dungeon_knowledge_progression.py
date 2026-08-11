import asyncio

from app.repository import InMemoryRepository
from app.providers import _server_owned_memory_candidates
from app.schemas import NpcGenerationRequest, NpcGenerationResult
from app.service import NpcCognitionService


def _request(request_id: str, text: str = "Please remember that Mossjaw guards the first depth."):
    return NpcGenerationRequest(
        request_id=request_id,
        player_profile_id="player-1",
        world_save_id="save-1",
        npc_definition_id="mira",
        npc_persistent_id="base:town/npc/mira_0001",
        session_id="session-mira",
        text=text,
        world_context={"region_id": "base:town", "visible_entity_ids": ["region:base:town"]},
    )


class TaughtWorldFactProvider:
    async def generate_npc_reply(self, request):
        return NpcGenerationResult(
            reply_text="I will record that report and treat it as something you told me.",
            memory_candidates=[
                {
                    "content": request.text,
                    "summary": "Player reported a dungeon fact.",
                    "visibility": "told",
                    "confidence": 0.5,
                    "source_id": request.request_id,
                    "subject_node_ids": ["dungeon:returning_stars_hollow"],
                }
            ],
            graph_update_candidates=[
                {
                    "subject_node_id": "npc_instance:base:town/npc/mira_0001",
                    "predicate": "KNOWS_ABOUT",
                    "object_node_id": "dungeon:returning_stars_hollow",
                    "visibility": "told",
                    "confidence": 0.5,
                    "source_id": request.request_id,
                    "evidence_memory_ids": [request.request_id],
                }
            ],
        )


def test_dungeon_ontology_is_seeded_without_becoming_private_npc_knowledge():
    repository = InMemoryRepository()
    service = NpcCognitionService(repository=repository)
    repository.deploy_profile(
        service.catalog.get_profile("mira"),
        "player-1",
        "save-1",
        "base:town/npc/mira_0001",
    )

    node_ids = {node.node_id for node in repository.graph.nodes.values()}
    edge_facts = {
        (edge.subject_node_id, edge.predicate, edge.object_node_id)
        for edge in repository.graph.edges.values()
    }
    assert "dungeon:returning_stars_hollow" in node_ids
    assert ("dungeon:returning_stars_hollow", "HAS_BOSS", "npc_definition:mossjaw") in edge_facts
    assert ("location:wardens_threshold", "GUARDED_BY", "npc_definition:dungeon_warden") in edge_facts
    retrieved = service.retrieve_graph(_request("r-ontology"))
    assert not any(
        edge["object_node_id"] == "npc_definition:mossjaw"
        for edge in retrieved
    )


def test_told_dungeon_fact_strengthens_npc_knowledge_level():
    repository = InMemoryRepository()
    service = NpcCognitionService(repository=repository, llm=TaughtWorldFactProvider())

    first = asyncio.run(service.handle_turn(_request("r-first")))
    second = asyncio.run(service.handle_turn(_request("r-second")))
    third = asyncio.run(service.handle_turn(_request("r-third")))

    assert first.knowledge_updates[0]["stage"] == "aware"
    assert second.knowledge_updates[0]["confidence"] > first.knowledge_updates[0]["confidence"]
    assert third.knowledge_updates[0]["confidence"] > second.knowledge_updates[0]["confidence"]
    assert third.knowledge_updates[0]["stage"] == "familiar"
    learned = [
        edge
        for edge in repository.graph.edges.values()
        if edge.predicate == "KNOWS_ABOUT"
        and edge.object_node_id == "dungeon:returning_stars_hollow"
        and edge.visibility == "told"
    ]
    assert len(learned) == 1
    assert learned[0].confidence >= 0.7
    # Identical reports consolidate into one durable semantic memory while the
    # confidence level still rises with each independently validated report.
    assert len(learned[0].evidence_memory_ids) == 1


def test_text_provider_classifies_explicit_world_report_as_told_semantic_memory():
    candidates = _server_owned_memory_candidates(
        _request("r-text-report", "请记住：地下城的 Mossjaw 守在第一层。")
    )
    assert len(candidates) == 1
    assert candidates[0].memory_type == "semantic"
    assert candidates[0].visibility == "told"
    assert candidates[0].confidence <= 0.6
