from app.graph import GraphEdge, GraphNode, KnowledgeGraph


def test_contradicting_beliefs_are_preserved_as_edges():
    graph = KnowledgeGraph()
    graph.add_node(GraphNode("p", "player"))
    graph.add_node(GraphNode("a", "concept"))
    graph.add_node(GraphNode("b", "concept"))
    graph.add_edge(GraphEdge("old", "npc", "p", "BELIEVES", "a", confidence=0.4))
    graph.add_edge(
        GraphEdge("new", "npc", "p", "BELIEVES", "b", confidence=0.8, supersedes_edge_id="old")
    )
    assert {edge.id for edge in graph.visible_edges("npc")} == {"old", "new"}
