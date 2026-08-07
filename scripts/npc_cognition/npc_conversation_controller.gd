class_name NPCConversationController
extends Node

signal reply_ready(reply: Dictionary)

var gateway: NPCDialogueGateway
var cache: NPCMemoryCache
var _active_npc: NPCController
var _npc_previous_state: NPCController.NPCState
var _pending_payload: Dictionary = {}

func setup(p_gateway: NPCDialogueGateway, p_cache: NPCMemoryCache) -> void:
	if gateway != null and gateway.request_completed.is_connected(_on_gateway_result):
		gateway.request_completed.disconnect(_on_gateway_result)
	gateway = p_gateway
	cache = p_cache
	if gateway != null and not gateway.request_completed.is_connected(_on_gateway_result):
		gateway.request_completed.connect(_on_gateway_result)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and gateway != null \
		and gateway.request_completed.is_connected(_on_gateway_result):
		gateway.request_completed.disconnect(_on_gateway_result)

func ask(npc: NPCController, payload: Dictionary) -> bool:
	if npc == null or npc.npc_definition == null or npc.npc_definition.mind_profile == null:
		_emit_fallback("missing_mind_profile")
		return false
	if gateway == null or cache == null:
		_emit_fallback("backend_unavailable")
		return false
	var resolved_id := NPCIdentityResolver.resolve_persistent_id(npc)
	if resolved_id == &"" or String(resolved_id) != str(payload.get("npc_persistent_id", "")):
		_emit_fallback("missing_persistent_identity")
		return false
	_active_npc = npc
	_npc_previous_state = npc.npc_state
	npc.set_npc_state(NPCController.NPCState.TALK)
	_pending_payload = payload.duplicate(true)
	if bool(payload.get("allow_conversation_storage", true)):
		cache.enqueue_turn(payload)
	var error := gateway.request_turn(payload)
	if error != OK:
		_restore_npc_state()
		_pending_payload.clear()
		_emit_fallback("backend_unavailable")
		return false
	return true

func cancel() -> void:
	if gateway != null: gateway.cancel()
	_restore_npc_state()

func _on_gateway_result(result: Dictionary) -> void:
	_restore_npc_state()
	if not bool(result.get("ok", false)):
		_emit_fallback(str(result.get("error_code", "backend_unavailable")))
	else:
		cache.acknowledge_turn(str(result.get("request_id", "")))
		var scope := _pending_payload
		cache.set_session(
			str(scope.get("player_profile_id", "")),
			str(scope.get("world_save_id", "")),
			str(scope.get("npc_persistent_id", "")),
			str(result.get("session_id", "")),
		)
		if bool(scope.get("allow_memory_personalization", true)):
			for memory in result.get("memory_writes", []):
				if memory is Dictionary:
					cache.remember(
						str(scope.get("player_profile_id", "")),
						str(scope.get("world_save_id", "")),
						str(scope.get("npc_persistent_id", "")),
						memory,
					)
		reply_ready.emit(result)
	_pending_payload.clear()

func _restore_npc_state() -> void:
	if _active_npc != null and is_instance_valid(_active_npc) and _active_npc.npc_state == NPCController.NPCState.TALK:
		_active_npc.set_npc_state(_npc_previous_state)
	_active_npc = null

func _emit_fallback(reason: String) -> void:
	reply_ready.emit({"ok": false, "fallback": true, "error_code": reason,
		"reply_text": "Let's speak about that another time."})
