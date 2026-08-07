import asyncio

from tests.postgres_test_support import request, scope, service


def test_postgres_player_save_scope_isolation(postgres_url):
    player, save, npc = scope()
    backend = service(postgres_url)
    asyncio.run(backend.handle_turn(request(player, save, npc)))
    assert backend.repository.memories_for(player, save, npc)
    assert backend.repository.memories_for(player + "-other", save, npc) == []
    assert backend.repository.memories_for(player, save + "-other", npc) == []
    assert backend.repository.memories_for(player, save, npc + "-other") == []
    backend.repository.close()
