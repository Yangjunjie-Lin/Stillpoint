from __future__ import annotations

import hashlib
import json
import uuid
from dataclasses import dataclass, field
from datetime import date, datetime, timezone
from decimal import Decimal
from typing import Any, Protocol, runtime_checkable

from sqlalchemy import Engine, create_engine, text

from .catalog import NpcProfile
from .graph import EDGE_TYPES, NODE_TYPES, GraphEdge, GraphNode, KnowledgeGraph
from .memory import MemoryRecord, consolidate, reinforce, vector_similarity


def scope_key(
    player_profile_id: str, world_save_id: str, npc_persistent_id: str
) -> tuple[str, str, str]:
    if not player_profile_id or not world_save_id or not npc_persistent_id:
        raise ValueError("invalid_cognition_scope")
    return player_profile_id, world_save_id, npc_persistent_id


@dataclass(slots=True)
class ConversationTurn:
    turn_id: str
    role: str
    text: str
    created_at_real: str
    occurred_at_game: dict[str, Any]
    region_id: str
    emotion: str = "neutral"
    token_usage: dict[str, int] = field(default_factory=dict)
    request_id: str = ""

    def to_dict(self) -> dict[str, Any]:
        return {name: getattr(self, name) for name in self.__dataclass_fields__}


@dataclass(slots=True)
class ConversationSession:
    session_id: str
    player_profile_id: str
    world_save_id: str
    npc_persistent_id: str
    npc_definition_id: str
    started_at: str
    last_active_at: str
    title: str = ""
    rolling_summary: str = ""
    turns: list[ConversationTurn] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return {
            "session_id": self.session_id,
            "player_profile_id": self.player_profile_id,
            "world_save_id": self.world_save_id,
            "npc_persistent_id": self.npc_persistent_id,
            "npc_definition_id": self.npc_definition_id,
            "started_at": self.started_at,
            "last_active_at": self.last_active_at,
            "title": self.title,
            "rolling_summary": self.rolling_summary,
            "turns": [turn.to_dict() for turn in self.turns],
        }


@runtime_checkable
class CognitionRepository(Protocol):
    def create_session(self, values: dict[str, Any]) -> ConversationSession: ...
    def get_session(
        self,
        session_id: str,
        player: str | None = None,
        save: str | None = None,
        npc: str | None = None,
    ) -> ConversationSession | None: ...
    def add_turn(
        self,
        session: ConversationSession,
        role: str,
        text_value: str,
        request_id: str,
        **kwargs: Any,
    ) -> ConversationTurn: ...
    def add_memory(self, memory: MemoryRecord) -> MemoryRecord: ...
    def memories_for(self, player: str, save: str, npc: str) -> list[MemoryRecord]: ...
    def search_memories(
        self, player: str, save: str, npc: str, embedding: list[float], limit: int
    ) -> list[tuple[MemoryRecord, float]]: ...
    def record_recall(
        self, memory: MemoryRecord, query: str, vector_score: float, combined_score: float
    ) -> None: ...
    def get_idempotent_response(
        self, player: str, save: str, npc: str, request_id: str
    ) -> dict[str, Any] | None: ...
    def store_idempotent_response(
        self, player: str, save: str, npc: str, request_id: str, response: dict[str, Any]
    ) -> None: ...
    def record_usage(
        self,
        player: str,
        save: str,
        npc: str,
        request_id: str,
        usage: dict[str, int],
        cost_usd: float,
    ) -> None: ...
    def daily_cost(self, player: str, usage_day: date | None = None) -> float: ...
    def deploy_profile(self, profile: NpcProfile, player: str, save: str, npc: str) -> None: ...
    def resolve_npc_definition_id(
        self, player: str, save: str, npc: str
    ) -> str | None: ...
    def graph_edges_for(self, player: str, save: str, npc: str) -> list[GraphEdge]: ...
    def graph_nodes_for_edges(self, edges: list[GraphEdge]) -> list[GraphNode]: ...
    def add_graph_edge(self, edge: GraphEdge) -> GraphEdge: ...
    def graph_node_exists(self, node_id: str, player: str, save: str, npc: str) -> bool: ...
    def delete_npc(self, player: str, save: str, npc: str) -> int: ...
    def delete_player(self, player: str, save: str | None = None) -> int: ...
    def export_player(self, player: str, save: str) -> dict[str, Any]: ...
    def outbox_receipt_exists(
        self, player: str, save: str, npc: str, kind: str, entry_id: str
    ) -> bool: ...
    def store_outbox_receipt(
        self,
        player: str,
        save: str,
        npc: str,
        kind: str,
        entry_id: str,
        payload: dict[str, Any],
    ) -> None: ...
    def sync_revision(self, player: str, save: str, npc: str) -> int: ...
    def advance_sync_revision(self, player: str, save: str, npc: str) -> int: ...
    def add_conflict(
        self,
        player: str,
        save: str,
        npc: str,
        client_revision: int,
        server_revision: int,
        reason: str,
    ) -> dict[str, Any]: ...


