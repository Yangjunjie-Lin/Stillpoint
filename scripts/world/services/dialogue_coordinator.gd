class_name DialogueCoordinator
extends Node
## Selects and runs dialogues using Conditions and Effects.

signal dialogue_started(npc: NPCController)
signal dialogue_ended
signal choice_effect_failed(reason: String)

var _runner := DialogueRunner.new()
var _session_context: WorldSessionContext
var _npc: NPCController
var _player: PlayerController3D
var _npc_state_before_dialogue: NPCController.NPCState = NPCController.NPCState.IDLE
var _player_input_before_dialogue: bool = true
var _cognition_service: NPCCognitionService
var _free_form_npc: NPCController
var _free_form_player: PlayerController3D


func setup(context: WorldSessionContext) -> void:
	_session_context = context
	_runner.line_presented.connect(_on_line)
	_runner.choices_presented.connect(_on_choices)
	_runner.dialogue_finished.connect(_on_finished)
	_runner.choice_effect_failed.connect(_on_choice_effect_failed)


func get_runner() -> DialogueRunner:
	return _runner


func start_dialogue(npc: NPCController, player: PlayerController3D) -> bool:
	if npc == null or player == null:
		return false
	if not npc.can_talk_to(player):
		EventBus.notice_requested.emit("They refuse to speak with you.")
		return false
	var dialogue := _resolve_dialogue(npc)
	if dialogue == null:
		return false
	_npc = npc
	_player = player
	_npc_state_before_dialogue = npc.npc_state
	_player_input_before_dialogue = player.state.input_enabled
	player.set_input_enabled(false)
	npc.set_npc_state(NPCController.NPCState.TALK)
	if not _runner.start(dialogue, npc, player, _session_context):
		_restore_actor_state()
		_npc = null
		_player = null
		return false
	dialogue_started.emit(npc)
	return true


func apply_choice(index: int) -> EffectResult:
	return _runner.choose(index)


func start_free_form_dialogue(
	npc: NPCController,
	player: PlayerController3D,
	text: String,
	player_profile_id: String = "player-001",
	world_save_id: String = "slot-01",
	session_id: String = "",
) -> bool:
	## Optional AI path. Authored/quest dialogue continues through start_dialogue.
	if not bool(SaveService.settings.get("ai_dialogue_enabled", false)):
		return false
	_ensure_cognition_service()
	if _cognition_service == null or not _cognition_service.can_use_free_form(npc):
		return false
	if player == null or text.strip_edges().is_empty() or not npc.can_talk_to(player):
		return false
	_free_form_npc = npc
	_free_form_player = player
	_player_input_before_dialogue = player.state.input_enabled
	player.set_input_enabled(false)
	npc.set_npc_state(NPCController.NPCState.TALK)
	var persistent_id := str(npc.get("persistent_id"))
	if persistent_id.is_empty():
		persistent_id = str(npc.character_id)
	var payload := {
		"request_id": "%s-%s" % [session_id if not session_id.is_empty() else "turn", Time.get_ticks_usec()],
		"player_profile_id": player_profile_id,
		"world_save_id": world_save_id,
		"npc_definition_id": String(npc.npc_definition.id),
		"npc_persistent_id": persistent_id,
		"session_id": session_id if not session_id.is_empty() else persistent_id,
		"text": text,
		"locale": "en",
		"world_context": {"region_id": String(npc.region_id), "game_time": WorldTimeService.to_dict()},
	}
	if not _cognition_service.conversation_controller.ask(npc, payload):
		_restore_free_form_state()
		return false
	return true


func _ensure_cognition_service() -> void:
	if _cognition_service != null:
		return
	_cognition_service = NPCCognitionService.new()
	add_child(_cognition_service)
	_cognition_service.conversation_controller.reply_ready.connect(_on_free_form_reply)


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
	_restore_actor_state()
	EventBus.dialogue_finished.emit()
	dialogue_ended.emit()
	_npc = null
	_player = null


func _on_choice_effect_failed(_choice: DialogueChoice, reason: String) -> void:
	choice_effect_failed.emit(reason)
	EventBus.notice_requested.emit("Dialogue choice failed: %s" % reason)


func _restore_actor_state() -> void:
	if _player != null and is_instance_valid(_player):
		_player.set_input_enabled(_player_input_before_dialogue)
	if _npc != null and is_instance_valid(_npc) \
		and _npc.npc_state == NPCController.NPCState.TALK:
		_npc.set_npc_state(_npc_state_before_dialogue)


func _on_free_form_reply(reply: Dictionary) -> void:
	var speaker: String = str(_free_form_npc.get("display_name")) if _free_form_npc != null else "NPC"
	EventBus.dialogue_line.emit(speaker, str(reply.get("reply_text", "Let's speak later.")))
	EventBus.dialogue_finished.emit()
	_restore_free_form_state()


func _restore_free_form_state() -> void:
	if _free_form_player != null and is_instance_valid(_free_form_player):
		_free_form_player.set_input_enabled(_player_input_before_dialogue)
	if _free_form_npc != null and is_instance_valid(_free_form_npc) and _free_form_npc.npc_state == NPCController.NPCState.TALK:
		_free_form_npc.set_npc_state(NPCController.NPCState.IDLE)
	_free_form_npc = null
	_free_form_player = null
