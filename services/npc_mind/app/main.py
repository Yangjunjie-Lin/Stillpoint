from __future__ import annotations

from fastapi import FastAPI, HTTPException, Query

from .schemas import ConversationRequest, MemoryQuery, NpcGenerationRequest
from .service import NpcCognitionService


def create_app(service: NpcCognitionService | None = None) -> FastAPI:
    app = FastAPI(title="Stillpoint NPC Mind", version="0.8.0")
    cognition = service or NpcCognitionService()

    @app.get("/health")
    async def health() -> dict[str, str]:
        return {"status": "ok", "service": "stillpoint-npc-mind", "version": "0.8.0"}

    @app.post("/v1/conversations")
    async def create_conversation(request: ConversationRequest) -> dict:
        try:
            session = cognition.repository.create_session(request.model_dump())
        except ValueError as error:
            raise HTTPException(status_code=409, detail=str(error)) from error
        return session.to_dict()

    @app.post("/v1/conversations/{session_id}/turns")
    async def create_turn(session_id: str, request: NpcGenerationRequest) -> dict:
        if request.session_id != session_id:
            raise HTTPException(status_code=409, detail="session_id_mismatch")
        try:
            return (await cognition.handle_turn(request)).model_dump()
        except ValueError as error:
            code = str(error)
            raise HTTPException(
                status_code=429 if "limited" in code else 400, detail=code
            ) from error

    @app.get("/v1/conversations/{session_id}")
    async def get_conversation(session_id: str) -> dict:
        session = cognition.repository.sessions.get(session_id)
        if session is None:
            raise HTTPException(status_code=404, detail="session_not_found")
        return session.to_dict()

    @app.post("/v1/npcs/{npc_persistent_id:path}/memories/query")
    async def query_memories(npc_persistent_id: str, query: MemoryQuery) -> dict:
        request = NpcGenerationRequest(
            request_id="query",
            player_profile_id=query.player_profile_id,
            world_save_id=query.world_save_id,
            npc_definition_id="",
            npc_persistent_id=npc_persistent_id,
            session_id="query",
            text=query.query,
        )
        memories = cognition.retrieve_memories(request)[: query.limit]
        return {
            "npc_persistent_id": npc_persistent_id,
            "memories": [memory.to_dict() for memory in memories],
        }

    @app.get("/v1/npcs/{npc_persistent_id:path}/memories")
    async def list_memories(
        npc_persistent_id: str, player_profile_id: str = Query(...), world_save_id: str = Query(...)
    ) -> dict:
        memories = cognition.repository.memories_for(
            player_profile_id, world_save_id, npc_persistent_id
        )
        return {"memories": [memory.to_dict() for memory in memories]}

    @app.delete("/v1/npcs/{npc_persistent_id:path}/memories")
    async def delete_npc_memories(
        npc_persistent_id: str,
        player_profile_id: str = Query(...),
        world_save_id: str = Query(...),
    ) -> dict[str, int]:
        return {
            "deleted": cognition.repository.delete_npc(
                player_profile_id, world_save_id, npc_persistent_id
            )
        }

    @app.get("/v1/npcs/{npc_persistent_id:path}/graph")
    async def get_graph(
        npc_persistent_id: str, player_profile_id: str = Query(...), world_save_id: str = Query(...)
    ) -> dict:
        edges = cognition.repository.graph.visible_edges(npc_persistent_id)
        nodes = [
            {
                "node_id": node.node_id,
                "node_type": node.node_type,
                "label": node.label,
                "metadata": node.metadata,
            }
            for node in cognition.repository.graph.nodes.values()
        ]
        return {"nodes": nodes, "edges": [edge.to_dict() for edge in edges]}

    @app.post("/v1/sync/npc-cognition")
    async def sync_npc_cognition(payload: dict) -> dict:
        return {"accepted": True, "revision": 1, "pending": payload.get("pending_event_outbox", [])}

    @app.delete("/v1/players/{player_profile_id}/npc-memories")
    async def delete_player_memories(player_profile_id: str) -> dict[str, int]:
        return {"deleted": cognition.repository.delete_player(player_profile_id)}

    @app.get("/v1/players/{player_profile_id}/npc-memories/export")
    async def export_player_memories(player_profile_id: str) -> dict:
        memories = [
            memory.to_dict()
            for memory in cognition.repository.memories.values()
            if memory.player_profile_id == player_profile_id
        ]
        sessions = [
            session.to_dict()
            for session in cognition.repository.sessions.values()
            if session.player_profile_id == player_profile_id
        ]
        return {"player_profile_id": player_profile_id, "memories": memories, "sessions": sessions}

    return app


app = create_app()
