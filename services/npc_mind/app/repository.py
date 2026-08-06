from __future__ import annotations

import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any

from .graph import KnowledgeGraph
from .memory import MemoryRecord, consolidate


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


class InMemoryRepository:
    """Reference repository used in development/tests; PostgreSQL is the production target."""

    def __init__(self) -> None:
        self.sessions: dict[str, ConversationSession] = {}
        self.memories: dict[str, MemoryRecord] = {}
        self.graph = KnowledgeGraph()
        self.idempotent_responses: dict[str, dict[str, Any]] = {}
        self.usage: dict[str, int] = {}

    def create_session(self, values: dict[str, Any]) -> ConversationSession:
        requested = values.get("session_id") or str(uuid.uuid4())
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
            return existing
        now = datetime.now(timezone.utc).isoformat()
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

    def add_turn(
        self,
        session: ConversationSession,
        role: str,
        text: str,
        request_id: str,
        *,
        emotion: str = "neutral",
        usage: dict[str, int] | None = None,
        occurred_at_game: dict[str, Any] | None = None,
        region_id: str = "",
    ) -> ConversationTurn:
        turn = ConversationTurn(
            turn_id=str(uuid.uuid4()),
            role=role,
            text=text,
            created_at_real=datetime.now(timezone.utc).isoformat(),
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
                if memory.salience > existing.salience:
                    existing.salience = memory.salience
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

    def consolidate_scope(self, player: str, save: str, npc: str) -> list[MemoryRecord]:
        records = self.memories_for(player, save, npc)
        records = consolidate(records)
        keep = {record.memory_id for record in records}
        for memory_id in list(self.memories):
            memory = self.memories[memory_id]
            if (memory.player_profile_id, memory.world_save_id, memory.owner_npc_persistent_id) == (
                player,
                save,
                npc,
            ) and memory_id not in keep:
                memory.archived = True
        return records

    def delete_npc(self, player: str, save: str, npc: str) -> int:
        removed = [
            memory_id
            for memory_id, memory in self.memories.items()
            if (memory.player_profile_id, memory.world_save_id, memory.owner_npc_persistent_id)
            == (player, save, npc)
        ]
        for memory_id in removed:
            del self.memories[memory_id]
        for session_id, session in list(self.sessions.items()):
            if (session.player_profile_id, session.world_save_id, session.npc_persistent_id) == (
                player,
                save,
                npc,
            ):
                del self.sessions[session_id]
        return len(removed)

    def delete_player(self, player: str) -> int:
        removed = [
            memory_id
            for memory_id, memory in self.memories.items()
            if memory.player_profile_id == player
        ]
        for memory_id in removed:
            del self.memories[memory_id]
        for session_id, session in list(self.sessions.items()):
            if session.player_profile_id == player:
                del self.sessions[session_id]
        return len(removed)


def _summarize_turns(turns: list[ConversationTurn], previous: str) -> str:
    snippets = [f"{turn.role}: {turn.text[:180]}" for turn in turns]
    combined = "; ".join(snippets)
    return ((previous + "; " + combined).strip("; "))[-2000:]
