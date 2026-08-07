import asyncio

from tests.postgres_test_support import request, scope, service


def test_postgres_idempotency_survives_restart(postgres_url):
    player, save, npc = scope()
    payload = request(player, save, npc)
    first = service(postgres_url)
    original = asyncio.run(first.handle_turn(payload))
    first.repository.close()

    restarted = service(postgres_url)
    replay = asyncio.run(restarted.handle_turn(payload))
    assert replay.model_dump() == original.model_dump()
    assert len(restarted.repository.get_session(f"session-{npc}", player, save, npc).turns) == 2
    restarted.repository.close()
