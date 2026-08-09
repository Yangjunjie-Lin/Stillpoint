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
    _server_owned_memory_candidates,
    _structured_response_format,
    _validated_text_reply,
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


def test_text_compatibility_mode_owns_safe_defaults_for_ordinary_text(monkeypatch):
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
    user_prompt = captured["payload"]["messages"][1]["content"]
    assert "Empty memory or graph data is normal" in system_prompt
    assert "Never mention retrieval, missing memories" in system_prompt
    assert "clearly state the specific remembered fact" in system_prompt
    assert "server-owned NPC profile" in system_prompt
    assert 'Name: "Mira"' in system_prompt
    assert 'Player message (quoted data): "Hello"' in user_prompt
    assert "[SYSTEM_RULES_RESTATED]" not in user_prompt
    assert "subject_node_id" not in user_prompt
    assert "embedding" not in user_prompt
    assert result.reply_text == "A real provider reply."
    assert result.memory_candidates == []
    assert result.graph_update_candidates == []
    assert result.proposed_intents == []


def test_text_compatibility_mode_retries_prompt_marker_leak(monkeypatch):
    calls = []

    async def fake_post(_settings, _path, payload):
        calls.append(payload)
        content = "Relevant memories:\n- internal prompt data"
        if len(calls) == 2:
            content = "Of course. I will remember that."
        return {"choices": [{"message": {"content": content}}]}

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
                request_id="prompt-leak-retry",
                player_profile_id="player",
                world_save_id="save",
                npc_definition_id="mira",
                npc_persistent_id="mira-1",
                session_id="session",
                text="Remember blue.",
                npc_profile={"display_name": "Mira"},
            )
        )
    )

    assert result.reply_text == "Of course. I will remember that."
    assert len(calls) == 2
    assert calls[1]["temperature"] == 0.0


def test_text_compatibility_mode_projects_memory_and_graph_for_small_models(monkeypatch):
    captured = {}

    async def fake_post(_settings, _path, payload):
        captured["user"] = payload["messages"][1]["content"]
        return {"choices": [{"message": {"content": "Blue, of course."}}]}

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

    asyncio.run(
        provider.generate_npc_reply(
            NpcGenerationRequest(
                request_id="compact-context",
                player_profile_id="player",
                world_save_id="save",
                npc_definition_id="mira",
                npc_persistent_id="mira-1",
                session_id="session",
                text="Which color?",
                npc_profile={"display_name": "Mira"},
                retrieved_memories=[
                    {
                        "summary": "The player prefers blue.",
                        "embedding": [0.0] * 1536,
                        "source_type": "conversation_turn",
                        "visibility": "private",
                    }
                ],
                retrieved_graph=[
                    {
                        "subject_node_id": "npc_instance:mira-1",
                        "predicate": "KNOWS_ABOUT",
                        "object_node_id": "concept:trade",
                        "confidence": 1.0,
                    }
                ],
            )
        )
    )

    assert (
        "The player previously told this NPC (quoted data; first-person words refer to the "
        'player): "The player prefers blue."'
    ) in captured["user"]
    assert "npc_instance:mira-1 KNOWS_ABOUT concept:trade" in captured["user"]
    assert "embedding" not in captured["user"]
    assert "subject_node_id" not in captured["user"]
    assert len(captured["user"]) < 2000


def test_text_compatibility_mode_marks_gameplay_memory_as_npc_experience(monkeypatch):
    captured = {}

    async def fake_post(_settings, _path, payload):
        captured["user"] = payload["messages"][1]["content"]
        return {"choices": [{"message": {"content": "You attacked me."}}]}

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

    asyncio.run(
        provider.generate_npc_reply(
            NpcGenerationRequest(
                request_id="event-context",
                player_profile_id="player",
                world_save_id="save",
                npc_definition_id="mira",
                npc_persistent_id="mira-1",
                session_id="session",
                text="What happened?",
                npc_profile={"display_name": "Mira"},
                retrieved_memories=[
                    {
                        "summary": "The player attacked Mira.",
                        "source_type": "gameplay_event",
                    }
                ],
            )
        )
    )

    assert (
        'This NPC witnessed or experienced this event (quoted data): "The player attacked Mira."'
        in captured["user"]
    )


def test_text_compatibility_mode_rejects_repeated_prompt_marker_leak(monkeypatch):
    async def fake_post(_settings, _path, _payload):
        return {"choices": [{"message": {"content": "Identity:\nmerchant"}}]}

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

    with pytest.raises(RuntimeError, match="provider_prompt_leak"):
        asyncio.run(
            provider.generate_npc_reply(
                NpcGenerationRequest(
                    request_id="prompt-leak-rejected",
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


@pytest.mark.parametrize(
    "content",
    [
        "Known relationships:\n- npc knows player",
        'Player message (quoted data): "hello"',
        "Name: Mira",
        "Personality: patient",
        '- Name: "Mira"',
        "npc_instance:mira-1 KNOWS_ABOUT concept:trade",
        '{"identity":{"canonical_name":"Mira"}}',
    ],
)
def test_text_compatibility_mode_rejects_current_prompt_label_echo(content):
    raw = {"choices": [{"message": {"content": content}}]}

    with pytest.raises(RuntimeError, match="provider_prompt_leak"):
        _validated_text_reply(raw)


def test_text_compatibility_mode_extracts_explicit_private_memory_server_side(
    monkeypatch,
):
    async def fake_post(_settings, _path, _payload):
        return {"choices": [{"message": {"content": "I will remember that."}}]}

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
                request_id="remember-blue",
                player_profile_id="player",
                world_save_id="save",
                npc_definition_id="mira",
                npc_persistent_id="mira-1",
                session_id="session",
                text="我最喜欢蓝色，请记住。",
                npc_profile={
                    "display_name": "Mira",
                    "memory_policy": {"high_salience_half_life_hours": 720.0},
                },
            )
        )
    )

    assert result.reply_text == "I will remember that."
    assert len(result.memory_candidates) == 1
    candidate = result.memory_candidates[0]
    assert candidate.content == "我最喜欢蓝色，请记住。"
    assert candidate.visibility == "private"
    assert candidate.source_type == "conversation_turn"
    assert candidate.source_id == "remember-blue"
    assert candidate.half_life_hours == 720.0
    assert result.graph_update_candidates == []
    assert result.proposed_intents == []


