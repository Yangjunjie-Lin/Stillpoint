"""Bind one trusted NPC definition to each deployed NPC instance."""

from __future__ import annotations

from alembic import op

revision = "0002_unique_profile_deployment"
down_revision = "0001_npc_cognition"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        DO $$
        BEGIN
            IF EXISTS (
                SELECT 1
                FROM npc_profile_deployments
                GROUP BY player_profile_id, world_save_id, npc_persistent_id
                HAVING COUNT(DISTINCT npc_definition_id) > 1
            ) THEN
                RAISE EXCEPTION 'npc_profile_deployment_conflict';
            END IF;
        END
        $$
        """
    )
    op.execute(
        """
        DELETE FROM npc_profile_deployments older
        USING npc_profile_deployments newer
        WHERE older.player_profile_id = newer.player_profile_id
          AND older.world_save_id = newer.world_save_id
          AND older.npc_persistent_id = newer.npc_persistent_id
          AND (
              older.deployed_at < newer.deployed_at
              OR (
                  older.deployed_at = newer.deployed_at
                  AND older.deployment_id::text < newer.deployment_id::text
              )
          )
        """
    )
    op.drop_constraint(
        "uq_profile_deployment_scope_revision",
        "npc_profile_deployments",
        type_="unique",
    )
    op.create_unique_constraint(
        "uq_profile_deployment_instance",
        "npc_profile_deployments",
        ["player_profile_id", "world_save_id", "npc_persistent_id"],
    )


def downgrade() -> None:
    op.drop_constraint(
        "uq_profile_deployment_instance",
        "npc_profile_deployments",
        type_="unique",
    )
    op.create_unique_constraint(
        "uq_profile_deployment_scope_revision",
        "npc_profile_deployments",
        [
            "player_profile_id",
            "world_save_id",
            "npc_persistent_id",
            "npc_definition_id",
            "catalog_revision",
        ],
    )
