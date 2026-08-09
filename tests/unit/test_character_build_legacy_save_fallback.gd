extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var packed := load("res://scenes/characters/player_3d.tscn") as PackedScene
	var player := packed.instantiate() as PlayerController3D
	tree.root.add_child(player)
	await tree.process_frame
	player.apply_character_build({
		"origin_id": "ronin",
		"faction_id": "dawn_covenant",
		"profession_id": "guardian",
	}, true)
	var legacy_data := player.to_dict()
	legacy_data.erase("character_build")
	player.from_dict(legacy_data)
	var ok := (
		player.origin_id == GameManager.DEFAULT_ORIGIN_ID
		and player.selected_faction_id == GameManager.DEFAULT_FACTION_ID
		and player.profession_id == GameManager.DEFAULT_PROFESSION_ID
		and player.health.max_health == 120.0
		and player.energy.max_energy == 120.0
	)
	player.free()
	if not ok:
		push_error("Save v4 player data without character_build did not use safe defaults")
	return ok
