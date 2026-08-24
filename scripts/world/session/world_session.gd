class_name WorldSession
extends Node3D
## Thin world session coordinator; initializes services and exposes read-only APIs.

signal region_changed(region_id: StringName)
signal restore_failed(reason: StringName)

@export var player_scene: PackedScene
@export var initial_region_id: StringName = &"base:town"
@export var autosave_interval: float = 60.0

var event_bus := GameplayEventBus.new()
var player: PlayerController3D
var current_region_id: StringName = &""
var discovered_regions: Array = ["base:town"]
var unlocked_pet_ids: Array = []
var active_pet_instance_id: StringName = &""
var unlocked_mount_ids: Array = []
var _autosave_timer: float = 0.0
var _autosave_enabled: bool = true
var _restore_failed_state: bool = false
var _session_context: WorldSessionContext
var _pending_player_transform: Dictionary = {}
var _skip_saved_player_transform: bool = false
var pet_conversation_service: Node
var pet_motion_assessment_service: PetMotionAssessmentService
var pet_motion_gateway: NPCDialogueGateway
var intent_validator := WorldIntentValidator.new()
var intent_executor := WorldIntentExecutor.new()

@onready var persistent_root: Node3D = $PersistentRoot
@onready var player_root: Node3D = $PersistentRoot/PlayerRoot
@onready var companion_root: Node3D = $PersistentRoot/CompanionRoot
@onready var active_region_slot: Node3D = $ActiveRegionSlot
@onready var world_services: Node = $WorldServices
@onready var entity_repository: WorldEntityRepository = $WorldServices/WorldEntityRepository
@onready var actor_factory: ActorFactory = $WorldServices/ActorFactory
@onready var region_service: RegionRuntimeService = $WorldServices/RegionRuntimeService
@onready var interaction_index: InteractionIndex = $WorldServices/InteractionIndex
@onready var dialogue_coordinator: DialogueCoordinator = $WorldServices/DialogueCoordinator
@onready var quest_event_router: QuestEventRouter = $WorldServices/QuestEventRouter
@onready var quest_coordinator: QuestCoordinator = $WorldServices/QuestCoordinator
@onready var save_coordinator: WorldSaveCoordinator = $WorldServices/WorldSaveCoordinator
@onready var simulation_service: WorldSimulationService = $WorldServices/WorldSimulationService
@onready var world_flags: WorldFlagService = $WorldServices/WorldFlagService
@onready var cognition_service: NPCCognitionService = $WorldServices/NPCCognitionService
@onready var dungeon_progression_service: DungeonProgressionService = $WorldServices/DungeonProgressionService
@onready var property_bank_service: PropertyBankService = $WorldServices/PropertyBankService
@onready var hidden_encounter_service: HiddenEncounterService = $WorldServices/HiddenEncounterService
@onready var actor_economy_service: ActorEconomyService = $WorldServices/ActorEconomyService

# Compatibility aliases for tests and legacy code paths.
var regions_root: Node3D
var actors_root: Node3D
var interactables_root: Node3D


func _ready() -> void:
	add_to_group("world_manager")
	regions_root = active_region_slot
	actors_root = companion_root
	interactables_root = active_region_slot
	_setup_services()
	_spawn_player()
	_spawn_companions()
	var start_region := RegionIdUtil.normalize(initial_region_id)
	if GameManager.resume_requested:
		var validation := SaveSlotService.inspect_adventure_summary()
		var restored := false
		if bool(validation.get("valid", false)):
			restored = save_coordinator.restore_session()
		GameManager.resume_requested = false
		if restored:
			current_region_id = region_service.get_current_region_id()
			if current_region_id == &"":
				restored = false
		if not restored:
			var reason := StringName(str(validation.get("reason", "restore_failed")))
			if reason == &"":
				reason = &"restore_failed"
			_handle_restore_failure(reason)
			return
	else:
		region_service.enter_region(start_region)
		current_region_id = region_service.get_current_region_id()
	if player != null:
		player.current_region_id = current_region_id
		player.refresh_contextual_capabilities()
	region_service.region_changed.connect(_on_region_changed)
	if not WorldTimeService.hour_changed.is_connected(_on_world_hour_changed):
		WorldTimeService.hour_changed.connect(_on_world_hour_changed)
	if EventBus.has_signal("request_world_save"):
		EventBus.request_world_save.connect(save_world_state)


func _process(delta: float) -> void:
	if not _autosave_enabled or _restore_failed_state:
		return
	_autosave_timer += delta
	if _autosave_timer >= autosave_interval:
		_autosave_timer = 0.0
		# Autosave always marks core sections; regions only if dirty.
		save_coordinator.mark_dirty(&"player")
		save_coordinator.mark_dirty(&"global_world")
		save_coordinator.save_dirty_sections()


func _exit_tree() -> void:
	# A background personality assessment may still own an HTTPRequest when a
	# test, scene transition, or player exit frees the world. Shut it down without
	# constructing a replacement transport in the exiting tree.
	if pet_motion_gateway != null and is_instance_valid(pet_motion_gateway):
		pet_motion_gateway.shutdown()


