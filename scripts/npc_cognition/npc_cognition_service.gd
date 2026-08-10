class_name NPCCognitionService
extends Node
## WorldSession-owned composition root for dialogue, cache, save, observation and sync.

var save_provider := NPCCognitionSaveProvider.new()
var gateway := NPCDialogueGateway.new()
var conversation_controller := NPCConversationController.new()
var event_observation_coordinator := NPCEventObservationCoordinator.new()
var _sync_elapsed: float = 0.0
var _session_context: WorldSessionContext

func _ready() -> void:
	for component in [save_provider, gateway, conversation_controller, event_observation_coordinator]:
		if component.get_parent() == null:
			add_child(component)
	conversation_controller.setup(gateway, save_provider.cache)
	if not gateway.sync_completed.is_connected(_on_sync_completed):
		gateway.sync_completed.connect(_on_sync_completed)
	set_process(true)

func setup(
	context: WorldSessionContext,
	event_bus: GameplayEventBus,
	entity_repository: WorldEntityRepository,
) -> void:
	if not is_node_ready():
		_ready()
	_session_context = context
	var player_profile_id := SaveService.get_or_create_player_profile_id()
	var world_save_id := "slot-01"
	save_provider.backend_player_profile_id = player_profile_id
	save_provider.world_save_id = world_save_id
	gateway.configure(SaveService.get_or_create_client_install_id())
	event_observation_coordinator.setup(
		save_provider.cache,
		player_profile_id,
		world_save_id,
		event_bus,
		entity_repository,
	)

func _process(delta: float) -> void:
	_sync_elapsed += delta
	if _sync_elapsed >= 5.0:
		_sync_elapsed = 0.0
		sync_pending()

func _exit_tree() -> void:
	if gateway != null and is_instance_valid(gateway) \
		and gateway.sync_completed.is_connected(_on_sync_completed):
		gateway.sync_completed.disconnect(_on_sync_completed)
	if gateway != null and is_instance_valid(gateway) and gateway.is_busy() \
		and conversation_controller != null and is_instance_valid(conversation_controller):
		conversation_controller.cancel()

func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	# Object-valued script members can outlive an unparented/partially constructed
	# composition root. Explicit disposal keeps failed scene construction leak-free.
	for component in [
		event_observation_coordinator,
		conversation_controller,
		gateway,
		save_provider,
	]:
		if component != null and is_instance_valid(component):
			component.free()

func is_ai_enabled() -> bool:
	return bool(SaveService.settings.get("ai_dialogue_enabled", false))

func can_use_free_form(npc: NPCController) -> bool:
	return is_ai_enabled() \
		and npc != null \
		and npc.npc_definition != null \
		and npc.npc_definition.mind_profile != null \
		and NPCIdentityResolver.resolve_persistent_id(npc) != &""

func build_turn_payload(npc: NPCController, text: String) -> Dictionary:
	var persistent_id := NPCIdentityResolver.resolve_persistent_id(npc)
	if persistent_id == &"":
		return {}
	var player_profile_id := save_provider.backend_player_profile_id
	var world_save_id := save_provider.world_save_id
	var session_id := save_provider.cache.get_session(
		player_profile_id, world_save_id, String(persistent_id)
	)
	if session_id.is_empty():
		session_id = "%s/session" % String(persistent_id)
	var payload := {
		"request_id": "turn-%s-%s" % [String(persistent_id), Time.get_ticks_usec()],
		"player_profile_id": player_profile_id,
		"world_save_id": world_save_id,
		"npc_definition_id": String(npc.npc_definition.id),
		"npc_persistent_id": String(persistent_id),
		"session_id": session_id,
		"text": text.left(4000),
		"locale": TranslationServer.get_locale(),
		"allow_conversation_storage": bool(
			SaveService.settings.get("allow_conversation_storage", false)
		),
		"allow_memory_personalization": bool(
			SaveService.settings.get("allow_memory_personalization", false)
		),
		"world_context": {
			"region_id": String(npc.region_id),
			"game_time": WorldTimeService.to_dict(),
		},
	}
	var player := _session_context.player if _session_context != null else null
	var player_ontology := PlayerOntologySnapshotBuilder.build(
		player, GameManager.player_name
	)
	if not player_ontology.is_empty():
		payload["player_ontology"] = player_ontology
	return payload

func sync_pending() -> bool:
	var cache := save_provider.cache
	if gateway.is_busy() or (
		cache.pending_turn_outbox.is_empty() and cache.pending_event_outbox.is_empty()
	):
		return false
	var payload := {
		"player_profile_id": save_provider.backend_player_profile_id,
		"world_save_id": save_provider.world_save_id,
		"pending_turn_outbox": cache.pending_turn_outbox.duplicate(true),
		"pending_event_outbox": cache.pending_event_outbox.duplicate(true),
		"last_sync_revision": cache.last_sync_revision,
	}
	return gateway.request_sync(payload) == OK

func delete_npc_memory(npc_persistent_id: String) -> void:
	save_provider.delete_npc_memory(npc_persistent_id)

func delete_all_player_memory() -> void:
	save_provider.delete_all_player_memory()

func export_memory_data() -> Dictionary:
	return save_provider.export_memory_data()

func _on_sync_completed(result: Dictionary) -> void:
	if bool(result.get("ok", false)):
		save_provider.cache.apply_sync_ack(result)
