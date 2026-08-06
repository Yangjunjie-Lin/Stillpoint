class_name DialogueRunner
extends RefCounted

signal line_presented(speaker: String, text: String)
signal choices_presented(choices: Array)
signal dialogue_finished
signal choice_effect_failed(choice: DialogueChoice, reason: String)

var _definition: DialogueDefinition
var _current_node: DialogueNode
var _npc: NPCController
var _player: PlayerController3D
var _available_choices: Array = []
var _session_context: WorldSessionContext
var _applied_choice_effect_ids: Dictionary = {}


func start(
	dialogue: DialogueDefinition,
	npc: NPCController,
	player: PlayerController3D,
	session_context: WorldSessionContext = null,
) -> bool:
	if dialogue == null or player == null:
		return false
	_definition = dialogue
	_npc = npc
	_player = player
	_session_context = session_context
	_applied_choice_effect_ids.clear()
	_current_node = dialogue.get_node(dialogue.start_node_id)
	if _current_node == null:
		return false
	_present_node()
	return true


func choose(index: int) -> EffectResult:
	if _current_node == null:
		dialogue_finished.emit()
		return EffectResult.fail("no active dialogue node")
	if index < 0 or index >= _available_choices.size():
		dialogue_finished.emit()
		return EffectResult.fail("invalid dialogue choice")
	var choice: DialogueChoice = _available_choices[index] as DialogueChoice
	if choice == null:
		dialogue_finished.emit()
		return EffectResult.fail("invalid dialogue choice")
	var effect_result := _apply_choice_effects(choice, index)
	if not effect_result.success:
		choice_effect_failed.emit(choice, effect_result.message)
		return effect_result
	_next_node(choice.next_node_id)
	return EffectResult.ok()


func _present_node() -> void:
	if _current_node == null:
		dialogue_finished.emit()
		return
	if not _evaluate_node_conditions(_current_node):
		dialogue_finished.emit()
		return
	var enter_result := _apply_node_enter_effects(_current_node)
	if not enter_result.success:
		dialogue_finished.emit()
		return
	if _npc != null and _player != null and _current_node.requires_not_attacked:
		if RelationshipService.get_disposition(_npc.character_id) == RelationshipComponent.Disposition.HOSTILE:
			line_presented.emit(_current_node.speaker, "I don't want to talk to you.")
			_apply_node_exit_effects(_current_node)
			dialogue_finished.emit()
			return
	for line in _current_node.lines:
		line_presented.emit(_current_node.speaker, line)
	if not _current_node.choices.is_empty():
		_available_choices.clear()
		for choice in _current_node.choices:
			if choice == null:
				continue
			if not _evaluate_choice_conditions(choice):
				continue
			_available_choices.append(choice)
		choices_presented.emit(_available_choices)
		return
	_next_node(_current_node.next_node_id)


func _next_node(node_id: StringName) -> void:
	if _current_node != null:
		var exit_result := _apply_node_exit_effects(_current_node)
		if not exit_result.success:
			push_warning(
				"DialogueRunner: required exit effects failed for node '%s': %s"
				% [String(_current_node.id), exit_result.message]
			)
	if node_id == &"":
		dialogue_finished.emit()
		return
	_current_node = _definition.get_node(node_id)
	if _current_node == null:
		dialogue_finished.emit()
		return
	_present_node()


func _evaluate_node_conditions(node: DialogueNode) -> bool:
	if _session_context == null or node.conditions.is_empty():
		return true
	for cond in node.conditions:
		if cond != null and not cond.evaluate(_session_context):
			return false
	return true


func _evaluate_choice_conditions(choice: DialogueChoice) -> bool:
	if choice.requires_not_hostile and _npc != null:
		if RelationshipService.get_disposition(_npc.character_id) == RelationshipComponent.Disposition.HOSTILE:
			return false
	if _npc != null and RelationshipService.get_affinity(_npc.character_id) < choice.required_affinity:
		return false
	if _session_context == null or choice.conditions.is_empty():
		return true
	for cond in choice.conditions:
		if cond != null and not cond.evaluate(_session_context):
			return false
	return true


func _apply_choice_effects(choice: DialogueChoice, choice_index: int) -> EffectResult:
	var talk_event := _make_npc_talked_event()
	var choice_session_context := _session_context
	if talk_event != null and _session_context != null:
		choice_session_context = _session_context.with_event(talk_event)
	var ctx := WorldEffectContext.new(choice_session_context)
	if talk_event != null:
		ctx.source_entity_id = talk_event.source_entity_id
		ctx.target_entity_id = talk_event.target_entity_id
	var effect_result := WorldEffect.apply_sequence_once(
		choice.effects,
		ctx,
		_applied_choice_effect_ids,
		StringName("dialogue/%s/%s/choice_%d" % [
			String(_definition.id), String(_current_node.id), choice_index,
		]),
	)
	if not effect_result.success:
		return effect_result
	# Affinity is committed with the choice only after required effects succeed, so
	# retrying a blocked choice cannot stack affinity changes.
	if choice.affinity_delta != 0.0 and _npc != null:
		RelationshipService.change_affinity(_npc.character_id, choice.affinity_delta, &"dialogue")
	return EffectResult.ok()


func _make_npc_talked_event() -> GameplayEvent:
	if _npc == null or _player == null:
		return null
	var region_id := RegionIdUtil.normalize(_npc.region_id)
	if _session_context != null:
		if _session_context.region_service != null:
			region_id = _session_context.region_service.resolve_entity_region(_npc)
		elif region_id == &"":
			region_id = _session_context.get_current_region_id()
	return GameplayEvent.make(
		GameplayEventTypes.NPC_TALKED,
		_get_persistent_id(_player),
		_get_persistent_id(_npc),
		_npc.character_id,
		region_id,
	)


func _apply_node_enter_effects(node: DialogueNode) -> EffectResult:
	if _session_context == null:
		return EffectResult.ok()
	var ctx := WorldEffectContext.new(_session_context)
	return WorldEffect.apply_sequence(node.enter_effects, ctx)


func _apply_node_exit_effects(node: DialogueNode) -> EffectResult:
	if _session_context == null:
		return EffectResult.ok()
	var ctx := WorldEffectContext.new(_session_context)
	return WorldEffect.apply_sequence(node.exit_effects, ctx)


func _get_persistent_id(actor: Node) -> StringName:
	for child in actor.get_children():
		if child is WorldEntityIdentity:
			return (child as WorldEntityIdentity).persistent_id
	return &""
