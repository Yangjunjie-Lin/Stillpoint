class_name CombatLabManager
extends Node3D

@onready var player_spawn: Marker3D = $SpawnPoints/PlayerSpawn
@onready var feedback: CombatFeedbackController = $CombatFeedback
@onready var debug_overlay: CombatDebugOverlay = $CombatDebugOverlay

var player: PlayerController3D


func _ready() -> void:
	PhysicsSettingsService.verify_physics_backend()
	_spawn_player()
	_wire_targets()
	var camera := get_node_or_null("CameraRig/Camera3D") as Camera3D
	if feedback != null and camera != null:
		feedback.bind_camera(camera)
	if debug_overlay != null:
		debug_overlay.bind_player(player)


func _spawn_player() -> void:
	var packed: PackedScene = load("res://scenes/characters/player_3d.tscn") as PackedScene
	player = packed.instantiate() as PlayerController3D
	add_child(player)
	if player_spawn != null:
		player.global_position = player_spawn.global_position
	player.reset_physics_interpolation()


func _wire_targets() -> void:
	if player == null or player.combat == null:
		return
	player.combat.hit_confirmed.connect(_on_player_hit)
	for node in get_tree().get_nodes_in_group("combat_lab_target"):
		if node is CharacterController and (node as CharacterController).combat != null:
			(node as CharacterController).combat.hit_confirmed.connect(_on_any_hit)


func _on_player_hit(result: CombatHitResult) -> void:
	if feedback != null:
		feedback.on_hit_confirmed(result)


func _on_any_hit(result: CombatHitResult) -> void:
	if feedback != null:
		feedback.on_hit_confirmed(result)


func exit_to_menu() -> void:
	SceneRouter.go_to_main_menu()
