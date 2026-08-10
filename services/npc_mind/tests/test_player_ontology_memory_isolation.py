import asyncio

from app.repository import InMemoryRepository
from app.schemas import NpcGenerationRequest, NpcGenerationResult
from app.service import NpcCognitionService


def _ontology() -> dict:
    return {
        "schema_version": 1,
        "public_identity": {
            "display_name": "Traveler",
            "origin_id": "ronin",
            "origin_label": "Ronin",
            "faction_id": "free_roads",
            "faction_label": "Free Roads",
            "profession_id": "wind_scout",
            "profession_label": "Wind Scout",
        },
        "visible_appearance": {
            "body_id": "slender",
            "skin_id": "warm",
            "hair_id": "topknot",
            "headwear_id": "none",
            "palette_id": "ocean",
            "accessory_id": "satchel",
        },
        "observable_capabilities": [
            {
                "trait_id": "agile",
                "evidence": "profession",
                "visibility": "public",
            }
        ],
    }


def _request(
    request_id: str,
    npc_persistent_id: str,
    text: str,
    *,
    npc_definition_id: str = "bandit",
) -> NpcGenerationRequest:
    return NpcGenerationRequest(
        request_id=request_id,
        player_profile_id="player",
        world_save_id="save",
        npc_definition_id=npc_definition_id,
        npc_persistent_id=npc_persistent_id,
        session_id=f"session-{npc_persistent_id}",
        text=text,
        player_ontology=_ontology(),
    )


class _LearningProvider:
    def __init__(self) -> None:
        self.requests: list[NpcGenerationRequest] = []

    async def generate_npc_reply(self, request: NpcGenerationRequest) -> NpcGenerationResult:
        self.requests.append(request)
        candidates = []
        if request.text.startswith("Remember"):
            candidates.append(
                {
                    "content": request.text,
                    "summary": "The player's moon password is silver heron.",
                    "salience": 0.95,
                    "confidence": 0.95,
                    "visibility": "private",
                    "source_type": "conversation_turn",
                    "source_id": request.request_id,
                }
            )
        return NpcGenerationResult(
            reply_text="Understood.",
            memory_candidates=candidates,
        )


def test_dialogue_learning_is_private_while_public_player_ontology_is_shared():
    repository = InMemoryRepository()
    provider = _LearningProvider()
    service = NpcCognitionService(repository=repository, llm=provider)

    learned = asyncio.run(
        service.handle_turn(
            _request(
                "learn-bandit-one",
                "base:dungeon/npc/bandit_0001",
                "Remember that my moon password is silver heron.",
            )
        )
    )
    asyncio.run(
        service.handle_turn(
            _request(
                "recall-bandit-one",
                "base:dungeon/npc/bandit_0001",
                "What is my moon password?",
            )
        )
    )
    asyncio.run(
        service.handle_turn(
            _request(
                "recall-bandit-two",
                "base:dungeon/npc/bandit_0002",
                "What is my moon password?",
            )
        )
    )

    first_recall = provider.requests[-2]
    second_recall = provider.requests[-1]
    assert len(learned.memory_write_ids) == 1
    assert first_recall.retrieved_memories
    assert "silver heron" in first_recall.retrieved_memories[0]["summary"]
    assert second_recall.retrieved_memories == []
    assert first_recall.player_ontology == second_recall.player_ontology
    assert repository.memories_for(
        "player", "save", "base:dungeon/npc/bandit_0002"
    ) == []


def test_same_public_player_ontology_does_not_blend_server_owned_npc_profiles():
    provider = _LearningProvider()
    service = NpcCognitionService(repository=InMemoryRepository(), llm=provider)

    asyncio.run(
        service.handle_turn(
            _request(
                "mira-public-context",
                "base:town/npc/mira",
                "Hello.",
                npc_definition_id="mira",
            )
        )
    )
    asyncio.run(
        service.handle_turn(
            _request(
                "bandit-public-context",
                "base:dungeon/npc/bandit_0001",
                "Hello.",
            )
        )
    )

    mira_request, bandit_request = provider.requests
    assert mira_request.player_ontology == bandit_request.player_ontology
    assert mira_request.npc_profile["display_name"] == "Mira"
    assert bandit_request.npc_profile["display_name"] == "Bandit"
    assert mira_request.npc_profile != bandit_request.npc_profile
