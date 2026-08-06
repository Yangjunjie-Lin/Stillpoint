"""NPC cognition relational schema (PostgreSQL + optional pgvector)."""

revision = "0001_npc_cognition"
down_revision = None


def upgrade() -> None:
    # The executable SQL is kept in schema.sql so deployments can use either
    # Alembic or a reviewed migration runner without changing the model.
    pass


def downgrade() -> None:
    pass
