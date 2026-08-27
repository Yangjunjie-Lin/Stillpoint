class_name NPCDefinition
extends CharacterDefinition

@export var npc_role: StringName = &"villager"
@export var home_region_id: StringName = &"base:town"
@export var home_marker_id: StringName = &"home"
@export var shop_id: StringName = &""
@export var witness_radius: float = 12.0
@export_group("Economic Actor Setup")
## Authored initialization only; mutable runtime state lives on actor components.
@export var job_id: StringName = &""
@export var worksite_id: StringName = &""
@export_range(0, 1000000, 1) var starting_wallet_balance: int = 0
@export var starting_inventory_item_ids: Array[StringName] = []
@export var starting_equipment_item_ids: Array[StringName] = []
@export_range(0, 1000000, 1) var minimum_wallet_reserve: int = 0
@export_group("Combat Rewards")
@export_range(0, 100000, 1) var experience_reward: int = 0
@export var loot_table: LootTableDefinition
@export_group("")
@export var dialogue_selector: DialogueSelectorDefinition
## Authored cognitive identity. Runtime memories are kept in the cognition service.
@export var mind_profile: NPCMindDefinition

@export_group("Dungeon Progression")
## Non-empty for a boss whose defeat is temporary and scheduled to return.
@export var dungeon_boss_id: StringName = &""
@export_range(0, 99, 1) var dungeon_depth: int = 0
@export_range(1, 99, 1) var dungeon_required_level: int = 1
@export_range(1, 365, 1) var dungeon_respawn_days: int = 3
@export var dungeon_phase: StringName = &""
