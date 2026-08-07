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
var _free_form_npc_previous_state: NPCController.NPCState = NPCController.NPCState.IDLE


func setup(context: WorldSessionContext, cognition_service: NPCCognitionService = null) -> void:
	_session_context = context
	_cognition_service = cognition_service
	if _cognition_service != null \
		and not _cognition_service.conversation_controller.reply_ready.is_connected(_on_free_form_reply):
		_cognition_service.conversation_controller.reply_ready.connect(_on_free_form_reply)
	_runner.line_presented.connect(_on_line)
	_runner.choices_presented.connect(_on_choices)
	_runner.dialogue_finished.connect(_on_finished)
	_runner.choice_effect_failed.connect(_on_choice_effect_failed)


func get_runner() -> DialogueRunner:
	return _runner


func get_active_npc() -> NPCController:
	return _npc


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
	_player_profile_id: String = "",
	_world_save_id: String = "",
	_session_id: String = "",
) -> bool:
	## Optional AI path. Authored/quest dialogue continues through start_dialogue.
	if not bool(SaveService.settings.get("ai_dialogue_enabled", false)):
		return false
	if _cognition_service == null or not _cognition_service.can_use_free_form(npc):
		if NPCIdentityResolver.resolve_persistent_id(npc) == &"":
			EventBus.notice_requested.emit("AI dialogue unavailable: this NPC has no persistent identity.")
		return false
	if player == null or text.strip_edges().is_empty() or not npc.can_talk_to(player):
		return false
	_free_form_npc = npc
	_free_form_player = player
	_free_form_npc_previous_state = npc.npc_state
	_player_input_before_dialogue = player.state.input_enabled
	player.set_input_enabled(false)
	npc.set_npc_state(NPCController.NPCState.TALK)
	var payload := _cognition_service.build_turn_payload(npc, text)
	if payload.is_empty():
		_restore_free_form_state()
		return false
	if not _cognition_service.conversation_controller.ask(npc, payload):
		_restore_free_form_state()
		return false
	return true


func start_free_form_from_active(text: String) -> bool:
	var npc := _npc
	var player := _player
	if npc == null or player == null or NPCIdentityResolver.resolve_persistent_id(npc) == &"":
		return false
	_runner.abandon()
	_restore_actor_state()
	_npc = null
	_player = null
	return start_free_form_dialogue(npc, player, text)


func cancel_free_form() -> void:
	if _cognition_service != null:
		_cognition_service.conversation_controller.cancel()
	_restore_free_form_state()


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
	EventBus.ai_dialogue_reply.emit(speaker, str(reply.get("reply_text", "Let's speak later.")))
	_restore_free_form_state()


func _restore_free_form_state() -> void:
	if _free_form_player != null and is_instance_valid(_free_form_player):
		_free_form_player.set_input_enabled(_player_input_before_dialogue)
	if _free_form_npc != null and is_instance_valid(_free_form_npc) and _free_form_npc.npc_state == NPCController.NPCState.TALK:
		_free_form_npc.set_npc_state(_free_form_npc_previous_state)
	_free_form_npc = null
	_free_form_player = null
