extends RefCounted


func run() -> bool:
	var normalized := CharacterAppearanceOptions.normalize({
		"body_id": "sturdy",
		"skin_id": "deep",
		"hair_id": "topknot",
		"headwear_id": "none",
		"palette_id": "ember",
		"accessory_id": "travel_pack",
	})
	var invalid := CharacterAppearanceOptions.normalize({
		"body_id": "giant",
		"skin_id": "unknown",
		"hair_id": "invalid",
		"headwear_id": "invalid",
		"palette_id": "invalid",
		"accessory_id": "invalid",
	})
	var ok := invalid == CharacterAppearanceOptions.default_options()

	var packed := load("res://scenes/characters/player/origins/ronin.tscn") as PackedScene
	var model := packed.instantiate() as StylizedHeroModel
	model.apply_customization(normalized)
	model._ready()
	var root := model.get_node_or_null("Model") as Node3D
	ok = ok and model.get_customization() == normalized
	var body_root := root.get_node_or_null("BodyParts") as Node3D
	var equipment_root := root.get_node_or_null("EquipmentParts") as Node3D
	ok = ok and body_root != null and body_root.scale.x > 1.0
	ok = ok and equipment_root != null and equipment_root.scale == Vector3.ONE
	ok = ok and root.find_child("CustomHair", true, false) != null
	ok = ok and root.find_child("CustomTopknot", true, false) != null
	ok = ok and root.find_child("CustomTravelPack", true, false) != null
	ok = ok and root.find_child("KatanaScabbard", true, false).get_parent() == equipment_root
	var origin_hat := root.find_child("Kasa", true, false) as Node3D
	ok = ok and origin_hat != null and not origin_hat.visible
	model.free()

	if not ok:
		push_error("Modular appearance options did not normalize or build expected parts")
	return ok
