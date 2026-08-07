from __future__ import annotations

import asyncio
import re
import time
import uuid
from typing import Any

from .catalog import NpcCatalogRepository
from .config import Settings
from .graph import EDGE_TYPES, GraphEdge, GraphNode
from .memory import MemoryRecord, lexical_similarity
from .output_validation import validate_structured_output
from .providers import (
    EmbeddingProvider,
    FakeEmbeddingProvider,
    FakeLlmProvider,
    LlmProvider,
    OpenAIEmbeddingProvider,
    OpenAILlmProvider,
)
from .repository import (
    CognitionRepository,
    ConversationSession,
    InMemoryRepository,
    PostgresCognitionRepository,
    scope_key,
)
from .schemas import (
    ConversationResponse,
    NpcGenerationRequest,
    NpcGenerationResult,
    SyncRequest,
    SyncResponse,
)


SAFE_FALLBACK = "Hello. I'm here, but I need a moment before I can answer."
ALLOWED_GRAPH_VISIBILITY = {"public", "witnessed", "told", "skill", "private"}


class RateLimiter:
    def __init__(self) -> None:
        self._events: dict[str, list[float]] = {}

    def allow(self, key: str, limit: int, now: float) -> bool:
        events = [stamp for stamp in self._events.get(key, []) if now - stamp < 60.0]
        if len(events) >= limit:
            self._events[key] = events
            return False
        events.append(now)
        self._events[key] = events
        return True