class InMemoryRepository:
    """Unit-test and explicit development repository. It is never a silent fallback."""

    def __init__(self) -> None:
        self.sessions: dict[str, ConversationSession] = {}
        self.memories: dict[str, MemoryRecord] = {}
        self.graph = KnowledgeGraph()
        self.idempotent_responses: dict[tuple[str, str, str, str], dict[str, Any]] = {}
        self.usage: dict[str, int] = {}
        self.usage_records: list[dict[str, Any]] = []
        self.profile_deployments: set[tuple[str, str, str, str, str]] = set()
        self.outbox_receipts: set[tuple[str, str, str, str, str]] = set()
        self.sync_revisions: dict[tuple[str, str, str], int] = {}
        self.conflicts: list[dict[str, Any]] = []

    def create_session(self, values: dict[str, Any]) -> ConversationSession:
        requested = str(values.get("session_id") or uuid.uuid4())
        existing = self.sessions.get(requested)
        if existing:
            if (
                existing.player_profile_id,
                existing.world_save_id,
                existing.npc_persistent_id,
            ) != scope_key(
                values["player_profile_id"], values["world_save_id"], values["npc_persistent_id"]
            ):
                raise ValueError("session_scope_conflict")
            requested_definition = str(values.get("npc_definition_id", ""))
            if (
                requested_definition
                and existing.npc_definition_id
                and requested_definition != existing.npc_definition_id
            ):
                raise ValueError("npc_definition_scope_mismatch")
            return existing
        now = _now().isoformat()
        session = ConversationSession(
            session_id=requested,
            player_profile_id=values["player_profile_id"],
            world_save_id=values["world_save_id"],
            npc_persistent_id=values["npc_persistent_id"],
            npc_definition_id=values.get("npc_definition_id", ""),
            started_at=now,
            last_active_at=now,
            title=values.get("title", ""),
        )
        self.sessions[requested] = session
        return session

    def get_session(
        self,
        session_id: str,
        player: str | None = None,
        save: str | None = None,
        npc: str | None = None,
    ) -> ConversationSession | None:
        session = self.sessions.get(session_id)
        if session is None:
            return None
        if player is not None and session.player_profile_id != player:
            return None
        if save is not None and session.world_save_id != save:
            return None
        if npc is not None and session.npc_persistent_id != npc:
            return None
        return session

    def add_turn(
        self,
        session: ConversationSession,
        role: str,
        text_value: str,
        request_id: str,
        *,
        emotion: str = "neutral",
        usage: dict[str, int] | None = None,
        occurred_at_game: dict[str, Any] | None = None,
        region_id: str = "",
    ) -> ConversationTurn:
        for existing in session.turns:
            if existing.request_id == request_id and existing.role == role:
                return existing
        turn = ConversationTurn(
            turn_id=str(uuid.uuid4()),
            role=role,
            text=text_value,
            created_at_real=_now().isoformat(),
            occurred_at_game=occurred_at_game or {},
            region_id=region_id,
            emotion=emotion,
            token_usage=usage or {},
            request_id=request_id,
        )
        session.turns.append(turn)
        session.last_active_at = turn.created_at_real
        if len(session.turns) > 8:
            old = session.turns[:-8]
            session.rolling_summary = _summarize_turns(old, session.rolling_summary)
            session.turns = session.turns[-8:]
        return turn

    def add_memory(self, memory: MemoryRecord) -> MemoryRecord:
        scope_key(memory.player_profile_id, memory.world_save_id, memory.owner_npc_persistent_id)
        for existing in self.memories.values():
            if (
                existing.player_profile_id,
                existing.world_save_id,
                existing.owner_npc_persistent_id,
                existing.content.strip().lower(),
            ) == (
                memory.player_profile_id,
                memory.world_save_id,
                memory.owner_npc_persistent_id,
                memory.content.strip().lower(),
            ):
                existing.salience = max(existing.salience, memory.salience)
                return existing
        self.memories[memory.memory_id] = memory
        return memory

    def memories_for(self, player: str, save: str, npc: str) -> list[MemoryRecord]:
        scope_key(player, save, npc)
        return [
            memory
            for memory in self.memories.values()
            if (memory.player_profile_id, memory.world_save_id, memory.owner_npc_persistent_id)
            == (player, save, npc)
            and not memory.archived
        ]

    def search_memories(
        self, player: str, save: str, npc: str, embedding: list[float], limit: int
    ) -> list[tuple[MemoryRecord, float]]:
        scored = [
            (memory, vector_similarity(embedding, memory.embedding))
            for memory in self.memories_for(player, save, npc)
        ]
        return sorted(scored, key=lambda item: item[1], reverse=True)[:limit]

    def record_recall(
        self, memory: MemoryRecord, query: str, vector_score: float, combined_score: float
    ) -> None:
        del query, vector_score, combined_score
        reinforce(memory)

    def consolidate_scope(self, player: str, save: str, npc: str) -> list[MemoryRecord]:
        records = consolidate(self.memories_for(player, save, npc))
        keep = {record.memory_id for record in records}
        for memory in self.memories.values():
            if (memory.player_profile_id, memory.world_save_id, memory.owner_npc_persistent_id) == (
                player,
                save,
                npc,
            ) and memory.memory_id not in keep:
                memory.archived = True
        return records

    def get_idempotent_response(
        self, player: str, save: str, npc: str, request_id: str
    ) -> dict[str, Any] | None:
        return self.idempotent_responses.get((*scope_key(player, save, npc), request_id))

    def store_idempotent_response(
        self, player: str, save: str, npc: str, request_id: str, response: dict[str, Any]
    ) -> None:
        self.idempotent_responses.setdefault(
            (*scope_key(player, save, npc), request_id), response.copy()
        )

    def record_usage(
        self,
        player: str,
        save: str,
        npc: str,
        request_id: str,
        usage: dict[str, int],
        cost_usd: float,
    ) -> None:
        if any(record["request_id"] == request_id and record["scope"] == (player, save, npc) for record in self.usage_records):
            return
        self.usage[player] = self.usage.get(player, 0) + usage.get("output_tokens", 0)
        self.usage_records.append(
            {
                "scope": scope_key(player, save, npc),
                "request_id": request_id,
                "usage": usage.copy(),
                "cost_usd": cost_usd,
                "usage_day": _now().date(),
            }
        )

    def daily_cost(self, player: str, usage_day: date | None = None) -> float:
        target = usage_day or _now().date()
        return sum(
            float(record["cost_usd"])
            for record in self.usage_records
            if record["scope"][0] == player and record["usage_day"] == target
        )

    def deploy_profile(self, profile: NpcProfile, player: str, save: str, npc: str) -> None:
        existing_definition = self.resolve_npc_definition_id(player, save, npc)
        if existing_definition is not None and existing_definition != profile.npc_definition_id:
            raise ValueError("npc_definition_scope_mismatch")
        deployment = (player, save, npc, profile.npc_definition_id, profile.catalog_revision)
        if deployment in self.profile_deployments:
            return
        self.profile_deployments = {
            item for item in self.profile_deployments if item[:3] != (player, save, npc)
        }
        self.profile_deployments.add(deployment)
        _seed_graph(self, profile, player, save, npc)

    def resolve_npc_definition_id(self, player: str, save: str, npc: str) -> str | None:
        scope = scope_key(player, save, npc)
        definitions = {
            deployment[3]
            for deployment in self.profile_deployments
            if deployment[:3] == scope
        }
        if not definitions:
            definitions = {
                session.npc_definition_id
                for session in self.sessions.values()
                if (
                    session.player_profile_id,
                    session.world_save_id,
                    session.npc_persistent_id,
                )
                == scope
                and session.npc_definition_id
            }
        if len(definitions) > 1:
            raise ValueError("npc_profile_deployment_conflict")
        return next(iter(definitions), None)

    def add_graph_node(self, node: GraphNode) -> GraphNode:
        existing = self.graph.nodes.get(_graph_memory_key(node))
        if existing:
            return existing
        self.graph.nodes[_graph_memory_key(node)] = node
        return node

    def add_graph_edge(self, edge: GraphEdge) -> GraphEdge:
        if edge.predicate not in EDGE_TYPES:
            raise ValueError("invalid_edge_type")
        existing = next(
            (
                item
                for item in self.graph.edges.values()
                if _edge_signature(item) == _edge_signature(edge)
            ),
            None,
        )
        if existing:
            return existing
        self.graph.edges[edge.id] = edge
        return edge

    def graph_edges_for(self, player: str, save: str, npc: str) -> list[GraphEdge]:
        return _relevant_graph_edges(
            self.graph.visible_edges(
                npc, player_profile_id=player, world_save_id=save
            ),
            player,
            save,
            npc,
        )

    def graph_nodes_for_edges(self, edges: list[GraphEdge]) -> list[GraphNode]:
        ids = {item for edge in edges for item in (edge.subject_node_id, edge.object_node_id)}
        allowed_scopes = {
            (edge.player_profile_id, edge.world_save_id, edge.owner_npc_persistent_id)
            for edge in edges
        }
        return [
            node
            for node in self.graph.nodes.values()
            if node.node_id in ids
            and (
                (node.player_profile_id is None and node.visibility != "private")
                or (
                    node.player_profile_id,
                    node.world_save_id,
                    node.owner_npc_persistent_id,
                )
                in allowed_scopes
            )
        ]

    def graph_node_exists(self, node_id: str, player: str, save: str, npc: str) -> bool:
        return any(
            node.node_id == node_id
            and (
                (node.player_profile_id is None and node.visibility != "private")
                or (node.player_profile_id, node.world_save_id, node.owner_npc_persistent_id)
                == (player, save, npc)
            )
            for node in self.graph.nodes.values()
        )

    def delete_npc(self, player: str, save: str, npc: str) -> int:
        removed = [m.memory_id for m in self.memories_for(player, save, npc)]
        for memory_id in removed:
            del self.memories[memory_id]
        for session_id, session in list(self.sessions.items()):
            if (session.player_profile_id, session.world_save_id, session.npc_persistent_id) == (
                player,
                save,
                npc,
            ):
                del self.sessions[session_id]
        self.idempotent_responses = {
            key: value
            for key, value in self.idempotent_responses.items()
            if key[:3] != (player, save, npc)
        }
        self.usage_records = [
            record for record in self.usage_records if record["scope"] != (player, save, npc)
        ]
        self.profile_deployments = {
            deployment
            for deployment in self.profile_deployments
            if deployment[:3] != (player, save, npc)
        }
        self.outbox_receipts = {
            receipt for receipt in self.outbox_receipts if receipt[:3] != (player, save, npc)
        }
        self.sync_revisions.pop((player, save, npc), None)
        self.conflicts = [
            conflict
            for conflict in self.conflicts
            if (
                conflict.get("player_profile_id"),
                conflict.get("world_save_id"),
                conflict.get("npc_persistent_id"),
            )
            != (player, save, npc)
        ]
        self.graph.edges = {
            edge_id: edge
            for edge_id, edge in self.graph.edges.items()
            if (edge.player_profile_id, edge.world_save_id, edge.owner_npc_persistent_id)
            != (player, save, npc)
        }
        self.graph.nodes = {
            node_id: node
            for node_id, node in self.graph.nodes.items()
            if (node.player_profile_id, node.world_save_id, node.owner_npc_persistent_id)
            != (player, save, npc)
        }
        return len(removed)

    def delete_player(self, player: str, save: str | None = None) -> int:
        scopes = {
            (memory.world_save_id, memory.owner_npc_persistent_id)
            for memory in self.memories.values()
            if memory.player_profile_id == player and (save is None or memory.world_save_id == save)
        }
        scopes.update(
            (session.world_save_id, session.npc_persistent_id)
            for session in self.sessions.values()
            if session.player_profile_id == player
            and (save is None or session.world_save_id == save)
        )
        scopes.update(
            (receipt[1], receipt[2])
            for receipt in self.outbox_receipts
            if receipt[0] == player and (save is None or receipt[1] == save)
        )
        return sum(self.delete_npc(player, world, npc) for world, npc in scopes)

    def export_player(self, player: str, save: str) -> dict[str, Any]:
        return {
            "player_profile_id": player,
            "world_save_id": save,
            "memories": [
                item.to_dict()
                for item in self.memories.values()
                if item.player_profile_id == player and item.world_save_id == save
            ],
            "sessions": [
                item.to_dict()
                for item in self.sessions.values()
                if item.player_profile_id == player and item.world_save_id == save
            ],
        }

    def outbox_receipt_exists(
        self, player: str, save: str, npc: str, kind: str, entry_id: str
    ) -> bool:
        return (player, save, npc, kind, entry_id) in self.outbox_receipts

    def store_outbox_receipt(
        self,
        player: str,
        save: str,
        npc: str,
        kind: str,
        entry_id: str,
        payload: dict[str, Any],
    ) -> None:
        del payload
        self.outbox_receipts.add((player, save, npc, kind, entry_id))

    def sync_revision(self, player: str, save: str, npc: str) -> int:
        return self.sync_revisions.get(scope_key(player, save, npc), 0)

    def advance_sync_revision(self, player: str, save: str, npc: str) -> int:
        scope = scope_key(player, save, npc)
        self.sync_revisions[scope] = self.sync_revisions.get(scope, 0) + 1
        return self.sync_revisions[scope]

    def add_conflict(
        self,
        player: str,
        save: str,
        npc: str,
        client_revision: int,
        server_revision: int,
        reason: str,
    ) -> dict[str, Any]:
        conflict = {
            "conflict_id": str(uuid.uuid4()),
            "player_profile_id": player,
            "world_save_id": save,
            "npc_persistent_id": npc,
            "client_revision": client_revision,
            "server_revision": server_revision,
            "reason": reason,
        }
        self.conflicts.append(conflict)
        return conflict


