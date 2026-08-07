import asyncio

from app.repository import PostgresCognitionRepository
from tests.postgres_test_support import request, scope, service


def test_postgres_memory_survives_restart(postgres_url):
    player, save, npc = scope()
    first = service(postgres_url)
    asyncio.run(first.handle_turn(request(player, save, npc)))
    first.repository.close()

    restarted = PostgresCognitionRepository(postgres_url)
    memories = restarted.memories_for(player, save, npc)
    assert len(memories) == 1
    assert "blue" in memories[0].content
    restarted.close()
