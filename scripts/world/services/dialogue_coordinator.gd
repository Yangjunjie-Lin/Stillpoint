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
var _authored_choices_presented: bool = false


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
	var can_use_authored := npc.can_talk_to(player)
	var can_use_free_form := _can_offer_free_form(npc, player)
	if not can_use_authored and not can_use_free_form:
		EventBus.notice_requested.emit("They refuse to speak with you.")
		return false
	var dialogue := _resolve_dialogue(npc)
	if dialogue == null or not can_use_authored:
		if not can_use_free_form:
			return false
		_begin_dialogue(npc, player)
		_on_line(_display_name(npc), "What would you like to ask?")
		_on_choices([])
		dialogue_started.emit(npc)
		return true
	_begin_dialogue(npc, player)
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
	if text.strip_edges().is_empty() or not _can_offer_free_form(npc, player):
		return false
	_free_form_npc = npc
	_free_form_player = player
	_free_form_npc_previous_state = npc.npc_state
	_player_input_before_dialogue = player.state.input_enabled
	player.set_input_enabled(false)
	_set_player_dialogue_motion(player, true)
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
	if not _can_offer_free_form(npc, player):
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


func cancel_dialogue() -> void:
	_runner.abandon()
	_finish_authored_dialogue()


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
	if not choices.is_empty():
		_authored_choices_presented = true
	EventBus.dialogue_choices.emit(choices)


func _on_finished() -> void:
	if not _authored_choices_presented and _can_offer_free_form(_npc, _player):
		# Keep terminal authored lines visible and append the universal free-form
		# entry instead of closing the panel synchronously.
		_on_choices([])
		return
	_finish_authored_dialogue()


func _finish_authored_dialogue() -> void:
	_restore_actor_state()
	EventBus.dialogue_finished.emit()
	dialogue_ended.emit()
	_npc = null
	_player = null
	_authored_choices_presented = false


func _on_choice_effect_failed(_choice: DialogueChoice, reason: String) -> void:
	choice_effect_failed.emit(reason)
	EventBus.notice_requested.emit("Dialogue choice failed: %s" % reason)


func _restore_actor_state() -> void:
	if _player != null and is_instance_valid(_player):
		_player.set_input_enabled(_player_input_before_dialogue)
		_set_player_dialogue_motion(_player, false)
	if _npc != null and is_instance_valid(_npc) \
		and _npc.npc_state == NPCController.NPCState.TALK:
		_npc.set_npc_state(_npc_state_before_dialogue)


func _begin_dialogue(npc: NPCController, player: PlayerController3D) -> void:
	_npc = npc
	_player = player
	_npc_state_before_dialogue = npc.npc_state
	_player_input_before_dialogue = player.state.input_enabled
	_authored_choices_presented = false
	player.set_input_enabled(false)
	_set_player_dialogue_motion(player, true)
	npc.set_npc_state(NPCController.NPCState.TALK)


func _can_offer_free_form(npc: NPCController, player: PlayerController3D) -> bool:
	return _cognition_service != null \
		and _cognition_service.can_use_free_form(npc) \
		and npc != null \
		and npc.can_engage_free_form(player)


func _display_name(npc: NPCController) -> String:
	if npc != null and npc.npc_definition != null:
		return npc.npc_definition.display_name
	return "NPC"


func _on_free_form_reply(reply: Dictionary) -> void:
	var speaker := _display_name(_free_form_npc)
	var responding_npc := _free_form_npc
	EventBus.ai_dialogue_reply.emit(speaker, str(reply.get("reply_text", "Let's speak later.")))
	if (
		bool(reply.get("ok", false))
		and not bool(reply.get("degraded", false))
		and responding_npc != null
		and is_instance_valid(responding_npc)
	):
		_emit_autonomous_dialogue_completed(responding_npc, reply)
	_restore_free_form_state()
	if responding_npc != null and is_instance_valid(responding_npc):
		responding_npc.play_knowledge_action(
			StringName(str(reply.get("animation_id", "talk")))
		)


func _emit_autonomous_dialogue_completed(npc: NPCController, reply: Dictionary) -> void:
	if _session_context == null or _session_context.world_session == null:
		return
	var session := _session_context.world_session as WorldSession
	if session == null or session.event_bus == null:
		return
	var persistent_id := NPCIdentityResolver.resolve_persistent_id(npc)
	if persistent_id == &"":
		return
	# This fact deliberately excludes the prompt and reply. The conversation store
	# owns private text; encounter evaluation needs only committed provenance.
	session.event_bus.emit_event(GameplayEvent.make(
		GameplayEventTypes.NPC_AUTONOMOUS_DIALOGUE_COMPLETED,
		&"base:player/main",
		persistent_id,
		npc.character_id,
		npc.region_id,
		1.0,
		{
			"player_initiated": true,
			"action_committed": true,
			"encounter_trigger_origin": String(GameplayEventTypes.ORIGIN_AUTONOMOUS_DIALOGUE),
			"request_id": str(reply.get("request_id", "")).left(160),
		},
	))


func _restore_free_form_state() -> void:
	if _free_form_player != null and is_instance_valid(_free_form_player):
		_free_form_player.set_input_enabled(_player_input_before_dialogue)
		_set_player_dialogue_motion(_free_form_player, false)
	if _free_form_npc != null and is_instance_valid(_free_form_npc) and _free_form_npc.npc_state == NPCController.NPCState.TALK:
		_free_form_npc.set_npc_state(_free_form_npc_previous_state)
	_free_form_npc = null
	_free_form_player = null


func _set_player_dialogue_motion(player: PlayerController3D, active: bool) -> void:
	if player == null:
		return
	var animation := player.get_node_or_null("CombatAnimationController") as CombatAnimationController
	if animation != null:
		animation.set_context_motion(&"talk" if active else &"")