class PostgresCognitionRepository:
    """Production repository. Connection errors are surfaced and never downgrade to memory."""

    def __init__(self, database_url: str, *, engine: Engine | None = None) -> None:
        if not database_url and engine is None:
            raise ValueError("database_url_required")
        self.engine = engine or create_engine(_normalize_database_url(database_url), pool_pre_ping=True)

    def close(self) -> None:
        self.engine.dispose()

    def create_session(self, values: dict[str, Any]) -> ConversationSession:
        player, save, npc = scope_key(
            values["player_profile_id"], values["world_save_id"], values["npc_persistent_id"]
        )
        session_id = str(values.get("session_id") or uuid.uuid4())
        now = _now()
        with self.engine.begin() as connection:
            existing = connection.execute(
                text(
                    "SELECT * FROM conversation_sessions WHERE session_id=:session_id "
                    "AND player_profile_id=:player AND world_save_id=:save AND npc_persistent_id=:npc"
                ),
                {"session_id": session_id, "player": player, "save": save, "npc": npc},
            ).mappings().first()
            if (
                existing
                and values.get("npc_definition_id")
                and existing["npc_definition_id"] != values["npc_definition_id"]
            ):
                raise ValueError("npc_definition_scope_mismatch")
            if not existing:
                connection.execute(
                    text(
                        "INSERT INTO conversation_sessions "
                        "(id, session_id, player_profile_id, world_save_id, npc_persistent_id, "
                        "npc_definition_id, started_at, last_active_at, title, rolling_summary) "
                        "VALUES (:id, :session_id, :player, :save, :npc, :definition, :now, :now, :title, '')"
                    ),
                    {
                        "id": uuid.uuid4(),
                        "session_id": session_id,
                        "player": player,
                        "save": save,
                        "npc": npc,
                        "definition": values.get("npc_definition_id", ""),
                        "now": now,
                        "title": values.get("title", ""),
                    },
                )
        result = self.get_session(session_id, player, save, npc)
        assert result is not None
        return result

    def get_session(
        self,
        session_id: str,
        player: str | None = None,
        save: str | None = None,
        npc: str | None = None,
    ) -> ConversationSession | None:
        conditions = ["session_id=:session_id"]
        params: dict[str, Any] = {"session_id": session_id}
        if player is not None:
            conditions.append("player_profile_id=:player")
            params["player"] = player
        if save is not None:
            conditions.append("world_save_id=:save")
            params["save"] = save
        if npc is not None:
            conditions.append("npc_persistent_id=:npc")
            params["npc"] = npc
        with self.engine.connect() as connection:
            row = connection.execute(
                text("SELECT * FROM conversation_sessions WHERE " + " AND ".join(conditions)),
                params,
            ).mappings().first()
            if row is None:
                return None
            turns = connection.execute(
                text(
                    "SELECT * FROM conversation_turns WHERE session_id=:session_id "
                    "AND player_profile_id=:player AND world_save_id=:save AND npc_persistent_id=:npc "
                    "ORDER BY created_at_real DESC LIMIT 8"
                ),
                {
                    "session_id": session_id,
                    "player": row["player_profile_id"],
                    "save": row["world_save_id"],
                    "npc": row["npc_persistent_id"],
                },
            ).mappings().all()
        return _session_from_row(row, list(reversed(turns)))

    def add_turn(
        self,
        session: ConversationSession,
        role: str,
        text_value: str,
        request_id: str,
        *,
        emotion: str = "neutral",
        usage: dict[str, int] | None = None,
        occurred_at_game: dict[str, Any] | None = None,
        region_id: str = "",
    ) -> ConversationTurn:
        now = _now()
        turn_id = uuid.uuid4()
        params = {
            "turn_id": turn_id,
            "player": session.player_profile_id,
            "save": session.world_save_id,
            "npc": session.npc_persistent_id,
            "session_id": session.session_id,
            "role": role,
            "text_value": text_value,
            "now": now,
            "game": json.dumps(occurred_at_game or {}),
            "region": region_id,
            "emotion": emotion,
            "usage": json.dumps(usage or {}),
            "request_id": request_id,
        }
        with self.engine.begin() as connection:
            session_row_id = connection.execute(
                text(
                    "SELECT id FROM conversation_sessions WHERE session_id=:session_id "
                    "AND player_profile_id=:player AND world_save_id=:save AND npc_persistent_id=:npc"
                ),
                params,
            ).scalar_one()
            params["session_row_id"] = session_row_id
            row = connection.execute(
                text(
                    "INSERT INTO conversation_turns "
                    "(turn_id, player_profile_id, world_save_id, npc_persistent_id, session_row_id, session_id, "
                    "role, text, created_at_real, occurred_at_game, region_id, emotion, token_usage, request_id) "
                    "VALUES (:turn_id, :player, :save, :npc, :session_row_id, :session_id, :role, :text_value, :now, "
                    "CAST(:game AS jsonb), :region, :emotion, CAST(:usage AS jsonb), :request_id) "
                    "ON CONFLICT (player_profile_id, world_save_id, npc_persistent_id, request_id, role) "
                    "DO UPDATE SET request_id=EXCLUDED.request_id RETURNING *"
                ),
                params,
            ).mappings().one()
            existing_turns = session.turns + [_turn_from_row(row)]
            if len(existing_turns) > 8:
                session.rolling_summary = _summarize_turns(
                    existing_turns[:-8], session.rolling_summary
                )
            connection.execute(
                text(
                    "UPDATE conversation_sessions SET last_active_at=:now, rolling_summary=:summary "
                    "WHERE session_id=:session_id AND player_profile_id=:player "
                    "AND world_save_id=:save AND npc_persistent_id=:npc"
                ),
                {
                    "now": now,
                    "summary": session.rolling_summary,
                    "session_id": session.session_id,
                    "player": session.player_profile_id,
                    "save": session.world_save_id,
                    "npc": session.npc_persistent_id,
                },
            )
        turn = _turn_from_row(row)
        if not any(item.turn_id == turn.turn_id for item in session.turns):
            session.turns.append(turn)
            session.turns = session.turns[-8:]
        session.last_active_at = _iso(now)
        return turn

    def add_memory(self, memory: MemoryRecord) -> MemoryRecord:
        scope_key(memory.player_profile_id, memory.world_save_id, memory.owner_npc_persistent_id)
        if len(memory.embedding) != 1536:
            raise ValueError("embedding_dimension_mismatch")
        with self.engine.begin() as connection:
            existing = connection.execute(
                text(
                    "SELECT * FROM npc_memories WHERE player_profile_id=:player AND world_save_id=:save "
                    "AND npc_persistent_id=:npc AND lower(trim(content))=lower(trim(:content)) "
                    "AND archived=false LIMIT 1"
                ),
                {
                    "player": memory.player_profile_id,
                    "save": memory.world_save_id,
                    "npc": memory.owner_npc_persistent_id,
                    "content": memory.content,
                },
            ).mappings().first()
            if existing:
                connection.execute(
                    text(
                        "UPDATE npc_memories SET salience=GREATEST(salience, :salience) "
                        "WHERE memory_id=:memory_id"
                    ),
                    {"salience": memory.salience, "memory_id": existing["memory_id"]},
                )
                return _memory_from_row(existing)
            connection.execute(
                text(
                    "INSERT INTO npc_memories "
                    "(memory_id, player_profile_id, world_save_id, npc_persistent_id, session_id, "
                    "memory_type, content, summary, embedding, occurred_at_game, created_at_real, "
                    "last_recalled_at, recall_count, salience, emotional_valence, confidence, "
                    "retention_strength, half_life_hours, source_type, source_id, subject_node_ids, "
                    "visibility, archived, supersedes_memory_id) VALUES "
                    "(:memory_id, :player, :save, :npc, :session_id, :memory_type, :content, :summary, "
                    "CAST(:embedding AS vector), CAST(:game AS jsonb), :created, :last_recalled, "
                    ":recall_count, :salience, :valence, :confidence, :retention, :half_life, "
                    ":source_type, :source_id, CAST(:subjects AS jsonb), :visibility, :archived, "
                    ":supersedes)"
                ),
                _memory_params(memory),
            )
        return memory

    def memories_for(self, player: str, save: str, npc: str) -> list[MemoryRecord]:
        scope_key(player, save, npc)
        with self.engine.connect() as connection:
            rows = connection.execute(
                text(
                    "SELECT * FROM npc_memories WHERE player_profile_id=:player "
                    "AND world_save_id=:save AND npc_persistent_id=:npc AND archived=false "
                    "ORDER BY created_at_real DESC"
                ),
                {"player": player, "save": save, "npc": npc},
            ).mappings().all()
        return [_memory_from_row(row) for row in rows]

    def search_memories(
        self, player: str, save: str, npc: str, embedding: list[float], limit: int
    ) -> list[tuple[MemoryRecord, float]]:
        scope_key(player, save, npc)
        if len(embedding) != 1536:
            raise ValueError("embedding_dimension_mismatch")
        with self.engine.connect() as connection:
            rows = connection.execute(
                text(
                    "SELECT *, 1 - (embedding <=> CAST(:embedding AS vector)) AS vector_similarity "
                    "FROM npc_memories WHERE player_profile_id=:player AND world_save_id=:save "
                    "AND npc_persistent_id=:npc AND archived=false "
                    "ORDER BY embedding <=> CAST(:embedding AS vector) LIMIT :limit"
                ),
                {
                    "embedding": _vector_literal(embedding),
                    "player": player,
                    "save": save,
                    "npc": npc,
                    "limit": max(1, min(limit, 100)),
                },
            ).mappings().all()
        return [(_memory_from_row(row), max(0.0, float(row["vector_similarity"]))) for row in rows]

    def record_recall(
        self, memory: MemoryRecord, query: str, vector_score: float, combined_score: float
    ) -> None:
        recalled_at = _now()
        with self.engine.begin() as connection:
            connection.execute(
                text(
                    "UPDATE npc_memories SET last_recalled_at=:now, recall_count=recall_count+1, "
                    "retention_strength=LEAST(2.0, retention_strength+0.05) "
                    "WHERE memory_id=:memory_id AND player_profile_id=:player AND world_save_id=:save "
                    "AND npc_persistent_id=:npc"
                ),
                {
                    "now": recalled_at,
                    "memory_id": uuid.UUID(memory.memory_id),
                    "player": memory.player_profile_id,
                    "save": memory.world_save_id,
                    "npc": memory.owner_npc_persistent_id,
                },
            )
            connection.execute(
                text(
                    "INSERT INTO recall_history (recall_id, player_profile_id, world_save_id, "
                    "npc_persistent_id, memory_id, query_text, vector_similarity, combined_score, recalled_at) "
                    "VALUES (:id, :player, :save, :npc, :memory, :query, :vector, :combined, :now)"
                ),
                {
                    "id": uuid.uuid4(),
                    "player": memory.player_profile_id,
                    "save": memory.world_save_id,
                    "npc": memory.owner_npc_persistent_id,
                    "memory": uuid.UUID(memory.memory_id),
                    "query": query,
                    "vector": vector_score,
                    "combined": combined_score,
                    "now": recalled_at,
                },
            )
        reinforce(memory)

    def get_idempotent_response(
        self, player: str, save: str, npc: str, request_id: str
    ) -> dict[str, Any] | None:
        with self.engine.connect() as connection:
            row = connection.execute(
                text(
                    "SELECT response_json FROM idempotent_request_responses "
                    "WHERE player_profile_id=:player AND world_save_id=:save "
                    "AND npc_persistent_id=:npc AND request_id=:request_id"
                ),
                {"player": player, "save": save, "npc": npc, "request_id": request_id},
            ).mappings().first()
        return dict(row["response_json"]) if row else None

    def store_idempotent_response(
        self, player: str, save: str, npc: str, request_id: str, response: dict[str, Any]
    ) -> None:
        with self.engine.begin() as connection:
            connection.execute(
                text(
                    "INSERT INTO idempotent_request_responses "
                    "(id, player_profile_id, world_save_id, npc_persistent_id, request_id, response_json, created_at) "
                    "VALUES (:id, :player, :save, :npc, :request, CAST(:response AS jsonb), :now) "
                    "ON CONFLICT (player_profile_id, world_save_id, npc_persistent_id, request_id) DO NOTHING"
                ),
                {
                    "id": uuid.uuid4(),
                    "player": player,
                    "save": save,
                    "npc": npc,
                    "request": request_id,
                    "response": json.dumps(response),
                    "now": _now(),
                },
            )

    def record_usage(
        self,
        player: str,
        save: str,
        npc: str,
        request_id: str,
        usage: dict[str, int],
        cost_usd: float,
    ) -> None:
        with self.engine.begin() as connection:
            connection.execute(
                text(
                    "INSERT INTO usage_records (usage_id, player_profile_id, world_save_id, "
                    "npc_persistent_id, request_id, input_tokens, output_tokens, cost_usd, usage_day, created_at) "
                    "VALUES (:id, :player, :save, :npc, :request, :input, :output, :cost, :day, :now) "
                    "ON CONFLICT (player_profile_id, world_save_id, npc_persistent_id, request_id) DO NOTHING"
                ),
                {
                    "id": uuid.uuid4(),
                    "player": player,
                    "save": save,
                    "npc": npc,
                    "request": request_id,
                    "input": usage.get("input_tokens", 0),
                    "output": usage.get("output_tokens", 0),
                    "cost": Decimal(str(cost_usd)),
                    "day": _now().date(),
                    "now": _now(),
                },
            )

    def daily_cost(self, player: str, usage_day: date | None = None) -> float:
        with self.engine.connect() as connection:
            value = connection.execute(
                text(
                    "SELECT COALESCE(SUM(cost_usd), 0) FROM usage_records "
                    "WHERE player_profile_id=:player AND usage_day=:day"
                ),
                {"player": player, "day": usage_day or _now().date()},
            ).scalar_one()
        return float(value)

    def deploy_profile(self, profile: NpcProfile, player: str, save: str, npc: str) -> None:
        existing_definition = self.resolve_npc_definition_id(player, save, npc)
        if existing_definition is not None and existing_definition != profile.npc_definition_id:
            raise ValueError("npc_definition_scope_mismatch")
        with self.engine.begin() as connection:
            result = connection.execute(
                text(
                    "INSERT INTO npc_profile_deployments (deployment_id, player_profile_id, "
                    "world_save_id, npc_persistent_id, npc_definition_id, catalog_revision, profile_json, deployed_at) "
                    "VALUES (:id, :player, :save, :npc, :definition, :revision, CAST(:profile AS jsonb), :now) "
                    "ON CONFLICT (player_profile_id, world_save_id, npc_persistent_id) "
                    "DO UPDATE SET catalog_revision=EXCLUDED.catalog_revision, "
                    "profile_json=EXCLUDED.profile_json, deployed_at=EXCLUDED.deployed_at "
                    "WHERE npc_profile_deployments.npc_definition_id=EXCLUDED.npc_definition_id "
                    "AND (npc_profile_deployments.catalog_revision IS DISTINCT FROM EXCLUDED.catalog_revision "
                    "OR npc_profile_deployments.profile_json IS DISTINCT FROM EXCLUDED.profile_json) "
                    "RETURNING deployment_id"
                ),
                {
                    "id": uuid.uuid4(),
                    "player": player,
                    "save": save,
                    "npc": npc,
                    "definition": profile.npc_definition_id,
                    "revision": profile.catalog_revision,
                    "profile": json.dumps(profile.payload),
                    "now": _now(),
                },
            ).first()
        if result:
            _seed_graph(self, profile, player, save, npc)
        deployed_definition = self.resolve_npc_definition_id(player, save, npc)
        if deployed_definition != profile.npc_definition_id:
            raise ValueError("npc_definition_scope_mismatch")

    def resolve_npc_definition_id(self, player: str, save: str, npc: str) -> str | None:
        player, save, npc = scope_key(player, save, npc)
        params = {"player": player, "save": save, "npc": npc}
        with self.engine.connect() as connection:
            definitions = connection.execute(
                text(
                    "SELECT DISTINCT npc_definition_id FROM npc_profile_deployments "
                    "WHERE player_profile_id=:player AND world_save_id=:save "
                    "AND npc_persistent_id=:npc"
                ),
                params,
            ).scalars().all()
            if not definitions:
                definitions = connection.execute(
                    text(
                        "SELECT DISTINCT npc_definition_id FROM conversation_sessions "
                        "WHERE player_profile_id=:player AND world_save_id=:save "
                        "AND npc_persistent_id=:npc AND npc_definition_id<>''"
                    ),
                    params,
                ).scalars().all()
        unique = {str(value) for value in definitions if value}
        if len(unique) > 1:
            raise ValueError("npc_profile_deployment_conflict")
        return next(iter(unique), None)

    def add_graph_node(self, node: GraphNode) -> GraphNode:
        canonical = node.player_profile_id is None
        with self.engine.begin() as connection:
            connection.execute(
                text(
                    "INSERT INTO knowledge_nodes (id, node_id, node_type, player_profile_id, world_save_id, "
                    "owner_npc_persistent_id, label, metadata, catalog_revision, visibility, source, canonical, created_at) "
                    "VALUES (:id, :node_id, :node_type, :player, :save, :owner, :label, CAST(:metadata AS jsonb), "
                    ":revision, :visibility, :source, :canonical, :now) ON CONFLICT DO NOTHING"
                ),
                {
                    "id": uuid.uuid4(),
                    "node_id": node.node_id,
                    "node_type": node.node_type,
                    "player": node.player_profile_id,
                    "save": node.world_save_id,
                    "owner": node.owner_npc_persistent_id,
                    "label": node.label,
                    "metadata": json.dumps(node.metadata),
                    "revision": node.catalog_revision,
                    "visibility": node.visibility,
                    "source": node.source,
                    "canonical": canonical,
                    "now": _now(),
                },
            )
        return node

    def add_graph_edge(self, edge: GraphEdge) -> GraphEdge:
        if edge.predicate not in EDGE_TYPES:
            raise ValueError("invalid_edge_type")
        canonical = edge.owner_npc_persistent_id is None
        with self.engine.begin() as connection:
            connection.execute(
                text(
                    "INSERT INTO knowledge_edges (id, player_profile_id, world_save_id, owner_npc_persistent_id, "
                    "subject_node_id, predicate, object_node_id, confidence, visibility, source_type, source_id, "
                    "catalog_revision, evidence_memory_ids, valid_from, valid_until, created_at, updated_at, "
                    "supersedes_edge_id, canonical) VALUES (:id, :player, :save, :owner, :subject, :predicate, "
                    ":object, :confidence, :visibility, :source_type, :source_id, :revision, CAST(:evidence AS jsonb), "
                    ":valid_from, :valid_until, :created, :updated, :supersedes, :canonical) ON CONFLICT DO NOTHING"
                ),
                {
                    "id": uuid.UUID(edge.id),
                    "player": edge.player_profile_id,
                    "save": edge.world_save_id,
                    "owner": edge.owner_npc_persistent_id,
                    "subject": edge.subject_node_id,
                    "predicate": edge.predicate,
                    "object": edge.object_node_id,
                    "confidence": edge.confidence,
                    "visibility": edge.visibility,
                    "source_type": edge.source_type,
                    "source_id": edge.source_id,
                    "revision": edge.catalog_revision,
                    "evidence": json.dumps(edge.evidence_memory_ids),
                    "valid_from": edge.valid_from,
                    "valid_until": edge.valid_until,
                    "created": _parse_time(edge.created_at) if edge.created_at else _now(),
                    "updated": _parse_time(edge.updated_at) if edge.updated_at else _now(),
                    "supersedes": uuid.UUID(edge.supersedes_edge_id) if edge.supersedes_edge_id else None,
                    "canonical": canonical,
                },
            )
        return edge

    def graph_edges_for(self, player: str, save: str, npc: str) -> list[GraphEdge]:
        with self.engine.connect() as connection:
            rows = connection.execute(
                text(
                    "SELECT * FROM knowledge_edges WHERE canonical=true OR "
                    "(player_profile_id=:player AND world_save_id=:save AND owner_npc_persistent_id=:npc)"
                ),
                {"player": player, "save": save, "npc": npc},
            ).mappings().all()
        visible = [
            _edge_from_row(row)
            for row in rows
            if row["visibility"] != "private" or not row["canonical"]
        ]
        return _relevant_graph_edges(visible, player, save, npc)

    def graph_nodes_for_edges(self, edges: list[GraphEdge]) -> list[GraphNode]:
        ids = sorted({value for edge in edges for value in (edge.subject_node_id, edge.object_node_id)})
        if not ids:
            return []
        with self.engine.connect() as connection:
            rows = connection.execute(
                text("SELECT * FROM knowledge_nodes WHERE node_id = ANY(:ids)"), {"ids": ids}
            ).mappings().all()
        allowed_scopes = {
            (edge.player_profile_id, edge.world_save_id, edge.owner_npc_persistent_id)
            for edge in edges
        }
        return [
            _node_from_row(row)
            for row in rows
            if (row["canonical"] and row["visibility"] != "private")
            or (row["player_profile_id"], row["world_save_id"], row["owner_npc_persistent_id"])
            in allowed_scopes
        ]

    def graph_node_exists(self, node_id: str, player: str, save: str, npc: str) -> bool:
        with self.engine.connect() as connection:
            return bool(
                connection.execute(
                    text(
                        "SELECT 1 FROM knowledge_nodes WHERE node_id=:node AND "
                        "((canonical=true AND visibility<>'private') OR "
                        "(player_profile_id=:player AND world_save_id=:save "
                        "AND owner_npc_persistent_id=:npc)) LIMIT 1"
                    ),
                    {"node": node_id, "player": player, "save": save, "npc": npc},
                ).first()
            )

    def delete_npc(self, player: str, save: str, npc: str) -> int:
        with self.engine.begin() as connection:
            count = connection.execute(
                text(
                    "DELETE FROM npc_memories WHERE player_profile_id=:player "
                    "AND world_save_id=:save AND npc_persistent_id=:npc"
                ),
                {"player": player, "save": save, "npc": npc},
            ).rowcount
            connection.execute(
                text(
                    "DELETE FROM conversation_sessions WHERE player_profile_id=:player "
                    "AND world_save_id=:save AND npc_persistent_id=:npc"
                ),
                {"player": player, "save": save, "npc": npc},
            )
            connection.execute(
                text(
                    "DELETE FROM knowledge_edges WHERE player_profile_id=:player "
                    "AND world_save_id=:save AND owner_npc_persistent_id=:npc"
                ),
                {"player": player, "save": save, "npc": npc},
            )
            connection.execute(
                text(
                    "DELETE FROM knowledge_nodes WHERE player_profile_id=:player "
                    "AND world_save_id=:save AND owner_npc_persistent_id=:npc"
                ),
                {"player": player, "save": save, "npc": npc},
            )
            for table in (
                "idempotent_request_responses",
                "usage_records",
                "outbox_receipts",
                "conflict_records",
                "sync_revisions",
                "npc_profile_deployments",
            ):
                connection.execute(
                    text(
                        f"DELETE FROM {table} WHERE player_profile_id=:player "
                        "AND world_save_id=:save AND npc_persistent_id=:npc"
                    ),
                    {"player": player, "save": save, "npc": npc},
                )
        return int(count or 0)

    def delete_player(self, player: str, save: str | None = None) -> int:
        where = "player_profile_id=:player" + (" AND world_save_id=:save" if save else "")
        params = {"player": player, "save": save}
        with self.engine.begin() as connection:
            count = connection.execute(text(f"DELETE FROM npc_memories WHERE {where}"), params).rowcount
            connection.execute(text(f"DELETE FROM conversation_sessions WHERE {where}"), params)
            connection.execute(text(f"DELETE FROM knowledge_edges WHERE {where}"), params)
            connection.execute(text(f"DELETE FROM knowledge_nodes WHERE {where}"), params)
            for table in (
                "idempotent_request_responses",
                "usage_records",
                "outbox_receipts",
                "conflict_records",
                "sync_revisions",
                "npc_profile_deployments",
            ):
                connection.execute(text(f"DELETE FROM {table} WHERE {where}"), params)
        return int(count or 0)

    def export_player(self, player: str, save: str) -> dict[str, Any]:
        with self.engine.connect() as connection:
            sessions = connection.execute(
                text(
                    "SELECT session_id, npc_persistent_id FROM conversation_sessions "
                    "WHERE player_profile_id=:player "
                    "AND world_save_id=:save ORDER BY started_at"
                ),
                {"player": player, "save": save},
            ).mappings().all()
        return {
            "player_profile_id": player,
            "world_save_id": save,
            "memories": [
                memory.to_dict()
                for npc in self._npc_ids_for_player(player, save)
                for memory in self.memories_for(player, save, npc)
            ],
            "sessions": [
                session.to_dict()
                for item in sessions
                if (
                    session := self.get_session(
                        item["session_id"],
                        player,
                        save,
                        item["npc_persistent_id"],
                    )
                )
                is not None
            ],
        }

    def _npc_ids_for_player(self, player: str, save: str) -> list[str]:
        with self.engine.connect() as connection:
            return list(
                connection.execute(
                    text(
                        "SELECT DISTINCT npc_persistent_id FROM npc_memories "
                        "WHERE player_profile_id=:player AND world_save_id=:save"
                    ),
                    {"player": player, "save": save},
                ).scalars()
            )

    def outbox_receipt_exists(
        self, player: str, save: str, npc: str, kind: str, entry_id: str
    ) -> bool:
        with self.engine.connect() as connection:
            return bool(
                connection.execute(
                    text(
                        "SELECT 1 FROM outbox_receipts WHERE player_profile_id=:player "
                        "AND world_save_id=:save AND npc_persistent_id=:npc "
                        "AND outbox_kind=:kind AND entry_id=:entry LIMIT 1"
                    ),
                    {"player": player, "save": save, "npc": npc, "kind": kind, "entry": entry_id},
                ).first()
            )

    def store_outbox_receipt(
        self,
        player: str,
        save: str,
        npc: str,
        kind: str,
        entry_id: str,
        payload: dict[str, Any],
    ) -> None:
        digest = hashlib.sha256(json.dumps(payload, sort_keys=True).encode()).hexdigest()
        with self.engine.begin() as connection:
            connection.execute(
                text(
                    "INSERT INTO outbox_receipts (receipt_id, player_profile_id, world_save_id, "
                    "npc_persistent_id, outbox_kind, entry_id, payload_hash, accepted_at) "
                    "VALUES (:id, :player, :save, :npc, :kind, :entry, :hash, :now) "
                    "ON CONFLICT (player_profile_id, world_save_id, npc_persistent_id, outbox_kind, entry_id) DO NOTHING"
                ),
                {
                    "id": uuid.uuid4(), "player": player, "save": save, "npc": npc,
                    "kind": kind, "entry": entry_id, "hash": digest, "now": _now(),
                },
            )

    def sync_revision(self, player: str, save: str, npc: str) -> int:
        with self.engine.connect() as connection:
            value = connection.execute(
                text(
                    "SELECT revision FROM sync_revisions WHERE player_profile_id=:player "
                    "AND world_save_id=:save AND npc_persistent_id=:npc"
                ),
                {"player": player, "save": save, "npc": npc},
            ).scalar()
        return int(value or 0)

    def advance_sync_revision(self, player: str, save: str, npc: str) -> int:
        with self.engine.begin() as connection:
            value = connection.execute(
                text(
                    "INSERT INTO sync_revisions (player_profile_id, world_save_id, npc_persistent_id, revision, updated_at) "
                    "VALUES (:player, :save, :npc, 1, :now) ON CONFLICT "
                    "(player_profile_id, world_save_id, npc_persistent_id) DO UPDATE SET "
                    "revision=sync_revisions.revision+1, updated_at=EXCLUDED.updated_at RETURNING revision"
                ),
                {"player": player, "save": save, "npc": npc, "now": _now()},
            ).scalar_one()
        return int(value)

    def add_conflict(
        self,
        player: str,
        save: str,
        npc: str,
        client_revision: int,
        server_revision: int,
        reason: str,
    ) -> dict[str, Any]:
        conflict_id = uuid.uuid4()
        with self.engine.begin() as connection:
            connection.execute(
                text(
                    "INSERT INTO conflict_records (conflict_id, player_profile_id, world_save_id, "
                    "npc_persistent_id, client_revision, server_revision, reason, details, created_at) "
                    "VALUES (:id, :player, :save, :npc, :client, :server, :reason, '{}'::jsonb, :now)"
                ),
                {
                    "id": conflict_id, "player": player, "save": save, "npc": npc,
                    "client": client_revision, "server": server_revision, "reason": reason, "now": _now(),
                },
            )
        return {
            "conflict_id": str(conflict_id),
            "npc_persistent_id": npc,
            "client_revision": client_revision,
            "server_revision": server_revision,
            "reason": reason,
        }


