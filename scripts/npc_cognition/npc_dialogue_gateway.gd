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
var _finish_pending: bool = false
var _shutdown: bool = false

const PET_MOTION_REQUEST_FIELDS := [
	"request_id", "player_profile_id", "world_save_id", "pet_definition_id",
	"pet_persistent_id", "individual_traits", "mood_band", "region_type",
	"region_tags", "lifestyle_id", "context_revision",
]
const PET_MOTION_RESPONSE_FIELDS := [
	"assessment_id", "request_id", "context_revision", "motif_weights",
	"pace", "roam", "confidence", "degraded", "reason",
]
const PET_MOTION_MOTIF_FIELDS := [
	"idle_near_anchor", "follow_owner", "curious_explore", "playful_loop",
	"social_approach", "cautious_patrol", "perch_observe", "rest_sheltered",
]
const PET_MOTION_TRAIT_FIELDS := [
	"curiosity", "playfulness", "sociability", "independence", "courage",
	"patience", "energy",
]

func _init() -> void:
	var configured := OS.get_environment("NPC_BACKEND_URL").strip_edges()
	if not configured.is_empty():
		backend_base_url = configured
	timeout_seconds = parse_timeout_config(
		OS.get_environment("NPC_DIALOGUE_TIMEOUT_SECONDS"), timeout_seconds
	)
	max_retries = parse_retry_config(
		OS.get_environment("NPC_DIALOGUE_MAX_RETRIES"), max_retries
	)
	client_secret = OS.get_environment("NPC_CLIENT_SECRET")


static func parse_timeout_config(value: String, fallback: float = 8.0) -> float:
	var cleaned := value.strip_edges()
	if not cleaned.is_valid_float():
		return fallback
	return clampf(cleaned.to_float(), 1.0, 180.0)


static func parse_retry_config(value: String, fallback: int = 1) -> int:
	var cleaned := value.strip_edges()
	if not cleaned.is_valid_int():
		return fallback
	return clampi(cleaned.to_int(), 0, 3)

func _ready() -> void:
	# Dialogue panels pause the world while awaiting HTTP. Keep both this adapter
	# and its transport alive so a paused modal can receive its response.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _shutdown:
		return
	if _http != null:
		_http.process_mode = Node.PROCESS_MODE_ALWAYS
		return
	_http = HTTPRequest.new()
	_http.name = "NpcMindHTTPRequest"
	_http.process_mode = Node.PROCESS_MODE_ALWAYS
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


func request_pet_motion_assessment(payload: Dictionary) -> Error:
	var validation := validate_pet_motion_assessment_request(payload)
	if not bool(validation.get("valid", false)):
		return ERR_INVALID_DATA
	return _begin_request(
		"pet_motion_assessment", str(payload.get("request_id", "")), payload
	)

func cancel() -> void:
	if not is_busy() or _finish_pending:
		return
	_replace_http_transport()
	_publish_finish({"ok": false, "error_code": "cancelled", "request_id": _active_request_id})


func cancel_request(request_id: String) -> bool:
	## Cancel only when the caller owns the gateway's active request.
	## Multiple cognition adapters share this transport, so an unscoped cancel
	## from one adapter must never terminate another adapter's HTTP request.
	var expected_id := request_id.strip_edges()
	if expected_id.is_empty() or not is_busy() or _finish_pending \
			or expected_id != _active_request_id:
		return false
	_replace_http_transport()
	_publish_finish({"ok": false, "error_code": "cancelled", "request_id": expected_id})
	return true


func shutdown() -> void:
	## Terminal cleanup for an owner that is leaving the tree. Unlike `cancel`,
	## this deliberately does not create a replacement HTTPRequest or publish a
	## UI result into a scene that is already being destroyed.
	_shutdown = true
	_dispose_http_transport(false)
	_active_request_id = ""
	_active_payload.clear()
	_active_kind = ""
	_phase = ""
	_retry_count = 0
	_finish_pending = false
	_clear_session_token()

