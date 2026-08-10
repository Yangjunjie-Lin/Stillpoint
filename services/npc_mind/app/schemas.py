from __future__ import annotations

from typing import Annotated, Any, Literal

from pydantic import BaseModel, ConfigDict, Field


OntologyId = Annotated[
    str,
    Field(min_length=1, max_length=64, pattern=r"^[a-z0-9][a-z0-9_.:-]*$"),
]
OntologyLabel = Annotated[
    str,
    Field(min_length=1, max_length=80, pattern=r"^[^\r\n\x00-\x1f\x7f]+$"),
]


class PlayerPublicIdentity(BaseModel):
    """Public character-build identity supplied by the game client.

    This is observable player data, never an authority source for the server-owned NPC
    profile. Descriptions and private biography are intentionally excluded.
    """

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    display_name: str = Field(
        default="",
        max_length=80,
        pattern=r"^[^\r\n\x00-\x1f\x7f]*$",
    )
    origin_id: OntologyId
    origin_label: OntologyLabel
    faction_id: OntologyId
    faction_label: OntologyLabel
    profession_id: OntologyId
    profession_label: OntologyLabel


class PlayerVisibleAppearance(BaseModel):
    """Finite appearance choices that an NPC can plausibly observe."""

    model_config = ConfigDict(extra="forbid")

    body_id: Literal["balanced", "slender", "sturdy"]
    skin_id: Literal["origin", "light", "warm", "olive", "brown", "deep"]
    hair_id: Literal["origin", "short", "topknot", "shaved"]
    headwear_id: Literal["origin", "none", "travel_hood", "brimmed_hat"]
    palette_id: Literal["origin", "jade", "ocean", "ember", "earth"]
    accessory_id: Literal["none", "satchel", "travel_pack", "bedroll"]


class PlayerObservableCapability(BaseModel):
    """A qualitative tendency; exact rolled stats are deliberately not accepted."""

    model_config = ConfigDict(extra="forbid")

    trait_id: Literal[
        "resilient",
        "energetic",
        "forceful",
        "guarded",
        "agile",
        "focused",
    ]
    evidence: Literal["faction", "profession", "observable_build"]
    visibility: Literal["public"] = "public"


class PlayerOntologySnapshot(BaseModel):
    """Versioned, bounded public context an NPC may currently know or observe."""

    model_config = ConfigDict(extra="forbid")

    schema_version: Literal[1] = 1
    public_identity: PlayerPublicIdentity
    visible_appearance: PlayerVisibleAppearance
    observable_capabilities: list[PlayerObservableCapability] = Field(
        default_factory=list,
        max_length=6,
    )


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
    evidence_memory_ids: list[str] = Field(default_factory=list)


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
    player_ontology: PlayerOntologySnapshot | None = None
    npc_profile: dict[str, Any] = Field(default_factory=dict)
    recent_turns: list[dict[str, Any]] = Field(default_factory=list)
    retrieved_memories: list[dict[str, Any]] = Field(default_factory=list)
    retrieved_graph: list[dict[str, Any]] = Field(default_factory=list)
    allow_conversation_storage: bool = True
    allow_memory_personalization: bool = True


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
    memory_writes: list[dict[str, Any]] = Field(default_factory=list)
    proposed_intents: list[ProposedIntent] = Field(default_factory=list)
    usage: dict[str, int] = Field(default_factory=lambda: {"input_tokens": 0, "output_tokens": 0})
    degraded: bool = False
    degradation_reason: str = ""


class MemoryQuery(BaseModel):
    player_profile_id: str
    world_save_id: str
    npc_definition_id: str | None = Field(default=None, min_length=1, max_length=200)
    query: str = Field(min_length=1, max_length=4000)
    limit: int = Field(default=10, ge=1, le=50)
    entity_ids: list[str] = Field(default_factory=list)


class SessionTokenRequest(BaseModel):
    player_profile_id: str = Field(min_length=1, max_length=200)
    world_save_id: str = Field(min_length=1, max_length=200)
    client_install_id: str = Field(min_length=8, max_length=200)


class SyncRequest(BaseModel):
    player_profile_id: str
    world_save_id: str
    pending_turn_outbox: list[dict[str, Any]] = Field(default_factory=list)
    pending_event_outbox: list[dict[str, Any]] = Field(default_factory=list)
    last_sync_revision: int = Field(default=0, ge=0)


class SyncResponse(BaseModel):
    accepted_turn_ids: list[str] = Field(default_factory=list)
    accepted_event_ids: list[str] = Field(default_factory=list)
    rejected: list[dict[str, Any]] = Field(default_factory=list)
    revision: int = 0
    conflicts: list[dict[str, Any]] = Field(default_factory=list)
