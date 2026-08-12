from __future__ import annotations

import asyncio
import logging
import re
import time
import uuid
from typing import Any

from .catalog import NpcCatalogRepository
from .config import Settings
from .graph import CANONICAL_WORLD_EDGE_TYPES, EDGE_TYPES, NODE_TYPES, GraphEdge, GraphNode
from .graph_actions import annotate_graph_edge, build_graph_visualization, select_context_motion
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
    GraphUpdateCandidate,
    NpcGenerationRequest,
    NpcGenerationResult,
    SyncRequest,
    SyncResponse,
)


SAFE_FALLBACK = "Hello. I'm here, but I need a moment before I can answer."
ALLOWED_GRAPH_VISIBILITY = {"public", "witnessed", "told", "skill", "private"}
logger = logging.getLogger(__name__)
_SAFE_PROVIDER_ERROR_CODES = frozenset(
    {
        "provider_not_configured",
        "provider_timeout",
        "provider_unavailable",
        "provider_response_too_large",
        "invalid_provider_json",
        "invalid_provider_reply",
        "invalid_model_json",
        "provider_prompt_leak",
        "provider_repetitive_reply",
        "provider_reply_language_mismatch",
        "provider_speaker_label",
        "provider_narrated_reply",
        "provider_incomplete_reply",
        "provider_garbled_reply",
        "provider_internal_retrieval_status",
        "provider_unhelpful_reply",
    }
)


def _safe_provider_error_code(error: Exception) -> str:
    """Expose only controlled provider codes; never log prompts or provider payloads."""

    value = str(error).strip()
    if value in _SAFE_PROVIDER_ERROR_CODES or re.fullmatch(
        r"provider_http_[1-5][0-9]{2}", value
    ):
        return value
    return "unclassified"


