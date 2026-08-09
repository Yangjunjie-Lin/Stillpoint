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
    _text_memory_context,
    _text_profile_context,
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
    assert "你是Mira" in system_prompt
    assert "服务器角色设定最高优先" in system_prompt
    assert "玩家使用英语" in system_prompt
    assert "这是简单问候" in system_prompt
    assert user_prompt == "Hello"
    assert "Relevant memories:" not in user_prompt
    assert "Known relationships:" not in user_prompt
    assert captured["payload"]["temperature"] == 0.0
    assert "top_p" not in captured["payload"]
    assert "frequency_penalty" not in captured["payload"]
    assert captured["payload"]["max_tokens"] == 64
    assert "[SYSTEM_RULES_RESTATED]" not in user_prompt
    assert "subject_node_id" not in user_prompt
    assert "embedding" not in user_prompt
    assert result.reply_text == "A real provider reply."
    assert result.memory_candidates == []
    assert result.graph_update_candidates == []
    assert result.proposed_intents == []


def test_non_qwen_text_provider_keeps_full_context_and_output_budget(monkeypatch):
    captured = {}

    async def fake_post(_settings, _path, payload):
        captured["payload"] = payload
        return {"choices": [{"message": {"content": "A valid detailed reply."}}]}

    monkeypatch.setattr(providers, "_post_openai", fake_post)
    provider = OpenAILlmProvider(
        Settings(
            llm_provider="openai",
            embedding_provider="fake",
            openai_api_key="test-key",
            openai_text_model="generic-chat-model",
            openai_response_format="text",
            max_output_tokens=400,
        )
    )
    from app.schemas import NpcGenerationRequest

    asyncio.run(
        provider.generate_npc_reply(
            NpcGenerationRequest(
                request_id="generic-text-provider",
                player_profile_id="player",
                world_save_id="save",
                npc_definition_id="mira",
                npc_persistent_id="mira-1",
                session_id="session",
                text="Explain the local trade routes.",
                npc_profile={"display_name": "Mira"},
                retrieved_graph=[
                    {
                        "subject_node_id": "npc_instance:mira-1",
                        "predicate": "KNOWS_ABOUT",
                        "object_node_id": "concept:trade",
                    }
                ],
            )
        )
    )

    payload = captured["payload"]
    assert payload["temperature"] == 0.2
    assert payload["max_tokens"] == 240
    assert "frequency_penalty" not in payload
    assert "Server-owned NPC profile" in payload["messages"][0]["content"]
    assert "npc_instance:mira-1 KNOWS_ABOUT concept:trade" in payload["messages"][1][
        "content"
    ]


def test_qwen_compact_profile_is_dynamic_and_not_a_mira_fallback(monkeypatch):
    captured_system_prompts = []

    async def fake_post(_settings, _path, payload):
        captured_system_prompts.append(payload["messages"][0]["content"])
        return {"choices": [{"message": {"content": "A valid reply."}}]}

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

    profiles = [
        {
            "definition_id": "mira",
            "display_name": "Mira",
            "identity": {"occupation": "merchant"},
            "personality": {"honesty": 0.9, "empathy": 0.85},
            "speech_style": {"sentence_length": "medium", "verbosity": 0.55},
        },
        {
            "definition_id": "bandit",
            "display_name": "Bandit",
            "identity": {"occupation": "bandit"},
            "personality": {"honesty": 0.1, "empathy": 0.15},
            "speech_style": {"sentence_length": "short", "verbosity": 0.2},
        },
    ]
    for index, profile in enumerate(profiles):
        asyncio.run(
            provider.generate_npc_reply(
                NpcGenerationRequest(
                    request_id=f"dynamic-profile-{index}",
                    player_profile_id="player",
                    world_save_id="save",
                    npc_definition_id=profile["definition_id"],
                    npc_persistent_id=f"npc-{index}",
                    session_id=f"session-{index}",
                    text="Hello",
                    npc_profile=profile,
                )
            )
        )

    assert captured_system_prompts[0] != captured_system_prompts[1]
    assert "你是Mira，职业是merchant" in captured_system_prompts[0]
    assert "诚实" in captured_system_prompts[0]
    assert "你是Bandit，职业是bandit" in captured_system_prompts[1]
    assert "狡诈" in captured_system_prompts[1]


