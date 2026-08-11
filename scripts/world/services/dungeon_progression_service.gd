class_name DungeonProgressionService
extends Node
## Owns dungeon XP/loot, guarded depth travel, and persistent timed boss returns.

@export var dungeon_region_id: StringName = &"base:dungeon"
@export var dungeon_id: StringName = &"returning_stars_hollow"

const CUSTOM_STATE_KEY := "dungeon_progression"
const DEPTH_LEVELS := {1: 1, 2: 3, 3: 5}

var _session: WorldSession
var _actor_factory: ActorFactory
var _rewarded_enemy_ids: Dictionary = {}
var _boss_states: Dictionary = {}


func setup(session: WorldSession, actor_factory: ActorFactory) -> void:
	_session = session
	_actor_factory = actor_factory
	if (
		_actor_factory != null
		and not _actor_factory.actor_spawned.is_connected(_on_actor_spawned)
	):
		_actor_factory.actor_spawned.connect(_on_actor_spawned)
	if not WorldTimeService.day_changed.is_connected(_on_day_changed):
		WorldTimeService.day_changed.connect(_on_day_changed)
	if (
		_session != null
		and _session.region_service != null
		and not _session.region_service.region_loaded.is_connected(_on_region_loaded)
	):
		_session.region_service.region_loaded.connect(_on_region_loaded)


func can_enter_depth(player: PlayerController3D, depth: int) -> bool:
	if player == null or player.experience == null or not DEPTH_LEVELS.has(depth):
		return false
	return player.experience.level >= int(DEPTH_LEVELS[depth])


func required_level_for_depth(depth: int) -> int:
	return int(DEPTH_LEVELS.get(depth, 99))


func travel_to_depth(depth: int) -> bool:
	if _session == null or not can_enter_depth(_session.player, depth):
		EventBus.notice_requested.emit(
			"The Warden requires combat level %d for depth %d."
			% [required_level_for_depth(depth), depth]
		)
		return false
	_session.transition_to(dungeon_region_id, StringName("depth_%d" % depth))
	return true


func get_boss_state(persistent_id: StringName) -> Dictionary:
	return (_boss_states.get(String(persistent_id), {}) as Dictionary).duplicate(true)


func get_boss_status_line() -> String:
	var dungeon := ResourceRegistry.get_dungeon(dungeon_id)
	if dungeon == null:
		return ""
	var statuses: Array[String] = []
	for definition_id in dungeon.boss_definition_ids:
		var definition := ResourceRegistry.get_npc(definition_id)
		if definition == null:
			continue
		var persistent_id := StringName("%s/boss/%s_0001" % [String(dungeon_region_id), String(definition.dungeon_boss_id)])
		var state := get_boss_state(persistent_id)
		var next_day := int(state.get("next_respawn_day", 0))
		if next_day > 0:
			statuses.append("%s returns D%d" % [definition.display_name, next_day])
		else:
			statuses.append("%s active" % definition.display_name)
	return " · ".join(statuses)


func _on_actor_spawned(actor: CharacterController) -> void:
	if not _is_reward_enemy(actor):
		return
	var callback := Callable(self, "_on_enemy_defeated").bind(actor)
	if not actor.died_permanently.is_connected(callback):
		actor.died_permanently.connect(callback)


func _on_enemy_defeated(source: Node, actor: CharacterController) -> void:
	if _session == null or _session.player == null or not _source_is_player(source):
		return
	if not _is_reward_enemy(actor):
		return
	var identity := actor.get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
	if identity == null or identity.persistent_id == &"":
		return
	if _rewarded_enemy_ids.has(identity.persistent_id):
		return
	_rewarded_enemy_ids[identity.persistent_id] = true
	var definition := actor.definition as NPCDefinition
	if definition.dungeon_boss_id != &"":
		_record_boss_defeat(identity.persistent_id, definition)
	var levels := _session.player.grant_combat_experience(definition.experience_reward)
	var loot_result: Dictionary = {}
	if definition.loot_table != null:
		loot_result = definition.loot_table.roll_one(
			_session.player.get_combat_level(),
			String(identity.persistent_id),
		)
	var dropped_name := ""
	if not loot_result.is_empty():
		var item_id := StringName(str(loot_result.get("item_id", "")))
		var quantity := maxi(1, int(loot_result.get("quantity", 1)))
		var drop := _find_drop_for(identity.persistent_id)
		if drop != null and drop.activate(item_id, quantity, actor.global_position):
			var item_definition := ResourceRegistry.get_item(item_id)
			dropped_name = (
				item_definition.display_name
				if item_definition != null else String(item_id)
			)
	if _session.save_coordinator != null:
		_session.save_coordinator.mark_dirty(&"player")
		_session.save_coordinator.mark_region_dirty(dungeon_region_id)
	var message := "Defeated %s: +%d XP" % [
		definition.display_name,
		definition.experience_reward,
	]
	if not dropped_name.is_empty():
		message += " · dropped %s" % dropped_name
	if levels > 0:
		message += " · LEVEL UP"
	EventBus.notice_requested.emit(message)