def _seed_graph(
    repository: Any, profile: NpcProfile, player: str, save: str, npc: str
) -> None:
    data = profile.payload
    revision = profile.catalog_revision
    definition_node = f"npc_definition:{profile.npc_definition_id}"
    repository.add_graph_node(
        GraphNode(
            definition_node,
            "npc_definition",
            str(data.get("display_name", profile.npc_definition_id)),
            {"definition_id": profile.npc_definition_id},
            catalog_revision=revision,
            visibility="public",
            source="catalog",
        )
    )
    _seed_world_ontology(repository, profile)
    instance_node = f"npc_instance:{npc}"
    repository.add_graph_node(
        GraphNode(
            instance_node,
            "npc_instance",
            str(data.get("display_name", profile.npc_definition_id)),
            {"persistent_id": npc},
            player_profile_id=player,
            world_save_id=save,
            owner_npc_persistent_id=npc,
            catalog_revision=revision,
            visibility="private",
            source="deployment",
        )
    )
    repository.add_graph_edge(
        _scoped_edge(player, save, npc, instance_node, "IS_INSTANCE_OF", definition_node, revision)
    )
    identity = data.get("identity", {})
    canonical_relations: list[tuple[str, str, str, str]] = []
    for faction in identity.get("faction_ids", []):
        node_id = f"faction:{faction}"
        canonical_relations.append((node_id, "faction", "MEMBER_OF", str(faction)))
    home = str(identity.get("home_region_id", ""))
    if home:
        node_id = home if home.startswith("region:") else f"region:{home}"
        canonical_relations.append((node_id, "region", "LIVES_IN", home))
    profession = str(identity.get("occupation", ""))
    if profession:
        canonical_relations.append(
            (f"profession:{profession}", "profession", "RELATED_TO", profession)
        )
    for skill in data.get("cognitive_skills", []):
        skill_id = str(skill.get("id", ""))
        if skill_id:
            canonical_relations.append((f"skill:{skill_id}", "skill", "HAS_SKILL", skill_id))
    for skill_id in data.get("linked_gameplay_skill_ids", []):
        canonical_relations.append((f"skill:{skill_id}", "skill", "HAS_SKILL", str(skill_id)))
    for node_id, node_type, predicate, label in canonical_relations:
        repository.add_graph_node(
            GraphNode(
                node_id,
                node_type,
                label,
                catalog_revision=revision,
                visibility="public",
                source="catalog",
            )
        )
        repository.add_graph_edge(
            GraphEdge(
                id=str(uuid.uuid4()),
                owner_npc_persistent_id=None,
                subject_node_id=definition_node,
                predicate=predicate,
                object_node_id=node_id,
                confidence=1.0,
                visibility="public",
                source_type="catalog",
                source_id=profile.npc_definition_id,
                catalog_revision=revision,
            )
        )
    for seed in data.get("knowledge_seeds", []):
        node_id = str(seed.get("node_id", ""))
        node_type = str(seed.get("node_type", "concept"))
        if not node_id:
            continue
        repository.add_graph_node(
            GraphNode(
                node_id,
                node_type,
                str(seed.get("content", node_id)),
                {"domain_tags": seed.get("domain_tags", [])},
                catalog_revision=revision,
                visibility=str(seed.get("visibility", "public")),
                source="catalog_seed",
            )
        )
        repository.add_graph_edge(
            GraphEdge(
                id=str(uuid.uuid4()),
                owner_npc_persistent_id=None,
                subject_node_id=definition_node,
                predicate="KNOWS_ABOUT",
                object_node_id=node_id,
                confidence=float(seed.get("confidence", 1.0)),
                visibility=str(seed.get("visibility", "public")),
                source_type="catalog_seed",
                source_id=str(seed.get("source_id", profile.npc_definition_id)),
                catalog_revision=revision,
            )
        )
    for seed in data.get("belief_seeds", []):
        subject = str(seed.get("subject_node_id", ""))
        object_id = str(seed.get("object_node_id", ""))
        predicate = str(seed.get("predicate", "BELIEVES"))
        if not subject or not object_id or predicate not in EDGE_TYPES:
            continue
        if not repository.graph_node_exists(subject, player, save, npc):
            repository.add_graph_node(
                GraphNode(
                    subject,
                    "concept",
                    subject,
                    player_profile_id=player,
                    world_save_id=save,
                    owner_npc_persistent_id=npc,
                    catalog_revision=revision,
                    visibility="private",
                    source="belief_seed",
                )
            )
        if not repository.graph_node_exists(object_id, player, save, npc):
            repository.add_graph_node(
                GraphNode(
                    object_id,
                    "concept",
                    object_id,
                    player_profile_id=player,
                    world_save_id=save,
                    owner_npc_persistent_id=npc,
                    catalog_revision=revision,
                    visibility="private",
                    source="belief_seed",
                )
            )
        repository.add_graph_edge(
            GraphEdge(
                id=str(uuid.uuid4()),
                owner_npc_persistent_id=npc,
                subject_node_id=subject,
                predicate=predicate,
                object_node_id=object_id,
                confidence=float(seed.get("confidence", 0.5)),
                visibility=str(seed.get("visibility", "private")),
                source_type="catalog_belief_seed",
                source_id=str(seed.get("source_id", profile.npc_definition_id)),
                player_profile_id=player,
                world_save_id=save,
                catalog_revision=revision,
            )
        )


