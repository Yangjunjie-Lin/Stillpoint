class_name NPCDialogueGateway
extends Node
## HTTPS-only client for the Stillpoint-owned backend. No model-provider secret
## is accepted or stored by this class.

signal request_completed(result: Dictionary)

@export var backend_base_url: String = "https://localhost:8443"
@export var timeout_seconds: float = 8.0
@export var maximum_response_bytes: int = 65536
@export var max_retries: int = 1

var _http: HTTPRequest
var _active_request_id: String = ""
var _active_payload: Dictionary = {}
var _retry_count: int = 0

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.name = "NpcMindHTTPRequest"
	_http.timeout = timeout_seconds
	_http.download_chunk_size = mini(maximum_response_bytes, 65536)
	add_child(_http)
	_http.request_completed.connect(_on_http_completed)

func request_turn(payload: Dictionary) -> Error:
	if _http == null: _ready()
	if not _active_request_id.is_empty(): return ERR_BUSY
	var validation := validate_turn_request(payload)
	if not bool(validation.get("valid", false)):
		return ERR_INVALID_DATA
	if not backend_base_url.begins_with("https://") and not backend_base_url.begins_with("http://localhost") and not backend_base_url.begins_with("http://127.0.0.1"):
		return ERR_INVALID_PARAMETER
	_active_request_id = str(payload.get("request_id"))
	_active_payload = payload.duplicate(true)
	_retry_count = 0
	return _send_active()

func cancel() -> void:
	if _http != null: _http.cancel_request()
	_finish({"ok": false, "error_code": "cancelled", "request_id": _active_request_id})

static func validate_turn_request(payload: Dictionary) -> Dictionary:
	for field in ["request_id", "player_profile_id", "world_save_id", "npc_definition_id", "npc_persistent_id", "session_id", "text"]:
		if str(payload.get(field, "")).strip_edges().is_empty():
			return {"valid": false, "error": "missing_%s" % field}
	if str(payload.get("text")).length() > 4000: return {"valid": false, "error": "input_too_long"}
	if typeof(payload.get("world_context", {})) != TYPE_DICTIONARY: return {"valid": false, "error": "invalid_world_context"}
	return {"valid": true}

static func parse_response(body: PackedByteArray, maximum_bytes: int = 65536) -> Dictionary:
	if body.size() > maximum_bytes: return {"ok": false, "error_code": "response_too_large"}
	var parser := JSON.new()
	var parse_error := parser.parse(body.get_string_from_utf8())
	if parse_error != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return {"ok": false, "error_code": "invalid_json"}
	var data: Dictionary = parser.data
	for field in ["request_id", "session_id", "reply_text", "emotion", "animation_id", "proposed_intents", "usage"]:
		if not data.has(field): return {"ok": false, "error_code": "schema_mismatch"}
	if typeof(data.get("reply_text")) != TYPE_STRING or typeof(data.get("proposed_intents")) != TYPE_ARRAY or typeof(data.get("usage")) != TYPE_DICTIONARY:
		return {"ok": false, "error_code": "schema_mismatch"}
	data["ok"] = true
	return data

func _send_active() -> Error:
	var endpoint := backend_base_url.trim_suffix("/") + "/v1/conversations/%s/turns" % str(_active_payload.get("session_id"))
	var error := _http.request(endpoint, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(_active_payload))
	if error != OK: _finish({"ok": false, "error_code": "network_unavailable", "request_id": _active_request_id})
	return error

func _on_http_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code == 429 or response_code >= 500:
		if _retry_count < max_retries:
			_retry_count += 1
			_send_active()
			return
		_finish({"ok": false, "error_code": "rate_limited" if response_code == 429 else "backend_unavailable", "request_id": _active_request_id})
		return
	if response_code < 200 or response_code >= 300:
		_finish({"ok": false, "error_code": "http_%d" % response_code, "request_id": _active_request_id})
		return
	_finish(parse_response(body, maximum_response_bytes))

func _finish(result: Dictionary) -> void:
	_active_request_id = ""
	_active_payload.clear()
	_retry_count = 0
	request_completed.emit(result)
