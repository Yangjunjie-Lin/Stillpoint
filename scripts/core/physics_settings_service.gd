extends Node
## Verifies Jolt Physics backend and exposes physics diagnostics.

const REQUIRED_BACKEND := "Jolt Physics"


func _ready() -> void:
	verify_physics_backend()


func verify_physics_backend() -> void:
	var backend := str(
		ProjectSettings.get_setting("physics/3d/physics_engine", "DEFAULT")
	)
	if backend != REQUIRED_BACKEND:
		push_error("Stillpoint requires Jolt Physics, got %s" % backend)


func get_physics_backend() -> String:
	return str(ProjectSettings.get_setting("physics/3d/physics_engine", "DEFAULT"))


func get_physics_ticks_per_second() -> int:
	return int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60))


func is_physics_interpolation_enabled() -> bool:
	return bool(ProjectSettings.get_setting("physics/common/physics_interpolation", false))