def _seed_world_ontology(repository: Any, profile: NpcProfile) -> None:
    """Deploy immutable public world facts exported from authored Godot resources."""

    revision = profile.catalog_revision
    ontology = profile.world_ontology
    for raw in ontology.get("nodes", []):
        node_id = str(raw.get("node_id", "")).strip()
        node_type = str(raw.get("node_type", "")).strip()
        if not node_id or node_type not in NODE_TYPES:
            raise ValueError("invalid_world_ontology_node")
        if str(raw.get("visibility", "public")) != "public":
            raise ValueError("invalid_world_ontology_visibility")
        metadata = raw.get("metadata", {})
        if not isinstance(metadata, dict):
            raise ValueError("invalid_world_ontology_metadata")
        repository.add_graph_node(
            GraphNode(
                node_id=node_id,
                node_type=node_type,
                label=str(raw.get("label", node_id)),
                metadata=dict(metadata),
                catalog_revision=revision,
                visibility="public",
                source="world_catalog",
            )
        )
    for raw in ontology.get("edges", []):
        subject = str(raw.get("subject_node_id", "")).strip()
        predicate = str(raw.get("predicate", "")).strip()
        object_id = str(raw.get("object_node_id", "")).strip()
        source_id = str(raw.get("source_id", "world_ontology")).strip()
        if not subject or not object_id or predicate not in EDGE_TYPES:
            raise ValueError("invalid_world_ontology_edge")
        edge_key = f"stillpoint:{revision}:{subject}:{predicate}:{object_id}:{source_id}"
        repository.add_graph_edge(
            GraphEdge(
                id=str(uuid.uuid5(uuid.NAMESPACE_URL, edge_key)),
                owner_npc_persistent_id=None,
                subject_node_id=subject,
                predicate=predicate,
                object_node_id=object_id,
                confidence=1.0,
                visibility="public",
                source_type="world_catalog",
                source_id=source_id,
                catalog_revision=revision,
            )
        )


