from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


NODE_TYPES = {
    "npc_definition",
    "npc_instance",
    "player",
    "region",
    "faction",
    "item",
    "quest",
    "event",
    "location",
    "building",
    "container",
    "concept",
    "profession",
    "skill",
    "relationship",
    "memory",
    "crop",
    "encounter",
    "shop",
    "shop_offer",
    "forge_recipe",
}
EDGE_TYPES = {
    "IS_INSTANCE_OF",
    "KNOWS",
    "BELIEVES",
    "DOUBTS",
    "HAS_SKILL",
    "MEMBER_OF",
    "LIVES_IN",
    "WORKS_AT",
    "OWNS",
    "LIKES",
    "DISLIKES",
    "TRUSTS",
    "FEARS",
    "RELATED_TO",
    "WITNESSED",
    "EXPERIENCED",
    "PROMISED",
    "GAVE",
    "RECEIVED",
    "ATTACKED",
    "HELPED",
    "KNOWS_ABOUT",
    "LOCATED_IN",
    "CONTAINS",
    "CONNECTED_TO",
    "PORTAL_TO",
    "HAS_SEED",
    "PRODUCES",
    "GROWS_IN",
    "OPENED_BY",
    "HAS_DEPTH",
    "HAS_BOSS",
    "GUARDED_BY",
    "REQUIRES_LEVEL",
    "RESPAWNS_AFTER",
    "BELONGS_TO",
    "PRACTICED_WITH",
    "PRACTICED_BY",
    "SYNERGIZES_WITH",
    "RECOVERS_AFTER",
    "OPERATED_BY",
    "OFFERS",
    "SELLS",
    "AVAILABLE_AT",
    "PERFORMED_BY",
    "REQUIRES_MATERIAL",
    "INVOLVES",
    "DISCOVERED_IN",
    "MAY_REWARD",
}

CANONICAL_WORLD_EDGE_TYPES = {
    "LOCATED_IN",
    "CONTAINS",
    "CONNECTED_TO",
    "PORTAL_TO",
    "HAS_SEED",
    "PRODUCES",
    "GROWS_IN",
    "OPENED_BY",
    "HAS_DEPTH",
    "HAS_BOSS",
    "GUARDED_BY",
    "REQUIRES_LEVEL",
    "RESPAWNS_AFTER",
    "BELONGS_TO",
    "PRACTICED_WITH",
    "PRACTICED_BY",
    "SYNERGIZES_WITH",
    "RECOVERS_AFTER",
    "OPERATED_BY",
    "OFFERS",
    "SELLS",
    "AVAILABLE_AT",
    "PERFORMED_BY",
    "REQUIRES_MATERIAL",
    "INVOLVES",
    "DISCOVERED_IN",
    "MAY_REWARD",
}


@dataclass(slots=True)
class GraphNode:
    node_id: str
    node_type: str
    label: str = ""
    metadata: dict[str, Any] = field(default_factory=dict)
    player_profile_id: str | None = None
    world_save_id: str | None = None
    owner_npc_persistent_id: str | None = None
    catalog_revision: str = ""
    visibility: str = "public"
    source: str = "authored"


@dataclass(slots=True)
class GraphEdge:
    id: str
    owner_npc_persistent_id: str | None
    subject_node_id: str
    predicate: str
    object_node_id: str
    confidence: float = 0.5
    visibility: str = "private"
    source_type: str = "authored"
    source_id: str = ""
    evidence_memory_ids: list[str] = field(default_factory=list)
    valid_from: str | None = None
    valid_until: str | None = None
    created_at: str = ""
    updated_at: str = ""
    supersedes_edge_id: str | None = None
    player_profile_id: str | None = None
    world_save_id: str | None = None
    catalog_revision: str = ""

    def to_dict(self) -> dict[str, Any]:
        return {name: getattr(self, name) for name in self.__dataclass_fields__}


class KnowledgeGraph:
    def __init__(self) -> None:
        self.nodes: dict[str, GraphNode] = {}
        self.edges: dict[str, GraphEdge] = {}

    def add_node(self, node: GraphNode) -> None:
        if node.node_type not in NODE_TYPES:
            raise ValueError("invalid_node_type")
        self.nodes[node.node_id] = node

    def add_edge(self, edge: GraphEdge) -> None:
        if edge.predicate not in EDGE_TYPES:
            raise ValueError("invalid_edge_type")
        if edge.subject_node_id not in self.nodes or edge.object_node_id not in self.nodes:
            raise ValueError("unknown_graph_node")
        self.edges[edge.id] = edge

    def visible_edges(
        self,
        npc_persistent_id: str,
        allowed_domains: set[str] | None = None,
        player_profile_id: str | None = None,
        world_save_id: str | None = None,
    ) -> list[GraphEdge]:
        result: list[GraphEdge] = []
        for edge in self.edges.values():
            if edge.owner_npc_persistent_id not in (None, "", npc_persistent_id):
                continue
            if edge.owner_npc_persistent_id not in (None, ""):
                if player_profile_id is not None and edge.player_profile_id != player_profile_id:
                    continue
                if world_save_id is not None and edge.world_save_id != world_save_id:
                    continue
            if edge.visibility not in {"public", "witnessed", "told", "skill", "private"}:
                continue
            if edge.owner_npc_persistent_id is None and edge.visibility == "private":
                continue
            if (
                allowed_domains
                and edge.source_type == "skill"
                and not (allowed_domains & {edge.source_id})
            ):
                continue
            result.append(edge)
        return result

    def traverse(
        self,
        start_node_ids: set[str],
        npc_persistent_id: str,
        depth: int = 2,
        player_profile_id: str | None = None,
        world_save_id: str | None = None,
    ) -> list[GraphEdge]:
        depth = min(max(depth, 0), 2)
        visible = self.visible_edges(
            npc_persistent_id,
            player_profile_id=player_profile_id,
            world_save_id=world_save_id,
        )
        frontier = set(start_node_ids)
        seen_nodes = set(frontier)
        result: list[GraphEdge] = []
        for _ in range(depth):
            next_frontier: set[str] = set()
            for edge in visible:
                if edge.subject_node_id in frontier or edge.object_node_id in frontier:
                    if edge not in result:
                        result.append(edge)
                    next_frontier.add(edge.subject_node_id)
                    next_frontier.add(edge.object_node_id)
            next_frontier -= seen_nodes
            seen_nodes |= next_frontier
            frontier = next_frontier
            if not frontier:
                break
        return result