def _memory_prompt_payload(memory: MemoryRecord) -> dict[str, Any]:
    """Keep retrieval metadata useful without sending the vector to the LLM."""

    payload = memory.to_dict()
    payload.pop("embedding", None)
    return payload


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
            update={"retrieved_memories": [_memory_prompt_payload(memory) for memory in memories]}
        )
        try:
            generated = validate_generation(await self.llm.generate_npc_reply(trusted_request))
        except Exception as error:
            self.metrics["provider_or_output_error"] = self.metrics.get(
                "provider_or_output_error", 0
            ) + 1
            logger.warning(
                "NPC provider failed type=%s code=%s",
                type(error).__name__,
                _safe_provider_error_code(error),
            )
            return self._fallback_response(trusted_request, session, "provider_unavailable", store=True)
        _augment_told_world_learning(trusted_request, generated, profile.world_ontology)
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
        knowledge_updates = self._apply_graph_candidates(
            trusted_request, generated, set(memory_ids), evidence_aliases
        )
        response = ConversationResponse(
            request_id=request.request_id,
            session_id=session.session_id,
            reply_text=generated.reply_text,
            emotion=generated.emotion,
            animation_id=select_context_motion(
                request.text,
                trusted_request.retrieved_graph,
                self.catalog.relation_action_catalog,
                generated.animation_id,
            ),
            memory_citations=[memory.memory_id for memory in memories],
            memory_write_ids=memory_ids,
            memory_writes=memory_writes,
            knowledge_updates=knowledge_updates,
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
        nodes = {
            node.node_id: {
                "node_id": node.node_id,
                "node_type": node.node_type,
                "label": node.label,
                "metadata": node.metadata,
                "visibility": node.visibility,
                "source": node.source,
            }
            for node in self.repository.graph_nodes_for_edges(edges)
        }
        result: list[dict[str, Any]] = []
        for edge in edges[:100]:
            payload = edge.to_dict()
            if edge.subject_node_id in nodes:
                payload["subject_node"] = nodes[edge.subject_node_id]
            if edge.object_node_id in nodes:
                payload["object_node"] = nodes[edge.object_node_id]
            result.append(annotate_graph_edge(payload, self.catalog.relation_action_catalog))
        return result

    def graph_payload(self, player: str, save: str, npc: str) -> dict[str, Any]:
        edges = self.repository.graph_edges_for(player, save, npc)
        nodes = self.repository.graph_nodes_for_edges(edges)
        node_payloads = [
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
        ]
        edge_payloads = [
            annotate_graph_edge(edge.to_dict(), self.catalog.relation_action_catalog)
            for edge in edges
        ]
        return {
            "nodes": node_payloads,
            "edges": edge_payloads,
            "relation_action_catalog": self.catalog.relation_action_catalog,
            "visualization": build_graph_visualization(
                node_payloads, edge_payloads, self.catalog.relation_action_catalog
            ),
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
                subject_node_ids=_event_subject_node_ids(raw),
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
        if event_type == "encounter_discovered":
            self._materialize_encounter_discovery(
                request,
                raw,
                npc,
                entry_id,
                memory.memory_id,
            )

    def _materialize_encounter_discovery(
        self,
        request: SyncRequest,
        raw: dict[str, Any],
        npc: str,
        entry_id: str,
        evidence_memory_id: str,
    ) -> None:
        encounter_id = str(raw.get("definition_id", "")).strip()
        if not encounter_id:
            return
        encounter_node_id = f"encounter:{encounter_id}"
        hidden = self.catalog.hidden_encounter_ontology
        node_by_id = {
            str(node.get("node_id", "")): node
            for node in hidden.get("discovered_public_nodes", [])
            if isinstance(node, dict)
        }
        authored_node = node_by_id.get(encounter_node_id)
        if authored_node is None:
            return
        self.repository.add_graph_node(
            GraphNode(
                node_id=encounter_node_id,
                node_type="encounter",
                label=str(authored_node.get("label", encounter_id)),
                metadata=dict(authored_node.get("metadata", {})),
                player_profile_id=request.player_profile_id,
                world_save_id=request.world_save_id,
                owner_npc_persistent_id=npc,
                visibility="witnessed",
                source="gameplay_event",
            )
        )
        for edge_data in hidden.get("discovered_public_edges", []):
            if not isinstance(edge_data, dict):
                continue
            if str(edge_data.get("subject_node_id", "")) != encounter_node_id:
                continue
            predicate = str(edge_data.get("predicate", ""))
            object_id = str(edge_data.get("object_node_id", ""))
            if predicate not in EDGE_TYPES or not object_id:
                continue
            if not self.repository.graph_node_exists(
                object_id,
                request.player_profile_id,
                request.world_save_id,
                npc,
            ):
                self.repository.add_graph_node(
                    GraphNode(
                        node_id=object_id,
                        node_type=_ontology_node_type(object_id),
                        label=object_id.rsplit(":", 1)[-1].replace("_", " ").title(),
                        player_profile_id=request.player_profile_id,
                        world_save_id=request.world_save_id,
                        owner_npc_persistent_id=npc,
                        visibility="witnessed",
                        source="gameplay_event",
                    )
                )
            self.repository.add_graph_edge(
                GraphEdge(
                    id=str(uuid.uuid5(
                        uuid.NAMESPACE_URL,
                        f"encounter:{request.player_profile_id}:{request.world_save_id}:"
                        f"{npc}:{encounter_id}:{predicate}:{object_id}",
                    )),
                    owner_npc_persistent_id=npc,
                    subject_node_id=encounter_node_id,
                    predicate=predicate,
                    object_node_id=object_id,
                    confidence=1.0,
                    visibility="witnessed",
                    source_type="gameplay_event",
                    source_id=entry_id,
                    evidence_memory_ids=[evidence_memory_id],
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
    ) -> list[dict[str, Any]]:
        knowledge_updates: list[dict[str, Any]] = []
        for candidate in generated.graph_update_candidates:
            if candidate.predicate not in EDGE_TYPES:
                self.metrics["graph_candidate_rejected"] = self.metrics.get(
                    "graph_candidate_rejected", 0
                ) + 1
                continue
            if candidate.predicate in CANONICAL_WORLD_EDGE_TYPES:
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
            edge = GraphEdge(
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
            if candidate.predicate == "KNOWS_ABOUT":
                if candidate.subject_node_id != f"npc_instance:{request.npc_persistent_id}":
                    self.metrics["graph_candidate_rejected"] = self.metrics.get(
                        "graph_candidate_rejected", 0
                    ) + 1
                    continue
                edge.visibility = "told"
                edge.source_type = "player_report"
                stored = self.repository.strengthen_graph_edge(edge)
                knowledge_updates.append(
                    {
                        "node_id": stored.object_node_id,
                        "confidence": stored.confidence,
                        "stage": _knowledge_stage(stored.confidence),
                        "source": "told",
                    }
                )
            else:
                self.repository.add_graph_edge(edge)
        return knowledge_updates

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


def _event_subject_node_ids(raw: dict[str, Any]) -> list[str]:
    values = raw.get("subject_node_ids", [])
    result = [str(value) for value in values if value] if isinstance(values, list) else []
    result.extend(
        str(value)
        for value in (raw.get("source_entity_id", ""), raw.get("target_entity_id", ""))
        if value
    )
    return list(dict.fromkeys(result))[:16]


def _ontology_node_type(node_id: str) -> str:
    prefix = node_id.split(":", 1)[0]
    return prefix if prefix in NODE_TYPES else "concept"


def _knowledge_stage(confidence: float) -> str:
    if confidence < 0.45:
        return "rumor"
    if confidence < 0.7:
        return "aware"
    if confidence < 0.9:
        return "familiar"
    return "well_understood"


def _augment_told_world_learning(
    request: NpcGenerationRequest,
    generated: NpcGenerationResult,
    world_ontology: dict[str, Any],
) -> None:
    mentions = _mentioned_world_nodes(request.text, world_ontology)
    if not mentions:
        return
    existing = {
        (item.subject_node_id, item.predicate, item.object_node_id)
        for item in generated.graph_update_candidates
    }
    for candidate in generated.memory_candidates:
        if candidate.visibility != "told":
            continue
        candidate.subject_node_ids = list(
            dict.fromkeys(candidate.subject_node_ids + mentions)
        )[:8]
        evidence_id = candidate.source_id or request.request_id
        for node_id in mentions:
            signature = (
                f"npc_instance:{request.npc_persistent_id}",
                "KNOWS_ABOUT",
                node_id,
            )
            if signature in existing:
                continue
            generated.graph_update_candidates.append(
                GraphUpdateCandidate(
                    subject_node_id=signature[0],
                    predicate=signature[1],
                    object_node_id=signature[2],
                    confidence=min(0.6, candidate.confidence),
                    visibility="told",
                    source_type="conversation_turn",
                    source_id=request.request_id,
                    evidence_memory_ids=[evidence_id],
                )
            )
            existing.add(signature)


def _mentioned_world_nodes(text_value: str, ontology: dict[str, Any]) -> list[str]:
    normalized = text_value.casefold()
    result: list[str] = []
    for raw in ontology.get("nodes", []):
        if not isinstance(raw, dict):
            continue
        node_id = str(raw.get("node_id", "")).strip()
        label = str(raw.get("label", "")).strip().casefold()
        id_term = node_id.rsplit(":", 1)[-1].replace("_", " ").casefold()
        terms = [term for term in (label, id_term) if len(term) >= 4]
        if node_id and any(term in normalized for term in terms):
            result.append(node_id)
        if len(result) >= 8:
            break
    return result