def _scoped_edge(
    player: str,
    save: str,
    npc: str,
    subject: str,
    predicate: str,
    object_id: str,
    revision: str,
) -> GraphEdge:
    return GraphEdge(
        id=str(uuid.uuid4()),
        owner_npc_persistent_id=npc,
        subject_node_id=subject,
        predicate=predicate,
        object_node_id=object_id,
        confidence=1.0,
        visibility="private",
        source_type="deployment",
        source_id=revision,
        player_profile_id=player,
        world_save_id=save,
        catalog_revision=revision,
    )


def _relevant_graph_edges(
    edges: list[GraphEdge], player: str, save: str, npc: str
) -> list[GraphEdge]:
    """Return scoped beliefs plus the directed public ontology relevant to this NPC."""
    scoped = [
        edge
        for edge in edges
        if (
            edge.player_profile_id,
            edge.world_save_id,
            edge.owner_npc_persistent_id,
        )
        == (player, save, npc)
    ]
    definition_nodes = {
        node_id
        for edge in scoped
        for node_id in (edge.subject_node_id, edge.object_node_id)
        if node_id.startswith("npc_definition:")
    }
    canonical_pool = [
        edge for edge in edges if edge.owner_npc_persistent_id in (None, "")
    ]
    canonical: list[GraphEdge] = []
    frontier = set(definition_nodes)
    seen_nodes = set(frontier)
    # Directional traversal exposes a profile's building, facilities, and
    # region connections without walking backward through a shared region into
    # another NPC definition.
    for _ in range(2):
        next_frontier: set[str] = set()
        for edge in canonical_pool:
            if edge.subject_node_id not in frontier:
                continue
            if edge not in canonical:
                canonical.append(edge)
            if not edge.object_node_id.startswith("npc_definition:"):
                next_frontier.add(edge.object_node_id)
        frontier = next_frontier - seen_nodes
        seen_nodes |= next_frontier
        if not frontier:
            break
    return scoped + canonical


