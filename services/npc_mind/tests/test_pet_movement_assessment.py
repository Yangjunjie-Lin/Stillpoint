import asyncio
import json

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

import app.pet_movement as pet_movement
import app.service as service_module
from app.auth import SessionTokenService
from app.config import Settings
from app.main import create_app
from app.pet_movement import (
    OpenAIPetMovementAssessmentProvider,
    PetMovementProviderError,
    PetMovementProviderOutcome,
    _movement_profile_projection,
    deterministic_pet_movement_result,
)
from app.repository import InMemoryRepository
from app.schemas import (
    PetMovementAssessmentRequest,
    PetMovementProviderRequest,
    PetMovementProviderResult,
)
from app.service import NpcCognitionService


SETTINGS = Settings(app_env="test", npc_mind_signing_key="pet-motion-signing-key")
PET_DEFINITION = "pet:mossfox"
PET_INSTANCE = "base:player/pet/mossfox_0001"


def _request(**updates: object) -> PetMovementAssessmentRequest:
    values: dict[str, object] = {
        "request_id": "motion-1",
        "player_profile_id": "player",
        "world_save_id": "save",
        "pet_definition_id": PET_DEFINITION,
        "pet_persistent_id": PET_INSTANCE,
        "individual_traits": {
            "curiosity": 0.82,
            "playfulness": 0.71,
            "sociability": 0.66,
            "independence": 0.58,
            "courage": 0.61,
            "patience": 0.43,
            "energy": 0.77,
        },
        "mood_band": "happy",
        "region_type": "town",
        "region_tags": ["safe", "farmland"],
        "lifestyle_id": "forager",
        "context_revision": 7,
    }
    values.update(updates)
    return PetMovementAssessmentRequest.model_validate(values)


def _text_settings(**updates: object) -> Settings:
    values: dict[str, object] = {
        "app_env": "test",
        "npc_mind_signing_key": "pet-motion-signing-key",
        "llm_provider": "openai",
        "embedding_provider": "fake",
        "openai_api_key": "test-only-key",
        "openai_text_model": "Qwen/Qwen2.5-7B-Instruct",
        "openai_response_format": "text",
        "provider_retries": 0,
    }
    values.update(updates)
    return Settings(**values)


def _trusted_request() -> PetMovementProviderRequest:
    service = NpcCognitionService(settings=SETTINGS, repository=InMemoryRepository())
    request = _request()
    return PetMovementProviderRequest(
        **request.model_dump(mode="python"),
        pet_profile=service.catalog.get_profile(PET_DEFINITION).payload,
    )


def _text_response(content: str, prompt_tokens: int, completion_tokens: int) -> dict:
    return {
        "choices": [{"message": {"content": content}}],
        "usage": {
            "prompt_tokens": prompt_tokens,
            "completion_tokens": completion_tokens,
        },
    }


class CapturingMovementProvider:
    def __init__(self, result: object | None = None, *, fail: bool = False) -> None:
        self.requests: list[PetMovementProviderRequest] = []
        self.result = result or {
            "motif_weights": {
                "idle_near_anchor": 0.2,
                "follow_owner": 0.4,
                "curious_explore": 0.9,
                "playful_loop": 0.7,
                "social_approach": 0.3,
                "cautious_patrol": 0.1,
                "perch_observe": 0.05,
                "rest_sheltered": 0.15,
            },
            "pace": 0.78,
            "roam": 0.74,
            "confidence": 0.86,
        }
        self.fail = fail

    async def assess_pet_movement(
        self, request: PetMovementProviderRequest
    ) -> object:
        self.requests.append(request)
        if self.fail:
            raise TimeoutError("sensitive-provider-message-must-not-escape")
        return self.result