func _record_boss_defeat(persistent_id: StringName, definition: NPCDefinition) -> void:
	var key := String(persistent_id)
	var state: Dictionary = _boss_states.get(key, {})
	state["boss_id"] = String(definition.dungeon_boss_id)
	state["definition_id"] = String(definition.id)
	state["depth"] = definition.dungeon_depth
	state["defeats"] = int(state.get("defeats", 0)) + 1
	state["last_defeated_day"] = WorldTimeService.day
	state["next_respawn_day"] = WorldTimeService.day + definition.dungeon_respawn_days
	_boss_states[key] = state
	_store_state_in_region_chunk()
	EventBus.notice_requested.emit(
		"%s will reform on Day %d."
		% [definition.display_name, int(state["next_respawn_day"])]
	)


func _is_reward_enemy(actor: CharacterController) -> bool:
	if actor == null or RegionIdUtil.normalize(actor.region_id) != dungeon_region_id:
		return false
	if not actor.definition is NPCDefinition:
		return false
	var definition := actor.definition as NPCDefinition
	return (
		definition.npc_role == &"enemy"
		and definition.can_be_killed
		and definition.experience_reward > 0
	)


func _on_region_loaded(region_id: StringName, _region_root: Node3D) -> void:
	if RegionIdUtil.normalize(region_id) != dungeon_region_id:
		return
	_load_state_from_region_chunk()
	_respawn_due_bosses(WorldTimeService.day)


func _on_day_changed(day: int) -> void:
	_respawn_due_bosses(day)


func _respawn_due_bosses(day: int) -> void:
	if _session == null or _session.region_service == null:
		return
	var changed := false
	for key in _boss_states.keys():
		var state: Dictionary = _boss_states[key]
		var respawn_day := int(state.get("next_respawn_day", 0))
		if respawn_day <= 0 or day < respawn_day:
			continue
		var persistent_id := StringName(str(key))
		if _session.region_service.get_current_region_id() == dungeon_region_id:
			var actor := _session.region_service.respawn_authored_actor(persistent_id)
			if actor == null:
				continue
			var drop := _find_drop_for(persistent_id)
			if drop != null:
				drop.reset_for_respawn()
		else:
			_session.entity_repository.clear_snapshot(persistent_id)
			_forget_cached_boss_snapshot(persistent_id)
		state["next_respawn_day"] = 0
		state["last_respawn_day"] = day
		_boss_states[key] = state
		_rewarded_enemy_ids.erase(persistent_id)
		changed = true
		EventBus.notice_requested.emit("A guardian has reformed in the Hollow of Returning Stars.")
	if changed:
		_store_state_in_region_chunk()


func _forget_cached_boss_snapshot(persistent_id: StringName) -> void:
	if _session == null or _session.region_service == null:
		return
	var chunk := _session.region_service.get_region_chunk(dungeon_region_id)
	if chunk.is_empty():
		return
	var entities: Dictionary = chunk.get("entities", {})
	entities.erase(String(persistent_id))
	chunk["entities"] = entities
	var destroyed: Array = chunk.get("destroyed_entities", [])
	destroyed.erase(String(persistent_id))
	chunk["destroyed_entities"] = destroyed
	_session.region_service.set_region_chunk(dungeon_region_id, chunk)


func _load_state_from_region_chunk() -> void:
	if _session == null or _session.region_service == null:
		return
	var chunk := _session.region_service.get_region_chunk(dungeon_region_id)
	var custom: Dictionary = chunk.get("custom_state", {})
	var stored: Variant = custom.get(CUSTOM_STATE_KEY, {})
	if typeof(stored) == TYPE_DICTIONARY:
		_boss_states = (stored as Dictionary).duplicate(true)


func _store_state_in_region_chunk() -> void:
	if _session == null or _session.region_service == null:
		return
	var chunk := _session.region_service.get_region_chunk(dungeon_region_id)
	if chunk.is_empty():
		chunk = {
			"region_id": String(dungeon_region_id),
			"region_state_version": 1,
			"entities": {},
			"destroyed_entities": [],
			"spawn_states": {},
			"custom_state": {},
		}
	var custom: Dictionary = chunk.get("custom_state", {})
	custom[CUSTOM_STATE_KEY] = _boss_states.duplicate(true)
	chunk["custom_state"] = custom
	_session.region_service.set_region_chunk(dungeon_region_id, chunk)
	if _session.save_coordinator != null:
		_session.save_coordinator.mark_region_dirty(dungeon_region_id)


func _source_is_player(source: Node) -> bool:
	var node := source
	while node != null:
		if node == _session.player:
			return true
		node = node.get_parent()
	return false


func _find_drop_for(enemy_persistent_id: StringName) -> LootDropInteractable3D:
	if _session == null or _session.region_service == null:
		return null
	var root := _session.region_service.get_current_region_root()
	return _find_drop_recursive(root, enemy_persistent_id)


func _find_drop_recursive(
	node: Node,
	enemy_persistent_id: StringName,
) -> LootDropInteractable3D:
	if node == null:
		return null
	if node is LootDropInteractable3D:
		var drop := node as LootDropInteractable3D
		if drop.source_enemy_persistent_id == enemy_persistent_id:
			return drop
	for child in node.get_children():
		var found := _find_drop_recursive(child, enemy_persistent_id)
		if found != null:
			return found
	return null
