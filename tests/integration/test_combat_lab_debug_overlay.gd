extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var packed := load("res://scenes/combat/combat_lab.tscn") as PackedScene
	var lab := packed.instantiate() as CombatLabManager
	tree.root.add_child(lab)
	await WorldTestHelper.await_frames(tree, 3)

	var overlay := lab.get_node_or_null("CombatDebugOverlay") as CombatDebugOverlay
	if overlay == null:
		push_error("Combat Lab diagnostics overlay is missing")
		lab.free()
		return false
	overlay.visible = true
	overlay.set_process(true)
	await WorldTestHelper.await_frames(tree, 2)

	var label := overlay.get_child(0) as Label
	var ok := label != null \
		and label.text.contains("Anim Attack: false") \
		and not label.text.contains("%s") \
		and not label.text.contains("%d")
	lab.free()
	if not ok:
		push_error("Combat Lab diagnostics did not render its runtime values")
	return ok
