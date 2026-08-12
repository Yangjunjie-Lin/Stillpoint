class_name EncounterExplorationZone
extends Area3D
## Authored spatial trigger whose encounter requirements remain hidden until completion.

@export var encounter_id: StringName = &""
@export var region_id: StringName = &""
@export var once_per_entry: bool = true

var _actors_inside: Dictionary = {}


func _ready() -> void:
	monitoring = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	var player := body as PlayerController3D
	if player == null or encounter_id == &"":
		return
	var key := player.get_instance_id()
	if once_per_entry and _actors_inside.has(key):
		return
	_actors_inside[key] = true
	var session := _find_session()
	if session == null or session.hidden_encounter_service == null:
		return
	var event := GameplayEvent.make(
		GameplayEventTypes.LOCATION_EXPLORED,
		&"base:player/main",
		StringName("encounter_zone:%s" % String(encounter_id)),
		encounter_id,
		region_id,
		1.0,
		{
			"player_initiated": true,
			"action_committed": true,
			"encounter_trigger_origin": String(GameplayEventTypes.ORIGIN_PLAYER_WORLD_ACTION),
			"position": {"x": global_position.x, "y": global_position.y, "z": global_position.z},
		},
	)
	session.hidden_encounter_service.attempt(encounter_id, event)


func _on_body_exited(body: Node) -> void:
	_actors_inside.erase(body.get_instance_id())


func _find_session() -> WorldSession:
	var node: Node = self
	while node != null:
		if node is WorldSession:
			return node as WorldSession
		node = node.get_parent()
	return get_tree().get_first_node_in_group("world_manager") as WorldSession
