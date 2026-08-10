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
        player_ontology={
            "schema_version": 1,
            "public_identity": {
                "display_name": "Traveler",
                "origin_id": "lotus_ascetic",
                "origin_label": "Lotus Ascetic",
                "faction_id": "ash_watch",
                "faction_label": "Ash Watch",
                "profession_id": "duelist",
                "profession_label": "Duelist",
            },
            "visible_appearance": {
                "body_id": "sturdy",
                "skin_id": "deep",
                "hair_id": "short",
                "headwear_id": "none",
                "palette_id": "ember",
                "accessory_id": "satchel",
            },
            "observable_capabilities": [
                {
                    "trait_id": "guarded",
                    "evidence": "faction",
                    "visibility": "public",
                },
                {
                    "trait_id": "forceful",
                    "evidence": "profession",
                    "visibility": "public",
                },
                {
                    "trait_id": "focused",
                    "evidence": "observable_build",
                    "visibility": "public",
                },
            ],
        },
    )
    request_payload = json.loads(request.model_dump_json())
    NpcGenerationRequest.model_validate(request_payload)
    serialized_request = json.dumps(request_payload, ensure_ascii=False)
    for private_field in (
        "attribute_seed",
        "attribute_points",
        "max_health_bonus",
        "inventory",
        "equipment",
    ):
        if private_field in serialized_request:
            raise AssertionError(f"private player field leaked into contract: {private_field}")
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
    if data.get("catalog_version") != 2 or int(data.get("npc_count", 0)) < 1:
        raise AssertionError("invalid generated NPC catalog")
    ontology = data.get("world_ontology", {})
    if not ontology.get("nodes") or not ontology.get("edges"):
        raise AssertionError("generated world ontology is missing")
    print("NPC cognition contract: request, response, and catalog valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
