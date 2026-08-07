"""NPC cognition production schema (PostgreSQL + pgvector)."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from pgvector.sqlalchemy import Vector
from sqlalchemy.dialects import postgresql

revision = "0001_npc_cognition"
down_revision = None
branch_labels = None
depends_on = None

SCOPE = (
    sa.Column("player_profile_id", sa.Text(), nullable=False),
    sa.Column("world_save_id", sa.Text(), nullable=False),
    sa.Column("npc_persistent_id", sa.Text(), nullable=False),
)


def _scope_columns() -> list[sa.Column]:
    return [column._copy() for column in SCOPE]


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS vector")

    op.create_table(
        "npc_profile_deployments",
        sa.Column("deployment_id", postgresql.UUID(as_uuid=True), primary_key=True),
        *_scope_columns(),
        sa.Column("npc_definition_id", sa.Text(), nullable=False),
        sa.Column("catalog_revision", sa.Text(), nullable=False),
        sa.Column("profile_json", postgresql.JSONB(), nullable=False),
        sa.Column("deployed_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint(
            "player_profile_id",
            "world_save_id",
            "npc_persistent_id",
            "npc_definition_id",
            "catalog_revision",
            name="uq_profile_deployment_scope_revision",
        ),
    )
    op.create_table(
        "conversation_sessions",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("session_id", sa.Text(), nullable=False),
        *_scope_columns(),
        sa.Column("npc_definition_id", sa.Text(), nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_active_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("title", sa.Text(), nullable=False, server_default=""),
        sa.Column("rolling_summary", sa.Text(), nullable=False, server_default=""),
        sa.UniqueConstraint(
            "player_profile_id",
            "world_save_id",
            "npc_persistent_id",
            "session_id",
            name="uq_session_scope_id",
        ),
    )
    op.create_index(
        "ix_conversation_sessions_scope_active",
        "conversation_sessions",
        ["player_profile_id", "world_save_id", "npc_persistent_id", "last_active_at"],
    )
    op.create_table(
        "conversation_turns",
        sa.Column("turn_id", postgresql.UUID(as_uuid=True), primary_key=True),
        *_scope_columns(),
        sa.Column(
            "session_row_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("conversation_sessions.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("session_id", sa.Text(), nullable=False),
        sa.Column("role", sa.Text(), nullable=False),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column("created_at_real", sa.DateTime(timezone=True), nullable=False),
        sa.Column("occurred_at_game", postgresql.JSONB(), nullable=False, server_default="{}"),
        sa.Column("region_id", sa.Text(), nullable=False, server_default=""),
        sa.Column("emotion", sa.Text(), nullable=False, server_default="neutral"),
        sa.Column("token_usage", postgresql.JSONB(), nullable=False, server_default="{}"),
        sa.Column("request_id", sa.Text(), nullable=False),
        sa.CheckConstraint("role IN ('player', 'npc', 'system')", name="ck_turn_role"),
        sa.UniqueConstraint(
            "player_profile_id",
            "world_save_id",
            "npc_persistent_id",
            "request_id",
            "role",
            name="uq_turn_scope_request_role",
        ),
    )
    op.create_index(
        "ix_conversation_turns_scope_session_created",
        "conversation_turns",
        [
            "player_profile_id",
            "world_save_id",
            "npc_persistent_id",
            "session_id",
            "created_at_real",
        ],
    )
    op.create_table(
        "npc_memories",
        sa.Column("memory_id", postgresql.UUID(as_uuid=True), primary_key=True),
        *_scope_columns(),
        sa.Column("session_id", sa.Text()),
        sa.Column("memory_type", sa.Text(), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("summary", sa.Text(), nullable=False, server_default=""),
        sa.Column("embedding", Vector(1536), nullable=False),
        sa.Column("occurred_at_game", postgresql.JSONB(), nullable=False, server_default="{}"),
        sa.Column("created_at_real", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_recalled_at", sa.DateTime(timezone=True)),
        sa.Column("recall_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("salience", sa.Float(), nullable=False, server_default="0.5"),
        sa.Column("emotional_valence", sa.Float(), nullable=False, server_default="0"),
        sa.Column("confidence", sa.Float(), nullable=False, server_default="0.7"),
        sa.Column("retention_strength", sa.Float(), nullable=False, server_default="1"),
        sa.Column("half_life_hours", sa.Float(), nullable=False, server_default="168"),
        sa.Column("source_type", sa.Text(), nullable=False),
        sa.Column("source_id", sa.Text(), nullable=False, server_default=""),
        sa.Column("subject_node_ids", postgresql.JSONB(), nullable=False, server_default="[]"),
        sa.Column("visibility", sa.Text(), nullable=False),
        sa.Column("archived", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("supersedes_memory_id", postgresql.UUID(as_uuid=True)),
        sa.CheckConstraint(
            "memory_type IN ('episodic', 'semantic')", name="ck_memory_type"
        ),
        sa.CheckConstraint("salience BETWEEN 0 AND 1", name="ck_memory_salience"),
        sa.CheckConstraint("confidence BETWEEN 0 AND 1", name="ck_memory_confidence"),
    )
    op.create_index(
        "ix_npc_memories_scope_created",
        "npc_memories",
        ["player_profile_id", "world_save_id", "npc_persistent_id", "created_at_real"],
    )
    op.execute(
        "CREATE INDEX ix_npc_memories_embedding_hnsw ON npc_memories "
        "USING hnsw (embedding vector_cosine_ops)"
    )
    op.execute(
        "CREATE VIEW episodic_memories AS SELECT * FROM npc_memories WHERE memory_type = 'episodic'"
    )
    op.execute(
        "CREATE VIEW semantic_memories AS SELECT * FROM npc_memories WHERE memory_type = 'semantic'"
    )
    op.create_table(
        "recall_history",
        sa.Column("recall_id", postgresql.UUID(as_uuid=True), primary_key=True),
        *_scope_columns(),
        sa.Column(
            "memory_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("npc_memories.memory_id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("query_text", sa.Text(), nullable=False),
        sa.Column("vector_similarity", sa.Float(), nullable=False),
        sa.Column("combined_score", sa.Float(), nullable=False),
        sa.Column("recalled_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(
        "ix_recall_history_scope_memory",
        "recall_history",
        ["player_profile_id", "world_save_id", "npc_persistent_id", "memory_id"],
    )
    op.create_table(
        "idempotent_request_responses",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        *_scope_columns(),
        sa.Column("request_id", sa.Text(), nullable=False),
        sa.Column("response_json", postgresql.JSONB(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint(
            "player_profile_id",
            "world_save_id",
            "npc_persistent_id",
            "request_id",
            name="uq_idempotency_scope_request",
        ),
    )
    op.create_table(
        "usage_records",
        sa.Column("usage_id", postgresql.UUID(as_uuid=True), primary_key=True),
        *_scope_columns(),
        sa.Column("request_id", sa.Text(), nullable=False),
        sa.Column("input_tokens", sa.Integer(), nullable=False),
        sa.Column("output_tokens", sa.Integer(), nullable=False),
        sa.Column("cost_usd", sa.Numeric(12, 6), nullable=False),
        sa.Column("usage_day", sa.Date(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint(
            "player_profile_id",
            "world_save_id",
            "npc_persistent_id",
            "request_id",
            name="uq_usage_scope_request",
        ),
    )
    op.create_index(
        "ix_usage_player_day", "usage_records", ["player_profile_id", "usage_day"]
    )
    op.create_table(
        "knowledge_nodes",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("node_id", sa.Text(), nullable=False),
        sa.Column("node_type", sa.Text(), nullable=False),
        sa.Column("player_profile_id", sa.Text()),
        sa.Column("world_save_id", sa.Text()),
        sa.Column("owner_npc_persistent_id", sa.Text()),
        sa.Column("label", sa.Text(), nullable=False, server_default=""),
        sa.Column("metadata", postgresql.JSONB(), nullable=False, server_default="{}"),
        sa.Column("catalog_revision", sa.Text(), nullable=False, server_default=""),
        sa.Column("visibility", sa.Text(), nullable=False),
        sa.Column("source", sa.Text(), nullable=False),
        sa.Column("canonical", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "(canonical AND player_profile_id IS NULL AND world_save_id IS NULL "
            "AND owner_npc_persistent_id IS NULL) OR "
            "(NOT canonical AND player_profile_id IS NOT NULL AND world_save_id IS NOT NULL "
            "AND owner_npc_persistent_id IS NOT NULL)",
            name="ck_knowledge_node_scope",
        ),
    )
    op.execute(
        "CREATE UNIQUE INDEX uq_knowledge_node_scope_id ON knowledge_nodes "
        "(COALESCE(player_profile_id, ''), COALESCE(world_save_id, ''), "
        "COALESCE(owner_npc_persistent_id, ''), node_id)"
    )
    op.create_table(
        "knowledge_edges",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("player_profile_id", sa.Text()),
        sa.Column("world_save_id", sa.Text()),
        sa.Column("owner_npc_persistent_id", sa.Text()),
        sa.Column("subject_node_id", sa.Text(), nullable=False),
        sa.Column("predicate", sa.Text(), nullable=False),
        sa.Column("object_node_id", sa.Text(), nullable=False),
        sa.Column("confidence", sa.Float(), nullable=False),
        sa.Column("visibility", sa.Text(), nullable=False),
        sa.Column("source_type", sa.Text(), nullable=False),
        sa.Column("source_id", sa.Text(), nullable=False, server_default=""),
        sa.Column("catalog_revision", sa.Text(), nullable=False, server_default=""),
        sa.Column("evidence_memory_ids", postgresql.JSONB(), nullable=False, server_default="[]"),
        sa.Column("valid_from", sa.DateTime(timezone=True)),
        sa.Column("valid_until", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("supersedes_edge_id", postgresql.UUID(as_uuid=True)),
        sa.Column("canonical", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.CheckConstraint("confidence BETWEEN 0 AND 1", name="ck_edge_confidence"),
        sa.CheckConstraint(
            "(canonical AND player_profile_id IS NULL AND world_save_id IS NULL "
            "AND owner_npc_persistent_id IS NULL) OR "
            "(NOT canonical AND player_profile_id IS NOT NULL AND world_save_id IS NOT NULL "
            "AND owner_npc_persistent_id IS NOT NULL)",
            name="ck_knowledge_edge_scope",
        ),
    )
    op.execute(
        "CREATE UNIQUE INDEX uq_knowledge_edge_fact ON knowledge_edges "
        "(COALESCE(player_profile_id, ''), COALESCE(world_save_id, ''), "
        "COALESCE(owner_npc_persistent_id, ''), subject_node_id, predicate, object_node_id, source_id)"
    )
    op.create_index(
        "ix_knowledge_edges_scope",
        "knowledge_edges",
        ["player_profile_id", "world_save_id", "owner_npc_persistent_id"],
    )
    op.create_table(
        "sync_revisions",
        *_scope_columns(),
        sa.Column("revision", sa.BigInteger(), nullable=False, server_default="0"),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint(
            "player_profile_id", "world_save_id", "npc_persistent_id", name="pk_sync_revision"
        ),
    )
    op.create_table(
        "outbox_receipts",
        sa.Column("receipt_id", postgresql.UUID(as_uuid=True), primary_key=True),
        *_scope_columns(),
        sa.Column("outbox_kind", sa.Text(), nullable=False),
        sa.Column("entry_id", sa.Text(), nullable=False),
        sa.Column("payload_hash", sa.Text(), nullable=False),
        sa.Column("accepted_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint(
            "player_profile_id",
            "world_save_id",
            "npc_persistent_id",
            "outbox_kind",
            "entry_id",
            name="uq_outbox_receipt_scope_entry",
        ),
    )
    op.create_table(
        "conflict_records",
        sa.Column("conflict_id", postgresql.UUID(as_uuid=True), primary_key=True),
        *_scope_columns(),
        sa.Column("client_revision", sa.BigInteger(), nullable=False),
        sa.Column("server_revision", sa.BigInteger(), nullable=False),
        sa.Column("reason", sa.Text(), nullable=False),
        sa.Column("details", postgresql.JSONB(), nullable=False, server_default="{}"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("resolved_at", sa.DateTime(timezone=True)),
    )
    op.create_index(
        "ix_conflict_records_scope",
        "conflict_records",
        ["player_profile_id", "world_save_id", "npc_persistent_id", "created_at"],
    )


def downgrade() -> None:
    op.drop_table("conflict_records")
    op.drop_table("outbox_receipts")
    op.drop_table("sync_revisions")
    op.drop_table("knowledge_edges")
    op.drop_table("knowledge_nodes")
    op.drop_table("usage_records")
    op.drop_table("idempotent_request_responses")
    op.drop_table("recall_history")
    op.execute("DROP VIEW IF EXISTS semantic_memories")
    op.execute("DROP VIEW IF EXISTS episodic_memories")
    op.drop_table("npc_memories")
    op.drop_table("conversation_turns")
    op.drop_table("conversation_sessions")
    op.drop_table("npc_profile_deployments")
    op.execute("DROP EXTENSION IF EXISTS vector")