def _repository_snapshot(repository: InMemoryRepository) -> str:
    return json.dumps(
        {
            "sessions": sorted(repository.sessions),
            "memories": sorted(repository.memories),
            "nodes": sorted(repository.graph.nodes),
            "edges": sorted(repository.graph.edges),
            "responses": sorted(str(key) for key in repository.idempotent_responses),
            "usage": repository.usage,
            "usage_records": repository.usage_records,
            "deployments": sorted(repository.profile_deployments),
            "outbox": sorted(repository.outbox_receipts),
            "revisions": sorted((str(key), value) for key, value in repository.sync_revisions.items()),
            "conflicts": repository.conflicts,
        },
        sort_keys=True,
        default=str,
    )


def _cognition_snapshot(repository: InMemoryRepository) -> str:
    """Exclude the dedicated response cache and provider billing ledger."""

    return json.dumps(
        {
            "sessions": sorted(repository.sessions),
            "memories": sorted(repository.memories),
            "nodes": sorted(repository.graph.nodes),
            "edges": sorted(repository.graph.edges),
            "deployments": sorted(repository.profile_deployments),
            "outbox": sorted(repository.outbox_receipts),
            "revisions": sorted(
                (str(key), value) for key, value in repository.sync_revisions.items()
            ),
            "conflicts": repository.conflicts,
        },
        sort_keys=True,
        default=str,
    )


def test_assessment_injects_server_profile_and_writes_only_cache_and_usage() -> None:
    repository = InMemoryRepository()
    provider = CapturingMovementProvider()
    service = NpcCognitionService(
        settings=SETTINGS,
        repository=repository,
        pet_movement_provider=provider,
    )
    before = _cognition_snapshot(repository)

    response = asyncio.run(service.assess_pet_movement(_request()))

    assert response.request_id == "motion-1"
    assert response.context_revision == 7
    assert response.assessment_id.startswith("pet-motion:")
    assert response.degraded is False
    trusted = provider.requests[0]
    assert trusted.pet_profile["definition_id"] == PET_DEFINITION
    assert trusted.pet_profile["display_name"] == "Pip"
    assert trusted.pet_profile["entity_kind"] == "pet"
    assert trusted.pet_profile["personality"]["curiosity"] == 0.9
    assert _cognition_snapshot(repository) == before
    assert len(repository.idempotent_responses) == 1
    assert len(repository.usage_records) == 1
    assert repository.usage_records[0]["request_id"].startswith("server:pet-motion:")


def test_request_id_revision_and_tag_order_cannot_bypass_context_cache() -> None:
    repository = InMemoryRepository()
    provider = CapturingMovementProvider()
    service = NpcCognitionService(
        settings=SETTINGS,
        repository=repository,
        pet_movement_provider=provider,
    )

    first = asyncio.run(service.assess_pet_movement(_request()))
    second = asyncio.run(
        service.assess_pet_movement(
            _request(
                request_id="attacker-controlled-retry",
                context_revision=2_147_483_647,
                region_tags=["farmland", "safe", "safe"],
            )
        )
    )

    assert len(provider.requests) == 1
    assert len(repository.idempotent_responses) == 1
    assert len(repository.usage_records) == 1
    assert second.request_id == "attacker-controlled-retry"
    assert second.context_revision == 2_147_483_647
    assert second.assessment_id == first.assessment_id
    assert second.motif_weights == first.motif_weights


def test_concurrent_same_context_requests_coalesce_to_one_provider_call() -> None:
    repository = InMemoryRepository()
    provider = CapturingMovementProvider()
    service = NpcCognitionService(
        settings=SETTINGS,
        repository=repository,
        pet_movement_provider=provider,
    )

    async def exercise() -> list:
        return await asyncio.gather(
            *(
                service.assess_pet_movement(
                    _request(request_id=f"parallel-{index}", context_revision=index)
                )
                for index in range(8)
            )
        )

    results = asyncio.run(exercise())

    assert len(provider.requests) == 1
    assert len(repository.usage_records) == 1
    assert len({result.assessment_id for result in results}) == 1
    assert [result.request_id for result in results] == [
        f"parallel-{index}" for index in range(8)
    ]


