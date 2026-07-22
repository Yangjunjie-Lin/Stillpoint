class_name DialogueCoordinator
extends Node
## Selects and runs dialogues using Conditions and Effects.

signal dialogue_started(npc: NPCController)
signal dialogue_ended

var _runner := DialogueRunner.new()
var _session_context: WorldSessionContext
var _npc: NPCController
var _player: PlayerController3D


func setup(context: WorldSessionContext) -> void:
	_session_context = context
	_runner.line_presented.connect(_on_line)
	_runner.choices_presented.connect(_on_choices)
	_runner.dialogue_finished.connect(_on_finished)


func get_runner() -> DialogueRunner:
	return _runner


func start_dialogue(npc: NPCController, player: PlayerController3D) -> bool:
	if npc == null or player == null:
		return false
	if not npc.can_talk_to(player):
		EventBus.notice_requested.emit("They refuse to speak with you.")
		return false
	_npc = npc
	_player = player
	var dialogue := _resolve_dialogue(npc)
	if dialogue == null:
		return false
	player.set_input_enabled(false)
	npc.set_npc_state(NPCController.NPCState.TALK)
	_runner.start(dialogue, npc, player, _session_context)
	dialogue_started.emit(npc)
	return true


func apply_choice(index: int) -> void:
	_runner.choose(index)


func _resolve_dialogue(npc: NPCController) -> DialogueDefinition:
	var ctx := _session_context
	if npc.npc_definition != null and npc.npc_definition.dialogue_selector != null:
		var selected := npc.npc_definition.dialogue_selector.select(ctx)
		if selected != null:
			return selected
	if npc.npc_definition != null and npc.npc_definition.default_dialogue != null:
		return npc.npc_definition.default_dialogue
	return ResourceRegistry.get_dialogue(npc.character_id)


func _on_line(speaker: String, text: String) -> void:
	EventBus.dialogue_line.emit(speaker, text)


func _on_choices(choices: Array) -> void:
	EventBus.dialogue_choices.emit(choices)


func _on_finished() -> void:
	if _player != null:
		_player.set_input_enabled(true)
	if _npc != null and _npc.npc_state == NPCController.NPCState.TALK:
		_npc.set_npc_state(NPCController.NPCState.FOLLOW_SCHEDULE)
	EventBus.dialogue_finished.emit()
	dialogue_ended.emit()
