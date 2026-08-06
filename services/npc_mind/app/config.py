from __future__ import annotations

import os
from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class Settings:
    llm_provider: str = "fake"
    openai_api_key: str = ""
    openai_text_model: str = ""
    openai_embedding_model: str = ""
    database_url: str = ""
    npc_mind_signing_key: str = ""
    max_input_length: int = 4000
    max_output_tokens: int = 400
    retrieval_token_budget: int = 2400
    player_rate_per_minute: int = 30
    npc_rate_per_minute: int = 20
    daily_budget_usd: float = 1.0

    @classmethod
    def from_env(cls) -> "Settings":
        def integer(name: str, default: int) -> int:
            try:
                return max(1, int(os.getenv(name, str(default))))
            except ValueError:
                return default

        try:
            budget = max(0.0, float(os.getenv("NPC_DAILY_BUDGET_USD", "1.0")))
        except ValueError:
            budget = 1.0
        return cls(
            llm_provider=os.getenv("LLM_PROVIDER", "fake").lower(),
            openai_api_key=os.getenv("OPENAI_API_KEY", ""),
            openai_text_model=os.getenv("OPENAI_TEXT_MODEL", ""),
            openai_embedding_model=os.getenv("OPENAI_EMBEDDING_MODEL", ""),
            database_url=os.getenv("DATABASE_URL", ""),
            npc_mind_signing_key=os.getenv("NPC_MIND_SIGNING_KEY", ""),
            max_input_length=integer("NPC_MAX_INPUT_LENGTH", 4000),
            max_output_tokens=integer("NPC_MAX_OUTPUT_TOKENS", 400),
            retrieval_token_budget=integer("NPC_RETRIEVAL_TOKEN_BUDGET", 2400),
            player_rate_per_minute=integer("NPC_PLAYER_RATE_PER_MINUTE", 30),
            npc_rate_per_minute=integer("NPC_NPC_RATE_PER_MINUTE", 20),
            daily_budget_usd=budget,
        )
