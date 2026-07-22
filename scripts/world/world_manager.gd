class_name WorldManager
extends Node3D
## Owns region switching, dialogue, quests, and world save for the vertical slice.

signal region_changed(region_id: StringName)

@export var player_scene: PackedScene
@export var initial_region_id: StringName = &"town"
@export var autosave_interval: float = 60.0

@onready var regions_root: Node3D = $Regions
@onready var actors_root: Node3D = $Actors
@onready var interactables_root: Node3D = $Interactables

var player: PlayerController3D
var current_region_id: StringName = &"town"
var discovered_regions: Array = ["town"]
var _dialogue_runner := DialogueRunner.new()
var _interactables: Array = []
var _autosave_timer: float = 0.0
var _region_actors: Dictionary = {}


func _ready() -> void:
	add_to_group("world_manager")
	_index_region_membership()
	_collect_interactables()
	_spawn_player()
	_activate_region(initial_region_id)
	_dialogue_runner.line_presented.connect(_on_dialogue_line)
	_dialogue_runner.choices_presented.connect(_on_dialogue_choices)
	_dialogue_runner.dialogue_finished.connect(_on_dialogue_finished)
	if EventBus.has_signal("request_world_save"):
		EventBus.request_world_save.connect(save_world_state)
	if GameManager.resume_requested:
		load_world_state()
		GameManager.resume_requested = false


