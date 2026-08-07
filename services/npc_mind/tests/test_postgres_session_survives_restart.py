import asyncio

from app.repository import PostgresCognitionRepository
from tests.postgres_test_support import request, scope, service


def test_postgres_session_survives_restart(postgres_url):
    player, save, npc = scope()
    first = service(postgres_url)
    asyncio.run(first.handle_turn(request(player, save, npc)))
    first.repository.close()

    restarted = PostgresCognitionRepository(postgres_url)
    session = restarted.get_session(f"session-{npc}", player, save, npc)
    assert session is not None
    assert (session.player_profile_id, session.world_save_id, session.npc_persistent_id) == (
        player,
        save,
        npc,
    )
    assert len(session.turns) == 2
    restarted.close()
