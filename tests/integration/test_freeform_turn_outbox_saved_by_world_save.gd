extends RefCounted

func run() -> bool:
	SaveService.settings["ai_dialogue_enabled"] = true
	SaveService.settings["allow_conversation_storage"] = true
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var fake := FakeNPCDialogueGateway.new()
	fake.auto_reply = false
	world.cognition_service.add_child(fake)
	world.cognition_service.conversation_controller.setup(
		fake, world.cognition_service.save_provider.cache
	)
	var mira := WorldTestHelper.find_npc(world, "Mira")
	world.start_dialogue(mira)
	var accepted := world.ask_active_npc("Please remember my favorite color is blue.")
	var saved := world.save_world_state()
	var data := _read_json("user://saves/slot_01/npc_cognition.json")
	var pending: Array = data.get("pending_turn_outbox", [])
	var ok: bool = accepted and saved and pending.size() == 1 \
		and world.save_coordinator.get("_npc_cognition_provider") \
		== world.cognition_service.save_provider
	world.free()
	return ok

func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else {}
	return parsed if parsed is Dictionary else {}
