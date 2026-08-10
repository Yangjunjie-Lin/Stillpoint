class_name LootDropInteractable3D
extends Interactable
## A pre-authored persistent dungeon loot slot activated by one enemy defeat.

@export var source_enemy_persistent_id: StringName = &""
@export var identity: WorldEntityIdentity

var _active: bool = false
var _collected: bool = false
var _item_id: StringName = &""
var _quantity: int = 0
var _session: WorldSession
var _visual: Node3D
var _visual_base_y: float = 0.35
var _motion_time: float = 0.0


func _ready() -> void:
	interaction_priority = 24
	_session = _find_session()
	if identity == null:
		identity = get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
	_refresh_state()


func _process(delta: float) -> void:
	if not _active or _collected or _visual == null:
		return
	_motion_time += maxf(0.0, delta)
	_visual.position.y = _visual_base_y + sin(_motion_time * 2.4) * 0.08
	_visual.rotation.y += delta * 0.7


func activate(item_id: StringName, quantity: int, position_: Vector3) -> bool:
	if _active or _collected or item_id == &"" or quantity <= 0:
		return false
	var definition := ResourceRegistry.get_item(item_id)
	if definition == null or definition.equip_slot == ItemDefinition.EquipSlot.NONE:
		return false
	_item_id = item_id
	_quantity = quantity
	_active = true
	global_position = position_
	_refresh_state()
	_mark_dirty()
	return true


func can_interact(actor: CharacterController, context: InteractionContext) -> bool:
	return (
		_active
		and not _collected
		and actor is PlayerController3D
		and super.can_interact(actor, context)
	)


func get_interaction_text(_actor: CharacterController) -> String:
	var definition := ResourceRegistry.get_item(_item_id)
	return "Pick up %s" % (
		definition.display_name if definition != null else String(_item_id)
	)


func interact(actor: CharacterController, _context: InteractionContext) -> void:
	if not _active or _collected:
		return
	var player := actor as PlayerController3D
	if player == null or player.inventory == null:
		return
	if not player.inventory.can_add_item(_item_id, _quantity):
		EventBus.notice_requested.emit("Backpack is full; the equipment remains here.")
		return
	if player.inventory.add_item(_item_id, _quantity) != _quantity:
		EventBus.notice_requested.emit("Could not collect dungeon equipment.")
		return
	_collected = true
	_refresh_state()
	_mark_dirty()
	var definition := ResourceRegistry.get_item(_item_id)
	EventBus.notice_requested.emit("Loot acquired: %s." % [
		definition.display_name if definition != null else String(_item_id),
	])
	if _session != null and _session.event_bus != null:
		_session.event_bus.emit_event(GameplayEvent.make(
			GameplayEventTypes.ITEM_COLLECTED,
			&"base:player/main",
			identity.persistent_id if identity != null else &"",
			_item_id,
			region_id,
			float(_quantity),
		))


func is_active_drop() -> bool:
	return _active and not _collected


func is_collected() -> bool:
	return _collected


func get_item_id() -> StringName:
	return _item_id


func get_persistence_key() -> StringName:
	return &"loot_drop"


func capture_state() -> Dictionary:
	return {
		"active": _active,
		"collected": _collected,
		"item_id": String(_item_id),
		"quantity": _quantity,
	}


func restore_state(data: Dictionary) -> void:
	_active = bool(data.get("active", false))
	_collected = bool(data.get("collected", false))
	_item_id = StringName(str(data.get("item_id", "")))
	_quantity = maxi(0, int(data.get("quantity", 0)))
	if _item_id == &"" or _quantity <= 0:
		_active = false
	_refresh_state()


func get_state_version() -> int:
	return 1


func _refresh_state() -> void:
	visible = _active and not _collected
	interaction_enabled = visible
	set_process(visible)
	_build_visual()


func _build_visual() -> void:
	if _visual != null and is_instance_valid(_visual):
		_visual.free()
		_visual = null
	if not visible:
		return
	var definition := ResourceRegistry.get_item(_item_id)
	if definition == null:
		return
	_visual = ItemVisualFactory.create_model(definition)
	_visual.name = "DroppedEquipmentModel"
	_visual.scale = Vector3.ONE * 0.48
	_visual.position = Vector3(0.0, _visual_base_y, 0.0)
	add_child(_visual)
	set_meta("ontology_id", "item:%s" % String(_item_id))
	set_meta("loot_rarity", String(definition.rarity))


func _mark_dirty() -> void:
	if _session == null:
		_session = _find_session()
	if _session != null and identity != null and _session.entity_repository != null:
		_session.entity_repository.mark_dirty(identity.persistent_id)
		_session.save_coordinator.mark_region_dirty(region_id)


func _find_session() -> WorldSession:
	var node := get_parent()
	while node != null:
		if node is WorldSession:
			return node as WorldSession
		node = node.get_parent()
	var tree := get_tree()
	return tree.get_first_node_in_group("world_manager") as WorldSession if tree != null else null
