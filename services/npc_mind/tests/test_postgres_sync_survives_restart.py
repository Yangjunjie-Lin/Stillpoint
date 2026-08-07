import asyncio

from app.schemas import SyncRequest
from tests.postgres_test_support import scope, service


def test_postgres_sync_survives_restart(postgres_url):
    player, save, npc = scope()
    event = {
        "event_id": "restart-event",
        "player_profile_id": player,
        "world_save_id": save,
        "npc_persistent_id": npc,
        "event_type": "npc_attacked",
        "content": "The player attacked the NPC.",
    }
    payload = SyncRequest(
        player_profile_id=player,
        world_save_id=save,
        pending_event_outbox=[event],
    )
    first = service(postgres_url)
    original = asyncio.run(first.sync(payload))
    first.repository.close()

    restarted = service(postgres_url)
    replay = asyncio.run(
        restarted.sync(payload.model_copy(update={"last_sync_revision": original.revision}))
    )
    assert replay.accepted_event_ids == ["restart-event"]
    assert replay.revision == original.revision
    assert len(restarted.repository.memories_for(player, save, npc)) == 1
    restarted.repository.close()