func _physics_process(_delta: float) -> void:
	if _restore_failed_state:
		return
	if player != null:
		var nearby := interaction_index.query_nearby(player, 3.0)
		player.update_interaction_targets(nearby)


func transition_to(
	region_id: StringName,
	spawn_id: StringName = &"spawn",
	via_portal: bool = true,
) -> bool:
	var ctx := RegionTransitionContext.new()
	ctx.source_region_id = current_region_id
	ctx.target_spawn_id = spawn_id
	ctx.via_portal = via_portal
	if player != null:
		player.set_input_enabled(false)
	var transitioned := region_service.enter_region(region_id, spawn_id, ctx)
	if player != null:
		player.set_input_enabled(true)
	if not transitioned:
		return false
	discover_region(region_id)
	save_world_state()
	return true


func travel_via_road(region_id: StringName, spawn_id: StringName = &"spawn") -> bool:
	if not _route_is_authored(region_id, false):
		EventBus.notice_requested.emit("That road does not connect to this region.")
		return false
	return transition_to(region_id, spawn_id, false)


func travel_via_portal(region_id: StringName, spawn_id: StringName = &"spawn") -> bool:
	if not _route_is_authored(region_id, true):
		EventBus.notice_requested.emit("That portal route is not available here.")
		return false
	return transition_to(region_id, spawn_id, true)


func travel_via_door(region_id: StringName, spawn_id: StringName = &"spawn") -> bool:
	# Doors use the connected-region graph, but may link an outdoor main-world
	# region to a private interior. Dungeon travel is deliberately excluded and
	# must pass through DungeonProgressionService's guarded level gate.
	var target := ResourceRegistry.get_region(RegionIdUtil.normalize(region_id))
	if target == null or target.region_type == &"dungeon" or not _route_is_authored(
		region_id, false
	):
		EventBus.notice_requested.emit("That doorway is not connected from here.")
		return false
	return transition_to(region_id, spawn_id, false)


func _route_is_authored(region_id: StringName, portal: bool) -> bool:
	var source := ResourceRegistry.get_region(RegionIdUtil.normalize(current_region_id))
	var target := ResourceRegistry.get_region(RegionIdUtil.normalize(region_id))
	if source == null or target == null:
		return false
	if portal:
		return source.portal_region_ids.has(target.id)
	return (
		source.connected_region_ids.has(target.id)
		and target.connected_region_ids.has(source.id)
		and source.parent_world_id == target.parent_world_id
	)


func discover_region(region_id: StringName) -> void:
	var norm := String(RegionIdUtil.normalize(region_id))
	if not discovered_regions.has(norm):
		discovered_regions.append(norm)
		save_coordinator.mark_dirty(&"global_world")


func save_world_state() -> bool:
	# A failed restore must remain read-only until this partial session is removed.
	if _restore_failed_state or not _autosave_enabled or player == null:
		return false
	save_coordinator.mark_dirty(&"player")
	save_coordinator.mark_dirty(&"global_world")
	save_coordinator.mark_dirty(&"relationships")
	save_coordinator.mark_dirty(&"quests")
	save_coordinator.mark_dirty(&"world_flags")
	save_coordinator.mark_dirty(&"companions")
	save_coordinator.mark_region_dirty(region_service.get_current_region_id())
	return save_coordinator.save_dirty_sections()


func load_world_state() -> bool:
	var restored := save_coordinator.restore_session()
	if restored:
		return true
	var validation := SaveSlotService.inspect_adventure_summary()
	var reason := StringName(str(validation.get("reason", "restore_failed")))
	if reason == &"":
		reason = &"restore_failed"
	_handle_restore_failure(reason)
	return false


func _handle_restore_failure(reason: StringName = &"restore_failed") -> void:
	if _restore_failed_state:
		return
	_restore_failed_state = true
	_autosave_enabled = false
	_autosave_timer = 0.0
	set_process(false)
	set_physics_process(false)
	if player != null:
		player.set_input_enabled(false)
	if region_service != null:
		region_service.unload_current_region()
	current_region_id = &""
	_pending_player_transform.clear()
	GameManager.run_active = false
	restore_failed.emit(reason)
	push_error(
		"WorldSession: restore failed (%s); returning to the main menu without saving"
		% String(reason)
	)
	SceneRouter.call_deferred("go_to_main_menu")


func start_dialogue(npc: NPCController) -> bool:
	return dialogue_coordinator.start_dialogue(npc, player)


func apply_dialogue_choice(index: int) -> void:
	dialogue_coordinator.apply_choice(index)


func ask_active_npc(text: String) -> bool:
	return dialogue_coordinator.start_free_form_from_active(text)


func cancel_free_form_dialogue() -> void:
	dialogue_coordinator.cancel_free_form()


func cancel_active_dialogue() -> void:
	dialogue_coordinator.cancel_dialogue()


