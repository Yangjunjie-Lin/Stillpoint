class_name WorldSession
extends Node3D
## Thin world session coordinator; initializes services and exposes read-only APIs.

signal region_changed(region_id: StringName)

@export var player_scene: PackedScene
@export var initial_region_id: StringName = &"base:town"
@export var autosave_interval: float = 60.0

var event_bus := GameplayEventBus.new()
var player: PlayerController3D
var current_region_id: StringName = &""
var discovered_regions: Array = ["base:town"]
var _autosave_timer: float = 0.0
var _session_context: WorldSessionContext

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
@onready var save_coordinator: WorldSaveCoordinator = $WorldServices/WorldSaveCoordinator
@onready var simulation_service: WorldSimulationService = $WorldServices/WorldSimulationService
@onready var world_flags: WorldFlagService = $WorldServices/WorldFlagService

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
		save_coordinator.restore_session()
		current_region_id = region_service.get_current_region_id()
		GameManager.resume_requested = false
	else:
		region_service.enter_region(start_region)
		current_region_id = region_service.get_current_region_id()
	region_service.region_changed.connect(_on_region_changed)
	if EventBus.has_signal("request_world_save"):
		EventBus.request_world_save.connect(save_world_state)
	QuestManager.quest_state_changed.connect(_on_quest_state_changed)


func _process(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer >= autosave_interval:
		_autosave_timer = 0.0
		save_world_state()


func _physics_process(_delta: float) -> void:
	if player != null:
		var nearby := interaction_index.query_nearby(player, 3.0)
		player.update_interaction_targets(nearby)


func transition_to(region_id: StringName, spawn_id: StringName = &"spawn") -> void:
	var ctx := RegionTransitionContext.new()
	ctx.target_spawn_id = spawn_id
	ctx.via_portal = true
	if player != null:
		player.set_input_enabled(false)
	region_service.enter_region(region_id, spawn_id, ctx)
	if player != null:
		player.set_input_enabled(true)
	discover_region(region_id)
	save_world_state()


func discover_region(region_id: StringName) -> void:
	var norm := String(RegionIdUtil.normalize(region_id))
	if not discovered_regions.has(norm):
		discovered_regions.append(norm)


func save_world_state() -> bool:
	if player == null:
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
	return save_coordinator.restore_session()


func start_dialogue(npc: NPCController) -> void:
	dialogue_coordinator.start_dialogue(npc, player)


func apply_dialogue_choice(index: int) -> void:
	dialogue_coordinator.apply_choice(index)


func capture_player_data() -> Dictionary:
	var inventory_data := player.inventory.to_dict() if player.inventory else {}
	var player_data := player.to_dict()
	player_data.erase("inventory")
	return {"player": player_data, "inventory": inventory_data}


func restore_player_data(data: Dictionary) -> void:
	if player == null:
		return
	player.from_dict(data.get("player", {}))
	if player.inventory != null:
		player.inventory.from_dict(data.get("inventory", {}))


func capture_companions() -> Dictionary:
	return {"pets": _serialize_pet(), "mounts": _serialize_mount()}


func restore_companions(data: Dictionary) -> void:
	_restore_pet(data.get("pets", {}))
	_restore_mount(data.get("mounts", {}))


func unlock_pet(_pet_id: StringName) -> void:
	pass


func unlock_mount(_mount_id: StringName) -> void:
	pass


func get_session_context() -> WorldSessionContext:
	return _session_context


func _setup_services() -> void:
	actor_factory.setup(entity_repository)
	region_service.setup(self, entity_repository, actor_factory, interaction_index)
	region_service.active_region_slot_path = NodePath("ActiveRegionSlot")
	save_coordinator.setup(self, entity_repository, region_service, world_flags)
	simulation_service.setup(entity_repository)
	_session_context = WorldSessionContext.new(
		self, null, entity_repository, region_service,
		QuestManager, world_flags,
	)
	dialogue_coordinator.setup(_session_context)
	quest_event_router.setup(_session_context, event_bus)


func _spawn_player() -> void:
	if player_scene == null:
		return
	player = player_scene.instantiate() as PlayerController3D
	player_root.add_child(player)
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
	var camera_rig := get_node_or_null("CameraRig") as CameraController3D
	if camera_rig != null:
		camera_rig.set_target(player)


func _spawn_companions() -> void:
	var pet := companion_root.get_node_or_null("Pet") as PetController
	if pet != null and player != null:
		pet.setup(player)
		var pid := pet.get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
		if pid != null:
			entity_repository.register_entity(pet)
	var mount := companion_root.get_node_or_null("Mount") as MountController
	if mount != null:
		var mid := mount.get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
		if mid != null:
			entity_repository.register_entity(mount)


func _serialize_pet() -> Dictionary:
	var pet := companion_root.get_node_or_null("Pet") as PetController
	if pet == null:
		return {}
	return pet.to_dict()


func _serialize_mount() -> Dictionary:
	var mount := companion_root.get_node_or_null("Mount") as MountController
	if mount == null:
		return {}
	return mount.to_dict()


func _restore_pet(data: Dictionary) -> void:
	var pet := companion_root.get_node_or_null("Pet") as PetController
	if pet != null and not data.is_empty():
		pet.from_dict(data)
		pet.setup(player)


func _restore_mount(data: Dictionary) -> void:
	var mount := companion_root.get_node_or_null("Mount") as MountController
	if mount != null and not data.is_empty():
		mount.from_dict(data)


func _on_region_changed(previous: StringName, current: StringName) -> void:
	current_region_id = current
	region_changed.emit(current)
	EventBus.region_changed.emit(current)
	var pet := companion_root.get_node_or_null("Pet") as PetController
	if pet != null:
		pet.teleport_to_owner()
	var ev := GameplayEvent.make(
		GameplayEventTypes.REGION_ENTERED,
		&"base:player/main",
		&"",
		&"",
		current,
	)
	event_bus.emit_event(ev)


func _on_quest_state_changed(quest_id: StringName, state: int) -> void:
	if state == QuestDefinition.QuestState.COMPLETED:
		var def := ResourceRegistry.get_quest(quest_id)
		if def != null:
			var ctx := WorldEffectContext.new(_session_context)
			WorldEffect.apply_sequence(def.reward_effects, ctx)
