import asyncio
import json

import pytest

from app.config import Settings
from app import providers
from app.providers import (
    FakeEmbeddingProvider,
    OpenAILlmProvider,
    _parse_generation_content,
    _provider_url,
    _structured_response_format,
)
from app.repository import InMemoryRepository
from app.service import NpcCognitionService


def test_openai_compatible_base_url_is_used():
    settings = Settings(openai_base_url="https://api.siliconflow.cn/v1/")
    assert _provider_url(settings, "/chat/completions") == (
        "https://api.siliconflow.cn/v1/chat/completions"
    )
    assert _provider_url(settings, "/v1/chat/completions") == (
        "https://api.siliconflow.cn/v1/chat/completions"
    )


def test_external_provider_base_url_requires_https():
    settings = Settings(
        app_env="test",
        npc_repository="in_memory",
        llm_provider="openai",
        openai_base_url="http://api.example.invalid/v1",
    )
    with pytest.raises(ValueError, match="provider_base_url_must_use_https"):
        NpcCognitionService(settings=settings, repository=InMemoryRepository())


def test_openai_compatible_text_can_use_explicit_local_embeddings():
    settings = Settings(
        app_env="test",
        npc_repository="in_memory",
        llm_provider="openai",
        embedding_provider="fake",
        openai_api_key="test-key",
        openai_base_url="https://api.siliconflow.cn/v1",
        openai_text_model="Qwen/Qwen2.5-7B-Instruct",
    )
    service = NpcCognitionService(settings=settings, repository=InMemoryRepository())
    assert isinstance(service.llm, OpenAILlmProvider)
    assert isinstance(service.embeddings, FakeEmbeddingProvider)


def test_text_compatibility_mode_owns_structured_defaults(monkeypatch):
    captured = {}

    async def fake_post(_settings, path, payload):
        captured["path"] = path
        captured["payload"] = payload
        return {"choices": [{"message": {"content": "A real provider reply."}}]}

    monkeypatch.setattr(providers, "_post_openai", fake_post)
    provider = OpenAILlmProvider(
        Settings(
            llm_provider="openai",
            embedding_provider="fake",
            openai_api_key="test-key",
            openai_text_model="Qwen/Qwen2.5-7B-Instruct",
            openai_response_format="text",
        )
    )
    from app.schemas import NpcGenerationRequest

    result = asyncio.run(
        provider.generate_npc_reply(
            NpcGenerationRequest(
                request_id="text-compatibility",
                player_profile_id="player",
                world_save_id="save",
                npc_definition_id="mira",
                npc_persistent_id="mira-1",
                session_id="session",
                text="Hello",
                npc_profile={"display_name": "Mira"},
            )
        )
    )
    assert captured["path"] == "/v1/chat/completions"
    assert "response_format" not in captured["payload"]
    system_prompt = captured["payload"]["messages"][0]["content"]
    assert "Empty memory or graph data is normal" in system_prompt
    assert "Never mention retrieval, missing memories" in system_prompt
    assert result.reply_text == "A real provider reply."
    assert result.memory_candidates == []
    assert result.graph_update_candidates == []
    assert result.proposed_intents == []


def test_json_schema_response_format_requires_all_contract_fields():
    response_format = _structured_response_format(
        Settings(openai_response_format="json_schema")
    )
    schema = response_format["json_schema"]["schema"]
    assert response_format["type"] == "json_schema"
    assert schema["required"] == list(schema["properties"])
    assert schema["additionalProperties"] is False


def test_auto_embeddings_remain_remote_for_configured_openai_model():
    settings = Settings(
        llm_provider="openai",
        embedding_provider="auto",
        openai_embedding_model="text-embedding-3-small",
    )
    assert settings.use_remote_embeddings()


def test_text_provider_sends_explicit_structured_output_contract(monkeypatch):
    captured = {}

    async def fake_post(_settings, path, payload):
        captured["path"] = path
        captured["payload"] = payload
        return {
            "choices": [
                {
                    "message": {
                        "content": json.dumps(
                            {
                                "reply_text": "Hello.",
                                "emotion": "neutral",
                                "animation_id": "talk",
                                "memory_candidates": [],
                                "graph_update_candidates": [],
                                "proposed_intents": [],
                                "uncertainty": 0.0,
                            }
                        )
                    }
                }
            ]
        }

    monkeypatch.setattr(providers, "_post_openai", fake_post)
    provider = OpenAILlmProvider(
        Settings(
            llm_provider="openai",
            openai_api_key="test-key",
            openai_text_model="test-model",
        )
    )
    from app.schemas import NpcGenerationRequest

    result = asyncio.run(
        provider.generate_npc_reply(
            NpcGenerationRequest(
                request_id="structured-contract",
                player_profile_id="player",
                world_save_id="save",
                npc_definition_id="mira",
                npc_persistent_id="mira-1",
                session_id="session",
                text="Hello",
                npc_profile={"display_name": "Mira"},
            )
        )
    )
    system_prompt = captured["payload"]["messages"][0]["content"]
    assert captured["path"] == "/v1/chat/completions"
    assert "reply_text (a non-empty string)" in system_prompt
    assert result.reply_text == "Hello."


def test_fenced_compatible_provider_json_is_validated():
    result = _parse_generation_content(
        "Here is the result:\n```json\n"
        '{"reply_text":"Hello.","emotion":"neutral","animation_id":"talk",'
        '"memory_candidates":[],"graph_update_candidates":[],"proposed_intents":[],'
        '"uncertainty":0.0}\n```'
    )
    assert result.reply_text == "Hello."


def test_compatible_provider_without_json_is_rejected():
    with pytest.raises(RuntimeError, match="invalid_model_json"):
        _parse_generation_content("Hello without structured output")


def test_text_provider_retries_invalid_structure_once(monkeypatch):
    calls = []

    async def fake_post(_settings, _path, payload):
        calls.append(payload)
        content = "not json"
        if len(calls) == 2:
            content = json.dumps(
                {
                    "reply_text": "Corrected.",
                    "emotion": "neutral",
                    "animation_id": "talk",
                    "memory_candidates": [],
                    "graph_update_candidates": [],
                    "proposed_intents": [],
                    "uncertainty": 0.0,
                }
            )
        return {"choices": [{"message": {"content": content}}]}

    monkeypatch.setattr(providers, "_post_openai", fake_post)
    provider = OpenAILlmProvider(
        Settings(
            llm_provider="openai",
            openai_api_key="test-key",
            openai_text_model="test-model",
        )
    )
    from app.schemas import NpcGenerationRequest

    result = asyncio.run(
        provider.generate_npc_reply(
            NpcGenerationRequest(
                request_id="retry-structure",
                player_profile_id="player",
                world_save_id="save",
                npc_definition_id="bandit",
                npc_persistent_id="bandit-1",
                session_id="session",
                text="Hello",
                npc_profile={"display_name": "Bandit"},
            )
        )
    )
    assert result.reply_text == "Corrected."
    assert len(calls) == 2
    assert calls[1]["temperature"] == 0.1
