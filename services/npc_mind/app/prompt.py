from __future__ import annotations

import json
from typing import Any


def assemble_trusted_prompt(
    system_rules: str,
    npc_profile: dict[str, Any],
    player_text: str,
    retrieved_memories: list[dict[str, Any]],
    graph_facts: list[dict[str, Any]],
) -> str:
    """Build explicit data boundaries so untrusted text cannot become rules."""
    return "\n".join(
        [
            "[SYSTEM_RULES]\n" + system_rules,
            "[NPC_PROFILE_JSON]\n" + json.dumps(npc_profile, ensure_ascii=False, sort_keys=True),
            "[RETRIEVED_MEMORY_DATA_JSON]\n"
            + json.dumps(retrieved_memories, ensure_ascii=False, sort_keys=True),
            "[GRAPH_DATA_JSON]\n" + json.dumps(graph_facts, ensure_ascii=False, sort_keys=True),
            "[PLAYER_TEXT_DATA]\n" + player_text,
            "[END_UNTRUSTED_DATA]",
        ]
    )
