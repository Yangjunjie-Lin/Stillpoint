CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS conversation_sessions (
  session_id uuid PRIMARY KEY, player_profile_id text NOT NULL, world_save_id text NOT NULL,
  npc_persistent_id text NOT NULL, npc_definition_id text NOT NULL, started_at timestamptz NOT NULL,
  last_active_at timestamptz NOT NULL, title text NOT NULL DEFAULT '', rolling_summary text NOT NULL DEFAULT '',
  UNIQUE (player_profile_id, world_save_id, npc_persistent_id, session_id)
);
CREATE TABLE IF NOT EXISTS conversation_turns (
  turn_id uuid PRIMARY KEY, session_id uuid NOT NULL REFERENCES conversation_sessions(session_id),
  role text NOT NULL, text text NOT NULL, created_at_real timestamptz NOT NULL, occurred_at_game jsonb NOT NULL,
  region_id text NOT NULL DEFAULT '', emotion text NOT NULL DEFAULT 'neutral', token_usage jsonb NOT NULL DEFAULT '{}', request_id uuid NOT NULL UNIQUE
);
CREATE TABLE IF NOT EXISTS npc_memories (
  memory_id uuid PRIMARY KEY, player_profile_id text NOT NULL, world_save_id text NOT NULL,
  owner_npc_persistent_id text NOT NULL, session_id uuid, memory_type text NOT NULL, content text NOT NULL,
  summary text NOT NULL DEFAULT '', embedding vector(1536), occurred_at_game jsonb NOT NULL DEFAULT '{}',
  created_at_real timestamptz NOT NULL, last_recalled_at timestamptz, recall_count integer NOT NULL DEFAULT 0,
  salience real NOT NULL DEFAULT .5, emotional_valence real NOT NULL DEFAULT 0, confidence real NOT NULL DEFAULT .7,
  retention_strength real NOT NULL DEFAULT 1, half_life_hours real NOT NULL DEFAULT 168, source_type text NOT NULL,
  source_id text NOT NULL DEFAULT '', subject_node_ids jsonb NOT NULL DEFAULT '[]', visibility text NOT NULL,
  archived boolean NOT NULL DEFAULT false, supersedes_memory_id uuid
);
CREATE INDEX IF NOT EXISTS npc_memories_scope_idx ON npc_memories(player_profile_id, world_save_id, owner_npc_persistent_id);
CREATE TABLE IF NOT EXISTS knowledge_nodes (node_id text PRIMARY KEY, node_type text NOT NULL, label text NOT NULL DEFAULT '', metadata jsonb NOT NULL DEFAULT '{}');
CREATE TABLE IF NOT EXISTS knowledge_edges (
  id uuid PRIMARY KEY, owner_npc_persistent_id text, subject_node_id text NOT NULL REFERENCES knowledge_nodes(node_id),
  predicate text NOT NULL, object_node_id text NOT NULL REFERENCES knowledge_nodes(node_id), confidence real NOT NULL,
  visibility text NOT NULL, source_type text NOT NULL, source_id text NOT NULL DEFAULT '', evidence_memory_ids jsonb NOT NULL DEFAULT '[]',
  valid_from timestamptz, valid_until timestamptz, created_at timestamptz NOT NULL, updated_at timestamptz NOT NULL, supersedes_edge_id uuid
);
