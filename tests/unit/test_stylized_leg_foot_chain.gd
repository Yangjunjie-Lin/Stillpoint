extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var hero_scene := load(
		"res://scenes/characters/player/origins/wuxia_swordsman.tscn"
	) as PackedScene
	var hero := hero_scene.instantiate() as StylizedHeroModel if hero_scene != null else null
	if hero == null:
		return false
	tree.root.add_child(hero)
	await tree.process_frame
	var ok := _foot_follows_leg(hero)
	hero.free()

	var npc := StylizedNPCModel.new()
	npc.definition_hint = &"bandit"
	npc.persistent_id_hint = &"base:dungeon/npc/bandit_foot_test"
	tree.root.add_child(npc)
	await tree.process_frame
	ok = ok and _foot_follows_leg(npc)
	npc.free()
	if not ok:
		push_error("stylized foot did not inherit its leg motion around the hip joint")
	return ok


func _foot_follows_leg(model: Node) -> bool:
	var leg := model.find_child("LeftLeg", true, false) as Node3D
	var foot := model.find_child("LeftBoot", true, false) as Node3D
	if leg == null or foot == null:
		return false
	var start_foot := foot.position
	var chain_length := foot.position.distance_to(leg.position)
	model.call("set_motion_state", &"walk")
	model.call("_process", 0.2)
	return (
		foot.position.distance_to(start_foot) > 0.06
		and absf(foot.position.distance_to(leg.position) - chain_length) < 0.02
		and absf(foot.rotation.x) > 0.05
	)