def _graph_memory_key(node: GraphNode) -> str:
    return "\x1f".join(
        [node.player_profile_id or "", node.world_save_id or "", node.owner_npc_persistent_id or "", node.node_id]
    )


def _edge_signature(edge: GraphEdge) -> tuple[Any, ...]:
    return (
        edge.player_profile_id,
        edge.world_save_id,
        edge.owner_npc_persistent_id,
        edge.subject_node_id,
        edge.predicate,
        edge.object_node_id,
        edge.source_id,
    )


def _memory_params(memory: MemoryRecord) -> dict[str, Any]:
    return {
        "memory_id": uuid.UUID(memory.memory_id),
        "player": memory.player_profile_id,
        "save": memory.world_save_id,
        "npc": memory.owner_npc_persistent_id,
        "session_id": memory.session_id or None,
        "memory_type": memory.memory_type,
        "content": memory.content,
        "summary": memory.summary,
        "embedding": _vector_literal(memory.embedding),
        "game": json.dumps(memory.occurred_at_game),
        "created": _parse_time(memory.created_at_real),
        "last_recalled": _parse_time(memory.last_recalled_at) if memory.last_recalled_at else None,
        "recall_count": memory.recall_count,
        "salience": memory.salience,
        "valence": memory.emotional_valence,
        "confidence": memory.confidence,
        "retention": memory.retention_strength,
        "half_life": memory.half_life_hours,
        "source_type": memory.source_type,
        "source_id": memory.source_id,
        "subjects": json.dumps(memory.subject_node_ids),
        "visibility": memory.visibility,
        "archived": memory.archived,
        "supersedes": uuid.UUID(memory.supersedes_memory_id) if memory.supersedes_memory_id else None,
    }


