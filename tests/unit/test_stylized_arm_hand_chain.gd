extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var packed := load(
		"res://scenes/characters/player/origins/wuxia_swordsman.tscn"
	) as PackedScene
	var model := packed.instantiate() as StylizedHeroModel if packed != null else null
	if model == null:
		return false
	tree.root.add_child(model)
	await tree.process_frame
	var sword := ResourceRegistry.get_item(&"training_sword")
	model.apply_loadout(sword, null, null, null)
	var arm := model.find_child("RightArm", true, false) as Node3D
	var hand := model.find_child("RightHand", true, false) as Node3D
	var held := model.find_child("DisplayedHandheld", true, false) as Node3D
	var ok := arm != null and hand != null and held != null
	var start_hand := hand.position if hand != null else Vector3.ZERO
	var chain_length := hand.position.distance_to(arm.position) if ok else 0.0
	model.set_motion_state(&"attack")
	model._process(0.25)
	if ok:
		ok = ok and hand.position.distance_to(start_hand) > 0.08
		ok = ok and absf(hand.position.distance_to(arm.position) - chain_length) < 0.02
		ok = ok and held.get_parent() == hand
		ok = ok and held.global_position.distance_to(hand.global_position) < 0.1
		var static_blade := model.find_child("JianBlade", true, false) as Node3D
		ok = ok and static_blade != null and static_blade.get_parent() == hand
	var shield := ResourceRegistry.get_item(&"shield")
	model.apply_loadout(null, null, null, shield)
	var left_hand := model.find_child("LeftHand", true, false) as Node3D
	var held_shield := model.find_child("DisplayedHandheld", true, false) as Node3D
	ok = ok and left_hand != null and held_shield != null
	if held_shield != null:
		ok = ok and held_shield.get_parent() == left_hand
		ok = ok and str(held_shield.get_meta("grip_kind", "")) == "shield_grip"
	model.free()
	if not ok:
		push_error("hand or held item did not inherit the procedural arm chain")
	return ok
