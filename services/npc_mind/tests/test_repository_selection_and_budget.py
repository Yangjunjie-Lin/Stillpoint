import asyncio

import pytest

from app.config import Settings
from app.repository import InMemoryRepository, PostgresCognitionRepository
from app.schemas import NpcGenerationRequest, NpcGenerationResult
from app.service import NpcCognitionService


class PaidProvider:
    def __init__(self):
        self.calls = 0

    async def generate_npc_reply(self, request):
        self.calls += 1
        return NpcGenerationResult(reply_text="paid")


class PaidEmbeddingProvider:
    def __init__(self):
        self.calls = 0

    async def embed(self, texts):
        self.calls += 1
        return [[0.0] * 1536 for _ in texts]


def _request():
    return NpcGenerationRequest(
        request_id="budget-request",
        player_profile_id="p",
        world_save_id="w",
        npc_definition_id="mira",
        npc_persistent_id="mira-1",
        session_id="s",
        text="hello",
    )


def test_production_defaults_to_postgres_without_fallback():
    service = NpcCognitionService(
        settings=Settings(app_env="production", npc_repository="postgres")
    )
    assert isinstance(service.repository, PostgresCognitionRepository)
    service.repository.close()


def test_test_environment_does_not_implicitly_select_memory_repository():
    settings = Settings(app_env="test", npc_repository="postgres")
    assert not settings.repository_is_in_memory()


def test_explicit_test_configuration_may_use_in_memory():
    service = NpcCognitionService(
        settings=Settings(app_env="test", npc_repository="in_memory")
    )
    assert isinstance(service.repository, InMemoryRepository)


def test_production_cannot_select_memory_repository():
    settings = Settings(app_env="production", npc_repository="in_memory")
    with pytest.raises(ValueError, match="in_memory_repository_requires_test_environment"):
        settings.repository_is_in_memory()


def test_daily_budget_stops_paid_provider_call():
    repository = InMemoryRepository()
    repository.record_usage("p", "w", "mira-1", "earlier", {}, 5.0)
    provider = PaidProvider()
    embeddings = PaidEmbeddingProvider()
    service = NpcCognitionService(
        settings=Settings(app_env="test", daily_budget_usd=1.0),
        repository=repository,
        llm=provider,
        embeddings=embeddings,
    )
    result = asyncio.run(service.handle_turn(_request()))
    assert provider.calls == 0
    assert embeddings.calls == 0
    assert result.degraded is True
    assert result.degradation_reason == "daily_budget_exceeded"
