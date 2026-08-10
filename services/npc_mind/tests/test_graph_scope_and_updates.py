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


class CanonicalWorldCandidateProvider:
    async def generate_npc_reply(self, request):
        return NpcGenerationResult(
            reply_text="I will not rewrite authored geography.",
            memory_candidates=[
                {"content": "A claim about a building.", "source_id": request.request_id}
            ],
            graph_update_candidates=[
                {
                    "subject_node_id": "building:mira_apothecary",
                    "predicate": "LOCATED_IN",
                    "object_node_id": "region:base:dungeon",
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


def test_graph_endpoint_does_not_return_other_profile_catalog_nodes():
    repository = InMemoryRepository()
    service = NpcCognitionService(repository=repository)
    repository.deploy_profile(service.catalog.get_profile("mira"), "p", "w", "mira-1")
    repository.deploy_profile(
        service.catalog.get_profile("bandit"), "p", "w", "bandit-1"
    )

    payload = service.graph_payload("p", "w", "mira-1")
    node_ids = {node["node_id"] for node in payload["nodes"]}

    assert "npc_definition:mira" in node_ids
    assert "npc_definition:bandit" not in node_ids
    assert "skill:ambush" not in node_ids
    assert "region:base:dungeon" not in node_ids


def test_in_memory_session_lookup_enforces_full_scope():
    repository = InMemoryRepository()
    session = repository.create_session(_request().model_dump())

    assert repository.get_session(session.session_id, "p", "w", "mira-1") is session
    assert repository.get_session(session.session_id, "other", "w", "mira-1") is None
    assert repository.get_session(session.session_id, "p", "other", "mira-1") is None
    assert repository.get_session(session.session_id, "p", "w", "other") is None


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


def test_world_house_ontology_is_connected_to_mira_profile():
    repository = InMemoryRepository()
    service = NpcCognitionService(repository=repository)
    repository.deploy_profile(service.catalog.get_profile("mira"), "p", "w", "mira-1")

    payload = service.graph_payload("p", "w", "mira-1")
    nodes = {node["node_id"]: node for node in payload["nodes"]}
    edges = {
        (edge["subject_node_id"], edge["predicate"], edge["object_node_id"])
        for edge in payload["edges"]
    }

    assert nodes["building:mira_apothecary"]["node_type"] == "building"
    assert nodes["building:mira_apothecary"]["metadata"]["floor_count"] == 2
    assert (
        "npc_definition:mira",
        "WORKS_AT",
        "building:mira_apothecary",
    ) in edges
    assert (
        "building:mira_apothecary",
        "LOCATED_IN",
        "region:base:town",
    ) in edges
    assert (
        "building:mira_apothecary",
        "CONNECTED_TO",
        "location:town_plaza",
    ) in edges
    retrieved = service.retrieve_graph(_request())
    works_at = next(edge for edge in retrieved if edge["predicate"] == "WORKS_AT")
    assert works_at["object_node"]["label"] == "Mira's Apothecary"
    assert works_at["object_node"]["metadata"]["primary_function"] == "apothecary_trade"


def test_world_ontology_does_not_walk_backward_into_other_npc_buildings():
    repository = InMemoryRepository()
    service = NpcCognitionService(repository=repository)
    repository.deploy_profile(service.catalog.get_profile("mira"), "p", "w", "mira-1")
    repository.deploy_profile(service.catalog.get_profile("ren"), "p", "w", "ren-1")

    mira_nodes = {
        node["node_id"] for node in service.graph_payload("p", "w", "mira-1")["nodes"]
    }
    ren_nodes = {
        node["node_id"] for node in service.graph_payload("p", "w", "ren-1")["nodes"]
    }
    assert "building:mira_apothecary" in mira_nodes
    assert "building:town_guardhouse" not in mira_nodes
    assert "building:town_guardhouse" in ren_nodes
    assert "building:mira_apothecary" not in ren_nodes


def test_llm_candidate_cannot_rewrite_canonical_house_geography():
    repository = InMemoryRepository()
    service = NpcCognitionService(
        repository=repository, llm=CanonicalWorldCandidateProvider()
    )
    asyncio.run(service.handle_turn(_request()))

    invalid = [
        edge
        for edge in repository.graph.edges.values()
        if edge.subject_node_id == "building:mira_apothecary"
        and edge.predicate == "LOCATED_IN"
        and edge.object_node_id == "region:base:dungeon"
    ]
    assert invalid == []
    assert service.metrics["graph_candidate_rejected"] >= 1
