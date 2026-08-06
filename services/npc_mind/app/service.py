from __future__ import annotations

import re
import uuid
from typing import Any

from .config import Settings
from .memory import MemoryRecord, reinforce
from .providers import (
    EmbeddingProvider,
    FakeEmbeddingProvider,
    FakeLlmProvider,
    LlmProvider,
    OpenAIEmbeddingProvider,
    OpenAILlmProvider,
)
from .repository import InMemoryRepository, scope_key
from .schemas import ConversationResponse, NpcGenerationRequest, NpcGenerationResult
from .output_validation import validate_structured_output


SAFE_FALLBACK = "I can't reach my thoughts right now. Let's continue with what we know."


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
        repository: InMemoryRepository | None = None,
        llm: LlmProvider | None = None,
        embeddings: EmbeddingProvider | None = None,
    ) -> None:
        self.settings = settings or Settings.from_env()
        self.repository = repository or InMemoryRepository()
        self.llm = llm or (
            OpenAILlmProvider(self.settings)
            if self.settings.llm_provider == "openai"
            else FakeLlmProvider()
        )
        self.embeddings = embeddings or (
            OpenAIEmbeddingProvider(self.settings)
            if self.settings.llm_provider == "openai"
            else FakeEmbeddingProvider()
        )
        self.rate_limiter = RateLimiter()
        self.metrics: dict[str, int] = {}

    async def handle_turn(self, request: NpcGenerationRequest) -> ConversationResponse:
        scope_key(request.player_profile_id, request.world_save_id, request.npc_persistent_id)
        if len(request.text) > self.settings.max_input_length:
            raise ValueError("input_too_long")
        now = __import__("time").time()
        if not self.rate_limiter.allow(
            f"player:{request.player_profile_id}", self.settings.player_rate_per_minute, now
        ):
            raise ValueError("player_rate_limited")
        if not self.rate_limiter.allow(
            f"npc:{request.npc_persistent_id}", self.settings.npc_rate_per_minute, now
        ):
            raise ValueError("npc_rate_limited")
        if request.request_id in self.repository.idempotent_responses:
            return ConversationResponse.model_validate(
                self.repository.idempotent_responses[request.request_id]
            )
        session = self.repository.create_session(request.model_dump())
        memories = self.retrieve_memories(request)
        graph = self.retrieve_graph(request)
        request = request.model_copy(
            update={
                "retrieved_memories": [m.to_dict() for m in memories],
                "retrieved_graph": graph,
                "recent_turns": [turn.to_dict() for turn in session.turns[-6:]],
            }
        )
        try:
            generated = await self.llm.generate_npc_reply(request)
            generated = validate_generation(generated)
        except Exception:
            self.metrics["invalid_model_output"] = self.metrics.get("invalid_model_output", 0) + 1
            return self._fallback_response(request, session)
        usage = {
            "input_tokens": _token_count(request.text)
            + sum(_token_count(str(item)) for item in request.retrieved_memories),
            "output_tokens": _token_count(generated.reply_text),
        }
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
        memory_ids: list[str] = []
        if generated.memory_candidates:
            vectors = await self.embeddings.embed(
                [candidate.content for candidate in generated.memory_candidates]
            )
            for candidate, vector in zip(generated.memory_candidates, vectors):
                memory = MemoryRecord(
                    memory_id=str(uuid.uuid4()),
                    player_profile_id=request.player_profile_id,
                    world_save_id=request.world_save_id,
                    owner_npc_persistent_id=request.npc_persistent_id,
                    session_id=request.session_id,
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
                    source_id=candidate.source_id,
                    subject_node_ids=candidate.subject_node_ids,
                    visibility=candidate.visibility,
                )
                saved = self.repository.add_memory(memory)
                memory_ids.append(saved.memory_id)
        response = ConversationResponse(
            request_id=request.request_id,
            session_id=session.session_id,
            reply_text=generated.reply_text,
            emotion=generated.emotion,
            animation_id=generated.animation_id,
            memory_citations=[memory.memory_id for memory in memories],
            memory_write_ids=memory_ids,
            proposed_intents=generated.proposed_intents,
            usage=usage,
        )
        self.repository.idempotent_responses[request.request_id] = response.model_dump()
        self.repository.usage[request.player_profile_id] = (
            self.repository.usage.get(request.player_profile_id, 0) + usage["output_tokens"]
        )
        return response

    def retrieve_memories(self, request: NpcGenerationRequest) -> list[MemoryRecord]:
        memories = self.repository.memories_for(
            request.player_profile_id, request.world_save_id, request.npc_persistent_id
        )
        scored = sorted(
            ((memory.score(request.text), memory) for memory in memories),
            key=lambda item: item[0],
            reverse=True,
        )
        result: list[MemoryRecord] = []
        for score, memory in scored[:10]:
            if score <= 0 and not _explicit_entity_query(request.text, memory):
                continue
            reinforce(memory)
            result.append(memory)
        return result

    def retrieve_graph(self, request: NpcGenerationRequest) -> list[dict[str, Any]]:
        entities = {entity for entity in request.world_context.visible_entity_ids if entity}
        edges = self.repository.graph.traverse(entities, request.npc_persistent_id, 2)
        return [edge.to_dict() for edge in edges]

    def _fallback_response(
        self, request: NpcGenerationRequest, session: Any
    ) -> ConversationResponse:
        usage = {
            "input_tokens": _token_count(request.text),
            "output_tokens": _token_count(SAFE_FALLBACK),
        }
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
            reply_text=SAFE_FALLBACK,
            usage=usage,
        )
        self.repository.idempotent_responses[request.request_id] = response.model_dump()
        return response


def validate_generation(value: Any) -> NpcGenerationResult:
    return validate_structured_output(value)


def _token_count(value: str) -> int:
    return max(1, len(re.findall(r"\S+", value)))


def _explicit_entity_query(query: str, memory: MemoryRecord) -> bool:
    entities = set(re.findall(r"[\w:-]+", query.lower()))
    return bool(entities & {item.lower() for item in memory.subject_node_ids})
