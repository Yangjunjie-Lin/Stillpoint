import asyncio

import pytest

from app.repository import InMemoryRepository
from app.schemas import NpcGenerationRequest, NpcGenerationResult
from app.memory import MemoryRecord
from app.service import NpcCognitionService


class CapturingProvider:
    def __init__(self):
        self.requests = []

    async def generate_npc_reply(self, request):
        self.requests.append(request)
        return NpcGenerationResult(reply_text="ok")


def _request(definition="mira", npc="npc-1", profile=None):
    return NpcGenerationRequest(
        request_id=f"r-{definition}-{npc}",
        player_profile_id="p",
        world_save_id="w",
        npc_definition_id=definition,
        npc_persistent_id=npc,
        session_id=f"s-{npc}",
        text="hello",
        npc_profile=profile or {},
    )


def test_catalog_profile_is_injected_server_side():
    provider = CapturingProvider()
    service = NpcCognitionService(repository=InMemoryRepository(), llm=provider)
    asyncio.run(service.handle_turn(_request()))
    profile = provider.requests[0].npc_profile
    for field in (
        "identity", "personality", "speech_style", "biography", "values", "taboos",
        "goals", "cognitive_skills", "knowledge_seeds", "belief_seeds", "memory_policy",
        "response_constraints",
    ):
        assert field in profile


def test_client_cannot_override_npc_profile():
    provider = CapturingProvider()
    service = NpcCognitionService(repository=InMemoryRepository(), llm=provider)
    asyncio.run(service.handle_turn(_request(profile={"display_name": "Evil override"})))
    assert provider.requests[0].npc_profile["display_name"] == "Mira"


def test_mira_and_bandit_prompts_differ():
    provider = CapturingProvider()
    service = NpcCognitionService(repository=InMemoryRepository(), llm=provider)
    asyncio.run(service.handle_turn(_request("mira", "mira-1")))
    asyncio.run(service.handle_turn(_request("ren", "ren-1")))
    asyncio.run(service.handle_turn(_request("bandit", "bandit-1")))
    assert provider.requests[0].npc_profile != provider.requests[1].npc_profile
    assert provider.requests[1].npc_profile != provider.requests[2].npc_profile
    assert provider.requests[0].npc_profile["speech_style"] != provider.requests[1].npc_profile["speech_style"]
    assert provider.requests[1].npc_profile["speech_style"] != provider.requests[2].npc_profile["speech_style"]


def test_retrieved_memory_prompt_omits_embedding_vector():
    provider = CapturingProvider()
    repository = InMemoryRepository()
    repository.add_memory(
        MemoryRecord(
            memory_id="memory-1",
            player_profile_id="p",
            world_save_id="w",
            owner_npc_persistent_id="npc-1",
            session_id="s-npc-1",
            memory_type="episodic",
            content="The player prefers blue.",
            embedding=[0.0] * 1536,
        )
    )
    service = NpcCognitionService(repository=repository, llm=provider)

    asyncio.run(service.handle_turn(_request()))

    retrieved = provider.requests[0].retrieved_memories
    assert retrieved
    assert "embedding" not in retrieved[0]
    assert retrieved[0]["content"] == "The player prefers blue."


def test_unknown_npc_definition_rejected():
    service = NpcCognitionService(repository=InMemoryRepository())
    with pytest.raises(ValueError, match="unknown_npc_definition"):
        asyncio.run(service.handle_turn(_request("not-real")))
