class_name TransitionPortal
extends Interactable

@export var target_region_id: StringName = &"base:wilderness"
@export var target_spawn_id: StringName = &"spawn"
@export var prompt_text: String = "Enter"
@export var identity: WorldEntityIdentity
@export var conditions: Array[WorldCondition] = []
@export var effects: Array[WorldEffect] = []

var _session: WorldSession


func _ready() -> void:
	_session = _find_session()


func can_interact(actor: CharacterController, _context: InteractionContext) -> bool:
	return actor is PlayerController3D


func get_interaction_text(_actor: CharacterController) -> String:
	return prompt_text


func interact(actor: CharacterController, _context: InteractionContext) -> void:
	if _session == null:
		_session = _find_session()
	if _session == null:
		return
	var session_ctx := _session.get_session_context()
	for cond in conditions:
		if cond != null and not cond.evaluate(session_ctx):
			return
	var effect_ctx := WorldEffectContext.new(session_ctx)
	WorldEffect.apply_sequence(effects, effect_ctx)
	_session.transition_to(target_region_id, target_spawn_id)


func _find_session() -> WorldSession:
	var node := get_parent()
	while node != null:
		if node is WorldSession:
			return node as WorldSession
		node = node.get_parent()
	return null
