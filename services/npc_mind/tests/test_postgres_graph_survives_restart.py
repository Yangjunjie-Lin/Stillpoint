import asyncio

from app.repository import PostgresCognitionRepository
from tests.postgres_test_support import request, scope, service


def test_postgres_graph_survives_restart(postgres_url):
    player, save, npc = scope()
    first = service(postgres_url)
    asyncio.run(first.handle_turn(request(player, save, npc)))
    first.repository.close()

    restarted = PostgresCognitionRepository(postgres_url)
    edges = restarted.graph_edges_for(player, save, npc)
    assert any(
        edge.subject_node_id == f"npc_instance:{npc}"
        and edge.predicate == "IS_INSTANCE_OF"
        for edge in edges
    )
    assert any(
        edge.subject_node_id == "npc_definition:mira"
        and edge.predicate == "WORKS_AT"
        and edge.object_node_id == "building:mira_apothecary"
        for edge in edges
    )
    assert any(
        edge.subject_node_id == "building:mira_apothecary"
        and edge.predicate == "LOCATED_IN"
        and edge.object_node_id == "region:base:town"
        for edge in edges
    )
    restarted.close()