func capture_player_data() -> Dictionary:
	var inventory_data := player.inventory.to_dict() if player.inventory else {}
	var equipment_data := player.equipment.to_dict() if player.equipment else {}
	var wallet_data := player.wallet.to_dict() if player.wallet else {}
	var player_data := player.to_dict()
	player_data.erase("inventory")
	player_data.erase("equipment")
	player_data["region_id"] = String(current_region_id)
	return {
		"player": player_data,
		"inventory": inventory_data,
		"equipment": equipment_data,
		"wallet": wallet_data,
	}


func restore_player_data(data: Dictionary) -> void:
	if player == null:
		return
	var player_data: Dictionary = data.get("player", {})
	_pending_player_transform = player_data.get("position", {})
	# Restore non-transform fields first; position applied after region load.
	var saved_pos := player.global_position
	player.from_dict(player_data)
	player.global_position = saved_pos
	if player.inventory != null:
		player.inventory.from_dict(data.get("inventory", {}))
	if player.equipment != null:
		player.equipment.from_dict(data.get("equipment", {}))
	if player.wallet != null and data.get("wallet", {}) is Dictionary \
			and not (data.get("wallet", {}) as Dictionary).is_empty():
		player.wallet.from_dict(data.get("wallet", {}) as Dictionary)
	player.apply_equipment_bonuses()


func apply_saved_player_transform(data: Dictionary) -> void:
	if player == null:
		return
	if _skip_saved_player_transform:
		_skip_saved_player_transform = false
		_pending_player_transform.clear()
		return
	var player_data: Dictionary = data.get("player", data)
	var pos: Dictionary = player_data.get("position", _pending_player_transform)
	if pos.is_empty():
		return
	player.global_position = Vector3(
		float(pos.get("x", player.global_position.x)),
		float(pos.get("y", player.global_position.y)),
		float(pos.get("z", player.global_position.z)),
	)
	player.reset_physics_interpolation()
	_pending_player_transform.clear()


func capture_global_world_data() -> Dictionary:
	return {
		"world_time": WorldTimeService.to_dict(),
		"discovered_regions": discovered_regions.duplicate(),
		"current_region_id": String(current_region_id),
		"property_banking": property_bank_service.capture_save_data()
			if property_bank_service != null else {},
		"hidden_encounters": hidden_encounter_service.capture_save_data()
			if hidden_encounter_service != null else {},
		"actor_economy": actor_economy_service.capture_save_data()
			if actor_economy_service != null else {},
	}


func restore_global_world_data(data: Dictionary) -> void:
	var discovered: Variant = data.get("discovered_regions", ["base:town"])
	if typeof(discovered) == TYPE_ARRAY:
		discovered_regions.clear()
		for d in discovered:
			discovered_regions.append(String(RegionIdUtil.normalize(StringName(str(d)))))
	if discovered_regions.is_empty():
		discovered_regions = ["base:town"]
	if property_bank_service != null:
		property_bank_service.restore_save_data(
			data.get("property_banking", {}) as Dictionary
			if data.get("property_banking", {}) is Dictionary else {}
		)
	if hidden_encounter_service != null:
		hidden_encounter_service.restore_save_data(
			data.get("hidden_encounters", {}) as Dictionary
			if data.get("hidden_encounters", {}) is Dictionary else {}
		)
	if actor_economy_service != null:
		actor_economy_service.restore_save_data(
			data.get("actor_economy", {}) as Dictionary
			if data.get("actor_economy", {}) is Dictionary else {}
		)


func open_property_storage(mode: StringName) -> bool:
	if property_bank_service == null or player == null:
		return false
	if mode == PropertyBankService.HOME_STORAGE_MODE and not property_bank_service.has_active_house():
		return false
	var menu := get_node_or_null("WorldUI/PropertyStorageMenu")
	if menu == null or not menu.has_method("open_menu"):
		return false
	menu.call("open_menu", mode)
	return true


func open_commerce(
	shop_id: StringName,
	forge_recipe_ids: Array[StringName] = [],
) -> bool:
	if property_bank_service == null or player == null:
		return false
	var shop := ResourceRegistry.get_shop(shop_id)
	if shop == null:
		return false
	var menu := get_node_or_null("WorldUI/CommerceMenu")
	if menu == null or not menu.has_method("open_menu"):
		return false
	menu.call("open_menu", shop_id, forge_recipe_ids)
	return true


func open_pet_companion(pet: Node = null) -> bool:
	var target: Node = pet if pet != null else get_active_pet()
	var menu := get_node_or_null("WorldUI/PetCompanionMenu")
	if target == null or menu == null:
		return false
	if target is PetController:
		set_active_pet((target as PetController).runtime_state.get_pet_instance_id())
	menu.call("open_menu", target)
	return bool(menu.call("is_open"))


func ask_pet(pet: Node, text: String) -> bool:
	return bool(pet_conversation_service.call(
		"request_turn", pet, text, &"player_initiated"
	)) if pet_conversation_service != null else false


func resolve_restored_region_id(region_id: StringName) -> StringName:
	if (
		region_id == &"base:player_home"
		and property_bank_service != null
		and not property_bank_service.has_active_house()
	):
		_skip_saved_player_transform = true
		call_deferred("_notify_repossessed_return")
		return &"base:town"
	return region_id


