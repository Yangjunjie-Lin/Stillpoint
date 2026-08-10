class_name DungeonProgressionService
extends Node
## Grants player-owned dungeon rewards exactly once per persistent enemy death.

@export var dungeon_region_id: StringName = &"base:dungeon"

var _session: WorldSession
var _actor_factory: ActorFactory
var _rewarded_enemy_ids: Dictionary = {}


func setup(session: WorldSession, actor_factory: ActorFactory) -> void:
	_session = session
	_actor_factory = actor_factory
	if (
		_actor_factory != null
		and not _actor_factory.actor_spawned.is_connected(_on_actor_spawned)
	):
		_actor_factory.actor_spawned.connect(_on_actor_spawned)


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