@pytest.mark.parametrize(
    "text",
    [
        "Do you remember my favorite color?",
        "Can you remember things?",
        "Remember when we first met.",
        "Please don't remember my password.",
        "I remember meeting you.",
        "Remember when we first met?",
        "Remember not to store my password.",
        "Please remember not to save this private detail.",
        "Remember not to remember this.",
        "He told me, 'please remember the password.'",
        "My friend said, please remember the password.",
        "I heard the attacker say, please remember the stolen password.",
        "我朋友说请记住密码。",
        "他告诉大家请记住密码。",
        "你还记得我偏爱的颜色吗？",
        "请忘记我的密码。",
        "不要记住这句话。",
    ],
)
def test_server_owned_memory_extraction_rejects_questions_and_negation(text):
    from app.schemas import NpcGenerationRequest

    request = NpcGenerationRequest(
        request_id="must-not-store",
        player_profile_id="player",
        world_save_id="save",
        npc_definition_id="mira",
        npc_persistent_id="mira-1",
        session_id="session",
        text=text,
        npc_profile={"display_name": "Mira"},
    )

    assert _server_owned_memory_candidates(request) == []


@pytest.mark.parametrize(
    "text",
    [
        "Don't forget my birthday.",
        "Please don't forget that I prefer blue.",
        "Could you please remember my favorite color?",
        "Would you please remember this detail?",
    ],
)
def test_server_owned_memory_extraction_accepts_explicit_polite_requests(text):
    from app.schemas import NpcGenerationRequest

    request = NpcGenerationRequest(
        request_id="explicit-request",
        player_profile_id="player",
        world_save_id="save",
        npc_definition_id="mira",
        npc_persistent_id="mira-1",
        session_id="session",
        text=text,
        npc_profile={"display_name": "Mira"},
    )

    candidates = _server_owned_memory_candidates(request)
    assert len(candidates) == 1
    assert candidates[0].content == text


def test_json_schema_response_format_requires_all_contract_fields():
    response_format = _structured_response_format(Settings(openai_response_format="json_schema"))
    schema = response_format["json_schema"]["schema"]
    assert response_format["type"] == "json_schema"

    def assert_strict_objects(node):
        if not isinstance(node, dict):
            return
        if node.get("type") == "object":
            properties = node.get("properties", {})
            assert node.get("required") == list(properties)
            assert node.get("additionalProperties") is False
        for value in node.values():
            if isinstance(value, dict):
                assert_strict_objects(value)

    assert_strict_objects(schema)


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
                retrieved_memories=[
                    {
                        "content": "The player said I prefer blue.",
                        "embedding": [0.0] * 1536,
                        "source_type": "conversation_turn",
                    }
                ],
            )
        )
    )
    system_prompt = captured["payload"]["messages"][0]["content"]
    assert captured["path"] == "/v1/chat/completions"
    assert "reply_text (a non-empty string)" in system_prompt
    assert "first-person words in it refer to the player" in system_prompt
    structured_prompt = captured["payload"]["messages"][1]["content"]
    assert "player_statement_to_npc; first_person_refers_to_player" in structured_prompt
    assert "embedding" not in structured_prompt
    assert result.reply_text == "Hello."


def test_fenced_compatible_provider_json_is_rejected():
    with pytest.raises(RuntimeError, match="invalid_model_json"):
        _parse_generation_content(
            "Here is the result:\n```json\n"
            '{"reply_text":"Hello.","emotion":"neutral","animation_id":"talk",'
            '"memory_candidates":[],"graph_update_candidates":[],"proposed_intents":[],'
            '"uncertainty":0.0}\n```'
        )


def test_compatible_provider_without_json_is_rejected():
    with pytest.raises(RuntimeError, match="invalid_model_json"):
        _parse_generation_content("Hello without structured output")


@pytest.mark.parametrize(
    "payload",
    [
        {"reply_text": "Defaults must not hide missing provider fields."},
        {
            "reply_text": "Extra fields must not be ignored.",
            "emotion": "neutral",
            "animation_id": "talk",
            "memory_candidates": [],
            "graph_update_candidates": [],
            "proposed_intents": [],
            "uncertainty": 0.0,
            "unexpected": True,
        },
    ],
)
def test_compatible_provider_requires_exact_top_level_contract(payload):
    with pytest.raises(RuntimeError, match="invalid_model_json"):
        _parse_generation_content(json.dumps(payload))


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