func _notify_repossessed_return() -> void:
	EventBus.notice_requested.emit(
		"Your residence was reclaimed during your absence. Stillpoint Bank holds the compensation and every stored belonging."
	)


func capture_companions() -> Dictionary:
	return {
		"pets": _serialize_pets(),
		"active_pet_instance_id": String(active_pet_instance_id),
		"mounts": _serialize_mount(),
		"unlocked_pet_ids": unlocked_pet_ids.duplicate(),
		"unlocked_mount_ids": unlocked_mount_ids.duplicate(),
	}


func restore_companions(data: Dictionary) -> void:
	var unlocked_value: Variant = data.get("unlocked_pet_ids", [])
	unlocked_pet_ids = unlocked_value.duplicate() if unlocked_value is Array else []
	_restore_pets(data.get("pets", {}))
	var requested_active := StringName(str(data.get("active_pet_instance_id", "")))
	if get_pet_by_instance_id(requested_active) != null:
		active_pet_instance_id = requested_active
	elif get_pet_by_instance_id(active_pet_instance_id) != null:
		# Legacy one-pet saves did not persist an active instance. Preserve the
		# already-authored Pip selection instead of changing it due to ID sorting.
		pass
	else:
		var pets := get_owned_pets()
		active_pet_instance_id = pets[0].runtime_state.get_pet_instance_id() \
			if not pets.is_empty() else &""
	_restore_mount(data.get("mounts", {}))
	unlocked_mount_ids = data.get("unlocked_mount_ids", []).duplicate()


func unlock_pet(pet_id: StringName) -> bool:
	var key := String(pet_id)
	var definition := ResourceRegistry.get_pet_companion(pet_id)
	if key.is_empty():
		return false
	if not unlocked_pet_ids.has(key):
		unlocked_pet_ids.append(key)
		var instance_id := _default_pet_instance_id(pet_id)
		if definition != null and definition.is_valid() \
				and get_pet_by_instance_id(instance_id) == null:
			var pet := _create_pet_actor(definition, instance_id)
			if pet == null:
				unlocked_pet_ids.erase(key)
				return false
			if not _register_pet_actor(pet):
				pet.queue_free()
				unlocked_pet_ids.erase(key)
				return false
		save_coordinator.mark_dirty(&"companions")
	return true


func set_active_pet(instance_id: StringName) -> bool:
	var pet := get_pet_by_instance_id(instance_id)
	if pet == null:
		return false
	if active_pet_instance_id == instance_id:
		return true
	active_pet_instance_id = instance_id
	save_coordinator.mark_dirty(&"companions")
	return true


func get_active_pet() -> PetController:
	var selected := get_pet_by_instance_id(active_pet_instance_id)
	if selected != null:
		return selected
	var pets := get_owned_pets()
	return pets[0] if not pets.is_empty() else null


func get_pet_by_instance_id(instance_id: StringName) -> PetController:
	if instance_id == &"":
		return null
	for pet in get_owned_pets():
		if pet.runtime_state.get_pet_instance_id() == instance_id:
			return pet
	return null


func get_owned_pets() -> Array[PetController]:
	var result: Array[PetController] = []
	for child in companion_root.get_children():
		if child is PetController:
			result.append(child as PetController)
	result.sort_custom(func(a: PetController, b: PetController) -> bool:
		return String(a.runtime_state.get_pet_instance_id()) \
			< String(b.runtime_state.get_pet_instance_id()))
	return result


func unlock_mount(mount_id: StringName) -> bool:
	var key := String(mount_id)
	if key.is_empty():
		return false
	if not unlocked_mount_ids.has(key):
		unlocked_mount_ids.append(key)
		save_coordinator.mark_dirty(&"companions")
	return true


func get_session_context() -> WorldSessionContext:
	return _session_context


func submit_intent(proposal: IntentProposal) -> IntentValidationResult:
	return intent_executor.execute(proposal)


func submit_interaction_intent(
	proposal: IntentProposal,
	conditions: Array[WorldCondition],
	effects: Array[WorldEffect],
) -> IntentValidationResult:
	return intent_executor.execute_interaction(proposal, conditions, effects)