def _memory_from_row(row: Any) -> MemoryRecord:
    embedding = row["embedding"]
    return MemoryRecord(
        memory_id=str(row["memory_id"]),
        player_profile_id=row["player_profile_id"],
        world_save_id=row["world_save_id"],
        owner_npc_persistent_id=row["npc_persistent_id"],
        session_id=row["session_id"] or "",
        memory_type=row["memory_type"],
        content=row["content"],
        summary=row["summary"],
        embedding=list(embedding) if not isinstance(embedding, str) else _parse_vector(embedding),
        occurred_at_game=dict(row["occurred_at_game"]),
        created_at_real=_iso(row["created_at_real"]),
        last_recalled_at=_iso(row["last_recalled_at"]) if row["last_recalled_at"] else None,
        recall_count=row["recall_count"],
        salience=float(row["salience"]),
        emotional_valence=float(row["emotional_valence"]),
        confidence=float(row["confidence"]),
        retention_strength=float(row["retention_strength"]),
        half_life_hours=float(row["half_life_hours"]),
        source_type=row["source_type"],
        source_id=row["source_id"],
        subject_node_ids=list(row["subject_node_ids"]),
        visibility=row["visibility"],
        archived=row["archived"],
        supersedes_memory_id=str(row["supersedes_memory_id"]) if row["supersedes_memory_id"] else None,
    )


def _session_from_row(row: Any, turns: list[Any]) -> ConversationSession:
    return ConversationSession(
        session_id=row["session_id"],
        player_profile_id=row["player_profile_id"],
        world_save_id=row["world_save_id"],
        npc_persistent_id=row["npc_persistent_id"],
        npc_definition_id=row["npc_definition_id"],
        started_at=_iso(row["started_at"]),
        last_active_at=_iso(row["last_active_at"]),
        title=row["title"],
        rolling_summary=row["rolling_summary"],
        turns=[_turn_from_row(turn) for turn in turns],
    )


def _turn_from_row(row: Any) -> ConversationTurn:
    return ConversationTurn(
        turn_id=str(row["turn_id"]),
        role=row["role"],
        text=row["text"],
        created_at_real=_iso(row["created_at_real"]),
        occurred_at_game=dict(row["occurred_at_game"]),
        region_id=row["region_id"],
        emotion=row["emotion"],
        token_usage=dict(row["token_usage"]),
        request_id=row["request_id"],
    )


def _edge_from_row(row: Any) -> GraphEdge:
    return GraphEdge(
        id=str(row["id"]),
        owner_npc_persistent_id=row["owner_npc_persistent_id"],
        subject_node_id=row["subject_node_id"],
        predicate=row["predicate"],
        object_node_id=row["object_node_id"],
        confidence=float(row["confidence"]),
        visibility=row["visibility"],
        source_type=row["source_type"],
        source_id=row["source_id"],
        evidence_memory_ids=list(row["evidence_memory_ids"]),
        valid_from=_iso(row["valid_from"]) if row["valid_from"] else None,
        valid_until=_iso(row["valid_until"]) if row["valid_until"] else None,
        created_at=_iso(row["created_at"]),
        updated_at=_iso(row["updated_at"]),
        supersedes_edge_id=str(row["supersedes_edge_id"]) if row["supersedes_edge_id"] else None,
        player_profile_id=row["player_profile_id"],
        world_save_id=row["world_save_id"],
        catalog_revision=row["catalog_revision"],
    )


def _node_from_row(row: Any) -> GraphNode:
    return GraphNode(
        node_id=row["node_id"],
        node_type=row["node_type"],
        label=row["label"],
        metadata=dict(row["metadata"]),
        player_profile_id=row["player_profile_id"],
        world_save_id=row["world_save_id"],
        owner_npc_persistent_id=row["owner_npc_persistent_id"],
        catalog_revision=row["catalog_revision"],
        visibility=row["visibility"],
        source=row["source"],
    )


def _normalize_database_url(value: str) -> str:
    return value.replace("postgresql+asyncpg://", "postgresql+psycopg://")


def _vector_literal(values: list[float]) -> str:
    return "[" + ",".join(f"{value:.10g}" for value in values) + "]"


def _parse_vector(value: str) -> list[float]:
    return [float(item) for item in value.strip("[]").split(",") if item]


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _iso(value: datetime) -> str:
    return value.isoformat()


def _parse_time(value: str) -> datetime:
    result = datetime.fromisoformat(value.replace("Z", "+00:00"))
    return result if result.tzinfo else result.replace(tzinfo=timezone.utc)


def _summarize_turns(turns: list[ConversationTurn], previous: str) -> str:
    snippets = [f"{turn.role}: {turn.text[:180]}" for turn in turns]
    combined = "; ".join(snippets)
    return ((previous + "; " + combined).strip("; "))[-2000:]