def test_qwen_greeting_omits_irrelevant_retrieved_memory(monkeypatch):
    captured = {}

    async def fake_post(_settings, _path, payload):
        captured["user"] = payload["messages"][1]["content"]
        return {"choices": [{"message": {"content": "Hello! How can I help?"}}]}

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
                request_id="qwen-greeting-with-memory",
                player_profile_id="player",
                world_save_id="save",
                npc_definition_id="mira",
                npc_persistent_id="mira-1",
                session_id="session",
                text="Hello",
                npc_profile={"display_name": "Mira"},
                retrieved_memories=[
                    {
                        "summary": "The player prefers blue.",
                        "source_type": "conversation_turn",
                        "salience": 0.9,
                    }
                ],
            )
        )
    )

    assert captured["user"] == "Hello"


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
    assert "frequency_penalty" not in calls[1]


def test_text_compatibility_mode_retries_internal_retrieval_status(monkeypatch):
    calls = []

    async def fake_post(_settings, _path, payload):
        calls.append(payload)
        content = "No memories were retrieved."
        if len(calls) == 2:
            content = "Hello, traveler. How can I help?"
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
                request_id="internal-retrieval-status-retry",
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

    assert result.reply_text == "Hello, traveler. How can I help?"
    assert len(calls) == 2
    assert "上次输出不合格" in calls[1]["messages"][0]["content"]


def test_text_compatibility_mode_retries_unhelpful_greeting_deferral(monkeypatch):
    calls = []

    async def fake_post(_settings, _path, payload):
        calls.append(payload)
        content = "Hello. I need a moment before I can answer."
        if len(calls) == 2:
            content = "Hello, traveler. Welcome to my shop."
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
                request_id="unhelpful-greeting-retry",
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

    assert result.reply_text == "Hello, traveler. Welcome to my shop."
    assert len(calls) == 2
    assert "这是简单问候" in calls[0]["messages"][0]["content"]


def test_text_compatibility_mode_retries_repetition_and_language_mismatch(monkeypatch):
    calls = []

    async def fake_post(_settings, _path, payload):
        calls.append(payload)
        content = (
            "Warm, traveler, I see see understands what you find find find like. "
            "I can show show trade if if if if."
        )
        if len(calls) == 2:
            content = (
                "\u597d\u7684\uff0c\u6211\u4f1a\u8bb0\u4f4f\u4f60\u559c\u6b22\u84dd\u8272\u3002"
            )
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
                request_id="repetition-retry",
                player_profile_id="player",
                world_save_id="save",
                npc_definition_id="mira",
                npc_persistent_id="mira-1",
                session_id="session",
                text="\u6211\u559c\u6b22\u84dd\u8272\uff0c\u8bf7\u8bb0\u4f4f\u3002",
                npc_profile={"display_name": "Mira"},
            )
        )
    )

    assert (
        result.reply_text
        == "\u597d\u7684\uff0c\u6211\u4f1a\u8bb0\u4f4f\u4f60\u559c\u6b22\u84dd\u8272\u3002"
    )
    assert len(calls) == 2
    assert calls[1]["temperature"] == 0.0
    assert "frequency_penalty" not in calls[1]
    assert "上次输出不合格" in calls[1]["messages"][0]["content"]
    assert "玩家使用简体中文" in calls[1]["messages"][0]["content"]
    assert "玩家要求记住关于玩家的信息" in calls[1]["messages"][0]["content"]


