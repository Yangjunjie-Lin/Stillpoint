class_name NPCConversationController
extends Node

signal reply_ready(reply: Dictionary)

var gateway: NPCDialogueGateway
var cache := NPCMemoryCache.new()
var _active_npc: NPCController
var _npc_previous_state: NPCController.NPCState
var _pending_payload: Dictionary = {}

func setup(p_gateway: NPCDialogueGateway, p_cache: NPCMemoryCache = null) -> void:
	gateway = p_gateway
	if p_cache != null: cache = p_cache
	if gateway != null and not gateway.request_completed.is_connected(_on_gateway_result):
		gateway.request_completed.connect(_on_gateway_result)

func ask(npc: NPCController, payload: Dictionary) -> bool:
	if npc == null or npc.npc_definition == null or npc.npc_definition.mind_profile == null:
		_emit_fallback("missing_mind_profile")
		return false
	if gateway == null:
		_emit_fallback("backend_unavailable")
		return false
	_active_npc = npc
	_npc_previous_state = npc.npc_state
	npc.set_npc_state(NPCController.NPCState.TALK)
	_pending_payload = payload.duplicate(true)
	var error := gateway.request_turn(payload)
	if error != OK:
		_restore_npc_state()
		_emit_fallback("backend_unavailable")
		return false
	return true

func cancel() -> void:
	if gateway != null: gateway.cancel()
	_restore_npc_state()

func _on_gateway_result(result: Dictionary) -> void:
	_restore_npc_state()
	if not bool(result.get("ok", false)):
		if not _pending_payload.is_empty(): cache.enqueue_turn(_pending_payload)
		_emit_fallback(str(result.get("error_code", "backend_unavailable")))
	else:
		reply_ready.emit(result)
	_pending_payload.clear()

func _restore_npc_state() -> void:
	if _active_npc != null and is_instance_valid(_active_npc) and _active_npc.npc_state == NPCController.NPCState.TALK:
		_active_npc.set_npc_state(_npc_previous_state)
	_active_npc = null

func _emit_fallback(reason: String) -> void:
	reply_ready.emit({"ok": false, "fallback": true, "error_code": reason,
		"reply_text": "Let's speak about that another time."})
