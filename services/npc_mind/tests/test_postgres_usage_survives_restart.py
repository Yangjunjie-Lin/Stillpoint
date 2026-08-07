import asyncio

from tests.postgres_test_support import request, scope, service


def test_postgres_usage_survives_restart(postgres_url):
    player, save, npc = scope()
    first = service(postgres_url)
    asyncio.run(first.handle_turn(request(player, save, npc, text="hello")))
    first.repository.close()

    restarted = service(postgres_url)
    assert restarted.repository.daily_cost(player) > 0
    restarted.repository.close()