def test_text_compatibility_mode_uses_third_quality_attempt(monkeypatch):
    calls = []

    async def fake_post(_settings, _path, payload):
        calls.append(payload)
        content = "trade trade trade trade"
        if len(calls) == 3:
            content = "Stay alert and keep your supplies close."
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
                request_id="third-quality-attempt",
                player_profile_id="player",
                world_save_id="save",
                npc_definition_id="bandit",
                npc_persistent_id="bandit-1",
                session_id="session",
                text="What should I know?",
                npc_profile={"display_name": "Bandit"},
            )
        )
    )

    assert result.reply_text == "Stay alert and keep your supplies close."
    assert [call["temperature"] for call in calls] == [0.0, 0.0, 0.0]


@pytest.mark.parametrize(
    ("player_text", "reply"),
    [
        ("\u6211\u53ef\u4ee5\u770b\u770b\u5417\uff1f", "\u5f53\u7136\uff0c\u53ef\u4ee5\u6162\u6162\u770b\u770b\u3002"),
    ],
)
def test_text_validation_allows_natural_doubled_words(player_text, reply):
    raw = {"choices": [{"message": {"content": reply}}]}

    assert _validated_text_reply(raw, player_text, "Mira") == reply


def test_text_validation_allows_two_expressive_punctuation_marks():
    reply = "Hello?! I did not expect you so early!"
    raw = {"choices": [{"message": {"content": reply}}]}

    assert _validated_text_reply(raw, "Hello", "Mira") == reply


def test_text_profile_context_is_compact_and_keeps_all_authored_categories():
    context = _text_profile_context(
        {
            "definition_id": "mira",
            "display_name": "Mira",
            "identity": {
                "public_description": "A friendly town merchant.",
                "occupation": "merchant",
                "social_role": "town_merchant",
                "languages": ["common"],
            },
            "personality": {"empathy": 0.82, "honesty": 0.86, "greed": 0.25},
            "speech_style": {
                "dialect_notes": "Warm, practical, and concise.",
                "sentence_length": "medium",
                "preferred_terms": ["traveler"],
            },
            "biography": ["Mira learned the merchant trade from her family."],
            "goals": [{"id": "serve_town", "description": "Protect the town."}],
            "cognitive_skills": [
                {"id": "trade", "display_name": "Trade Appraisal", "proficiency": 0.8}
            ],
            "knowledge_seeds": [{"content": "Mira works in town."}],
            "belief_seeds": [{"content": "Fair trade matters."}],
            "memory_policy": {
                "default_half_life_hours": 336.0,
                "high_salience_half_life_hours": 17520.0,
                "recent_turn_limit": 8,
                "retrieval_limit": 10,
            },
            "values": ["fair_trade"],
            "taboos": ["betray_customer_confidence"],
            "response_constraints": ["Do not invent stock."],
            "system_prompt_addendum": "Admit uncertainty.",
        }
    )

    for label in (
        "Profile ID: mira",
        "Name: Mira",
        "Identity:",
        "Personality:",
        "Speech style:",
        "Biography:",
        "Goals:",
        "Cognitive skills:",
        "Knowledge:",
        "Beliefs:",
        "Memory policy:",
        "Safety rule:",
    ):
        assert label in context
    assert "{" not in context
    assert "[" not in context
    assert "languages common" not in context
    assert "preferred terms traveler" not in context
    assert len(context) < 1600


