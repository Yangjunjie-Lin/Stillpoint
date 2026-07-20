class_name WorldManager
extends Node3D
## Owns region switching, player spawn, and world save integration for the vertical slice.

signal region_changed(region_id: StringName)

@export var player_scene: PackedScene
@export var initial_region_id: StringName = &"town"

@onready var regions_root: Node3D = $Regions
@onready var actors_root: Node3D = $Actors
@onready var interactables_root: Node3D = $Interactables

var player: PlayerController3D
var current_region_id: StringName = &"town"
var _dialogue_runner := DialogueRunner.new()
var _interactables: Array = []


func _ready() -> void:
	_collect_interactables()
	_spawn_player()
	_activate_region(initial_region_id)
	if GameManager.resume_requested:
		call_deferred("load_world_state")
	_dialogue_runner.line_presented.connect(_on_dialogue_line)
	_dialogue_runner.choices_presented.connect(_on_dialogue_choices)
	_dialogue_runner.dialogue_finished.connect(_on_dialogue_finished)
	if EventBus.has_signal("request_world_save"):
		EventBus.request_world_save.connect(save_world_state)


func _physics_process(_delta: float) -> void:
	if player != null:
		player.update_interaction_targets(_interactables)


func _spawn_player() -> void:
	if player_scene == null:
		return
	player = player_scene.instantiate() as PlayerController3D
	actors_root.add_child(player)
	var spawn := _find_spawn(initial_region_id)
	player.global_position = spawn
	player.current_region_id = initial_region_id
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
	region_changed.emit(region_id)


func save_world_state() -> bool:
	if player == null:
		return false
	var payload := {
		"profile": {"player_name": GameManager.player_name},
		"player": player.to_dict(),
		"world": WorldTimeService.to_dict(),
		"relationships": RelationshipService.to_dict(),
		"quests": QuestManager.to_dict(),
		"inventory": player.inventory.to_dict() if player.inventory else {},
		"pets": _serialize_pets(),
		"mounts": _serialize_mounts(),
		"regions": {"current": String(current_region_id), "discovered": [String(current_region_id)]},
	}
	return WorldSaveService.save_world(payload)


func load_world_state() -> bool:
	var data := WorldSaveService.load_world()
	if data.is_empty():
		return false
	GameManager.player_name = str(data.get("profile", {}).get("player_name", GameManager.player_name))
	WorldTimeService.from_dict(data.get("world", {}))
	RelationshipService.from_dict(data.get("relationships", {}))
	QuestManager.from_dict(data.get("quests", {}))
	if player != null:
		player.from_dict(data.get("player", {}))
	var regions: Dictionary = data.get("regions", {})
	transition_to(StringName(str(regions.get("current", "town"))))
	return true


func start_dialogue(npc: NPCController) -> void:
	if player == null or npc == null:
		return
	if not npc.can_talk_to(player):
		return
	player.set_input_enabled(false)
	var dialogue := npc.definition.default_dialogue if npc.definition else null
	if dialogue == null:
		dialogue = ResourceRegistry.get_dialogue(npc.character_id)
	_dialogue_runner.start(dialogue, npc, player)


func apply_dialogue_choice(index: int) -> void:
	_dialogue_runner.choose(index)


func _activate_region(region_id: StringName) -> void:
	current_region_id = region_id
	for child in regions_root.get_children():
		if child is Node3D:
			child.visible = child.name == String(region_id)
	# Show region-specific interactables
	var herb := interactables_root.get_node_or_null("HerbPickup")
	if herb != null:
		herb.visible = region_id == &"wilderness"
	var town_portal := interactables_root.get_node_or_null("TownPortal")
	if town_portal != null:
		town_portal.visible = region_id != &"town"
	var bandit := actors_root.get_node_or_null("Bandit")
	if bandit != null:
		bandit.visible = region_id == &"dungeon"


func _find_spawn(region_id: StringName, spawn_id: StringName = &"spawn") -> Vector3:
	var region := regions_root.get_node_or_null(String(region_id))
	if region == null:
		return Vector3.ZERO
	var marker := region.get_node_or_null(String(spawn_id))
	if marker is Node3D:
		return (marker as Node3D).global_position
	return region.global_position if region is Node3D else Vector3.ZERO


func _collect_interactables() -> void:
	_interactables.clear()
	for child in interactables_root.get_children():
		_collect_recursive(child)


func _collect_recursive(node: Node) -> void:
	if node is Interactable:
		_interactables.append(node)
	for child in node.get_children():
		_collect_recursive(child)


func _serialize_pets() -> Dictionary:
	return {"bonds": {}}


func _serialize_mounts() -> Dictionary:
	return {"unlocked": ["placeholder_horse"], "bonds": {}}


func _on_dialogue_line(speaker: String, text: String) -> void:
	EventBus.dialogue_line.emit(speaker, text)


func _on_dialogue_choices(choices: Array) -> void:
	EventBus.dialogue_choices.emit(choices)


func _on_dialogue_finished() -> void:
	if player != null:
		player.set_input_enabled(true)
	EventBus.dialogue_finished.emit()