static func validate_turn_request(payload: Dictionary) -> Dictionary:
	for field in ["request_id", "player_profile_id", "world_save_id", "npc_definition_id", "npc_persistent_id", "session_id", "text"]:
		if str(payload.get(field, "")).strip_edges().is_empty():
			return {"valid": false, "error": "missing_%s" % field}
	if str(payload.get("text")).length() > 4000:
		return {"valid": false, "error": "input_too_long"}
	if typeof(payload.get("world_context", {})) != TYPE_DICTIONARY:
		return {"valid": false, "error": "invalid_world_context"}
	return {"valid": true}


static func validate_pet_motion_assessment_request(payload: Dictionary) -> Dictionary:
	if not _has_only_fields(payload, PET_MOTION_REQUEST_FIELDS):
		return {"valid": false, "error": "unexpected_assessment_field"}
	for field in [
		"request_id", "player_profile_id", "world_save_id", "pet_definition_id",
		"pet_persistent_id", "mood_band", "region_type", "lifestyle_id",
	]:
		if str(payload.get(field, "")).strip_edges().is_empty():
			return {"valid": false, "error": "missing_%s" % field}
	var revision: Variant = payload.get("context_revision")
	if not payload.get("individual_traits", {}) is Dictionary \
			or not payload.get("region_tags", []) is Array \
			or not revision is int or revision is bool or int(revision) < 0:
		return {"valid": false, "error": "invalid_assessment_context"}
	if not _has_only_fields(payload.individual_traits, PET_MOTION_TRAIT_FIELDS):
		return {"valid": false, "error": "unexpected_assessment_trait"}
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


static func parse_pet_motion_assessment_response(
	body: PackedByteArray,
	maximum_bytes: int = 65536,
) -> Dictionary:
	var parsed := _parse_json(body, maximum_bytes)
	if not bool(parsed.get("ok", false)):
		return parsed
	var data: Dictionary = parsed.get("data", {})
	if not _has_only_fields(data, PET_MOTION_RESPONSE_FIELDS):
		return {"ok": false, "error_code": "schema_mismatch"}
	for field in [
		"assessment_id", "request_id", "context_revision", "motif_weights",
		"pace", "roam", "confidence", "degraded",
	]:
		if not data.has(field):
			return {"ok": false, "error_code": "schema_mismatch"}
	if not data.motif_weights is Dictionary \
			or not data.context_revision is int or data.context_revision is bool \
			or int(data.context_revision) < 0 \
			or not _finite_number(data.pace) \
			or not _finite_number(data.roam) \
			or not _finite_number(data.confidence) \
			or not data.degraded is bool:
		return {"ok": false, "error_code": "schema_mismatch"}
	if not _has_only_fields(data.motif_weights, PET_MOTION_MOTIF_FIELDS):
		return {"ok": false, "error_code": "schema_mismatch"}
	if data.has("reason") and not data.reason is String:
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


static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and not value is bool \
		and is_finite(float(value))


static func _has_only_fields(value: Dictionary, allowed: Array) -> bool:
	for key in value:
		if str(key) not in allowed:
			return false
	return true

func _begin_request(kind: String, request_id: String, payload: Dictionary) -> Error:
	if _shutdown:
		return ERR_UNAVAILABLE
	if _http == null:
		_ready()
	if _http == null:
		return ERR_UNAVAILABLE
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
	_finish_pending = false
	if not _session_scope_matches(_active_payload):
		_clear_session_token()
	if _session_token.is_empty():
		return _send_auth()
	return _send_active()

func _send_auth() -> Error:
	if _shutdown or _http == null:
		return ERR_UNAVAILABLE
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
		_handle_transport_start_failure()
	return error

func _send_active() -> Error:
	if _shutdown or _http == null:
		return ERR_UNAVAILABLE
	_phase = "request"
	var endpoint := backend_base_url.trim_suffix("/")
	if _active_kind == "turn":
		endpoint += "/v1/conversations/%s/turns" % str(_active_payload.get("session_id"))
	elif _active_kind == "pet_motion_assessment":
		endpoint += "/v1/pets/movement-assessments"
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
		_handle_transport_start_failure()
	return error


func _handle_transport_start_failure() -> void:
	# A failed start can leave HTTPRequest internally marked as requesting until
	# deferred native cleanup runs. Replace it before publishing idle state so a
	# queued turn cannot collide with that stale transport.
	if _shutdown:
		return
	_replace_http_transport()
	_finish({
		"ok": false,
		"error_code": "network_unavailable",
		"request_id": _active_request_id,
	})