func _setup_services() -> void:
	if pet_conversation_service == null:
		var script: GDScript = load(
			"res://scripts/pet_cognition/pet_conversation_service.gd"
		) as GDScript
		pet_conversation_service = script.new() if script != null else null
	if pet_conversation_service != null and pet_conversation_service.get_parent() == null:
		pet_conversation_service.name = "PetConversationService"
		world_services.add_child(pet_conversation_service)
	if pet_motion_assessment_service == null:
		pet_motion_assessment_service = PetMotionAssessmentService.new()
		pet_motion_assessment_service.name = "PetMotionAssessmentService"
		world_services.add_child(pet_motion_assessment_service)
	if pet_motion_gateway == null:
		pet_motion_gateway = NPCDialogueGateway.new()
		pet_motion_gateway.name = "PetMotionGateway"
		world_services.add_child(pet_motion_gateway)
	actor_factory.setup(entity_repository)
	region_service.setup(self, entity_repository, actor_factory, interaction_index)
	dungeon_progression_service.setup(self, actor_factory)
	property_bank_service.setup(self)
	hidden_encounter_service.setup(self, event_bus)
	actor_economy_service.setup(self, entity_repository)
	# Resolved from WorldSession root via RegionRuntimeService._get_slot().
	region_service.active_region_slot_path = NodePath("ActiveRegionSlot")
	save_coordinator.setup(self, entity_repository, region_service, world_flags)
	if not property_bank_service.property_state_changed.is_connected(_on_property_state_changed):
		property_bank_service.property_state_changed.connect(_on_property_state_changed)
	if not actor_economy_service.economic_state_changed.is_connected(_on_actor_economic_state_changed):
		actor_economy_service.economic_state_changed.connect(_on_actor_economic_state_changed)
	simulation_service.setup(entity_repository)
	_session_context = WorldSessionContext.new(
		self, null, entity_repository, region_service,
		QuestManager, world_flags,
	)
	intent_validator.setup(_session_context)
	intent_executor.setup(_session_context, intent_validator)
	cognition_service.setup(_session_context, event_bus, entity_repository)
	# Movement assessment is low-priority and may wait on a provider. Give it an
	# independent transport so a player-initiated NPC/pet conversation can never
	# receive backend_busy because a background temperament refresh is in flight.
	pet_motion_gateway.configure(SaveService.get_or_create_client_install_id())
	if pet_conversation_service != null:
		pet_conversation_service.call(
			"setup",
			cognition_service.gateway,
			cognition_service.save_provider.cache,
			cognition_service.save_provider.backend_player_profile_id,
			cognition_service.save_provider.world_save_id,
		)
		if not pet_conversation_service.is_connected("reply_ready", _on_pet_reply_ready):
			pet_conversation_service.connect("reply_ready", _on_pet_reply_ready)
	pet_motion_assessment_service.setup(
		pet_motion_gateway,
		cognition_service.save_provider.backend_player_profile_id,
		cognition_service.save_provider.world_save_id,
	)
	if not pet_motion_assessment_service.assessment_ready.is_connected(
		_on_pet_motion_assessment_ready
	):
		pet_motion_assessment_service.assessment_ready.connect(
			_on_pet_motion_assessment_ready
		)
	if not save_coordinator.register_save_provider(cognition_service.save_provider):
		push_error("WorldSession: failed to register the shared cognition save provider")
	dialogue_coordinator.setup(_session_context, cognition_service)
	quest_coordinator.setup(_session_context)
	quest_event_router.setup(_session_context, event_bus, quest_coordinator)


func _spawn_player() -> void:
	if player_scene == null:
		return
	player = player_scene.instantiate() as PlayerController3D
	player_root.add_child(player)
	property_bank_service.bind_wallet(player.wallet)
	player.add_to_group("player")
	var identity := WorldEntityIdentity.new()
	identity.name = "WorldEntityIdentity"
	identity.persistent_id = &"base:player/main"
	identity.definition_id = &"player"
	identity.region_id = RegionIdUtil.normalize(initial_region_id)
	identity.persistence_policy = WorldEntityIdentity.PersistencePolicy.GLOBAL
	player.add_child(identity)
	entity_repository.register_entity(player)
	_session_context.player = player
	if not GameManager.resume_requested:
		player.apply_character_build(GameManager.consume_pending_character_build(), true)
		_grant_starter_inventory()
	if player.inventory != null and not player.inventory.inventory_changed.is_connected(_on_player_items_changed):
		player.inventory.inventory_changed.connect(_on_player_items_changed)
	if player.equipment != null and not player.equipment.equipment_changed.is_connected(_on_player_items_changed):
		player.equipment.equipment_changed.connect(_on_player_items_changed)
	if player.equipment != null and not player.equipment.presentation_mode_changed.is_connected(_on_player_presentation_mode_changed):
		player.equipment.presentation_mode_changed.connect(_on_player_presentation_mode_changed)
	if player.experience != null and not player.experience.experience_changed.is_connected(_on_player_progression_changed):
		player.experience.experience_changed.connect(_on_player_progression_changed)
	if player.skill_loadout != null and not player.skill_loadout.loadout_changed.is_connected(_on_player_items_changed):
		player.skill_loadout.loadout_changed.connect(_on_player_items_changed)
	var camera_rig := get_node_or_null("CameraRig") as CameraController3D
	if camera_rig != null:
		camera_rig.set_target(player)


func _on_property_state_changed() -> void:
	if save_coordinator != null:
		save_coordinator.mark_dirty(&"global_world")


