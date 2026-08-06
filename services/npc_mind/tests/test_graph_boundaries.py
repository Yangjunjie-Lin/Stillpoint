from app.graph import GraphEdge, GraphNode, KnowledgeGraph


def test_belief_graph_is_scoped_and_private_canonical_fact_is_not_public():
    graph = KnowledgeGraph()
    for node in [GraphNode("player", "player"), GraphNode("secret", "concept")]:
        graph.add_node(node)
    graph.add_edge(GraphEdge("private", None, "player", "KNOWS", "secret", visibility="private"))
    graph.add_edge(
        GraphEdge("belief", "npc-1", "player", "BELIEVES", "secret", visibility="private")
    )
    assert [edge.id for edge in graph.visible_edges("npc-1")] == ["belief"]
    assert graph.visible_edges("npc-2") == []
