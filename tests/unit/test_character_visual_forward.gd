extends RefCounted


func run() -> bool:
	var packed := load("res://scenes/characters/player_3d.tscn") as PackedScene
	if packed == null:
		return false
	var player := packed.instantiate() as PlayerController3D
	var visual := player.get_node_or_null("VisualRoot") as Node3D
	var ok := visual != null and visual.transform.basis.z.dot(Vector3.BACK) < -0.99
	player.free()
	if not ok:
		push_error("Player visual forward correction is missing")
	return ok
