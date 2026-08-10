extends RefCounted


const MODEL_PATHS: Array[String] = [
	"res://scenes/characters/player/origins/wuxia_swordsman.tscn",
	"res://scenes/characters/player/origins/lotus_ascetic.tscn",
	"res://scenes/characters/player/origins/ronin.tscn",
	"res://scenes/characters/player/origins/oathbound_knight.tscn",
	"res://scenes/characters/player/origins/dune_ranger.tscn",
	"res://scenes/characters/player/origins/steppe_rider.tscn",
]


func run() -> bool:
	var ok := true
	for path in MODEL_PATHS:
		var packed := load(path) as PackedScene
		if packed == null:
			ok = false
			continue
		var model := packed.instantiate() as StylizedHeroModel
		if model == null:
			ok = false
			continue
		model._ready()
		ok = ok and model.get_node_or_null("Model") != null
		ok = ok and _mesh_count(model.get_node("Model")) >= 15
		model.free()
	if not ok:
		push_error("one or more stylized origin models failed to build")
	return ok


func _mesh_count(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += _mesh_count(child)
	return count
