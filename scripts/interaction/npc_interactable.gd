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
	if _npc.can_talk_to(actor):
		return true
	if _session == null:
		_session = _find_session()
	return _session != null \
		and _session.cognition_service != null \
		and _session.cognition_service.can_use_free_form(_npc) \
		and _npc.can_engage_free_form(actor)


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
	var actor_id := _get_actor_persistent_id(actor)
	var target_id := _get_npc_persistent_id()
	var intent := TalkIntent.new(actor_id, target_id)
	var proposal := IntentProposal.from_player_input(
		StringName("talk-%d" % Time.get_ticks_usec()),
		actor_id,
		intent,
	)
	var result := _session.submit_interaction_intent(proposal, conditions, effects)
	if not result.is_valid and not result.message.is_empty():
		EventBus.notice_requested.emit(result.message)


func _get_npc_persistent_id() -> StringName:
	for child in _npc.get_children():
		if child is WorldEntityIdentity:
			return (child as WorldEntityIdentity).persistent_id
	return &""


func _get_actor_persistent_id(actor: Node) -> StringName:
	if actor == null:
		return &""
	var actor_identity := actor.get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
	return actor_identity.persistent_id if actor_identity != null else &""


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
