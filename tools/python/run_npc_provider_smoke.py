"""Run a low-cost real OpenAI provider smoke without logging content or credentials."""

from __future__ import annotations

import asyncio
import contextlib
import io
import json
import logging
import os
import subprocess
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlsplit

import psycopg

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "artifacts" / "npc-provider-smoke.json"
sys.path.insert(0, str(ROOT / "services" / "npc_mind"))

from app.catalog import NpcCatalogRepository  # noqa: E402
from app.config import Settings  # noqa: E402
from app.memory import MemoryRecord, vector_similarity  # noqa: E402
from app.providers import (  # noqa: E402
    OpenAIEmbeddingProvider,
    OpenAILlmProvider,
    _GENERATION_CONTRACT_FIELDS,
    _prompt_profile,
)
from app.repository import InMemoryRepository, PostgresCognitionRepository  # noqa: E402
from app.schemas import NpcGenerationRequest, NpcGenerationResult  # noqa: E402
from app.service import SAFE_FALLBACK, NpcCognitionService  # noqa: E402


_REQUIRED_PROFILE_FIELDS = {
    "identity",
    "personality",
    "speech_style",
    "biography",
    "goals",
    "cognitive_skills",
    "knowledge",
    "beliefs",
    "memory_policy",
}


class _CapturingLlm:
    """Keep non-sensitive request objects in memory while delegating real calls."""

    def __init__(self, delegate: OpenAILlmProvider) -> None:
        self.delegate = delegate
        self.requests: list[NpcGenerationRequest] = []
        self.results: list[NpcGenerationResult] = []

    async def generate_npc_reply(
        self, request: NpcGenerationRequest
    ) -> NpcGenerationResult:
        self.requests.append(request)
        result = await self.delegate.generate_npc_reply(request)
        self.results.append(result)
        return result


class _StaticEmbedding:
    async def embed(self, texts: list[str]) -> list[list[float]]:
        return [[1.0] + [0.0] * 1535 for _text in texts]


class _ForcedFailureLlm:
    async def generate_npc_reply(
        self, request: NpcGenerationRequest
    ) -> NpcGenerationResult:
        raise TimeoutError("provider_timeout")


def _required(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"missing_{name.lower()}")
    return value


def _request(
    definition: str,
    *,
    request_id: str | None = None,
    text: str = "Greet a traveler in one short sentence while staying in character.",
    client_profile: dict | None = None,
    player_profile_id: str = "provider-smoke-player",
    world_save_id: str = "provider-smoke-save",
    npc_persistent_id: str | None = None,
    session_id: str | None = None,
) -> NpcGenerationRequest:
    return NpcGenerationRequest(
        request_id=request_id or f"provider-smoke-{definition}",
        player_profile_id=player_profile_id,
        world_save_id=world_save_id,
        npc_definition_id=definition,
        npc_persistent_id=npc_persistent_id or f"provider-smoke-{definition}",
        session_id=session_id or f"provider-smoke-{definition}-session",
        text=text,
        npc_profile=client_profile
        or {
            "display_name": "CLIENT OVERRIDE MUST BE DISCARDED",
            "identity": {"canonical_name": "CLIENT OVERRIDE"},
        },
        allow_conversation_storage=False,
        allow_memory_personalization=False,
    )


def _assert_generation_contract(result: NpcGenerationResult) -> None:
    if (
        set(result.model_dump()) != _GENERATION_CONTRACT_FIELDS
        or not result.reply_text.strip()
    ):
        raise RuntimeError("structured_output_contract_mismatch")


def _assert_profile_injection(request: NpcGenerationRequest, expected: dict) -> None:
    if request.npc_profile != expected:
        raise RuntimeError("server_profile_injection_mismatch")
    projected = _prompt_profile(request.npc_profile)
    if not _REQUIRED_PROFILE_FIELDS.issubset(projected):
        raise RuntimeError("server_profile_projection_incomplete")
    if "CLIENT OVERRIDE" in json.dumps(projected, ensure_ascii=False):
        raise RuntimeError("client_profile_override_accepted")