def test_text_compatibility_mode_projects_memory_without_raw_graph_for_small_models(
    monkeypatch,
):
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
                        "salience": 0.8,
                        "visibility": "private",
                    },
                    {
                        "summary": "The player routinely talked to this NPC.",
                        "source_type": "gameplay_event",
                        "salience": 0.55,
                    },
                ],
                retrieved_graph=[
                    {
                        "subject_node_id": "npc_instance:mira-1",
                        "predicate": "KNOWS_ABOUT",
                        "object_node_id": "concept:trade",
                        "confidence": 1.0,
                    },
                    {
                        "subject_node_id": "npc_instance:mira-1",
                        "predicate": "LIVES_IN",
                        "object_node_id": "region:base:town",
                        "confidence": 1.0,
                    },
                ],
            )
        )
    )

    assert '玩家以前说过："The player prefers blue."' in captured["user"]
    assert "routinely talked" not in captured["user"]
    assert "npc_instance:mira-1 KNOWS_ABOUT concept:trade" not in captured["user"]
    assert "LIVES_IN" not in captured["user"]
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

    assert '你亲眼经历过："The player attacked Mira."' in captured["user"]


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
        "Profile ID: mira",
        "Known relationships:\n- npc knows player",
        'Player message (quoted data): "hello"',
        "服务器相关事实：玩家喜欢蓝色。",
        "玩家现在说：你好",
        "只输出NPC台词。",
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


def test_text_compatibility_mode_rejects_cjk_language_mismatch():
    raw = {"choices": [{"message": {"content": "I will remember blue."}}]}

    with pytest.raises(RuntimeError, match="provider_reply_language_mismatch"):
        _validated_text_reply(
            raw,
            "\u6211\u559c\u6b22\u84dd\u8272\uff0c\u8bf7\u8bb0\u4f4f\u3002",
        )


def test_text_compatibility_mode_rejects_english_to_chinese_language_mismatch():
    raw = {"choices": [{"message": {"content": "当然，我可以帮助你。"}}]}

    with pytest.raises(RuntimeError, match="provider_reply_language_mismatch"):
        _validated_text_reply(raw, "Can you help me?")


def test_text_compatibility_mode_rejects_latin_dominant_mixed_chinese_reply():
    raw = {
        "choices": [
            {
                "message": {
                    "content": "Ah yes trusted colors blue. 我记得你偏爱的颜色蓝色。"
                }
            }
        ]
    }

    with pytest.raises(RuntimeError, match="provider_reply_language_mismatch"):
        _validated_text_reply(raw, "你还记得我偏爱的颜色吗？")


def test_text_compatibility_mode_rejects_speaker_label():
    raw = {"choices": [{"message": {"content": "Mira: I remember blue."}}]}

    with pytest.raises(RuntimeError, match="provider_speaker_label"):
        _validated_text_reply(raw, "Do you remember?", "Mira")


def test_text_compatibility_mode_rejects_bare_provider_role_label():
    raw = {
        "choices": [
            {
                "message": {
                    "content": "Hello there!\nassistant\nHow can I help you today?"
                }
            }
        ]
    }

    with pytest.raises(RuntimeError, match="provider_speaker_label"):
        _validated_text_reply(raw, "Hello", "Mira")


@pytest.mark.parametrize(
    "content",
    [
        "I can help you if",
        "I remember blue,",
        "好的，",
        "Stay alert....",
        "Welcome to town. M",
    ],
)
def test_text_compatibility_mode_rejects_incomplete_endings(content):
    raw = {"choices": [{"message": {"content": content}}]}

    with pytest.raises(RuntimeError, match="provider_incomplete_reply"):
        _validated_text_reply(raw)


def test_text_compatibility_mode_rejects_length_finish_reason():
    raw = {
        "choices": [
            {
                "message": {"content": "This sentence appears complete."},
                "finish_reason": "length",
            }
        ]
    }

    with pytest.raises(RuntimeError, match="provider_incomplete_reply"):
        _validated_text_reply(raw)


@pytest.mark.parametrize(
    "content",
    [
        "No, no, that is not what I meant.",
        "That is very very important.",
    ],
)
def test_text_compatibility_mode_allows_one_adjacent_duplicate(content):
    raw = {"choices": [{"message": {"content": content}}]}

    assert _validated_text_reply(raw) == content