func _process(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer >= autosave_interval:
		_autosave_timer = 0.0
		save_world_state()


func _physics_process(_delta: float) -> void:
	if player != null:
		player.update_interaction_targets(_active_interactables())


func _spawn_player() -> void:
	if player_scene == null:
		return
	player = player_scene.instantiate() as PlayerController3D
	actors_root.add_child(player)
	player.add_to_group("player")
	var spawn := _find_spawn(initial_region_id)
	player.global_position = spawn
	player.current_region_id = initial_region_id
	player.region_id = initial_region_id
	var pet := actors_root.get_node_or_null("Pet") as PetController
	if pet != null:
		pet.setup(player)
	var camera_rig := get_node_or_null("CameraRig") as CameraController3D
	if camera_rig != null:
		camera_rig.set_target(player)


func transition_to(region_id: StringName, spawn_id: StringName = &"spawn") -> void:
	_activate_region(region_id)
	if player != null:
		player.global_position = _find_spawn(region_id, spawn_id)
		player.current_region_id = region_id
		player.region_id = region_id
		var pet := actors_root.get_node_or_null("Pet") as PetController
		if pet != null:
			pet.teleport_to_owner()
	if not discovered_regions.has(String(region_id)):
		discovered_regions.append(String(region_id))
	region_changed.emit(region_id)
	EventBus.region_changed.emit(region_id)
	save_world_state()


func save_world_state() -> bool:
	if player == null:
		return false
	var inventory_data := player.inventory.to_dict() if player.inventory else {}
	var player_data := player.to_dict()
	player_data.erase("inventory")
	var payload := {
		"profile": {"player_name": GameManager.player_name},
		"player": player_data,
		"world": WorldTimeService.to_dict(),
		"relationships": RelationshipService.to_dict(),
		"quests": QuestManager.to_dict(),
		"inventory": inventory_data,
		"pets": _serialize_pets(),
		"mounts": _serialize_mounts(),
		"npcs": _serialize_npcs(),
		"interactables": _serialize_interactables(),
		"regions": {
			"current": String(current_region_id),
			"discovered": discovered_regions.duplicate(),
		},
	}
	return WorldSaveService.save_world(payload)


func load_world_state() -> bool:
	var data := WorldSaveService.load_world()
	if data.is_empty() or not WorldSaveService.validate_schema(data):
		return false
	GameManager.player_name = str(data.get("profile", {}).get("player_name", GameManager.player_name))
	WorldTimeService.from_dict(data.get("world", {}))
	RelationshipService.from_dict(data.get("relationships", {}))
	QuestManager.from_dict(data.get("quests", {}))
	var regions: Dictionary = data.get("regions", {})
	discovered_regions = regions.get("discovered", ["town"])
	if typeof(discovered_regions) != TYPE_ARRAY:
		discovered_regions = ["town"]
	var region_id := StringName(str(regions.get("current", "town")))
	_activate_region(region_id)
	if player != null:
		player.from_dict(data.get("player", {}))
		if player.inventory != null:
			player.inventory.from_dict(data.get("inventory", {}))
		player.current_region_id = region_id
	_restore_npcs(data.get("npcs", {}))
	_restore_pets(data.get("pets", {}))
	_restore_mounts(data.get("mounts", {}))
	_restore_interactables(data.get("interactables", {}))
	return true


func start_dialogue(npc: NPCController) -> void:
	if player == null or npc == null:
		return
	if not npc.can_talk_to(player):
		EventBus.notice_requested.emit("They refuse to speak with you.")
		return
	player.set_input_enabled(false)
	npc.set_npc_state(NPCController.NPCState.TALK)
	var dialogue := npc.definition.default_dialogue if npc.definition else null
	if dialogue == null:
		dialogue = ResourceRegistry.get_dialogue(npc.character_id)
	_dialogue_runner.start(dialogue, npc, player)


func start_mira_dialogue(npc: NPCController) -> void:
	if player == null or npc == null:
		return
	if not npc.can_talk_to(player):
		EventBus.notice_requested.emit("Mira refuses to speak with you.")
		return
	var runtime := QuestManager.get_runtime(&"demo_errand")
	var dialogue: DialogueDefinition = null
	if runtime == null or runtime.state == QuestDefinition.QuestState.UNDISCOVERED:
		dialogue = ResourceRegistry.get_dialogue(&"mira_intro")
	elif runtime.state == QuestDefinition.QuestState.COMPLETED:
		dialogue = ResourceRegistry.get_dialogue(&"mira_done")
	elif runtime.state == QuestDefinition.QuestState.ACTIVE:
		var current := QuestManager.get_current_objective(&"demo_errand")
		if current != null and current.id == &"collect_herb":
			dialogue = ResourceRegistry.get_dialogue(&"mira_waiting")
		elif current != null and current.id == &"deliver_herb":
			dialogue = ResourceRegistry.get_dialogue(&"mira_deliver")
		else:
			dialogue = ResourceRegistry.get_dialogue(&"mira_waiting")
	else:
		dialogue = ResourceRegistry.get_dialogue(&"mira_intro")
	player.set_input_enabled(false)
	npc.set_npc_state(NPCController.NPCState.TALK)
	_dialogue_runner.start(dialogue, npc, player)


func apply_dialogue_choice(index: int) -> void:
	_dialogue_runner.choose(index)


func try_deliver_herb() -> bool:
	if player == null or player.inventory == null:
		return false
	if player.inventory.count_item(&"herb") < 1:
		return false
	player.inventory.remove_item(&"herb", 1)
	QuestManager.advance_objective(&"demo_errand", &"deliver_herb")
	var runtime := QuestManager.get_runtime(&"demo_errand")
	if runtime != null and runtime.state == QuestDefinition.QuestState.COMPLETED:
		player.inventory.add_item(&"gift_box", 1)
	return true


func _activate_region(region_id: StringName) -> void:
	current_region_id = region_id
	for child in regions_root.get_children():
		if child is Node3D:
			_set_region_active(child as Node3D, child.name == String(region_id))
	for child in actors_root.get_children():
		if child == player:
			continue
		var rid := _node_region_id(child)
		_set_actor_active(child, rid == region_id or rid == &"")
	for child in interactables_root.get_children():
		var rid2 := _node_region_id(child)
		var should_show := rid2 == region_id
		# Town portal only outside town (membership stays wilderness/dungeon portals).
		if child.name == "TownPortal":
			should_show = region_id != &"town"
		_set_actor_active(child, should_show)
		if child is Interactable:
			(child as Interactable).interaction_enabled = should_show


func _set_region_active(region: Node3D, active: bool) -> void:
	region.visible = active
	region.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	_set_collision_recursive(region, active)


func _set_actor_active(node: Node, active: bool) -> void:
	if node is Node3D:
		(node as Node3D).visible = active
	node.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	_set_collision_recursive(node, active)


func _set_collision_recursive(node: Node, active: bool) -> void:
	if node is CollisionObject3D:
		var body := node as CollisionObject3D
		if active:
			if body.collision_layer == 0 and body.collision_mask == 0:
				body.collision_layer = 1
				body.collision_mask = 1
		else:
			body.set_meta("_saved_layer", body.collision_layer)
			body.set_meta("_saved_mask", body.collision_mask)
			body.collision_layer = 0
			body.collision_mask = 0
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = not active
	if node is Area3D:
		var area := node as Area3D
		area.monitoring = active and area is Hitbox3D == false
		area.monitorable = active
		if node is Hitbox3D:
			area.monitoring = false
			area.monitorable = false
	for child in node.get_children():
		_set_collision_recursive(child, active)


func _node_region_id(node: Node) -> StringName:
	if node.get("region_id") != null:
		return StringName(str(node.get("region_id")))
	return &""


func _index_region_membership() -> void:
	for child in actors_root.get_children():
		if child is NPCController:
			var npc := child as NPCController
			if npc.npc_definition != null:
				npc.region_id = npc.npc_definition.home_region_id
			elif child.name == "Bandit":
				npc.region_id = &"dungeon"
			elif child.name in ["Mira", "Ren"]:
				npc.region_id = &"town"
		elif child is PetController:
			(child as PetController).region_id = &"town"
		elif child is MountController:
			(child as MountController).region_id = &"town"
	for child in interactables_root.get_children():
		if child is Interactable:
			var interactable := child as Interactable
			match child.name:
				"HerbPickup":
					interactable.region_id = &"wilderness"
				"ForestPortal", "DungeonPortal", "Chest", "PetInteract", "MountInteract", "MiraTalk", "RenTalk":
					if interactable.region_id == &"":
						interactable.region_id = &"town"
				"TownPortal":
					interactable.region_id = &"wilderness"


func _find_spawn(region_id: StringName, spawn_id: StringName = &"spawn") -> Vector3:
	var region := regions_root.get_node_or_null(String(region_id))
	if region == null:
		return Vector3(0, 1, 0)
	var marker := region.get_node_or_null(String(spawn_id))
	if marker is Node3D:
		return (marker as Node3D).global_position
	return Vector3(0, 1, 0)


func _collect_interactables() -> void:
	_interactables.clear()
	for child in interactables_root.get_children():
		_collect_recursive(child)


func _collect_recursive(node: Node) -> void:
	if node is Interactable:
		_interactables.append(node)
	for child in node.get_children():
		_collect_recursive(child)


func _active_interactables() -> Array:
	var result: Array = []
	for item in _interactables:
		if item is Interactable and (item as Interactable).is_interaction_enabled():
			result.append(item)
	return result


func _serialize_pets() -> Dictionary:
	var pet := actors_root.get_node_or_null("Pet") as PetController
	if pet == null:
		return {}
	return pet.to_dict()


func _serialize_mounts() -> Dictionary:
	var mount := actors_root.get_node_or_null("Mount") as MountController
	if mount == null:
		return {}
	return mount.to_dict()


func _serialize_npcs() -> Dictionary:
	var out := {}
	for child in actors_root.get_children():
		if child is NPCController:
			var npc := child as NPCController
			out[String(npc.character_id)] = npc.to_dict()
	return out


func _serialize_interactables() -> Dictionary:
	var out := {}
	for child in interactables_root.get_children():
		if child.has_method("to_dict"):
			out[child.name] = child.call("to_dict")
	return out


func _restore_npcs(data: Dictionary) -> void:
	for child in actors_root.get_children():
		if child is NPCController:
			var npc := child as NPCController
			var key := String(npc.character_id)
			if data.has(key) and typeof(data[key]) == TYPE_DICTIONARY:
				npc.from_dict(data[key])


func _restore_pets(data: Dictionary) -> void:
	var pet := actors_root.get_node_or_null("Pet") as PetController
	if pet != null and not data.is_empty():
		pet.from_dict(data)
		pet.setup(player)


func _restore_mounts(data: Dictionary) -> void:
	var mount := actors_root.get_node_or_null("Mount") as MountController
	if mount != null and not data.is_empty():
		mount.from_dict(data)


func _restore_interactables(data: Dictionary) -> void:
	for child in interactables_root.get_children():
		if data.has(child.name) and child.has_method("from_dict"):
			child.call("from_dict", data[child.name])


func _on_dialogue_line(speaker: String, text: String) -> void:
	EventBus.dialogue_line.emit(speaker, text)


func _on_dialogue_choices(choices: Array) -> void:
	EventBus.dialogue_choices.emit(choices)


func _on_dialogue_finished() -> void:
	if player != null:
		player.set_input_enabled(true)
	for child in actors_root.get_children():
		if child is NPCController:
			var npc := child as NPCController
			if npc.npc_state == NPCController.NPCState.TALK:
				npc.set_npc_state(NPCController.NPCState.FOLLOW_SCHEDULE)
	EventBus.dialogue_finished.emit()
