extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var scene := load("res://scenes/ui/character_creation.tscn") as PackedScene
	var creation := scene.instantiate() as CharacterCreationUI
	tree.root.add_child(creation)
	await tree.process_frame

	var origin_list := creation.get_node("%OriginList") as ItemList
	var faction_list := creation.get_node("%FactionList") as ItemList
	var profession_list := creation.get_node("%ProfessionList") as ItemList
	var confirm_button := creation.get_node("%ConfirmButton") as Button
	var ok := origin_list.item_count == 6
	ok = ok and faction_list.item_count == 4
	ok = ok and profession_list.item_count == 6

	# A South Asian-inspired appearance remains freely combinable with a frontier
	# faction and a duelist profession; recommendations are guidance only.
	origin_list.select(1)
	origin_list.item_selected.emit(1)
	faction_list.select(3)
	faction_list.item_selected.emit(3)
	profession_list.select(2)
	profession_list.item_selected.emit(2)
	await tree.process_frame
	ok = ok and creation.get("_origin_id") == &"lotus_ascetic"
	ok = ok and creation.get("_faction_id") == &"ash_watch"
	ok = ok and creation.get("_profession_id") == &"duelist"
	ok = ok and not confirm_button.disabled
	ok = ok and GameManager.is_valid_character_build(
		&"lotus_ascetic",
		&"ash_watch",
		&"duelist",
	)
	var preview_root := creation.get_node("%PreviewModelRoot") as Node3D
	ok = ok and preview_root.get_child_count() == 1
	var model := preview_root.get_child(0) as StylizedHeroModel
	ok = ok and model != null and model.style == StylizedHeroModel.HeroStyle.LOTUS_ASCETIC

	creation.free()
	if not ok:
		push_error("Character Creation did not preserve independent selectable choices")
	return ok