func _spawn_companions() -> void:
	var legacy_pet := companion_root.get_node_or_null("Pet") as PetController
	if legacy_pet != null:
		unlocked_pet_ids = [String(legacy_pet.pet_id)]
		if _register_pet_actor(legacy_pet):
			active_pet_instance_id = legacy_pet.runtime_state.get_pet_instance_id()
	for definition in ResourceRegistry.get_all_pet_companions():
		if definition == null or not definition.is_valid() \
				or definition.id == &"mossfox":
			continue
		var key := String(definition.id)
		if not unlocked_pet_ids.has(key):
			unlocked_pet_ids.append(key)
		var instance_id := _default_pet_instance_id(definition.id)
		if get_pet_by_instance_id(instance_id) != null:
			continue
		var pet := _create_pet_actor(definition, instance_id)
		if pet != null:
			if not _register_pet_actor(pet):
				pet.queue_free()
	var mount := companion_root.get_node_or_null("Mount") as MountController
	if mount != null:
		var mid := mount.get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
		if mid != null:
			entity_repository.register_entity(mount)


func _grant_starter_inventory() -> void:
	if player == null or player.inventory == null:
		return
	var profession := ResourceRegistry.get_profession(player.profession_id)
	if not StarterKitCalculator.grant(player.inventory, profession):
		push_warning("WorldSession: invalid profession starter kit; using safe default")
		if not StarterKitCalculator.grant_safe_default(player.inventory):
			push_error("WorldSession: could not grant safe starter inventory")
	if not StarterKitCalculator.grant_farming_essentials(player.inventory):
		push_error("WorldSession: could not grant farming essentials")
	if not StarterKitCalculator.grant_utility_essentials(player.inventory):
		push_error("WorldSession: could not grant utility essentials")
	if not StarterKitCalculator.grant_equipment_foundation(player.inventory):
		push_error("WorldSession: could not grant equipment foundation")
	for pet_item_id in [&"mossfox_collar", &"mossfox_harness", &"quiet_bell_charm"]:
		if player.inventory.add_item(pet_item_id, 1) != 1:
			push_error("WorldSession: could not grant starter pet equipment %s" % pet_item_id)


func _on_player_progression_changed(_current: int, _to_next: int, _level: int) -> void:
	if save_coordinator != null:
		save_coordinator.mark_dirty(&"player")


func _serialize_pets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for pet in get_owned_pets():
		result.append(pet.to_dict())
	return result


func _serialize_mount() -> Dictionary:
	var mount := companion_root.get_node_or_null("Mount") as MountController
	if mount == null:
		return {}
	return mount.to_dict()


func _restore_pets(data: Variant) -> void:
	var entries: Array = []
	if data is Array:
		entries = data as Array
	elif data is Dictionary and not (data as Dictionary).is_empty():
		# Save v4/0.8 compatibility: the previous schema stored one pet dictionary.
		entries = [data]
	var restored_ids: Dictionary = {}
	for value in entries:
		if not value is Dictionary:
			continue
		var pet_data := value as Dictionary
		var definition_id := StringName(str(
			pet_data.get("definition_id", pet_data.get("pet_id", "mossfox"))
		))
		# The original one-pet save used placeholder aliases. Resolve them before
		# looking in the new catalog; PetController will then migrate the remaining
		# v0 fields (bond/mode/region) against the canonical mossfox definition.
		if int(pet_data.get("section_version", 0)) == 0 \
				and String(definition_id) in ["placeholder_pet", "pet"]:
			definition_id = &"mossfox"
		var definition := ResourceRegistry.get_pet_companion(definition_id)
		if definition == null or not definition.is_valid():
			continue
		var instance_id := StringName(str(pet_data.get(
			"instance_id", _default_pet_instance_id(definition_id)
		)))
		var pet := get_pet_by_instance_id(instance_id)
		if pet == null:
			# Save data cannot claim the player's, an NPC's, or another world
			# entity's persistent identity as a pet cognition/memory scope.
			if entity_repository.get_loaded_entity(instance_id) != null:
				continue
			pet = _create_pet_actor(definition, instance_id)
			if pet == null:
				continue
			if not _register_pet_actor(pet):
				pet.queue_free()
				continue
		pet.from_dict(pet_data)
		pet.setup(player)
		pet.update_region_presence(region_service.get_current_region_id())
		restored_ids[String(pet.runtime_state.get_pet_instance_id())] = true
		var key := String(definition_id)
		if not unlocked_pet_ids.has(key):
			unlocked_pet_ids.append(key)
	# Newly authored companion types become independently owned instances without
	# replacing or resetting any restored pet. Their future unlock conditions can
	# remove them from this starter roster without changing the save schema.
	for definition in ResourceRegistry.get_all_pet_companions():
		if definition == null or not definition.is_valid():
			continue
		if not unlocked_pet_ids.has(String(definition.id)):
			unlocked_pet_ids.append(String(definition.id))
		var instance_id := _default_pet_instance_id(definition.id)
		if restored_ids.has(String(instance_id)) or get_pet_by_instance_id(instance_id) != null:
			continue
		var pet := _create_pet_actor(definition, instance_id)
		if pet != null:
			if not _register_pet_actor(pet):
				pet.queue_free()