def _git_head() -> str:
    status = subprocess.run(
        ["git", "status", "--porcelain"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    if status.stdout.strip():
        raise RuntimeError("provider_smoke_requires_clean_worktree")
    completed = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return completed.stdout.strip()


def _assert_secret_hygiene(
    report: dict[str, object], runtime_output: str, secrets: list[str]
) -> None:
    inspected = json.dumps(report, ensure_ascii=False) + "\n" + runtime_output
    if any(secret and secret in inspected for secret in secrets):
        raise RuntimeError("secret_found_in_smoke_report")
    forbidden = (
        "OPENAI_API_KEY",
        "Authorization",
        "Bearer ",
        "NPC_MIND_SIGNING_KEY",
        "session_token",
        "database_url",
        "reply_text",
        "private_conversation",
        "The player says their favorite color is blue.",
        "What shade do I usually prefer?",
        "Greet a traveler in one short sentence",
        "[NPC_PROFILE",
        "Player message (quoted data)",
    )
    if any(marker.casefold() in inspected.casefold() for marker in forbidden):
        raise RuntimeError("private_content_marker_in_smoke_report")


async def _run() -> dict[str, object]:
    commit_sha = _git_head()
    api_key = _required("OPENAI_API_KEY")
    text_model = _required("OPENAI_TEXT_MODEL")
    embedding_model = _required("OPENAI_EMBEDDING_MODEL")
    base_url = os.getenv("OPENAI_BASE_URL", "https://api.openai.com").strip()
    parsed_base_url = urlsplit(base_url)
    if (
        parsed_base_url.scheme != "https"
        or (parsed_base_url.hostname or "").casefold() != "api.openai.com"
        or parsed_base_url.port not in {None, 443}
        or parsed_base_url.username
        or parsed_base_url.password
        or parsed_base_url.query
        or parsed_base_url.fragment
        or parsed_base_url.path.rstrip("/") not in {"", "/v1"}
    ):
        raise RuntimeError("provider_smoke_requires_real_openai_endpoint")
    response_format = os.getenv("OPENAI_RESPONSE_FORMAT", "json_schema").strip().lower()
    if response_format != "json_schema":
        raise RuntimeError("provider_smoke_requires_strict_json_schema")
    database_url = (
        os.getenv("NPC_PROVIDER_SMOKE_DATABASE_URL", "").strip()
        or os.getenv("DATABASE_URL", "").strip()
        or "postgresql://stillpoint:stillpoint@127.0.0.1:55432/stillpoint"
    )
    settings = Settings(
        app_env="test",
        npc_repository="in_memory",
        llm_provider="openai",
        embedding_provider="openai",
        openai_api_key=api_key,
        openai_base_url=base_url,
        openai_response_format=response_format,
        openai_text_model=text_model,
        openai_embedding_model=embedding_model,
        embedding_dimensions=1536,
        provider_retries=0,
        max_output_tokens=120,
    )
    settings.validate_embedding_configuration()
    settings.validate_provider_configuration()
    catalog = NpcCatalogRepository()
    real_llm = OpenAILlmProvider(settings)
    capturing_llm = _CapturingLlm(real_llm)
    embeddings = OpenAIEmbeddingProvider(settings)

    memory_text = "The player says their favorite color is blue."
    distractor_text = "A merchant opens the east gate at dawn."
    paraphrase = "What shade do I usually prefer?"
    vectors = await embeddings.embed([memory_text, distractor_text, paraphrase])
    if len(vectors) != 3 or any(len(vector) != 1536 for vector in vectors):
        raise RuntimeError("embedding_dimension_mismatch")
    with psycopg.connect(
        database_url.replace("postgresql+psycopg://", "postgresql://")
    ) as connection:
        database_type = connection.execute(
            "SELECT format_type(a.atttypid, a.atttypmod) "
            "FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid "
            "WHERE c.relname='npc_memories' AND a.attname='embedding' "
            "AND a.attnum > 0 AND NOT a.attisdropped"
        ).fetchone()
    if database_type is None or database_type[0] != "vector(1536)":
        raise RuntimeError("postgres_vector_dimension_mismatch")

    semantic_repository = InMemoryRepository()
    semantic_repository.add_memory(
        MemoryRecord(
            memory_id="provider-smoke-blue-memory",
            player_profile_id="provider-smoke-player",
            world_save_id="provider-smoke-save",
            owner_npc_persistent_id="provider-smoke-mira",
            session_id="provider-smoke-mira-session",
            memory_type="episodic",
            content=memory_text,
            summary=memory_text,
            embedding=vectors[0],
            salience=0.7,
            confidence=1.0,
        )
    )
    semantic_repository.add_memory(
        MemoryRecord(
            memory_id="provider-smoke-distractor-memory",
            player_profile_id="provider-smoke-player",
            world_save_id="provider-smoke-save",
            owner_npc_persistent_id="provider-smoke-mira",
            session_id="provider-smoke-mira-session",
            memory_type="episodic",
            content=distractor_text,
            summary=distractor_text,
            embedding=vectors[1],
            salience=0.7,
            confidence=1.0,
        )
    )
    blue_similarity = vector_similarity(vectors[2], vectors[0])
    distractor_similarity = vector_similarity(vectors[2], vectors[1])
    recalled = semantic_repository.search_memories(
        "provider-smoke-player",
        "provider-smoke-save",
        "provider-smoke-mira",
        vectors[2],
        2,
    )
    if (
        blue_similarity <= distractor_similarity
        or not recalled
        or recalled[0][0].memory_id != "provider-smoke-blue-memory"
        or recalled[0][1] <= recalled[1][1]
    ):
        raise RuntimeError("semantic_paraphrase_recall_failed")

    dialogue_service = NpcCognitionService(
        settings=settings,
        repository=InMemoryRepository(),
        llm=capturing_llm,
        embeddings=embeddings,
        catalog=catalog,
    )
    mira = await dialogue_service.handle_turn(_request("mira"))
    bandit = await dialogue_service.handle_turn(_request("bandit"))
    if mira.degraded or bandit.degraded or len(capturing_llm.results) != 2:
        raise RuntimeError("real_text_generation_failed")
    for result in capturing_llm.results:
        _assert_generation_contract(result)
    mira_profile = catalog.get_profile("mira").payload
    bandit_profile = catalog.get_profile("bandit").payload
    _assert_profile_injection(capturing_llm.requests[0], mira_profile)
    _assert_profile_injection(capturing_llm.requests[1], bandit_profile)
    if (
        capturing_llm.requests[0].text != capturing_llm.requests[1].text
        or capturing_llm.requests[0].npc_definition_id
        == capturing_llm.requests[1].npc_definition_id
        or _prompt_profile(mira_profile) == _prompt_profile(bandit_profile)
        or not mira.reply_text.strip()
        or not bandit.reply_text.strip()
    ):
        raise RuntimeError("npc_profile_differentiation_failed")

    repository_url = database_url
    if repository_url.startswith("postgresql://"):
        repository_url = repository_url.replace(
            "postgresql://", "postgresql+psycopg://", 1
        )
    timeout_repository = PostgresCognitionRepository(repository_url)
    scope_suffix = uuid.uuid4().hex
    timeout_player = f"provider-smoke-failure-{scope_suffix}"
    timeout_save = "provider-smoke-failure-save"
    timeout_npc = f"provider-smoke-failure-mira-{scope_suffix}"
    timeout_request = _request(
        "mira",
        request_id="provider-smoke-timeout",
        text="Please answer briefly.",
        player_profile_id=timeout_player,
        world_save_id=timeout_save,
        npc_persistent_id=timeout_npc,
        session_id=f"provider-smoke-failure-session-{scope_suffix}",
    )
    try:
        timeout_repository.deploy_profile(
            catalog.get_profile("mira"),
            timeout_player,
            timeout_save,
            timeout_npc,
        )
        baseline_graph_edges = len(
            timeout_repository.graph_edges_for(
                timeout_player, timeout_save, timeout_npc
            )
        )
        timeout_service = NpcCognitionService(
            settings=settings,
            repository=timeout_repository,
            llm=_ForcedFailureLlm(),
            embeddings=_StaticEmbedding(),
            catalog=catalog,
        )
        timeout_result = await timeout_service.handle_turn(timeout_request)
        timeout_session = timeout_repository.get_session(
            timeout_request.session_id,
            timeout_player,
            timeout_save,
            timeout_npc,
        )
        if (
            not timeout_result.degraded
            or timeout_result.degradation_reason != "provider_unavailable"
            or timeout_result.reply_text != SAFE_FALLBACK
            or timeout_result.memory_write_ids
            or timeout_result.proposed_intents
            or timeout_repository.memories_for(
                timeout_player, timeout_save, timeout_npc
            )
            or len(
                timeout_repository.graph_edges_for(
                    timeout_player, timeout_save, timeout_npc
                )
            )
            != baseline_graph_edges
            or timeout_session is None
            or timeout_session.turns
        ):
            raise RuntimeError("provider_timeout_state_safety_failed")
    finally:
        timeout_repository.delete_player(timeout_player, timeout_save)
        timeout_repository.close()

    report: dict[str, object] = {
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "commit_sha": commit_sha,
        "provider": "openai",
        "text_model": text_model,
        "embedding_model": embedding_model,
        "structured_output_valid": True,
        "embedding_dimension": len(vectors[0]),
        "postgres_vector_type": database_type[0],
        "semantic_recall_valid": True,
        "server_profile_injection_valid": True,
        "timeout_fallback_valid": True,
        "timeout_state_mutation_free": True,
        "npc_profile_difference_valid": True,
    }
    return report


def main() -> int:
    REPORT.unlink(missing_ok=True)
    stdout_capture = io.StringIO()
    stderr_capture = io.StringIO()
    log_capture = io.StringIO()
    root_logger = logging.getLogger()
    previous_handlers = list(root_logger.handlers)
    previous_level = root_logger.level
    for existing_handler in previous_handlers:
        root_logger.removeHandler(existing_handler)
    capture_handler = logging.StreamHandler(log_capture)
    root_logger.addHandler(capture_handler)
    root_logger.setLevel(logging.DEBUG)
    report: dict[str, object] | None = None
    failure: Exception | None = None
    try:
        with (
            contextlib.redirect_stdout(stdout_capture),
            contextlib.redirect_stderr(stderr_capture),
        ):
            report = asyncio.run(_run())
    except Exception as error:
        failure = error
    finally:
        root_logger.removeHandler(capture_handler)
        root_logger.setLevel(previous_level)
        for existing_handler in previous_handlers:
            root_logger.addHandler(existing_handler)

    database_url = (
        os.getenv("NPC_PROVIDER_SMOKE_DATABASE_URL", "").strip()
        or os.getenv("DATABASE_URL", "").strip()
        or "postgresql://stillpoint:stillpoint@127.0.0.1:55432/stillpoint"
    )
    parsed_database = urlsplit(
        database_url.replace("postgresql+psycopg://", "postgresql://")
    )
    runtime_output = (
        stdout_capture.getvalue() + stderr_capture.getvalue() + log_capture.getvalue()
    )
    try:
        _assert_secret_hygiene(
            report or {},
            runtime_output,
            [
                os.getenv("OPENAI_API_KEY", ""),
                os.getenv("NPC_MIND_SIGNING_KEY", ""),
                os.getenv("NPC_SESSION_TOKEN", ""),
                parsed_database.password or "",
            ],
        )
    except Exception as hygiene_error:
        failure = hygiene_error

    if failure is not None or report is None:
        error_name = type(failure).__name__ if failure is not None else "RuntimeError"
        print(f"Provider smoke FAILED ({error_name})")
        return 1
    report["secret_hygiene_valid"] = True
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(
        "Provider smoke passed: structured output, vector(1536), semantic recall, "
        "server profile differentiation, timeout safety, and secret hygiene"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
