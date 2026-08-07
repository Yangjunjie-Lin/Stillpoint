import asyncio
from datetime import datetime, timedelta, timezone

from app.memory import MemoryRecord
from app.repository import InMemoryRepository
from app.schemas import NpcGenerationRequest
from app.service import NpcCognitionService


def _request(query, player="p", save="w", npc="mira-1"):
    return NpcGenerationRequest(
        request_id="query",
        player_profile_id=player,
        world_save_id=save,
        npc_definition_id="mira",
        npc_persistent_id=npc,
        session_id="s",
        text=query,
    )


def _memory(service, content, **values):
    vector = asyncio.run(service.embeddings.embed([content]))[0]
    record = MemoryRecord(
        memory_id=values.pop("memory_id", content),
        player_profile_id=values.pop("player", "p"),
        world_save_id=values.pop("save", "w"),
        owner_npc_persistent_id=values.pop("npc", "mira-1"),
        session_id="s",
        memory_type="episodic",
        content=content,
        embedding=vector,
        **values,
    )
    service.repository.add_memory(record)
    return record


def test_old_memory_paraphrase_recall():
    service = NpcCognitionService(repository=InMemoryRepository())
    _memory(service, "The player said their favorite color is blue.")
    assert service.retrieve_memories(_request("What hue do I prefer?"))[0].content.endswith("blue.")


def test_old_memory_without_shared_words():
    service = NpcCognitionService(repository=InMemoryRepository())
    original = "My favorite color is blue."
    query = "Which hue do I prefer?"
    assert not set(original.lower().split()) & set(query.lower().split())
    _memory(service, original)
    assert service.retrieve_memories(_request(query))


def test_vector_scope_isolation():
    service = NpcCognitionService(repository=InMemoryRepository())
    _memory(service, "My favorite color is blue.", player="other")
    assert service.retrieve_memories(_request("Which hue do I prefer?")) == []


def test_high_salience_overrides_low_recency():
    service = NpcCognitionService(repository=InMemoryRepository())
    old = (datetime.now(timezone.utc) - timedelta(days=3650)).isoformat()
    _memory(service, "A blue preference was solemnly promised.", salience=1.0, created_at_real=old)
    _memory(service, "A color was mentioned recently.", salience=0.01)
    results = service.retrieve_memories(_request("What hue do I prefer?"))
    assert results[0].salience == 1.0


def test_explicit_entity_query_recalls_old_memory():
    service = NpcCognitionService(repository=InMemoryRepository())
    old = (datetime.now(timezone.utc) - timedelta(days=3650)).isoformat()
    _memory(
        service,
        "An ancient unrelated-looking account.",
        created_at_real=old,
        subject_node_ids=["relic:moon-key"],
    )
    request = _request("Do you remember the old account?")
    request.world_context.visible_entity_ids = ["relic:moon-key"]
    assert service.retrieve_memories(request)