func _create_pet_actor(
	definition: PetCompanionDefinition,
	instance_id: StringName,
) -> PetController:
	if definition == null or not definition.is_valid() or instance_id == &"":
		return null
	if definition.scene != null:
		if not definition.scene.can_instantiate():
			push_error("WorldSession: pet scene cannot be instantiated for %s" % definition.id)
			return null
		var scene_root := definition.scene.instantiate()
		var authored_pet := scene_root as PetController
		if authored_pet == null:
			push_error("WorldSession: pet scene root is not PetController for %s" % definition.id)
			scene_root.free()
			return null
		if _configure_authored_pet_actor(authored_pet, definition, instance_id):
			return authored_pet
		authored_pet.free()
		return null
	var pet := PetController.new()
	pet.name = "Pet_%s" % String(definition.id)
	pet.pet_id = definition.id
	pet.pet_definition = definition
	pet.region_id = RegionIdUtil.normalize(initial_region_id)
	var identity := WorldEntityIdentity.new()
	identity.name = "WorldEntityIdentity"
	identity.persistent_id = instance_id
	identity.definition_id = definition.id
	identity.region_id = pet.region_id
	identity.persistence_policy = WorldEntityIdentity.PersistencePolicy.GLOBAL
	pet.add_child(identity)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4 * definition.species.visual_scale
	shape.height = 1.25 * definition.species.visual_scale
	collision.position = Vector3(0.0, shape.height * 0.32, 0.0)
	collision.shape = shape
	pet.add_child(collision)
	var hurtbox := PetHurtbox3D.new()
	hurtbox.name = "PetHurtbox3D"
	hurtbox.team = &"player"
	pet.add_child(hurtbox)
	var hurt_shape := CollisionShape3D.new()
	hurt_shape.name = "CollisionShape3D"
	hurt_shape.position = collision.position
	hurt_shape.shape = shape.duplicate()
	hurtbox.add_child(hurt_shape)
	var visual_root := Node3D.new()
	visual_root.name = "VisualRoot"
	pet.add_child(visual_root)
	var model := StylizedPetModel.new()
	model.name = "PetModel"
	visual_root.add_child(model)
	var interactable := PetInteractable.new()
	interactable.name = "PetInteractable"
	interactable.pet_path = NodePath("..")
	interactable.region_id = pet.region_id
	pet.add_child(interactable)
	var spawn_offset := float(get_owned_pets().size()) * 1.8
	pet.position = Vector3(-1.0 + spawn_offset, 1.0, -1.0)
	companion_root.add_child(pet)
	return pet


