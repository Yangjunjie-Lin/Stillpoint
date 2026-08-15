from __future__ import annotations

from fastapi import Depends, FastAPI, Header, HTTPException, Query, Request

from .auth import ClientAuthenticator, SessionClaims, SessionTokenService
from .schemas import (
    ConversationRequest,
    MemoryQuery,
    NpcGenerationRequest,
    PetMovementAssessmentRequest,
    SessionTokenRequest,
    SyncRequest,
)
from .service import NpcCognitionService


def create_app(service: NpcCognitionService | None = None) -> FastAPI:
    app = FastAPI(title="Stillpoint NPC Mind", version="0.8.0")
    cognition = service or NpcCognitionService()
    tokens = SessionTokenService(cognition.settings)
    clients = ClientAuthenticator(cognition.settings)

    def authenticate(
        authorization: str | None = Header(default=None),
        x_client_install_id: str | None = Header(default=None),
    ) -> SessionClaims:
        if not authorization or not authorization.startswith("Bearer "):
            raise HTTPException(status_code=401, detail="missing_auth")
        if not x_client_install_id:
            raise HTTPException(status_code=401, detail="missing_client_install_id")
        try:
            return tokens.verify(
                authorization.removeprefix("Bearer ").strip(),
                client_install_id=x_client_install_id,
            )
        except RuntimeError as error:
            raise HTTPException(status_code=503, detail=str(error)) from error
        except ValueError as error:
            code = str(error)
            raise HTTPException(
                status_code=401 if code in {"expired_token", "invalid_token"} else 403,
                detail=code,
            ) from error

    def require_scope(claims: SessionClaims, player: str, save: str) -> None:
        if claims.player_profile_id != player or claims.world_save_id != save:
            raise HTTPException(status_code=403, detail="wrong_player_scope")

    @app.get("/health")
    async def health() -> dict[str, str]:
        return {
            "status": "ok",
            "service": "stillpoint-npc-mind",
            "version": "0.8.0",
            "repository": type(cognition.repository).__name__,
            "llm_provider": cognition.settings.llm_provider,
            "text_model": (
                cognition.settings.openai_text_model
                if cognition.settings.llm_provider == "openai"
                else "fake"
            ),
            "response_format": cognition.settings.openai_response_format,
            "embedding_provider": (
                "openai" if cognition.settings.use_remote_embeddings() else "fake"
            ),
            "embedding_dimensions": str(cognition.settings.embedding_dimensions),
        }

    @app.post("/v1/auth/session")
    async def create_session_token(
        http_request: Request,
        request: SessionTokenRequest,
        x_client_install_id: str | None = Header(default=None),
        x_client_secret: str | None = Header(default=None),
    ) -> dict[str, str | int]:
        try:
            clients.authorize_issue(
                client_host=http_request.client.host if http_request.client else "",
                header_client_install_id=x_client_install_id or "",
                client_secret=x_client_secret or "",
                player_profile_id=request.player_profile_id,
                world_save_id=request.world_save_id,
                requested_client_install_id=request.client_install_id,
            )
            token, expires_at = tokens.issue(
                request.player_profile_id,
                request.world_save_id,
                request.client_install_id,
            )
        except RuntimeError as error:
            raise HTTPException(status_code=503, detail=str(error)) from error
        except ValueError as error:
            code = str(error)
            status = 401 if code in {
                "paired_client_credentials_required",
                "invalid_client_credentials",
            } else 403
            raise HTTPException(status_code=status, detail=code) from error
        return {"token": token, "expires_at": expires_at, "token_type": "Bearer"}

    @app.post("/v1/conversations")
    async def create_conversation(
        request: ConversationRequest, claims: SessionClaims = Depends(authenticate)
    ) -> dict:
        require_scope(claims, request.player_profile_id, request.world_save_id)
        try:
            profile = cognition.catalog.get_profile(request.npc_definition_id)
            cognition.repository.deploy_profile(
                profile,
                request.player_profile_id,
                request.world_save_id,
                request.npc_persistent_id,
            )
            session = cognition.repository.create_session(request.model_dump())
        except ValueError as error:
            raise HTTPException(status_code=409, detail=str(error)) from error
        return session.to_dict()

    @app.post("/v1/pets/movement-assessments")
    async def assess_pet_movement(
        request: PetMovementAssessmentRequest,
        claims: SessionClaims = Depends(authenticate),
    ) -> dict:
        require_scope(claims, request.player_profile_id, request.world_save_id)
        try:
            return (await cognition.assess_pet_movement(request)).model_dump(
                mode="json", exclude_none=True
            )
        except ValueError as error:
            code = str(error)
            status = 404 if code == "unknown_npc_definition" else 409
            raise HTTPException(status_code=status, detail=code) from error

    @app.post("/v1/conversations/{session_id:path}/turns")
    async def create_turn(
        session_id: str,
        request: NpcGenerationRequest,
        claims: SessionClaims = Depends(authenticate),
    ) -> dict:
        require_scope(claims, request.player_profile_id, request.world_save_id)
        if request.session_id != session_id:
            raise HTTPException(status_code=409, detail="session_id_mismatch")
        try:
            return (await cognition.handle_turn(request)).model_dump()
        except ValueError as error:
            code = str(error)
            status = 404 if code == "unknown_npc_definition" else 429 if "limited" in code else 400
            raise HTTPException(status_code=status, detail=code) from error

    @app.get("/v1/conversations/{session_id:path}")
    async def get_conversation(
        session_id: str,
        npc_persistent_id: str = Query(min_length=1),
        claims: SessionClaims = Depends(authenticate),
    ) -> dict:
        session = cognition.repository.get_session(
            session_id,
            claims.player_profile_id,
            claims.world_save_id,
            npc_persistent_id,
        )
        if session is None:
            raise HTTPException(status_code=404, detail="session_not_found")
        require_scope(claims, session.player_profile_id, session.world_save_id)
        return session.to_dict()

    @app.post("/v1/npcs/{npc_persistent_id:path}/memories/query")
    async def query_memories(
        npc_persistent_id: str,
        query: MemoryQuery,
        claims: SessionClaims = Depends(authenticate),
    ) -> dict:
        require_scope(claims, query.player_profile_id, query.world_save_id)
        if cognition.budget_exhausted(claims.player_profile_id):
            raise HTTPException(status_code=429, detail="daily_budget_exceeded")
        try:
            npc_definition_id = cognition.repository.resolve_npc_definition_id(
                claims.player_profile_id,
                claims.world_save_id,
                npc_persistent_id,
            )
        except ValueError as error:
            raise HTTPException(status_code=409, detail=str(error)) from error
        if npc_definition_id is None:
            raise HTTPException(status_code=404, detail="unknown_npc_instance")
        if (
            query.npc_definition_id is not None
            and query.npc_definition_id != npc_definition_id
        ):
            raise HTTPException(status_code=409, detail="npc_definition_scope_mismatch")
        try:
            profile = cognition.catalog.get_profile(npc_definition_id)
        except ValueError as error:
            raise HTTPException(status_code=409, detail="npc_profile_not_deployed") from error
        request = NpcGenerationRequest(
            request_id=f"query:{npc_persistent_id}",
            player_profile_id=claims.player_profile_id,
            world_save_id=claims.world_save_id,
            npc_definition_id=npc_definition_id,
            npc_persistent_id=npc_persistent_id,
            session_id="query",
            text=query.query,
            world_context={"visible_entity_ids": query.entity_ids},
            npc_profile=profile.payload,
        )
        try:
            memories = await cognition.retrieve_memories_async(request, query.limit)
        except (RuntimeError, TimeoutError) as error:
            raise HTTPException(
                status_code=503, detail="memory_retrieval_unavailable"
            ) from error
        return {
            "npc_persistent_id": npc_persistent_id,
            "memories": [memory.to_dict() for memory in memories],
        }

    @app.get("/v1/npcs/{npc_persistent_id:path}/memories")
    async def list_memories(
        npc_persistent_id: str,
        claims: SessionClaims = Depends(authenticate),
        player_profile_id: str | None = Query(default=None),
        world_save_id: str | None = Query(default=None),
    ) -> dict:
        if player_profile_id and player_profile_id != claims.player_profile_id:
            raise HTTPException(status_code=403, detail="wrong_player_scope")
        if world_save_id and world_save_id != claims.world_save_id:
            raise HTTPException(status_code=403, detail="wrong_player_scope")
        memories = cognition.repository.memories_for(
            claims.player_profile_id, claims.world_save_id, npc_persistent_id
        )
        return {"memories": [memory.to_dict() for memory in memories]}

    @app.delete("/v1/npcs/{npc_persistent_id:path}/memories")
    async def delete_npc_memories(
        npc_persistent_id: str, claims: SessionClaims = Depends(authenticate)
    ) -> dict[str, int]:
        return {
            "deleted": cognition.repository.delete_npc(
                claims.player_profile_id, claims.world_save_id, npc_persistent_id
            )
        }

    @app.get("/v1/npcs/{npc_persistent_id:path}/graph")
    async def get_graph(
        npc_persistent_id: str, claims: SessionClaims = Depends(authenticate)
    ) -> dict:
        return cognition.graph_payload(
            claims.player_profile_id, claims.world_save_id, npc_persistent_id
        )

    @app.post("/v1/sync/npc-cognition")
    async def sync_npc_cognition(
        payload: SyncRequest, claims: SessionClaims = Depends(authenticate)
    ) -> dict:
        require_scope(claims, payload.player_profile_id, payload.world_save_id)
        return (await cognition.sync(payload)).model_dump()

    @app.delete("/v1/players/{player_profile_id}/npc-memories")
    async def delete_player_memories(
        player_profile_id: str, claims: SessionClaims = Depends(authenticate)
    ) -> dict[str, int]:
        require_scope(claims, player_profile_id, claims.world_save_id)
        return {
            "deleted": cognition.repository.delete_player(
                player_profile_id, claims.world_save_id
            )
        }

    @app.get("/v1/players/{player_profile_id}/npc-memories/export")
    async def export_player_memories(
        player_profile_id: str, claims: SessionClaims = Depends(authenticate)
    ) -> dict:
        require_scope(claims, player_profile_id, claims.world_save_id)
        return cognition.repository.export_player(player_profile_id, claims.world_save_id)

    return app


app = create_app()
