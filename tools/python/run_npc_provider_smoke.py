"""Run a low-cost real OpenAI provider smoke without logging content or credentials."""

from __future__ import annotations

import asyncio
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

import psycopg

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "artifacts" / "npc-provider-smoke.json"
sys.path.insert(0, str(ROOT / "services" / "npc_mind"))

from app.catalog import NpcCatalogRepository  # noqa: E402
from app.config import Settings  # noqa: E402
from app.providers import OpenAIEmbeddingProvider, OpenAILlmProvider  # noqa: E402
from app.repository import InMemoryRepository  # noqa: E402
from app.schemas import NpcGenerationRequest  # noqa: E402
from app.service import NpcCognitionService  # noqa: E402


def _required(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"missing_{name.lower()}")
    return value


def _request(definition: str, profile: dict) -> NpcGenerationRequest:
    return NpcGenerationRequest(
        request_id=f"provider-smoke-{definition}",
        player_profile_id="provider-smoke-player",
        world_save_id="provider-smoke-save",
        npc_definition_id=definition,
        npc_persistent_id=f"provider-smoke-{definition}",
        session_id=f"provider-smoke-{definition}-session",
        text="Greet a traveler in one short sentence while staying in character.",
        npc_profile=profile,
        allow_conversation_storage=False,
        allow_memory_personalization=False,
    )


async def _run() -> dict[str, object]:
    api_key = _required("OPENAI_API_KEY")
    text_model = _required("OPENAI_TEXT_MODEL")
    embedding_model = _required("OPENAI_EMBEDDING_MODEL")
    database_url = os.getenv(
        "NPC_PROVIDER_SMOKE_DATABASE_URL",
        "postgresql://stillpoint:stillpoint@127.0.0.1:55432/stillpoint",
    )
    settings = Settings(
        app_env="test",
        npc_repository="in_memory",
        llm_provider="openai",
        openai_api_key=api_key,
        openai_text_model=text_model,
        openai_embedding_model=embedding_model,
        embedding_dimensions=1536,
        provider_retries=0,
        max_output_tokens=120,
    )
    settings.validate_embedding_configuration()
    catalog = NpcCatalogRepository()
    llm = OpenAILlmProvider(settings)
    embeddings = OpenAIEmbeddingProvider(settings)

    vector = (await embeddings.embed(["A generic blue geometric shape."]))[0]
    if len(vector) != 1536:
        raise RuntimeError("embedding_dimension_mismatch")
    with psycopg.connect(database_url.replace("postgresql+psycopg://", "postgresql://")) as connection:
        database_type = connection.execute(
            "SELECT format_type(a.atttypid, a.atttypmod) "
            "FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid "
            "WHERE c.relname='npc_memories' AND a.attname='embedding' "
            "AND a.attnum > 0 AND NOT a.attisdropped"
        ).fetchone()
    if database_type is None or database_type[0] != "vector(1536)":
        raise RuntimeError("postgres_vector_dimension_mismatch")

    mira = await llm.generate_npc_reply(
        _request("mira", catalog.get_profile("mira").payload)
    )
    bandit = await llm.generate_npc_reply(
        _request("bandit", catalog.get_profile("bandit").payload)
    )
    if mira.reply_text == bandit.reply_text:
        raise RuntimeError("npc_profile_did_not_affect_response")

    timeout_settings = Settings(
        app_env="test",
        npc_repository="in_memory",
        llm_provider="openai",
        openai_api_key=api_key,
        openai_text_model=text_model,
        openai_embedding_model=embedding_model,
        embedding_dimensions=1536,
        provider_connect_timeout_seconds=0.000001,
        provider_read_timeout_seconds=0.000001,
        provider_retries=0,
        max_output_tokens=40,
    )
    timeout_service = NpcCognitionService(
        settings=timeout_settings,
        repository=InMemoryRepository(),
    )
    timeout_result = await timeout_service.handle_turn(
        _request("mira", catalog.get_profile("mira").payload)
    )
    if not timeout_result.degraded:
        raise RuntimeError("provider_timeout_did_not_degrade")

    return {
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "provider": "openai",
        "text_model": text_model,
        "embedding_model": embedding_model,
        "structured_output_valid": True,
        "embedding_dimension": len(vector),
        "postgres_vector_type": database_type[0],
        "timeout_fallback_valid": True,
        "npc_profile_difference_valid": True,
        "content_logged": False,
        "credentials_logged": False,
    }


def main() -> int:
    try:
        report = asyncio.run(_run())
    except Exception as error:
        print(f"Provider smoke FAILED ({type(error).__name__})")
        return 1
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(
        "Provider smoke passed: structured output, vector(1536), timeout fallback, "
        "and NPC profile differentiation"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
