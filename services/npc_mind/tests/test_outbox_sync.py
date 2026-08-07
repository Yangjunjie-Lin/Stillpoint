import asyncio

from app.repository import InMemoryRepository
from app.schemas import SyncRequest
from app.service import NpcCognitionService


def _event(event_id="e1", npc="mira-1"):
    return {
        "event_id": event_id,
        "player_profile_id": "p",
        "world_save_id": "w",
        "npc_persistent_id": npc,
        "event_type": "npc_attacked",
        "content": "The player attacked Mira near the well.",
        "salience": 0.95,
    }


def test_sync_ack_and_retry_do_not_duplicate_memory():
    repository = InMemoryRepository()
    service = NpcCognitionService(repository=repository)
    request = SyncRequest(
        player_profile_id="p", world_save_id="w", pending_event_outbox=[_event()]
    )
    first = asyncio.run(service.sync(request))
    replay = asyncio.run(service.sync(request.model_copy(update={"last_sync_revision": first.revision})))
    assert first.accepted_event_ids == ["e1"]
    assert replay.accepted_event_ids == ["e1"]
    assert len(repository.memories_for("p", "w", "mira-1")) == 1


def test_sync_partial_success_only_acks_valid_entries():
    service = NpcCognitionService(repository=InMemoryRepository())
    invalid = _event("e2")
    invalid["player_profile_id"] = "other"
    response = asyncio.run(
        service.sync(
            SyncRequest(
                player_profile_id="p",
                world_save_id="w",
                pending_event_outbox=[_event(), invalid],
            )
        )
    )
    assert response.accepted_event_ids == ["e1"]
    assert response.rejected[0]["entry_id"] == "e2"


def test_sync_revision_conflict_is_recoverable():
    service = NpcCognitionService(repository=InMemoryRepository())
    first = asyncio.run(
        service.sync(
            SyncRequest(player_profile_id="p", world_save_id="w", pending_event_outbox=[_event()])
        )
    )
    second = asyncio.run(
        service.sync(
            SyncRequest(
                player_profile_id="p",
                world_save_id="w",
                pending_event_outbox=[_event("e2")],
                last_sync_revision=0,
            )
        )
    )
    assert first.revision == 1
    assert second.revision == 2
    assert second.conflicts and second.conflicts[0]["reason"] == "revision_mismatch"
