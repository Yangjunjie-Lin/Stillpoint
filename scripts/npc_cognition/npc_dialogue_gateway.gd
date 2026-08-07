class_name NPCDialogueGateway
extends Node
## Authenticated client for the Stillpoint-owned backend. Provider secrets never enter Godot.

signal request_completed(result: Dictionary)
signal sync_completed(result: Dictionary)

@export var backend_base_url: String = "http://127.0.0.1:8443"
@export var timeout_seconds: float = 8.0
@export var maximum_response_bytes: int = 65536
@export var max_retries: int = 1

var client_install_id: String = ""
var client_secret: String = ""
var _http: HTTPRequest
var _active_request_id: String = ""
var _active_payload: Dictionary = {}
var _active_kind: String = ""
var _phase: String = ""
var _session_token: String = ""
var _session_player_profile_id: String = ""
var _session_world_save_id: String = ""
var _retry_count: int = 0
var _auth_retry_used: bool = false

func _init() -> void:
	var configured := OS.get_environment("NPC_BACKEND_URL").strip_edges()
	if not configured.is_empty():
		backend_base_url = configured
	client_secret = OS.get_environment("NPC_CLIENT_SECRET")

func _ready() -> void:
	if _http != null:
		return
	_http = HTTPRequest.new()
	_http.name = "NpcMindHTTPRequest"
	_http.timeout = timeout_seconds
	_http.download_chunk_size = mini(maximum_response_bytes, 65536)
	add_child(_http)
	_http.request_completed.connect(_on_http_completed)

func configure(p_client_install_id: String, p_client_secret: String = "") -> void:
	if client_install_id != p_client_install_id:
		_clear_session_token()
	client_install_id = p_client_install_id
	if not p_client_secret.is_empty():
		client_secret = p_client_secret

func is_busy() -> bool:
	return not _active_kind.is_empty()

func request_turn(payload: Dictionary) -> Error:
	var validation := validate_turn_request(payload)
	if not bool(validation.get("valid", false)):
		return ERR_INVALID_DATA
	return _begin_request("turn", str(payload.get("request_id")), payload)

func request_sync(payload: Dictionary) -> Error:
	if str(payload.get("player_profile_id", "")).is_empty() \
		or str(payload.get("world_save_id", "")).is_empty():
		return ERR_INVALID_DATA
	return _begin_request("sync", "sync-%s" % Time.get_ticks_usec(), payload)

func cancel() -> void:
	if not is_busy():
		return
	_replace_http_transport()
	_finish({"ok": false, "error_code": "cancelled", "request_id": _active_request_id})

static func validate_turn_request(payload: Dictionary) -> Dictionary:
	for field in ["request_id", "player_profile_id", "world_save_id", "npc_definition_id", "npc_persistent_id", "session_id", "text"]:
		if str(payload.get(field, "")).strip_edges().is_empty():
			return {"valid": false, "error": "missing_%s" % field}
	if str(payload.get("text")).length() > 4000:
		return {"valid": false, "error": "input_too_long"}
	if typeof(payload.get("world_context", {})) != TYPE_DICTIONARY:
		return {"valid": false, "error": "invalid_world_context"}
	return {"valid": true}

static func parse_response(body: PackedByteArray, maximum_bytes: int = 65536) -> Dictionary:
	var parsed := _parse_json(body, maximum_bytes)
	if not bool(parsed.get("ok", false)):
		return parsed
	var data: Dictionary = parsed.get("data", {})
	for field in ["request_id", "session_id", "reply_text", "emotion", "animation_id", "proposed_intents", "usage"]:
		if not data.has(field):
			return {"ok": false, "error_code": "schema_mismatch"}
	if typeof(data.get("reply_text")) != TYPE_STRING \
		or typeof(data.get("proposed_intents")) != TYPE_ARRAY \
		or typeof(data.get("usage")) != TYPE_DICTIONARY:
		return {"ok": false, "error_code": "schema_mismatch"}
	data["ok"] = true
	return data

static func parse_sync_response(body: PackedByteArray, maximum_bytes: int = 65536) -> Dictionary:
	var parsed := _parse_json(body, maximum_bytes)
	if not bool(parsed.get("ok", false)):
		return parsed
	var data: Dictionary = parsed.get("data", {})
	for field in ["accepted_turn_ids", "accepted_event_ids", "rejected", "revision", "conflicts"]:
		if not data.has(field):
			return {"ok": false, "error_code": "schema_mismatch"}
	data["ok"] = true
	return data

static func _parse_json(body: PackedByteArray, maximum_bytes: int) -> Dictionary:
	if body.size() > maximum_bytes:
		return {"ok": false, "error_code": "response_too_large"}
	var parser := JSON.new()
	var parse_error := parser.parse(body.get_string_from_utf8())
	if parse_error != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return {"ok": false, "error_code": "invalid_json"}
	return {"ok": true, "data": parser.data}

