class_name PickupInteractable3D
extends Interactable

@export var item_id: StringName = &"herb"
@export var quantity: int = 1
@export var identity: WorldEntityIdentity
@export var conditions: Array[WorldCondition] = []
@export var effects: Array[WorldEffect] = []

var _collected: bool = false
var _session: WorldSession


func _ready() -> void:
	_session = _find_session()
	if identity == null:
		identity = get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity


func can_interact(actor: CharacterController, context: InteractionContext) -> bool:
	return not _collected and super.can_interact(actor, context) and actor is PlayerController3D


func get_interaction_text(_actor: CharacterController) -> String:
	return "Pick Up"


func interact(actor: CharacterController, _context: InteractionContext) -> void:
	if _collected:
		return
	var player := actor as PlayerController3D
	if player == null or player.inventory == null:
		return
	if item_id == &"" or quantity <= 0 or not player.inventory.can_add_item(item_id, quantity):
		EventBus.notice_requested.emit("Backpack is full.")
		return
	if _session == null:
		_session = _find_session()
	var session_ctx: WorldSessionContext = null
	if _session != null:
		session_ctx = _session.get_session_context()
	if session_ctx != null:
		for cond in conditions:
			if cond != null and not cond.evaluate(session_ctx):
				return
		var effect_ctx := WorldEffectContext.new(session_ctx)
		if identity != null:
			effect_ctx.source_entity_id = identity.persistent_id
		var effect_result := WorldEffect.apply_sequence(effects, effect_ctx)
		if not effect_result.success:
			EventBus.notice_requested.emit("Pickup effect failed: %s" % effect_result.message)
			return
	var inventory_before := player.inventory.to_dict()
	if player.inventory.add_item(item_id, quantity) != quantity:
		player.inventory.from_dict(inventory_before)
		EventBus.notice_requested.emit("Could not pick up item.")
		return
	_collected = true
	interaction_enabled = false
	visible = false
	if session_ctx != null and _session != null:
		player.practice_skill(&"foraging", &"gather_wild_resource", item_id)
		var ev := GameplayEvent.make(
			GameplayEventTypes.ITEM_COLLECTED,
			&"base:player/main",
			identity.persistent_id if identity != null else &"",
			item_id,
			region_id,
			float(quantity),
		)
		_session.event_bus.emit_event(ev)
		if identity != null and _session.entity_repository != null:
			_session.entity_repository.mark_dirty(identity.persistent_id)


func to_dict() -> Dictionary:
	return {"collected": _collected}


func from_dict(data: Dictionary) -> void:
	_collected = bool(data.get("collected", false))
	visible = not _collected
	interaction_enabled = not _collected


func get_persistence_key() -> StringName:
	return &"pickup"


func capture_state() -> Dictionary:
	return to_dict()


func restore_state(data: Dictionary) -> void:
	from_dict(data)


func get_state_version() -> int:
	return 1


func _find_session() -> WorldSession:
	var node := get_parent()
	while node != null:
		if node is WorldSession:
			return node as WorldSession
		node = node.get_parent()
	var tree := get_tree()
	if tree != null:
		return tree.get_first_node_in_group("world_manager") as WorldSession
	return null
