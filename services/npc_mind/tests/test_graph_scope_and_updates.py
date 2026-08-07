import asyncio

from app.graph import GraphEdge, GraphNode
from app.repository import InMemoryRepository
from app.schemas import NpcGenerationRequest, NpcGenerationResult
from app.service import NpcCognitionService


def _request(player="p", save="w", npc="mira-1"):
    return NpcGenerationRequest(
        request_id=f"r-{player}-{save}-{npc}",
        player_profile_id=player,
        world_save_id=save,
        npc_definition_id="mira",
        npc_persistent_id=npc,
        session_id=f"s-{player}-{save}-{npc}",
        text="Remember this graph fact.",
    )


def test_graph_player_scope_isolation():
    repository = InMemoryRepository()
    service = NpcCognitionService(repository=repository)
    asyncio.run(service.handle_turn(_request()))
    assert service.graph_payload("p", "w", "mira-1")["edges"]
    other = service.graph_payload("other", "w", "mira-1")["edges"]
    assert not any(edge["owner_npc_persistent_id"] == "mira-1" for edge in other)


def test_graph_world_save_scope_isolation():
    repository = InMemoryRepository()
    service = NpcCognitionService(repository=repository)
    asyncio.run(service.handle_turn(_request()))
    other = service.graph_payload("p", "other", "mira-1")["edges"]
    assert not any(edge["owner_npc_persistent_id"] == "mira-1" for edge in other)


def test_graph_updates_persist():
    repository = InMemoryRepository()
    repository.add_graph_node(GraphNode("concept:a", "concept"))
    repository.add_graph_node(GraphNode("concept:b", "concept"))
    edge = GraphEdge(
        "edge-1", "mira-1", "concept:a", "BELIEVES", "concept:b",
        player_profile_id="p", world_save_id="w",
    )
    repository.add_graph_edge(edge)
    assert repository.graph_edges_for("p", "w", "mira-1") == [edge]


class InvalidCandidateProvider:
    async def generate_npc_reply(self, request):
        return NpcGenerationResult(
            reply_text="ok",
            memory_candidates=[
                {"content": "evidence", "source_id": request.request_id}
            ],
            graph_update_candidates=[
                {
                    "subject_node_id": "npc_definition:mira",
                    "predicate": "CANONICAL_REWRITE",
                    "object_node_id": "region:base:town",
                    "evidence_memory_ids": [request.request_id],
                }
            ],
        )


def test_graph_candidate_validation():
    repository = InMemoryRepository()
    service = NpcCognitionService(repository=repository, llm=InvalidCandidateProvider())
    asyncio.run(service.handle_turn(_request()))
    assert all(edge.predicate != "CANONICAL_REWRITE" for edge in repository.graph.edges.values())


def test_graph_endpoint_does_not_return_unrelated_nodes():
    repository = InMemoryRepository()
    service = NpcCognitionService(repository=repository)
    asyncio.run(service.handle_turn(_request()))
    repository.add_graph_node(GraphNode("concept:unrelated", "concept"))
    payload = service.graph_payload("p", "w", "mira-1")
    assert "concept:unrelated" not in {node["node_id"] for node in payload["nodes"]}


def test_private_canonical_node_is_not_a_valid_candidate_target():
    repository = InMemoryRepository()
    repository.add_graph_node(
        GraphNode("concept:canonical-secret", "concept", visibility="private")
    )
    assert not repository.graph_node_exists(
        "concept:canonical-secret", "p", "w", "mira-1"
    )


def test_catalog_seeds_graph():
    service = NpcCognitionService(repository=InMemoryRepository())
    asyncio.run(service.handle_turn(_request()))
    payload = service.graph_payload("p", "w", "mira-1")
    assert any(edge["predicate"] == "IS_INSTANCE_OF" for edge in payload["edges"])
    assert any(node["node_type"] == "skill" for node in payload["nodes"])