class NpcCognitionService:
    def __init__(
        self,
        settings: Settings | None = None,
        repository: CognitionRepository | None = None,
        llm: LlmProvider | None = None,
        embeddings: EmbeddingProvider | None = None,
        catalog: NpcCatalogRepository | None = None,
    ) -> None:
        self.settings = settings or Settings.from_env()
        self.settings.validate_embedding_configuration()
        self.settings.validate_provider_configuration()
        if repository is not None:
            self.repository = repository
        elif self.settings.repository_is_in_memory():
            self.repository = InMemoryRepository()
        else:
            self.repository = PostgresCognitionRepository(self.settings.database_url)
        self.llm = llm or (
            OpenAILlmProvider(self.settings)
            if self.settings.llm_provider == "openai"
            else FakeLlmProvider()
        )
        self.embeddings = embeddings or (
            OpenAIEmbeddingProvider(self.settings)
            if self.settings.use_remote_embeddings()
            else FakeEmbeddingProvider()
        )
        self.catalog = catalog or NpcCatalogRepository()
        self.rate_limiter = RateLimiter()
        self.metrics: dict[str, int] = {}

    async def handle_turn(self, request: NpcGenerationRequest) -> ConversationResponse:
        scope_key(request.player_profile_id, request.world_save_id, request.npc_persistent_id)
        if len(request.text) > self.settings.max_input_length:
            raise ValueError("input_too_long")
        profile = self.catalog.get_profile(request.npc_definition_id)
        self.repository.deploy_profile(
            profile,
            request.player_profile_id,
            request.world_save_id,
            request.npc_persistent_id,
        )
        existing = self.repository.get_idempotent_response(
            request.player_profile_id,
            request.world_save_id,
            request.npc_persistent_id,
            request.request_id,
        )
        if existing is not None:
            return ConversationResponse.model_validate(existing)
        now = time.time()
        if not self.rate_limiter.allow(
            f"player:{request.player_profile_id}", self.settings.player_rate_per_minute, now
        ):
            raise ValueError("player_rate_limited")
        if not self.rate_limiter.allow(
            f"npc:{request.player_profile_id}:{request.world_save_id}:{request.npc_persistent_id}",
            self.settings.npc_rate_per_minute,
            now,
        ):
            raise ValueError("npc_rate_limited")
        session = self.repository.create_session(request.model_dump())
        graph = self.retrieve_graph(request)
        trusted_request = request.model_copy(
            update={
                # Client-supplied npc_profile is always discarded.
                "npc_profile": profile.payload,
                "retrieved_memories": [],
                "retrieved_graph": graph,
                "recent_turns": [turn.to_dict() for turn in session.turns[-6:]],
            }
        )
        if self.budget_exhausted(request.player_profile_id):
            return self._fallback_response(
                trusted_request, session, "daily_budget_exceeded", store=True
            )
        degradation_reasons: list[str] = []
        try:
            memories = await self.retrieve_memories_async(trusted_request)
        except (RuntimeError, TimeoutError):
            self.metrics["memory_retrieval_error"] = self.metrics.get(
                "memory_retrieval_error", 0
            ) + 1
            memories = []
            degradation_reasons.append("memory_retrieval_unavailable")
        trusted_request = trusted_request.model_copy(
            update={"retrieved_memories": [memory.to_dict() for memory in memories]}
        )
        try:
            generated = validate_generation(await self.llm.generate_npc_reply(trusted_request))
        except Exception:
            self.metrics["provider_or_output_error"] = self.metrics.get(
                "provider_or_output_error", 0
            ) + 1
            return self._fallback_response(trusted_request, session, "provider_unavailable", store=True)
        usage = {
            "input_tokens": _token_count(trusted_request.text)
            + sum(_token_count(str(item)) for item in trusted_request.retrieved_memories),
            "output_tokens": _token_count(generated.reply_text),
        }
        if request.allow_conversation_storage:
            self._store_turn_pair(session, trusted_request, generated, usage)
        memory_ids: list[str] = []
        memory_writes: list[dict[str, Any]] = []
        evidence_aliases: dict[str, str] = {}
        if request.allow_memory_personalization and generated.memory_candidates:
            try:
                vectors = await self.embeddings.embed(
                    [candidate.content for candidate in generated.memory_candidates]
                )
            except (RuntimeError, TimeoutError):
                self.metrics["memory_embedding_error"] = self.metrics.get(
                    "memory_embedding_error", 0
                ) + 1
                vectors = []
                degradation_reasons.append("memory_embedding_unavailable")
            for candidate, vector in zip(generated.memory_candidates, vectors):
                memory = MemoryRecord(
                    memory_id=str(uuid.uuid4()),
                    player_profile_id=request.player_profile_id,
                    world_save_id=request.world_save_id,
                    owner_npc_persistent_id=request.npc_persistent_id,
                    session_id=session.session_id,
                    memory_type=candidate.memory_type,
                    content=candidate.content,
                    summary=candidate.summary or candidate.content[:240],
                    embedding=vector,
                    occurred_at_game=request.world_context.game_time,
                    salience=candidate.salience,
                    emotional_valence=candidate.emotional_valence,
                    confidence=candidate.confidence,
                    half_life_hours=candidate.half_life_hours or 168.0,
                    source_type=candidate.source_type,
                    source_id=candidate.source_id or request.request_id,
                    subject_node_ids=candidate.subject_node_ids,
                    visibility=candidate.visibility,
                )
                saved = self.repository.add_memory(memory)
                memory_ids.append(saved.memory_id)
                memory_writes.append(saved.to_dict())
                evidence_aliases[candidate.source_id or request.request_id] = saved.memory_id
        self._apply_graph_candidates(
            trusted_request, generated, set(memory_ids), evidence_aliases
        )
        response = ConversationResponse(
            request_id=request.request_id,
            session_id=session.session_id,
            reply_text=generated.reply_text,
            emotion=generated.emotion,
            animation_id=generated.animation_id,
            memory_citations=[memory.memory_id for memory in memories],
            memory_write_ids=memory_ids,
            memory_writes=memory_writes,
            proposed_intents=generated.proposed_intents,
            usage=usage,
            degraded=bool(degradation_reasons),
            degradation_reason=",".join(degradation_reasons),
        )
        self._store_response_and_usage(trusted_request, response)
        return response

    async def retrieve_memories_async(
        self, request: NpcGenerationRequest, limit: int | None = None
    ) -> list[MemoryRecord]:
        query_vector = (await self.embeddings.embed([request.text]))[0]
        candidates = self.repository.search_memories(
            request.player_profile_id,
            request.world_save_id,
            request.npc_persistent_id,
            query_vector,
            max((limit or 10) * 5, 20),
        )
        weights = self._retrieval_weights()
        goals = " ".join(
            str(goal.get("description", "")) for goal in request.npc_profile.get("goals", [])
        )
        relationship = request.world_context.relationship
        scored: list[tuple[float, float, MemoryRecord]] = []
        for memory, vector_score in candidates:
            memory_text = f"{memory.content} {memory.summary}"
            goal_relevance = lexical_similarity(memory_text, goals)
            graph_relevance = 1.0 if _explicit_entity_query(request, memory) else 0.0
            relationship_relevance = (
                lexical_similarity(memory_text, str(relationship)) if relationship else 0.0
            )
            score = memory.score(
                request.text,
                query_embedding=query_vector,
                vector_score=vector_score,
                goal_relevance=goal_relevance,
                graph_relevance=graph_relevance,
                relationship_relevance=relationship_relevance,
                weights=weights,
            )
            scored.append((score, vector_score, memory))
        result: list[MemoryRecord] = []
        for score, vector_score, memory in sorted(scored, reverse=True, key=lambda item: item[0])[
            : limit or 10
        ]:
            if score <= 0 and not _explicit_entity_query(request, memory):
                continue
            self.repository.record_recall(memory, request.text, vector_score, score)
            result.append(memory)
        return result

    def retrieve_memories(self, request: NpcGenerationRequest) -> list[MemoryRecord]:
        """Compatibility wrapper for synchronous unit callers."""
        return asyncio.run(self.retrieve_memories_async(request))

    def retrieve_graph(self, request: NpcGenerationRequest) -> list[dict[str, Any]]:
        edges = self.repository.graph_edges_for(
            request.player_profile_id, request.world_save_id, request.npc_persistent_id
        )
        visible = set(request.world_context.visible_entity_ids)
        visible.add(f"npc_instance:{request.npc_persistent_id}")
        if visible:
            traversed: list[GraphEdge] = []
            frontier = visible.copy()
            seen = frontier.copy()
            for _ in range(2):
                next_frontier: set[str] = set()
                for edge in edges:
                    if edge.subject_node_id in frontier or edge.object_node_id in frontier:
                        if edge not in traversed:
                            traversed.append(edge)
                        next_frontier.update((edge.subject_node_id, edge.object_node_id))
                frontier = next_frontier - seen
                seen |= next_frontier
                if not frontier:
                    break
            if traversed:
                edges = traversed
        return [edge.to_dict() for edge in edges[:100]]

    def graph_payload(self, player: str, save: str, npc: str) -> dict[str, Any]:
        edges = self.repository.graph_edges_for(player, save, npc)
        nodes = self.repository.graph_nodes_for_edges(edges)
        return {
            "nodes": [
                {
                    "node_id": node.node_id,
                    "node_type": node.node_type,
                    "label": node.label,
                    "metadata": node.metadata,
                    "visibility": node.visibility,
                    "source": node.source,
                    "catalog_revision": node.catalog_revision,
                }
                for node in nodes
            ],
            "edges": [edge.to_dict() for edge in edges],
        }

    async def sync(self, request: SyncRequest) -> SyncResponse:
        accepted_turns: list[str] = []
        accepted_events: list[str] = []
        rejected: list[dict[str, Any]] = []
        conflicts: list[dict[str, Any]] = []
        touched: set[str] = set()
        mutated: set[str] = set()
        for raw in request.pending_turn_outbox:
            entry_id = str(raw.get("request_id", ""))
            try:
                npc = self._validate_sync_item_scope(request, raw)
                if not entry_id:
                    raise ValueError("missing_request_id")
                touched.add(npc)
                if not self.repository.outbox_receipt_exists(
                    request.player_profile_id, request.world_save_id, npc, "turn", entry_id
                ):
                    turn_request = NpcGenerationRequest.model_validate(raw)
                    await self.handle_turn(turn_request)
                    self.repository.store_outbox_receipt(
                        request.player_profile_id,
                        request.world_save_id,
                        npc,
                        "turn",
                        entry_id,
                        raw,
                    )
                    mutated.add(npc)
                accepted_turns.append(entry_id)
            except Exception as error:
                rejected.append({"kind": "turn", "entry_id": entry_id, "reason": str(error)})
        for raw in request.pending_event_outbox:
            entry_id = str(raw.get("event_id") or raw.get("source_id") or raw.get("payload", {}).get("event_id", ""))
            try:
                npc = self._validate_sync_item_scope(request, raw)
                if not entry_id:
                    raise ValueError("missing_event_id")
                touched.add(npc)
                if not self.repository.outbox_receipt_exists(
                    request.player_profile_id, request.world_save_id, npc, "event", entry_id
                ):
                    await self._store_event_memory(request, raw, npc, entry_id)
                    self.repository.store_outbox_receipt(
                        request.player_profile_id,
                        request.world_save_id,
                        npc,
                        "event",
                        entry_id,
                        raw,
                    )
                    mutated.add(npc)
                accepted_events.append(entry_id)
            except Exception as error:
                rejected.append({"kind": "event", "entry_id": entry_id, "reason": str(error)})
        revision = request.last_sync_revision
        for npc in touched:
            server_revision = self.repository.sync_revision(
                request.player_profile_id, request.world_save_id, npc
            )
            if request.last_sync_revision != server_revision:
                conflicts.append(
                    self.repository.add_conflict(
                        request.player_profile_id,
                        request.world_save_id,
                        npc,
                        request.last_sync_revision,
                        server_revision,
                        "revision_mismatch",
                    )
                )
            if npc in mutated:
                server_revision = self.repository.advance_sync_revision(
                    request.player_profile_id, request.world_save_id, npc
                )
            revision = max(revision, server_revision)
        return SyncResponse(
            accepted_turn_ids=accepted_turns,
            accepted_event_ids=accepted_events,
            rejected=rejected,
            revision=revision,
            conflicts=conflicts,
        )

    def _validate_sync_item_scope(self, request: SyncRequest, item: dict[str, Any]) -> str:
        npc = str(item.get("npc_persistent_id") or item.get("owner_npc_persistent_id", ""))
        if (
            str(item.get("player_profile_id", "")) != request.player_profile_id
            or str(item.get("world_save_id", "")) != request.world_save_id
            or not npc
        ):
            raise ValueError("sync_scope_mismatch")
        scope_key(request.player_profile_id, request.world_save_id, npc)
        return npc

    async def _store_event_memory(
        self, request: SyncRequest, raw: dict[str, Any], npc: str, entry_id: str
    ) -> None:
        event_type = str(raw.get("event_type", "gameplay_event"))
        content = str(raw.get("content") or f"Witnessed {event_type}: {raw.get('payload', {})}")
        vector = (await self.embeddings.embed([content]))[0]
        memory = self.repository.add_memory(
            MemoryRecord(
                memory_id=str(uuid.uuid4()),
                player_profile_id=request.player_profile_id,
                world_save_id=request.world_save_id,
                owner_npc_persistent_id=npc,
                session_id="",
                memory_type="episodic",
                content=content,
                summary=str(raw.get("summary", content[:240])),
                embedding=vector,
                occurred_at_game=dict(raw.get("world_time", raw.get("occurred_at_game", {}))),
                salience=float(raw.get("salience", 0.75)),
                confidence=float(raw.get("confidence", 1.0)),
                source_type="gameplay_event",
                source_id=entry_id,
                subject_node_ids=[
                    str(value)
                    for value in (raw.get("source_entity_id", ""), raw.get("target_entity_id", ""))
                    if value
                ],
                visibility=str(raw.get("visibility", "witnessed")),
            )
        )
        event_node = f"event:{entry_id}"
        add_node = getattr(self.repository, "add_graph_node")
        add_node(
            GraphNode(
                event_node,
                "event",
                event_type,
                {"event_type": event_type},
                player_profile_id=request.player_profile_id,
                world_save_id=request.world_save_id,
                owner_npc_persistent_id=npc,
                visibility="witnessed",
                source="gameplay_event",
            )
        )
        self.repository.add_graph_edge(
            GraphEdge(
                id=str(uuid.uuid4()),
                owner_npc_persistent_id=npc,
                subject_node_id=f"npc_instance:{npc}",
                predicate="WITNESSED",
                object_node_id=event_node,
                confidence=1.0,
                visibility="witnessed",
                source_type="gameplay_event",
                source_id=entry_id,
                evidence_memory_ids=[memory.memory_id],
                player_profile_id=request.player_profile_id,
                world_save_id=request.world_save_id,
            )
        )

    def _apply_graph_candidates(
        self,
        request: NpcGenerationRequest,
        generated: NpcGenerationResult,
        memory_ids: set[str],
        evidence_aliases: dict[str, str],
    ) -> None:
        for candidate in generated.graph_update_candidates:
            if candidate.predicate not in EDGE_TYPES:
                self.metrics["graph_candidate_rejected"] = self.metrics.get(
                    "graph_candidate_rejected", 0
                ) + 1
                continue
            if candidate.visibility not in ALLOWED_GRAPH_VISIBILITY:
                continue
            if not self.repository.graph_node_exists(
                candidate.subject_node_id,
                request.player_profile_id,
                request.world_save_id,
                request.npc_persistent_id,
            ) or not self.repository.graph_node_exists(
                candidate.object_node_id,
                request.player_profile_id,
                request.world_save_id,
                request.npc_persistent_id,
            ):
                continue
            evidence = {
                evidence_aliases.get(item, item) for item in candidate.evidence_memory_ids
            }
            if not evidence or not evidence.issubset(memory_ids):
                continue
            self.repository.add_graph_edge(
                GraphEdge(
                    id=str(uuid.uuid4()),
                    owner_npc_persistent_id=request.npc_persistent_id,
                    subject_node_id=candidate.subject_node_id,
                    predicate=candidate.predicate,
                    object_node_id=candidate.object_node_id,
                    confidence=candidate.confidence,
                    visibility=candidate.visibility,
                    source_type="validated_llm_candidate",
                    source_id=candidate.source_id or request.request_id,
                    evidence_memory_ids=list(evidence),
                    player_profile_id=request.player_profile_id,
                    world_save_id=request.world_save_id,
                )
            )

    def _store_turn_pair(
        self,
        session: ConversationSession,
        request: NpcGenerationRequest,
        generated: NpcGenerationResult,
        usage: dict[str, int],
    ) -> None:
        self.repository.add_turn(
            session,
            "player",
            request.text,
            request.request_id,
            occurred_at_game=request.world_context.game_time,
            region_id=request.world_context.region_id,
            usage=usage,
        )
        self.repository.add_turn(
            session,
            "npc",
            generated.reply_text,
            request.request_id,
            emotion=generated.emotion,
            occurred_at_game=request.world_context.game_time,
            region_id=request.world_context.region_id,
            usage=usage,
        )

    def _fallback_response(
        self,
        request: NpcGenerationRequest,
        session: ConversationSession,
        reason: str,
        *,
        store: bool,
    ) -> ConversationResponse:
        reply_text = _safe_fallback_text(request.text)
        usage = {
            "input_tokens": _token_count(request.text),
            "output_tokens": _token_count(reply_text),
        }
        if request.allow_conversation_storage:
            self.repository.add_turn(
                session,
                "player",
                request.text,
                request.request_id,
                occurred_at_game=request.world_context.game_time,
                region_id=request.world_context.region_id,
                usage=usage,
            )
        response = ConversationResponse(
            request_id=request.request_id,
            session_id=session.session_id,
            reply_text=reply_text,
            usage=usage,
            degraded=True,
            degradation_reason=reason,
        )
        if store:
            self._store_response_and_usage(request, response, cost=0.0)
        return response

    def _store_response_and_usage(
        self, request: NpcGenerationRequest, response: ConversationResponse, cost: float | None = None
    ) -> None:
        self.repository.store_idempotent_response(
            request.player_profile_id,
            request.world_save_id,
            request.npc_persistent_id,
            request.request_id,
            response.model_dump(),
        )
        estimated = (
            cost
            if cost is not None
            else (sum(response.usage.values()) / 1000.0)
            * self.settings.estimated_cost_per_1k_tokens_usd
        )
        self.repository.record_usage(
            request.player_profile_id,
            request.world_save_id,
            request.npc_persistent_id,
            request.request_id,
            response.usage,
            estimated,
        )

    def budget_exhausted(self, player: str) -> bool:
        if isinstance(self.llm, FakeLlmProvider):
            return False
        return self.repository.daily_cost(player) >= self.settings.daily_budget_usd

    def _retrieval_weights(self) -> dict[str, float]:
        return {
            "vector": self.settings.retrieval_vector_weight,
            "lexical": self.settings.retrieval_lexical_weight,
            "salience": self.settings.retrieval_salience_weight,
            "confidence": self.settings.retrieval_confidence_weight,
            "goal": self.settings.retrieval_goal_weight,
            "graph": self.settings.retrieval_graph_weight,
            "relationship": self.settings.retrieval_relationship_weight,
            "recency": self.settings.retrieval_recency_weight,
            "reinforcement": self.settings.retrieval_reinforcement_weight,
        }


def validate_generation(value: Any) -> NpcGenerationResult:
    return validate_structured_output(value)


def _token_count(value: str) -> int:
    return max(1, len(re.findall(r"\S+", value)))


def _safe_fallback_text(player_text: str) -> str:
    if re.search(r"[\u4e00-\u9fff]", player_text):
        return "我在这里，只是现在需要一点时间才能回答。"
    return SAFE_FALLBACK


def _explicit_entity_query(request: NpcGenerationRequest, memory: MemoryRecord) -> bool:
    entities = set(re.findall(r"[\w:-]+", request.text.lower()))
    entities.update(item.lower() for item in request.world_context.visible_entity_ids)
    return bool(entities & {item.lower() for item in memory.subject_node_ids})
