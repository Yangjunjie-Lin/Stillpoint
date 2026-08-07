from __future__ import annotations

import os
from dataclasses import dataclass
from urllib.parse import urlparse


@dataclass(frozen=True, slots=True)
class Settings:
    app_env: str = "development"
    auth_mode: str = "local_loopback"
    paired_client_credentials_json: str = ""
    npc_repository: str = "postgres"
    llm_provider: str = "fake"
    embedding_provider: str = "auto"
    openai_api_key: str = ""
    openai_base_url: str = "https://api.openai.com"
    openai_response_format: str = "json_object"
    openai_text_model: str = ""
    openai_embedding_model: str = ""
    database_url: str = "postgresql+psycopg://stillpoint:stillpoint@127.0.0.1:5432/stillpoint"
    npc_mind_signing_key: str = ""
    session_token_ttl_seconds: int = 900
    provider_connect_timeout_seconds: float = 3.0
    provider_read_timeout_seconds: float = 15.0
    provider_retries: int = 2
    provider_max_response_bytes: int = 262144
    estimated_cost_per_1k_tokens_usd: float = 0.01
    embedding_dimensions: int = 1536
    max_input_length: int = 4000
    max_output_tokens: int = 400
    retrieval_token_budget: int = 2400
    player_rate_per_minute: int = 30
    npc_rate_per_minute: int = 20
    daily_budget_usd: float = 1.0
    retrieval_vector_weight: float = 0.40
    retrieval_lexical_weight: float = 0.08
    retrieval_salience_weight: float = 0.12
    retrieval_confidence_weight: float = 0.08
    retrieval_goal_weight: float = 0.08
    retrieval_graph_weight: float = 0.08
    retrieval_relationship_weight: float = 0.06
    retrieval_recency_weight: float = 0.06
    retrieval_reinforcement_weight: float = 0.04

    @classmethod
    def from_env(cls) -> "Settings":
        def integer(name: str, default: int) -> int:
            try:
                return max(1, int(os.getenv(name, str(default))))
            except ValueError:
                return default

        def number(name: str, default: float, minimum: float = 0.0) -> float:
            try:
                return max(minimum, float(os.getenv(name, str(default))))
            except ValueError:
                return default

        try:
            budget = max(0.0, float(os.getenv("NPC_DAILY_BUDGET_USD", "1.0")))
        except ValueError:
            budget = 1.0
        return cls(
            app_env=os.getenv("APP_ENV", "development").lower(),
            auth_mode=os.getenv("AUTH_MODE", "local_loopback").lower(),
            paired_client_credentials_json=os.getenv(
                "NPC_PAIRED_CLIENT_CREDENTIALS_JSON", ""
            ),
            npc_repository=os.getenv("NPC_REPOSITORY", "postgres").lower(),
            llm_provider=os.getenv("LLM_PROVIDER", "fake").lower(),
            embedding_provider=os.getenv("NPC_EMBEDDING_PROVIDER", "auto").lower(),
            openai_api_key=os.getenv("OPENAI_API_KEY", ""),
            openai_base_url=os.getenv("OPENAI_BASE_URL", "https://api.openai.com"),
            openai_response_format=os.getenv(
                "OPENAI_RESPONSE_FORMAT", "json_object"
            ).lower(),
            openai_text_model=os.getenv("OPENAI_TEXT_MODEL", ""),
            openai_embedding_model=os.getenv("OPENAI_EMBEDDING_MODEL", ""),
            database_url=os.getenv(
                "DATABASE_URL",
                "postgresql+psycopg://stillpoint:stillpoint@127.0.0.1:5432/stillpoint",
            ),
            npc_mind_signing_key=os.getenv("NPC_MIND_SIGNING_KEY", ""),
            session_token_ttl_seconds=integer("NPC_SESSION_TOKEN_TTL_SECONDS", 900),
            provider_connect_timeout_seconds=number("NPC_PROVIDER_CONNECT_TIMEOUT_SECONDS", 3.0),
            provider_read_timeout_seconds=number("NPC_PROVIDER_READ_TIMEOUT_SECONDS", 15.0),
            provider_retries=integer("NPC_PROVIDER_RETRIES", 2),
            provider_max_response_bytes=integer("NPC_PROVIDER_MAX_RESPONSE_BYTES", 262144),
            estimated_cost_per_1k_tokens_usd=number(
                "NPC_ESTIMATED_COST_PER_1K_TOKENS_USD", 0.01
            ),
            embedding_dimensions=integer("NPC_EMBEDDING_DIMENSIONS", 1536),
            max_input_length=integer("NPC_MAX_INPUT_LENGTH", 4000),
            max_output_tokens=integer("NPC_MAX_OUTPUT_TOKENS", 400),
            retrieval_token_budget=integer("NPC_RETRIEVAL_TOKEN_BUDGET", 2400),
            player_rate_per_minute=integer("NPC_PLAYER_RATE_PER_MINUTE", 30),
            npc_rate_per_minute=integer("NPC_NPC_RATE_PER_MINUTE", 20),
            daily_budget_usd=budget,
            retrieval_vector_weight=number("NPC_RETRIEVAL_VECTOR_WEIGHT", 0.40),
            retrieval_lexical_weight=number("NPC_RETRIEVAL_LEXICAL_WEIGHT", 0.08),
            retrieval_salience_weight=number("NPC_RETRIEVAL_SALIENCE_WEIGHT", 0.12),
            retrieval_confidence_weight=number("NPC_RETRIEVAL_CONFIDENCE_WEIGHT", 0.08),
            retrieval_goal_weight=number("NPC_RETRIEVAL_GOAL_WEIGHT", 0.08),
            retrieval_graph_weight=number("NPC_RETRIEVAL_GRAPH_WEIGHT", 0.08),
            retrieval_relationship_weight=number(
                "NPC_RETRIEVAL_RELATIONSHIP_WEIGHT", 0.06
            ),
            retrieval_recency_weight=number("NPC_RETRIEVAL_RECENCY_WEIGHT", 0.06),
            retrieval_reinforcement_weight=number(
                "NPC_RETRIEVAL_REINFORCEMENT_WEIGHT", 0.04
            ),
        )

    def repository_is_in_memory(self) -> bool:
        if self.npc_repository == "in_memory":
            if self.app_env != "test":
                raise ValueError("in_memory_repository_requires_test_environment")
            return True
        if self.npc_repository != "postgres":
            raise ValueError("unsupported_npc_repository")
        return False

    def validate_auth_mode(self) -> None:
        if self.auth_mode not in {"local_loopback", "paired_client"}:
            raise ValueError("unsupported_auth_mode")
        if self.auth_mode == "paired_client" and not self.paired_client_credentials_json:
            raise ValueError("paired_client_registry_required")

    def validate_embedding_configuration(self) -> None:
        # Save schema 4 / migration 0001 owns a PostgreSQL vector(1536) column.
        if self.embedding_dimensions != 1536:
            raise ValueError("embedding_dimension_must_match_schema")

    def validate_provider_configuration(self) -> None:
        if self.llm_provider not in {"fake", "openai"}:
            raise ValueError("unsupported_llm_provider")
        if self.embedding_provider not in {"auto", "fake", "openai"}:
            raise ValueError("unsupported_embedding_provider")
        if self.openai_response_format not in {"json_object", "json_schema", "text"}:
            raise ValueError("unsupported_provider_response_format")
        if self.llm_provider != "openai" and self.embedding_provider != "openai":
            return
        parsed = urlparse(self.openai_base_url.strip())
        if not parsed.hostname or parsed.username or parsed.password or parsed.query or parsed.fragment:
            raise ValueError("invalid_provider_base_url")
        is_loopback = parsed.hostname in {"127.0.0.1", "localhost", "::1"}
        if parsed.scheme != "https" and not (parsed.scheme == "http" and is_loopback):
            raise ValueError("provider_base_url_must_use_https")

    def use_remote_embeddings(self) -> bool:
        if self.embedding_provider == "fake":
            return False
        if self.embedding_provider == "openai":
            return True
        return self.llm_provider == "openai" and bool(self.openai_embedding_model)