def test_changed_context_is_locally_degraded_during_per_pet_cooldown(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    now = [10_000.0]
    monkeypatch.setattr(service_module.time, "time", lambda: now[0])
    provider = CapturingMovementProvider()
    service = NpcCognitionService(
        settings=Settings(
            app_env="test",
            npc_mind_signing_key="pet-motion-signing-key",
            pet_movement_assessment_cooldown_seconds=60,
        ),
        repository=InMemoryRepository(),
        pet_movement_provider=provider,
    )

    first = asyncio.run(service.assess_pet_movement(_request()))
    changed_request = _request(
        request_id="motion-new-mood",
        mood_band="anxious",
        context_revision=8,
    )
    during_cooldown = asyncio.run(service.assess_pet_movement(changed_request))
    repeated = asyncio.run(
        service.assess_pet_movement(
            changed_request.model_copy(update={"request_id": "motion-new-mood-retry"})
        )
    )

    assert first.degraded is False
    assert during_cooldown.degraded is True
    assert during_cooldown.reason == "assessment_cooldown"
    assert repeated.reason == "assessment_cooldown"
    assert repeated.request_id == "motion-new-mood-retry"
    assert len(provider.requests) == 1

    now[0] += 61.0
    after_cooldown = asyncio.run(service.assess_pet_movement(changed_request))
    assert after_cooldown.degraded is False
    assert len(provider.requests) == 2


def test_daily_budget_is_checked_before_paid_movement_provider() -> None:
    repository = InMemoryRepository()
    repository.record_usage("player", "save", PET_INSTANCE, "earlier", {}, 1.0)
    provider = CapturingMovementProvider()
    service = NpcCognitionService(
        settings=Settings(
            app_env="test",
            npc_mind_signing_key="pet-motion-signing-key",
            daily_budget_usd=1.0,
        ),
        repository=repository,
        pet_movement_provider=provider,
    )
    cognition_before = _cognition_snapshot(repository)

    result = asyncio.run(service.assess_pet_movement(_request()))

    assert result.degraded is True
    assert result.reason == "daily_budget_exceeded"
    assert provider.requests == []
    assert len(repository.usage_records) == 1
    assert _cognition_snapshot(repository) == cognition_before


def test_successful_provider_usage_is_counted_once_and_never_underestimated() -> None:
    repository = InMemoryRepository()
    base_provider = CapturingMovementProvider()

    class MeteredProvider:
        def __init__(self) -> None:
            self.calls = 0

        async def assess_pet_movement(
            self, request: PetMovementProviderRequest
        ) -> PetMovementProviderOutcome:
            self.calls += 1
            result = PetMovementProviderResult.model_validate(base_provider.result)
            return PetMovementProviderOutcome(
                result=result,
                usage={"input_tokens": 1, "output_tokens": 1},
            )

    provider = MeteredProvider()
    settings = Settings(
        app_env="test",
        npc_mind_signing_key="pet-motion-signing-key",
        estimated_cost_per_1k_tokens_usd=0.01,
    )
    service = NpcCognitionService(
        settings=settings,
        repository=repository,
        pet_movement_provider=provider,
    )

    asyncio.run(service.assess_pet_movement(_request()))
    asyncio.run(
        service.assess_pet_movement(
            _request(request_id="usage-retry", context_revision=999)
        )
    )

    assert provider.calls == 1
    assert len(repository.usage_records) == 1
    usage = repository.usage_records[0]["usage"]
    assert usage["input_tokens"] > 1
    assert usage["output_tokens"] > 1
    assert repository.usage_records[0]["cost_usd"] > 0.0


def test_provider_failure_is_metered_once_and_cached_without_cognition_writes() -> None:
    repository = InMemoryRepository()
    provider = CapturingMovementProvider(fail=True)
    service = NpcCognitionService(
        settings=SETTINGS,
        repository=repository,
        pet_movement_provider=provider,
    )
    before = _cognition_snapshot(repository)

    first = asyncio.run(service.assess_pet_movement(_request()))
    second = asyncio.run(
        service.assess_pet_movement(
            _request(request_id="failed-retry", context_revision=99)
        )
    )

    assert first.reason == "provider_unavailable"
    assert second.reason == "provider_unavailable"
    assert len(provider.requests) == 1
    assert len(repository.usage_records) == 1
    assert repository.usage_records[0]["cost_usd"] > 0.0
    assert repository.idempotent_responses == {}
    assert _cognition_snapshot(repository) == before


def test_different_species_and_mood_produce_distinct_deterministic_tendencies() -> None:
    repository = InMemoryRepository()
    service = NpcCognitionService(settings=SETTINGS, repository=repository)
    happy_fox = asyncio.run(service.assess_pet_movement(_request()))
    anxious_hound = asyncio.run(
        service.assess_pet_movement(
            _request(
                request_id="motion-hound",
                pet_definition_id="pet:stonehound",
                pet_persistent_id="base:player/pet/stonehound_0001",
                mood_band="anxious",
                lifestyle_id="guardian",
                region_type="dungeon",
                region_tags=["dungeon", "threshold"],
                context_revision=8,
            )
        )
    )

    assert happy_fox.motif_weights.playful_loop > anxious_hound.motif_weights.playful_loop
    assert (
        anxious_hound.motif_weights.cautious_patrol
        > happy_fox.motif_weights.cautious_patrol
    )
    assert happy_fox.roam != anxious_hound.roam
    assert repository.usage_records == []


def test_public_request_and_provider_result_forbid_extra_fields() -> None:
    payload = _request().model_dump(mode="json")
    payload["pet_profile"] = {"display_name": "Forged"}
    with pytest.raises(ValidationError, match="extra_forbidden"):
        PetMovementAssessmentRequest.model_validate(payload)

    with pytest.raises(ValidationError, match="extra_forbidden"):
        PetMovementProviderResult.model_validate(
            {
                "motif_weights": {
                    "idle_near_anchor": 0.2,
                    "follow_owner": 0.2,
                    "curious_explore": 0.2,
                    "playful_loop": 0.2,
                    "social_approach": 0.2,
                    "cautious_patrol": 0.2,
                    "perch_observe": 0.2,
                    "rest_sheltered": 0.2,
                    "move_to_coordinates": 1.0,
                },
                "pace": 0.5,
                "roam": 0.5,
                "confidence": 0.5,
                "target_id": "player",
            }
        )


@pytest.mark.parametrize(
    "provider",
    [
        CapturingMovementProvider(
            {
                "motif_weights": {"curious_explore": 5.0},
                "pace": 4.0,
                "roam": -2.0,
                "confidence": 0.7,
                "coordinates": [1, 2, 3],
            }
        ),
        CapturingMovementProvider(fail=True),
    ],
)
def test_invalid_or_failed_provider_uses_deterministic_read_only_fallback(
    provider: CapturingMovementProvider,
) -> None:
    repository = InMemoryRepository()
    service = NpcCognitionService(
        settings=SETTINGS,
        repository=repository,
        pet_movement_provider=provider,
    )
    before = _repository_snapshot(repository)
    request = _request()

    first = asyncio.run(service.assess_pet_movement(request))
    second = asyncio.run(service.assess_pet_movement(request))

    assert first == second
    assert first.degraded is True
    assert first.reason == "provider_unavailable"
    assert first.confidence == 0.45
    assert 0.0 <= first.pace <= 1.0
    assert 0.0 <= first.roam <= 1.0
    assert all(
        0.0 <= value <= 1.0
        for value in first.motif_weights.model_dump().values()
    )
    assert _cognition_snapshot(repository) == _cognition_snapshot(
        InMemoryRepository()
    )
    assert len(repository.usage_records) == 1
    assert repository.usage_records[0]["request_id"].startswith(
        "server:pet-motion-attempt:"
    )
    assert _repository_snapshot(repository) != before


def test_non_pet_and_existing_instance_definition_mismatch_are_rejected() -> None:
    repository = InMemoryRepository()
    service = NpcCognitionService(settings=SETTINGS, repository=repository)

    with pytest.raises(ValueError, match="entity_kind_mismatch"):
        asyncio.run(
            service.assess_pet_movement(_request(pet_definition_id="mira"))
        )

    repository.deploy_profile(
        service.catalog.get_profile("pet:stonehound"),
        "player",
        "save",
        PET_INSTANCE,
    )
    with pytest.raises(ValueError, match="pet_definition_scope_mismatch"):
        asyncio.run(service.assess_pet_movement(_request()))


def test_authenticated_route_preserves_revision_and_rejects_extra_input() -> None:
    repository = InMemoryRepository()
    provider = CapturingMovementProvider()
    service = NpcCognitionService(
        settings=SETTINGS,
        repository=repository,
        pet_movement_provider=provider,
    )
    client = TestClient(create_app(service))
    token, _ = SessionTokenService(SETTINGS).issue(
        "player", "save", "install-1234"
    )
    headers = {
        "Authorization": f"Bearer {token}",
        "X-Client-Install-ID": "install-1234",
    }
    payload = _request().model_dump(mode="json")

    response = client.post(
        "/v1/pets/movement-assessments", headers=headers, json=payload
    )
    assert response.status_code == 200
    assert response.json()["request_id"] == "motion-1"
    assert response.json()["context_revision"] == 7
    assert set(response.json()["motif_weights"]) == {
        "idle_near_anchor",
        "follow_owner",
        "curious_explore",
        "playful_loop",
        "social_approach",
        "cautious_patrol",
        "perch_observe",
        "rest_sheltered",
    }

    payload["coordinates"] = [1, 2, 3]
    assert (
        client.post(
            "/v1/pets/movement-assessments", headers=headers, json=payload
        ).status_code
        == 422
    )
    assert (
        client.post(
            "/v1/pets/movement-assessments",
            headers=headers,
            json={**_request().model_dump(mode="json"), "player_profile_id": "other"},
        ).status_code
        == 403
    )


def test_openai_provider_sends_server_profile_and_accepts_only_allowlisted_result(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    captured: dict = {}

    async def fake_post(settings: Settings, path: str, payload: dict) -> dict:
        del settings
        captured.update({"path": path, "payload": payload})
        return {
            "choices": [
                {
                    "message": {
                        "content": json.dumps(
                            {
                                "motif_weights": {
                                    "idle_near_anchor": 0.1,
                                    "follow_owner": 0.2,
                                    "curious_explore": 0.8,
                                    "playful_loop": 0.6,
                                    "social_approach": 0.3,
                                    "cautious_patrol": 0.2,
                                    "perch_observe": 0.1,
                                    "rest_sheltered": 0.1,
                                },
                                "pace": 0.7,
                                "roam": 0.8,
                                "confidence": 0.9,
                            }
                        )
                    }
                }
            ]
        }

    monkeypatch.setattr(pet_movement, "_post_openai", fake_post)
    settings = Settings(
        app_env="test",
        npc_mind_signing_key="pet-motion-signing-key",
        llm_provider="openai",
        embedding_provider="fake",
        openai_api_key="test-only-key",
        openai_text_model="test-model",
    )
    service = NpcCognitionService(settings=settings, repository=InMemoryRepository())

    result = asyncio.run(service.assess_pet_movement(_request()))

    assert result.degraded is False
    assert captured["path"] == "/v1/chat/completions"
    prompt = captured["payload"]["messages"][1]["content"]
    assert '"definition_id": "pet:mossfox"' in prompt
    assert '"display_name": "Pip"' in prompt
    assert "coordinates" not in json.dumps(result.model_dump())
    assert "target" not in json.dumps(result.model_dump())


def test_text_provider_accepts_exact_chinese_allowlist_and_projects_server_profile(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    captured: list[dict] = []

    async def fake_post(settings: Settings, path: str, payload: dict) -> dict:
        del settings, path
        captured.append(payload)
        return _text_response("动作=探索;节奏=快;范围=远", 31, 9)

    monkeypatch.setattr(pet_movement, "_post_openai", fake_post)
    request = _trusted_request()
    baseline = deterministic_pet_movement_result(request)
    provider = OpenAIPetMovementAssessmentProvider(_text_settings())

    outcome = asyncio.run(provider.assess_pet_movement(request))

    assert len(captured) == 1
    assert "response_format" not in captured[0]
    assert outcome.usage == {"input_tokens": 31, "output_tokens": 9}
    assert outcome.result.motif_weights.curious_explore > (
        baseline.motif_weights.curious_explore
    )
    for motif, value in baseline.motif_weights.model_dump().items():
        if motif != "curious_explore":
            assert getattr(outcome.result.motif_weights, motif) == value
    assert outcome.result.pace == 0.82
    assert outcome.result.roam == 0.80
    assert outcome.result.confidence == 0.58
    user_prompt = captured[0]["messages"][1]["content"]
    assert '"definition_id":"pet:mossfox"' in user_prompt
    assert '"display_name":"Pip"' in user_prompt
    assert '"personality"' in user_prompt
    assert '"id":"mossfox"' in user_prompt
    assert '"habitat_tags":["farmland","wilderness","home"]' in user_prompt
    assert _movement_profile_projection(request.pet_profile)["definition_id"] == (
        PET_DEFINITION
    )


def test_text_provider_accepts_only_terminal_chinese_sentence_mark(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    async def fake_post(settings: Settings, path: str, payload: dict) -> dict:
        del settings, path, payload
        return _text_response("动作=观察;节奏=中;范围=近。", 12, 4)

    monkeypatch.setattr(pet_movement, "_post_openai", fake_post)
    outcome = asyncio.run(
        OpenAIPetMovementAssessmentProvider(_text_settings()).assess_pet_movement(
            _trusted_request()
        )
    )

    assert outcome.result.motif_weights.perch_observe > 0.0
    assert outcome.result.pace == 0.55
    assert outcome.result.roam == 0.24


def test_text_provider_retries_once_after_invalid_output_and_aggregates_usage(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls: list[dict] = []
    responses = [
        _text_response("我建议它探索。", 20, 5),
        _text_response("动作=巡逻;节奏=中;范围=近", 24, 7),
    ]

    async def fake_post(settings: Settings, path: str, payload: dict) -> dict:
        del settings, path
        calls.append(payload)
        return responses[len(calls) - 1]

    monkeypatch.setattr(pet_movement, "_post_openai", fake_post)
    outcome = asyncio.run(
        OpenAIPetMovementAssessmentProvider(_text_settings()).assess_pet_movement(
            _trusted_request()
        )
    )

    assert len(calls) == 2
    assert outcome.usage == {"input_tokens": 44, "output_tokens": 12}
    assert outcome.result.pace == 0.55
    assert outcome.result.roam == 0.24
    assert "上次输出不合规" in calls[1]["messages"][0]["content"]


@pytest.mark.parametrize(
    "invalid",
    [
        "动作=探索;节奏=快;范围=远\n",
        "动作=探索;节奏=快;范围=远;坐标=1,2,3",
        "动作=探索;节奏=快;范围=远;攻击=玩家",
        "先移动，然后动作=探索;节奏=快;范围=远",
        "动作=奔跑;节奏=快;范围=远",
        '{"动作":"探索","节奏":"快","范围":"远"}',
    ],
)
def test_text_provider_rejects_extra_text_fields_coordinates_and_actions(
    monkeypatch: pytest.MonkeyPatch,
    invalid: str,
) -> None:
    calls = 0

    async def fake_post(settings: Settings, path: str, payload: dict) -> dict:
        nonlocal calls
        del settings, path, payload
        calls += 1
        return _text_response(invalid, 11, 3)

    monkeypatch.setattr(pet_movement, "_post_openai", fake_post)
    with pytest.raises(
        PetMovementProviderError, match="invalid_pet_movement_assessment"
    ) as caught:
        asyncio.run(
            OpenAIPetMovementAssessmentProvider(
                _text_settings()
            ).assess_pet_movement(_trusted_request())
        )
    assert calls == 2
    assert caught.value.usage == {"input_tokens": 22, "output_tokens": 6}


@pytest.mark.parametrize(
    ("action", "motif"),
    [
        ("守候", "idle_near_anchor"),
        ("跟随", "follow_owner"),
        ("探索", "curious_explore"),
        ("玩耍", "playful_loop"),
        ("亲近", "social_approach"),
        ("巡逻", "cautious_patrol"),
        ("观察", "perch_observe"),
        ("休息", "rest_sheltered"),
    ],
)
def test_text_actions_map_to_distinct_allowlisted_motifs(
    monkeypatch: pytest.MonkeyPatch,
    action: str,
    motif: str,
) -> None:
    async def fake_post(settings: Settings, path: str, payload: dict) -> dict:
        del settings, path, payload
        return _text_response(f"动作={action};节奏=慢;范围=中", 10, 4)

    monkeypatch.setattr(pet_movement, "_post_openai", fake_post)
    request = _trusted_request()
    baseline = deterministic_pet_movement_result(request)
    outcome = asyncio.run(
        OpenAIPetMovementAssessmentProvider(_text_settings()).assess_pet_movement(
            request
        )
    )
    assert getattr(outcome.result.motif_weights, motif) > getattr(
        baseline.motif_weights, motif
    )


def test_text_service_failure_falls_back_and_records_two_attempt_usage(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls = 0

    async def fake_post(settings: Settings, path: str, payload: dict) -> dict:
        nonlocal calls
        del settings, path, payload
        calls += 1
        return _text_response("动作=传送;节奏=快;范围=远", 17, 4)

    monkeypatch.setattr(pet_movement, "_post_openai", fake_post)
    repository = InMemoryRepository()
    service = NpcCognitionService(
        settings=_text_settings(), repository=repository
    )

    result = asyncio.run(service.assess_pet_movement(_request()))

    assert calls == 2
    assert result.degraded is True
    assert result.reason == "provider_unavailable"
    assert len(repository.usage_records) == 1
    assert repository.usage_records[0]["usage"] == {
        "input_tokens": 34,
        "output_tokens": 8,
    }


def test_text_service_successful_retry_records_aggregated_usage(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls = 0
    responses = [
        _text_response("invalid", 1500, 100),
        _text_response("动作=观察;节奏=中;范围=中", 1500, 100),
    ]

    async def fake_post(settings: Settings, path: str, payload: dict) -> dict:
        nonlocal calls
        del settings, path, payload
        response = responses[calls]
        calls += 1
        return response

    monkeypatch.setattr(pet_movement, "_post_openai", fake_post)
    repository = InMemoryRepository()
    service = NpcCognitionService(
        settings=_text_settings(), repository=repository
    )

    result = asyncio.run(service.assess_pet_movement(_request()))

    assert calls == 2
    assert result.degraded is False
    assert len(repository.usage_records) == 1
    assert repository.usage_records[0]["usage"] == {
        "input_tokens": 3000,
        "output_tokens": 200,
    }


def test_text_service_budget_reserves_two_calls_before_provider(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls = 0

    async def fake_post(settings: Settings, path: str, payload: dict) -> dict:
        nonlocal calls
        del settings, path, payload
        calls += 1
        return _text_response("动作=守候;节奏=慢;范围=近", 5, 2)

    monkeypatch.setattr(pet_movement, "_post_openai", fake_post)
    repository = InMemoryRepository()
    # One text call fits, while the required two-call correction envelope does not.
    settings = _text_settings(
        estimated_cost_per_1k_tokens_usd=1.0,
        daily_budget_usd=3.0,
    )
    service = NpcCognitionService(settings=settings, repository=repository)

    result = asyncio.run(service.assess_pet_movement(_request()))

    assert calls == 0
    assert result.degraded is True
    assert result.reason == "daily_budget_exceeded"
