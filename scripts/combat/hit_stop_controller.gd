class_name HitStopController
extends Node
## Local hit stop — freezes bound actors without touching Engine.time_scale.

var _targets: Array[Node] = []
var _remaining: float = 0.0
var _saved_process_modes: Dictionary = {}
var _saved_speed_scales: Dictionary = {}


func is_active() -> bool:
	return _remaining > 0.0


func trigger(duration: float, targets: Array) -> void:
	if duration <= 0.0 or targets.is_empty():
		return
	_release()
	_remaining = duration
	for node in targets:
		if node == null or not is_instance_valid(node):
			continue
		if node in _targets:
			continue
		_targets.append(node)
		_saved_process_modes[node.get_instance_id()] = node.process_mode
		node.process_mode = Node.PROCESS_MODE_DISABLED
		if node is AnimationPlayer:
			var player := node as AnimationPlayer
			_saved_speed_scales[node.get_instance_id()] = player.speed_scale
			player.speed_scale = 0.0
		elif node is CharacterBody3D:
			var body := node as CharacterBody3D
			body.set_meta("_hitstop_vel", body.velocity)
			body.velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if _remaining <= 0.0:
		return
	_remaining -= delta
	if _remaining <= 0.0:
		_release()


func _release() -> void:
	for node in _targets:
		if node == null or not is_instance_valid(node):
			continue
		var id := node.get_instance_id()
		if _saved_process_modes.has(id):
			node.process_mode = _saved_process_modes[id]
		if node is AnimationPlayer and _saved_speed_scales.has(id):
			(node as AnimationPlayer).speed_scale = _saved_speed_scales[id]
		elif node is CharacterBody3D and node.has_meta("_hitstop_vel"):
			(node as CharacterBody3D).velocity = node.get_meta("_hitstop_vel")
			node.remove_meta("_hitstop_vel")
	_targets.clear()
	_saved_process_modes.clear()
	_saved_speed_scales.clear()
	_remaining = 0.0
