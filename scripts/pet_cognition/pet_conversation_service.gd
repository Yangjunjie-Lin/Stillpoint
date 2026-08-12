class_name PetConversationService
extends Node
## Pet-specific adapter over the authenticated cognition gateway.
##
## It reuses the same isolated memory cache and server-owned profile deployment
## as NPC dialogue, while never accepting model output as a gameplay command.

signal reply_ready(reply: Dictionary)

var _gateway: NPCDialogueGateway
var _cache: NPCMemoryCache
var _player_profile_id: String = ""
var _world_save_id: String = ""
var _pending_payload: Dictionary = {}


func setup(
	gateway: NPCDialogueGateway,
	cache: NPCMemoryCache,
	player_profile_id: String,
	world_save_id: String,
) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _gateway != null and _gateway.request_completed.is_connected(_on_gateway_result):
		_gateway.request_completed.disconnect(_on_gateway_result)
	_gateway = gateway
	_cache = cache
	_player_profile_id = player_profile_id
	_world_save_id = world_save_id
	if _gateway != null and not _gateway.request_completed.is_connected(_on_gateway_result):
		_gateway.request_completed.connect(_on_gateway_result)


func is_busy() -> bool:
	return not _pending_payload.is_empty() or (_gateway != null and _gateway.is_busy())


func request_turn(
	pet: PetController,
	text: String,
	origin: StringName = &"player_initiated",
) -> bool:
	if pet == null or pet.runtime_state == null or pet.pet_definition == null:
		return false
	if not bool(SaveService.settings.get("ai_dialogue_enabled", false)):
		return false
	if _gateway == null or _cache == null or is_busy():
		return false
	var cleaned := text.strip_edges().left(4000)
	if cleaned.is_empty():
		return false
	var persistent_id := String(pet.runtime_state.get_pet_instance_id())
	var definition_id := String(pet.pet_definition.server_dialogue_profile_id)
	if persistent_id.is_empty() or definition_id.is_empty():
		return false
	var session_id := _cache.get_session(
		_player_profile_id, _world_save_id, persistent_id
	)
	if session_id.is_empty():
		session_id = "%s/session" % persistent_id
	var proactive := origin == &"entity_proactive"
	var request_text := cleaned
	if proactive:
		# This is an observable, neutral event description—not an instruction
		# attributed to the player. The origin flag supplies trusted provenance.
		request_text = "The companion has a quiet moment near its owner."
	var payload := {
		"request_id": "pet-turn-%s-%s" % [persistent_id, Time.get_ticks_usec()],
		"player_profile_id": _player_profile_id,
		"world_save_id": _world_save_id,
		"npc_definition_id": definition_id,
		"npc_persistent_id": persistent_id,
		"session_id": session_id,
		"text": request_text,
		"locale": TranslationServer.get_locale(),
		"entity_kind": "pet",
		"dialogue_context": {
			"origin": String(origin),
			"proactive_dialogue_enabled": pet.runtime_state.is_auto_dialogue_enabled()
				and bool(SaveService.settings.get("pet_proactive_dialogue_enabled", true)),
		},
		"allow_conversation_storage": not proactive and bool(
			SaveService.settings.get("allow_conversation_storage", false)
		),
		"allow_memory_personalization": not proactive and bool(
			SaveService.settings.get("allow_memory_personalization", false)
		),
		"world_context": {
			"region_id": String(pet.region_id),
			"game_time": WorldTimeService.to_dict(),
			"visible_entity_ids": [
				"pet_instance:%s" % persistent_id,
				"region:%s" % String(RegionIdUtil.normalize(pet.region_id)),
				"player:current",
			],
			"pet_runtime": pet.runtime_state.to_llm_context().get("condition", {}),
		},
	}
	var world := pet.get_tree().get_first_node_in_group("world_manager") as WorldSession
	if world != null and world.player != null:
		var player_ontology := PlayerOntologySnapshotBuilder.build(
			world.player, GameManager.player_name
		)
		if not player_ontology.is_empty():
			payload["player_ontology"] = player_ontology
	_pending_payload = payload.duplicate(true)
	if bool(payload.allow_conversation_storage):
		_cache.enqueue_turn(payload)
	var error := _gateway.request_turn(payload)
	if error != OK:
		_pending_payload.clear()
		_emit_fallback(cleaned, "backend_unavailable")
		return false
	pet.set_dialogue_motion(true)
	return true


func cancel() -> void:
	var request_id := str(_pending_payload.get("request_id", ""))
	if _gateway != null and not request_id.is_empty():
		_gateway.cancel_request(request_id)
	_pending_payload.clear()


func _on_gateway_result(result: Dictionary) -> void:
	if _pending_payload.is_empty():
		return
	var request_id := str(_pending_payload.get("request_id", ""))
	if request_id.is_empty() or str(result.get("request_id", "")) != request_id:
		return
	var scope := _pending_payload
	_pending_payload = {}
	if not bool(result.get("ok", false)):
		_emit_fallback(str(scope.get("text", "")), str(result.get("error_code", "backend_unavailable")))
		return
	_cache.acknowledge_turn(str(result.get("request_id", "")))
	_cache.set_session(
		str(scope.get("player_profile_id", "")),
		str(scope.get("world_save_id", "")),
		str(scope.get("npc_persistent_id", "")),
		str(result.get("session_id", "")),
	)
	if bool(scope.get("allow_memory_personalization", false)):
		for memory in result.get("memory_writes", []):
			if memory is Dictionary:
				_cache.remember(
					str(scope.get("player_profile_id", "")),
					str(scope.get("world_save_id", "")),
					str(scope.get("npc_persistent_id", "")),
					memory,
				)
	# proposed_intents and animation_id never reach gameplay authority here.
	reply_ready.emit(result.duplicate(true))


func _emit_fallback(player_text: String, reason: String) -> void:
	var text := "Pip stays close and gives a reassuring little chirp."
	if NPCConversationController._contains_cjk(player_text):
		text = "皮普靠近你，轻轻叫了一声；它现在还没法把想法说清楚。"
	reply_ready.emit({
		"ok": false,
		"fallback": true,
		"error_code": reason,
		"reply_text": text,
		"emotion": "calm",
		"animation_id": "talk",
		"proposed_intents": [],
	})