func _begin_request(kind: String, request_id: String, payload: Dictionary) -> Error:
	if _http == null:
		_ready()
	if is_busy():
		return ERR_BUSY
	if not _valid_backend_url():
		return ERR_INVALID_PARAMETER
	if client_install_id.is_empty():
		return ERR_UNAUTHORIZED
	_active_kind = kind
	_active_request_id = request_id
	_active_payload = payload.duplicate(true)
	_retry_count = 0
	_auth_retry_used = false
	if not _session_scope_matches(_active_payload):
		_clear_session_token()
	if _session_token.is_empty():
		return _send_auth()
	return _send_active()

func _send_auth() -> Error:
	_phase = "auth"
	var endpoint := backend_base_url.trim_suffix("/") + "/v1/auth/session"
	var payload := {
		"player_profile_id": str(_active_payload.get("player_profile_id", "")),
		"world_save_id": str(_active_payload.get("world_save_id", "")),
		"client_install_id": client_install_id,
	}
	var headers := ["Content-Type: application/json", "X-Client-Install-ID: %s" % client_install_id]
	if not client_secret.is_empty():
		headers.append("X-Client-Secret: %s" % client_secret)
	var error := _http.request(
		endpoint,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload),
	)
	if error != OK:
		_finish({"ok": false, "error_code": "network_unavailable", "request_id": _active_request_id})
	return error

func _send_active() -> Error:
	_phase = "request"
	var endpoint := backend_base_url.trim_suffix("/")
	if _active_kind == "turn":
		endpoint += "/v1/conversations/%s/turns" % str(_active_payload.get("session_id"))
	else:
		endpoint += "/v1/sync/npc-cognition"
	var headers := [
		"Content-Type: application/json",
		"Authorization: %s%s" % ["Bearer ", _session_token],
		"X-Client-Install-ID: %s" % client_install_id,
	]
	var error := _http.request(
		endpoint, headers, HTTPClient.METHOD_POST, JSON.stringify(_active_payload)
	)
	if error != OK:
		_finish({"ok": false, "error_code": "network_unavailable", "request_id": _active_request_id})
	return error

func _on_http_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code == 429 or response_code >= 500:
		if _retry_count < max_retries:
			_retry_count += 1
			if _phase == "auth":
				_send_auth()
			else:
				_send_active()
			return
		_finish({
			"ok": false,
			"error_code": "rate_limited" if response_code == 429 else "backend_unavailable",
			"request_id": _active_request_id,
		})
		return
	if _phase == "request" and response_code == 401 and not _auth_retry_used:
		_auth_retry_used = true
		_clear_session_token()
		_send_auth()
		return
	if response_code < 200 or response_code >= 300:
		_finish({"ok": false, "error_code": "http_%d" % response_code, "request_id": _active_request_id})
		return
	if _phase == "auth":
		var auth := _parse_json(body, maximum_response_bytes)
		var data: Dictionary = auth.get("data", {})
		_session_token = str(data.get("token", ""))
		if not bool(auth.get("ok", false)) or _session_token.is_empty():
			_finish({"ok": false, "error_code": "auth_failed", "request_id": _active_request_id})
			return
		_session_player_profile_id = str(_active_payload.get("player_profile_id", ""))
		_session_world_save_id = str(_active_payload.get("world_save_id", ""))
		_retry_count = 0
		_send_active()
		return
	_finish(
		parse_response(body, maximum_response_bytes)
		if _active_kind == "turn"
		else parse_sync_response(body, maximum_response_bytes)
	)

func _finish(result: Dictionary) -> void:
	var kind := _active_kind
	_active_request_id = ""
	_active_payload.clear()
	_active_kind = ""
	_phase = ""
	_retry_count = 0
	if kind == "sync":
		sync_completed.emit(result)
	else:
		request_completed.emit(result)

func _valid_backend_url() -> bool:
	if backend_base_url.begins_with("https://"):
		return true
	var loopback := backend_base_url.begins_with("http://127.0.0.1") \
		or backend_base_url.begins_with("http://localhost")
	return loopback and (OS.is_debug_build() or Engine.is_editor_hint())

func _session_scope_matches(payload: Dictionary) -> bool:
	return not _session_token.is_empty() \
		and _session_player_profile_id == str(payload.get("player_profile_id", "")) \
		and _session_world_save_id == str(payload.get("world_save_id", ""))

func _clear_session_token() -> void:
	_session_token = ""
	_session_player_profile_id = ""
	_session_world_save_id = ""

func _replace_http_transport() -> void:
	if _http != null:
		if _http.request_completed.is_connected(_on_http_completed):
			_http.request_completed.disconnect(_on_http_completed)
		_http.cancel_request()
		if _http.get_parent() == self:
			remove_child(_http)
		_http.queue_free()
	_http = null
	_ready()
