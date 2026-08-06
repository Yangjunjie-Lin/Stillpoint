from __future__ import annotations

from typing import Any

from pydantic import BaseModel, ConfigDict, Field


class WorldContext(BaseModel):
    model_config = ConfigDict(extra="allow")

    region_id: str = ""
    game_time: dict[str, Any] = Field(default_factory=dict)
    relationship: dict[str, Any] = Field(default_factory=dict)
    quest_states: list[dict[str, Any]] = Field(default_factory=list)
    visible_entity_ids: list[str] = Field(default_factory=list)


class MemoryCandidate(BaseModel):
    model_config = ConfigDict(extra="ignore")

    memory_type: str = "episodic"
    content: str
    summary: str = ""
    salience: float = Field(default=0.5, ge=0.0, le=1.0)
    emotional_valence: float = Field(default=0.0, ge=-1.0, le=1.0)
    confidence: float = Field(default=0.7, ge=0.0, le=1.0)
    half_life_hours: float | None = Field(default=None, gt=0.0)
    subject_node_ids: list[str] = Field(default_factory=list)
    visibility: str = "private"
    source_type: str = "conversation_turn"
    source_id: str = ""


class GraphUpdateCandidate(BaseModel):
    model_config = ConfigDict(extra="ignore")

    subject_node_id: str
    predicate: str
    object_node_id: str
    confidence: float = Field(default=0.5, ge=0.0, le=1.0)
    visibility: str = "private"
    source_type: str = "conversation_turn"
    source_id: str = ""


class ProposedIntent(BaseModel):
    model_config = ConfigDict(extra="ignore")

    intent_id: str
    parameters: dict[str, Any] = Field(default_factory=dict)


class NpcGenerationRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    request_id: str
    player_profile_id: str
    world_save_id: str
    npc_definition_id: str
    npc_persistent_id: str
    session_id: str
    text: str = Field(min_length=1, max_length=4000)
    locale: str = "en"
    world_context: WorldContext = Field(default_factory=WorldContext)
    npc_profile: dict[str, Any] = Field(default_factory=dict)
    recent_turns: list[dict[str, Any]] = Field(default_factory=list)
    retrieved_memories: list[dict[str, Any]] = Field(default_factory=list)
    retrieved_graph: list[dict[str, Any]] = Field(default_factory=list)


class NpcGenerationResult(BaseModel):
    model_config = ConfigDict(extra="ignore")

    reply_text: str = Field(min_length=1, max_length=12000)
    emotion: str = "neutral"
    animation_id: str = "talk"
    memory_candidates: list[MemoryCandidate] = Field(default_factory=list)
    graph_update_candidates: list[GraphUpdateCandidate] = Field(default_factory=list)
    proposed_intents: list[ProposedIntent] = Field(default_factory=list)
    uncertainty: float = Field(default=0.0, ge=0.0, le=1.0)


class ConversationRequest(NpcGenerationRequest):
    pass


class ConversationResponse(BaseModel):
    request_id: str
    session_id: str
    reply_text: str
    emotion: str = "neutral"
    animation_id: str = "talk"
    memory_citations: list[str] = Field(default_factory=list)
    memory_write_ids: list[str] = Field(default_factory=list)
    proposed_intents: list[ProposedIntent] = Field(default_factory=list)
    usage: dict[str, int] = Field(default_factory=lambda: {"input_tokens": 0, "output_tokens": 0})


class MemoryQuery(BaseModel):
    player_profile_id: str
    world_save_id: str
    query: str = Field(min_length=1, max_length=4000)
    limit: int = Field(default=10, ge=1, le=50)
    entity_ids: list[str] = Field(default_factory=list)
