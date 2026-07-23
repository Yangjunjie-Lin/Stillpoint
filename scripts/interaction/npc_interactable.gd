class_name NPCInteractable
extends Interactable

@export var npc_path: NodePath
@export var identity: WorldEntityIdentity
@export var conditions: Array[WorldCondition] = []
@export var effects: Array[WorldEffect] = []

var _npc: NPCController
var _session: WorldSession


func _ready() -> void:
	if npc_path != NodePath():
		_npc = get_node_or_null(npc_path) as NPCController
	_session = _find_session()
	if _npc != null:
		region_id = _npc.region_id


func can_interact(actor: CharacterController, context: InteractionContext) -> bool:
	if not super.can_interact(actor, context):
		return false
	if _npc == null:
		return false
	return _npc.can_talk_to(actor)


func get_interaction_text(_actor: CharacterController) -> String:
	if _npc != null and _npc.definition != null:
		return "Talk to %s" % _npc.definition.display_name
	return "Talk"


func get_priority(_actor: CharacterController) -> int:
	return 10


func interact(actor: CharacterController, _context: InteractionContext) -> void:
	if _session == null:
		_session = _find_session()
	if _session == null or _npc == null:
		return
	var session_ctx := _session.get_session_context()
	for cond in conditions:
		if cond != null and not cond.evaluate(session_ctx):
			return
	var effect_ctx := WorldEffectContext.new(session_ctx)
	WorldEffect.apply_sequence(effects, effect_ctx)
	_session.start_dialogue(_npc)
	var ev := GameplayEvent.make(
		GameplayEventTypes.NPC_TALKED,
		&"base:player/main",
		_get_npc_persistent_id(),
		_npc.character_id,
		region_id,
	)
	_session.event_bus.emit_event(ev)


func _get_npc_persistent_id() -> StringName:
	for child in _npc.get_children():
		if child is WorldEntityIdentity:
			return (child as WorldEntityIdentity).persistent_id
	return &""


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