func _on_http_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
) -> void:
	# A transport replaced after a synchronous start failure may still have had
	# deferred native cleanup pending. It is disconnected, but keep this guard as
	# defense in depth for any stale/manual completion.
	if _shutdown or _active_kind.is_empty() or _active_request_id.is_empty() \
			or _finish_pending:
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code == 429 or response_code >= 500:
		if _retry_count < max_retries:
			_retry_count += 1
			_defer_transport_step(_phase)
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
		_defer_transport_step("auth")
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
		_defer_transport_step("request")
		return
	var parsed_result: Dictionary
	if _active_kind == "turn":
		parsed_result = parse_response(body, maximum_response_bytes)
	elif _active_kind == "pet_motion_assessment":
		parsed_result = parse_pet_motion_assessment_response(
			body, maximum_response_bytes
		)
	else:
		parsed_result = parse_sync_response(body, maximum_response_bytes)
	# Parser-level failures (invalid JSON, oversized responses, or schema
	# mismatches) cannot carry the backend request ID. Preserve the active turn
	# scope so the owning NPC/pet adapter consumes the failure and clears its
	# pending UI state. Never replace a non-empty ID supplied by the backend.
	if _active_kind in ["turn", "pet_motion_assessment"] \
		and str(parsed_result.get("request_id", "")).strip_edges().is_empty():
		parsed_result["request_id"] = _active_request_id
	_finish(parsed_result)

func _finish(result: Dictionary) -> void:
	# HTTPRequest keeps its internal `requesting` flag set while emitting
	# `request_completed`. Publishing our completion synchronously from that
	# callback lets an awaiting conversation (or a polling background queue) start
	# the next request before the transport has actually become idle. Keep this
	# gateway busy until the callback has unwound, then publish on the next loop.
	if _shutdown or _finish_pending:
		return
	_finish_pending = true
	call_deferred(
		"_publish_finish_if_current",
		result.duplicate(true),
		_active_kind,
		_active_request_id,
	)


func _publish_finish_if_current(
	result: Dictionary,
	expected_kind: String,
	expected_request_id: String,
) -> void:
	# Shutdown or explicit cancellation may invalidate a deferred completion.
	if _shutdown or not _finish_pending or _active_kind != expected_kind \
			or _active_request_id != expected_request_id:
		return
	_publish_finish(result)


func _publish_finish(result: Dictionary) -> void:
	if _shutdown:
		return
	var kind := _active_kind
	_active_request_id = ""
	_active_payload.clear()
	_active_kind = ""
	_phase = ""
	_retry_count = 0
	_finish_pending = false
	if kind == "sync":
		sync_completed.emit(result)
	else:
		request_completed.emit(result)


func _defer_transport_step(next_phase: String) -> void:
	# Starting auth/request/retry directly inside HTTPRequest's completion signal
	# is rejected as `HTTPRequest is processing a request`. On Windows, the
	# completed transport can remain internally busy even after one deferred
	# callback, so retire it now and continue on a fresh HTTPRequest. Scope the
	# deferred continuation so a cancellation cannot revive stale work.
	_replace_http_transport()
	call_deferred(
		"_resume_transport_step",
		_active_kind,
		_active_request_id,
		next_phase,
	)


func _resume_transport_step(
	expected_kind: String,
	expected_request_id: String,
	next_phase: String,
) -> void:
	if _shutdown or _finish_pending or _active_kind != expected_kind \
			or _active_request_id != expected_request_id:
		return
	if next_phase == "auth":
		_send_auth()
	else:
		_send_active()

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
	_dispose_http_transport(not _shutdown)


func _dispose_http_transport(recreate: bool) -> void:
	if _http != null:
		if _http.request_completed.is_connected(_on_http_completed):
			_http.request_completed.disconnect(_on_http_completed)
		_http.cancel_request()
		if _http.get_parent() == self:
			remove_child(_http)
		_http.queue_free()
	_http = null
	if recreate and not _shutdown and is_inside_tree():
		_ready()