func _configure_authored_pet_actor(
	pet: PetController,
	definition: PetCompanionDefinition,
	instance_id: StringName,
) -> bool:
	# A custom scene is accepted only when it exposes the same narrow runtime
	# contract as the procedural fallback. Gameplay remains on PetController;
	# the scene controls presentation and authored collision dimensions.
	var identity := pet.get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
	var collision := pet.get_node_or_null("CollisionShape3D") as CollisionShape3D
	var hurtbox := pet.get_node_or_null("PetHurtbox3D") as PetHurtbox3D
	var hurt_collision := pet.get_node_or_null(
		"PetHurtbox3D/CollisionShape3D"
	) as CollisionShape3D
	var model := pet.get_node_or_null("VisualRoot/PetModel") as StylizedPetModel
	var interactable := pet.get_node_or_null("PetInteractable") as PetInteractable
	if identity == null or collision == null or collision.shape == null \
			or hurtbox == null \
			or hurt_collision == null or hurt_collision.shape == null \
			or model == null or interactable == null:
		push_error("WorldSession: invalid authored pet scene contract for %s" % definition.id)
		return false
	if not pet.configure_definition(definition, instance_id):
		push_error("WorldSession: authored pet scene could not configure %s" % definition.id)
		return false
	pet.name = "Pet_%s" % String(definition.id)
	pet.region_id = RegionIdUtil.normalize(initial_region_id)
	identity.persistent_id = instance_id
	identity.definition_id = definition.id
	identity.region_id = pet.region_id
	identity.persistence_policy = WorldEntityIdentity.PersistencePolicy.GLOBAL
	# Companion ownership is restored from companions.json, not regional actor
	# snapshots. Marking it runtime-spawned would route it through ActorFactory.
	identity.runtime_spawned = false
	var scale_factor := definition.species.visual_scale
	for shape_node in [collision, hurt_collision]:
		if shape_node.shape is CapsuleShape3D:
			var shape := (shape_node.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
			shape.radius *= scale_factor
			shape.height *= scale_factor
			shape_node.shape = shape
			shape_node.position.y = shape.height * 0.32
	interactable.pet_path = NodePath("..")
	interactable.region_id = pet.region_id
	var spawn_offset := float(get_owned_pets().size()) * 1.8
	pet.position = Vector3(-1.0 + spawn_offset, 1.0, -1.0)
	companion_root.add_child(pet)
	return true


func _register_pet_actor(pet: PetController) -> bool:
	if pet == null or player == null:
		return false
	var identity := pet.get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
	if identity != null:
		var loaded := entity_repository.get_loaded_entity(identity.persistent_id)
		if loaded == null:
			if not entity_repository.register_entity(pet):
				return false
		elif loaded != pet:
			return false
	else:
		return false
	pet.setup(player)
	if not pet.state_changed.is_connected(_on_pet_state_changed):
		pet.state_changed.connect(_on_pet_state_changed)
	if not pet.autonomous_dialogue_requested.is_connected(
		_on_pet_autonomous_dialogue_requested
	):
		pet.autonomous_dialogue_requested.connect(
			_on_pet_autonomous_dialogue_requested.bind(pet)
		)
	var interactable := pet.get_node_or_null("PetInteractable") as Interactable
	if interactable != null:
		interaction_index.register(interactable)
	pet.update_region_presence(
		current_region_id if current_region_id != &"" else initial_region_id
	)
	if active_pet_instance_id == &"":
		active_pet_instance_id = pet.runtime_state.get_pet_instance_id()
	if not pet.motion_assessment_requested.is_connected(
		_on_pet_motion_assessment_requested.bind(pet)
	):
		pet.motion_assessment_requested.connect(
			_on_pet_motion_assessment_requested.bind(pet)
		)
	return true


func _default_pet_instance_id(definition_id: StringName) -> StringName:
	return &"base:town/companion/pet" if definition_id == &"mossfox" \
		else StringName("base:player/pet/%s_0001" % String(definition_id))


func _restore_mount(data: Dictionary) -> void:
	var mount := companion_root.get_node_or_null("Mount") as MountController
	if mount != null and not data.is_empty():
		mount.from_dict(data)


func _on_region_changed(_previous: StringName, current: StringName) -> void:
	current_region_id = current
	if player != null:
		player.current_region_id = current
		player.refresh_contextual_capabilities()
	region_changed.emit(current)
	EventBus.region_changed.emit(current)
	for pet in get_owned_pets():
		var present := pet.update_region_presence(current)
		if present:
			var interactable := pet.get_node_or_null("PetInteractable") as Interactable
			if interactable != null:
				# RegionRuntimeService clears the spatial index while unloading a
				# region. Companions live under PersistentRoot, so register their
				# persistent interaction entry again after the new region is active.
				interaction_index.register(interactable)
	var ev := GameplayEvent.make(
		GameplayEventTypes.REGION_ENTERED,
		&"base:player/main",
		&"",
		&"",
		current,
	)
	event_bus.emit_event(ev)


func _on_world_hour_changed(_day: int, _hour: int) -> void:
	for pet in get_owned_pets():
		pet.sync_game_clock(not pet.is_present_in_current_region())


func _on_pet_state_changed(_reason: StringName) -> void:
	if save_coordinator != null:
		save_coordinator.mark_dirty(&"companions")


func _on_actor_economic_state_changed(_actor_id: StringName, worksite_changed: bool) -> void:
	if save_coordinator != null and worksite_changed:
		save_coordinator.mark_dirty(&"global_world")


func _on_pet_reply_ready(reply: Dictionary) -> void:
	var pet_instance_id := StringName(str(reply.get("pet_instance_id", "")))
	var pet := get_pet_by_instance_id(pet_instance_id)
	if pet == null:
		pet = get_active_pet()
	var menu := get_node_or_null("WorldUI/PetCompanionMenu")
	if menu != null and bool(menu.call("is_open")):
		if bool(menu.call("show_reply", reply)):
			return
	if pet != null:
		pet.set_dialogue_motion(false)
	EventBus.ai_dialogue_reply.emit(
		pet.get_display_name() if pet != null else "Companion",
		str(reply.get("reply_text", "Your companion stays near.")),
	)


func _on_pet_motion_assessment_requested(context: Dictionary, pet: PetController) -> void:
	if pet_motion_assessment_service != null:
		pet_motion_assessment_service.request_assessment(pet, context)


func _on_pet_motion_assessment_ready(
	pet_instance_id: StringName,
	assessment: Dictionary,
) -> void:
	if not bool(SaveService.settings.get("ai_dialogue_enabled", false)):
		return
	var pet := get_pet_by_instance_id(pet_instance_id)
	if pet != null:
		pet.apply_motion_assessment(assessment)


func _on_pet_autonomous_dialogue_requested(
	context: Dictionary,
	pet: Node,
) -> void:
	if not bool(SaveService.settings.get("pet_proactive_dialogue_enabled", true)):
		return
	if pet_conversation_service == null or bool(pet_conversation_service.call("is_busy")):
		return
	# Only a neutral visible event crosses the client boundary. The server-owned
	# profile and entity_proactive provenance define how the pet may express it.
	var observation := "The companion is near its owner during a quiet moment."
	pet_conversation_service.call("request_turn", pet, observation, &"entity_proactive")


func _on_player_items_changed() -> void:
	if save_coordinator != null:
		save_coordinator.mark_dirty(&"player")


func _on_player_presentation_mode_changed(_mode: StringName) -> void:
	_on_player_items_changed()