def test_text_compatibility_mode_rejects_degenerate_adjacent_duplicates():
    raw = {"choices": [{"message": {"content": "Choose this or or or that."}}]}

    with pytest.raises(RuntimeError, match="provider_repetitive_reply"):
        _validated_text_reply(raw)


def test_text_compatibility_mode_normalizes_single_repeated_function_word():
    raw = {
        "choices": [
            {
                "message": {
                    "content": "I can help with supplies or or supplies you need."
                }
            }
        ]
    }

    assert (
        _validated_text_reply(raw)
        == "I can help with supplies or supplies you need."
    )


def test_text_compatibility_mode_preserves_title_cased_repeated_name():
    reply = "The band Duran Duran is known in town."
    raw = {"choices": [{"message": {"content": reply}}]}

    assert _validated_text_reply(raw, "Which band is playing?") == reply


def test_text_compatibility_mode_rejects_multiple_duplicate_word_pairs():
    raw = {
        "choices": [
            {"message": {"content": "I am here here and can offer offer help."}}
        ]
    }

    with pytest.raises(RuntimeError, match="provider_repetitive_reply"):
        _validated_text_reply(raw)


@pytest.mark.parametrize(
    ("player_text", "reply"),
    [
        ("Do you remember where the key is?", "I don't remember where I put that key."),
        ("你还记得那件事吗？", "我不记得你以前告诉过我这件事。"),
    ],
)
def test_text_compatibility_mode_allows_natural_memory_uncertainty(player_text, reply):
    raw = {"choices": [{"message": {"content": reply}}]}

    assert _validated_text_reply(raw, player_text) == reply


def test_text_compatibility_mode_allows_deferral_for_non_greeting_question():
    reply = "I need more time to answer that difficult question."
    raw = {"choices": [{"message": {"content": reply}}]}

    assert _validated_text_reply(raw, "Explain the origin of the universe.") == reply


@pytest.mark.parametrize(
    "content",
    [
        "No memories were retrieved.",
        "Memory retrieval returned no results.",
        "没有检索到相关记忆。",
        "记忆检索没有结果。",
    ],
)
def test_text_compatibility_mode_rejects_internal_retrieval_status(content):
    raw = {"choices": [{"message": {"content": content}}]}

    with pytest.raises(RuntimeError, match="provider_internal_retrieval_status"):
        _validated_text_reply(raw)


def test_text_memory_context_scans_past_filtered_low_salience_items():
    low_salience = [
        {
            "summary": f"Routine observation {index}",
            "source_type": "gameplay_event",
            "salience": 0.55,
        }
        for index in range(4)
    ]
    important = {
        "summary": "The player prefers blue.",
        "source_type": "conversation_turn",
        "salience": 0.8,
    }

    context = _text_memory_context([*low_salience, important])

    assert "The player prefers blue." in context
    assert "Routine observation" not in context


@pytest.mark.parametrize(
    "content",
    [
        "hello there,,, I can help.",
        "Hello there,! I can help.",
        "I have GOODS AND SUPPLIES READY FOR EVERY TRAVELER today.",
    ],
)
def test_text_compatibility_mode_rejects_garbled_text(content):
    raw = {"choices": [{"message": {"content": content}}]}

    with pytest.raises(RuntimeError, match="provider_garbled_reply"):
        _validated_text_reply(raw)


def test_text_compatibility_mode_extracts_explicit_private_memory_server_side(
    monkeypatch,
):
    async def fake_post(_settings, _path, _payload):
        return {
            "choices": [
                {
                    "message": {
                        "content": "\u597d\u7684\uff0c\u6211\u4f1a\u8bb0\u4f4f\u4f60\u559c\u6b22\u84dd\u8272\u3002"
                    }
                }
            ]
        }

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

    assert (
        result.reply_text
        == "\u597d\u7684\uff0c\u6211\u4f1a\u8bb0\u4f4f\u4f60\u559c\u6b22\u84dd\u8272\u3002"
    )
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
