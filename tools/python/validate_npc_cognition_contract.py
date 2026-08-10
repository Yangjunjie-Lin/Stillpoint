"""Validate the Godot/backend cognition JSON contract without network access."""

from __future__ import annotations

import json
from pathlib import Path

from app.schemas import ConversationResponse, NpcGenerationRequest


def main() -> int:
    request = NpcGenerationRequest(
        request_id="contract-request",
        player_profile_id="player-001",
        world_save_id="slot-01",
        npc_definition_id="mira",
        npc_persistent_id="base:town/npc/mira",
        session_id="session-001",
        text="Do you remember the herb?",
        world_context={"region_id": "base:town"},
    )
    response = ConversationResponse(
        request_id=request.request_id,
        session_id=request.session_id,
        reply_text="I remember.",
        usage={"input_tokens": 4, "output_tokens": 3},
    )
    payload = json.loads(response.model_dump_json())
    ConversationResponse.model_validate(payload)
    catalog = Path("services/npc_mind/catalog/generated_npc_catalog.json")
    data = json.loads(catalog.read_text(encoding="utf-8"))
    if data.get("catalog_version") != 1 or int(data.get("npc_count", 0)) < 1:
        raise AssertionError("invalid generated NPC catalog")
    print("NPC cognition contract: request, response, and catalog valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
