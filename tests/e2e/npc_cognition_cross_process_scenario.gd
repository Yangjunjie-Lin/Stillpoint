extends RefCounted
## Cross-process production-path acceptance. Never substitutes a fake gateway or repository.

const WORLD_SCENE := "res://scenes/world/world_session.tscn"
const PLAYER_ID := "e2e-player"
const SAVE_ID := "slot-01"
const CLIENT_ID := "e2e-install-0001"
const MIRA_ID := &"base:town/npc/mira"
const BANDIT_1_ID := &"base:dungeon/npc/bandit_0001"
const BANDIT_2_ID := &"base:dungeon/npc/bandit_0002"

var _failures: Array[String] = []
var _tree: SceneTree


func run(tree: SceneTree) -> bool:
	_tree = tree
	var phase := OS.get_environment("NPC_E2E_PHASE")
	_configure_private_settings()
	match phase:
		"seed":
			await _run_seed()
		"recall":
			await _run_recall()
		"offline":
			await _run_offline()
		"flush":
			await _run_flush()
		_:
			_fail("unknown phase: %s" % phase)
	await _settle(3)
	if _failures.is_empty():
		print("NPC_COGNITION_E2E PASS phase=%s" % phase)
		return true
	for failure in _failures:
		push_error("NPC_COGNITION_E2E %s" % failure)
	print("NPC_COGNITION_E2E FAIL phase=%s count=%d" % [phase, _failures.size()])
	return false


func _run_seed() -> void:
	if OS.get_environment("NPC_E2E_ISOLATED_USER_HOME") != "1":
		_fail("seed requires an isolated Godot user home")
		return
	_clear_local_save()
	var world := await _boot_world(false)
	if world == null:
		return
	var mira := world.entity_repository.get_loaded_entity(MIRA_ID) as NPCController
	_expect_identity(mira, MIRA_ID, "Mira")
	var color_reply := await _ask(
		world,
		mira,
		"My favorite color is blue; please remember it.",
	)
	_expect(bool(color_reply.get("ok", false)), "Mira free-form HTTP reply failed")
	_expect(
		world.cognition_service.save_provider.cache.memories_for(PLAYER_ID, SAVE_ID, String(MIRA_ID)).size() == 1,
		"Mira memory write did not reach the Godot cache",
	)

	mira.react_to_aggression(world.player, 5.0)
	_expect(
		world.cognition_service.save_provider.cache.pending_event_outbox.size() == 1,
		"player attack did not enter the gameplay-event outbox",
	)
	var event_sync := await _sync(world)
	_expect(bool(event_sync.get("ok", false)), "Mira gameplay-event HTTP sync failed")
	_expect(
		world.cognition_service.save_provider.cache.pending_event_outbox.is_empty(),
		"event outbox was not removed after server Ack",
	)

	world.transition_to(&"base:dungeon")
	await _settle(6)
	var bandit_1 := world.entity_repository.get_loaded_entity(BANDIT_1_ID) as NPCController
	var bandit_2 := world.entity_repository.get_loaded_entity(BANDIT_2_ID) as NPCController
	_expect_identity(bandit_1, BANDIT_1_ID, "Bandit 1")
	_expect_identity(bandit_2, BANDIT_2_ID, "Bandit 2")
	var secret_reply := await _ask(
		world,
		bandit_1,
		"Remember this moon secret: the hidden moon is silver.",
	)
	var control_reply := await _ask(
		world,
		bandit_2,
		"Tell me what you know about the night sky.",
	)
	_expect(bool(secret_reply.get("ok", false)), "bandit_0001 secret turn failed")
	_expect(bool(control_reply.get("ok", false)), "bandit_0002 control turn failed")
	_expect(world.save_world_state(), "seed Save v4 failed")
	_expect_save_versions()
	world.free()


func _run_recall() -> void:
	var world := await _boot_world(true)
	if world == null:
		return
	_expect(String(world.current_region_id) == "base:dungeon", "Continue did not restore dungeon")
	var bandit_1 := world.entity_repository.get_loaded_entity(BANDIT_1_ID) as NPCController
	var bandit_2 := world.entity_repository.get_loaded_entity(BANDIT_2_ID) as NPCController
	_expect_identity(bandit_1, BANDIT_1_ID, "restored Bandit 1")
	_expect_identity(bandit_2, BANDIT_2_ID, "restored Bandit 2")
	var known := await _ask(
		world,
		bandit_1,
		"What confidence about the night sky did I entrust to you?",
	)
	var isolated := await _ask(
		world,
		bandit_2,
		"What confidence about the night sky did I entrust to you?",
	)
	var known_text := str(known.get("reply_text", "")).to_lower()
	var isolated_text := str(isolated.get("reply_text", "")).to_lower()
	_expect(bool(known.get("ok", false)) and "silver" in known_text, "bandit_0001 semantic recall missed the moon secret")
	_expect(
		bool(isolated.get("ok", false)) and "silver" not in isolated_text,
		"bandit_0002 received bandit_0001 memory",
	)

	world.transition_to(&"base:town")
	await _settle(6)
	var mira := world.entity_repository.get_loaded_entity(MIRA_ID) as NPCController
	_expect_identity(mira, MIRA_ID, "restored Mira")
	var color := await _ask(world, mira, "Do you recall which hue I tend to prefer?")
	var attack := await _ask(world, mira, "Do you remember the player attacking you?")
	_expect(
		bool(color.get("ok", false)) and "blue" in str(color.get("reply_text", "")).to_lower(),
		"Mira did not semantically recall blue after Backend and Godot restart",
	)
	_expect(
		bool(attack.get("ok", false)) and "npc_attacked" in str(attack.get("reply_text", "")).to_lower(),
		"Mira did not recall the synced gameplay attack event",
	)
	_expect(world.save_world_state(), "recall Save v4 failed")
	world.free()


func _run_offline() -> void:
	if OS.get_environment("NPC_E2E_ISOLATED_USER_HOME") != "1":
		_fail("offline phase requires an isolated Godot user home")
		return
	# This scenario is intentionally independent from the recall save while the
	# PostgreSQL authority remains intact.
	_clear_local_save()
	var world := await _boot_world(false)
	if world == null:
		return
	var mira := world.entity_repository.get_loaded_entity(MIRA_ID) as NPCController
	_expect_identity(mira, MIRA_ID, "offline Mira")
	world.cognition_service.gateway.max_retries = 0
	world.cognition_service.gateway.timeout_seconds = 1.0
	world.cognition_service.gateway._http.timeout = 1.0

	world.start_dialogue(mira)
	world.apply_dialogue_choice(0)
	await _settle(2)
	var quest_manager := _autoload("QuestManager")
	_expect(quest_manager.call("get_runtime", &"demo_errand") != null, "quest dialogue failed offline")

	var offline_reply := await _ask(world, mira, "Remember this offline promise.", 240)
	_expect(
		bool(offline_reply.get("fallback", false)),
		"offline free-form dialogue did not produce an explicit fallback",
	)
	_expect(mira.npc_state != NPCController.NPCState.TALK, "NPC state was not restored offline")
	_expect(
		world.cognition_service.save_provider.cache.pending_turn_outbox.size() == 1,
		"offline turn was removed without an Ack",
	)

	var before_health := mira.health.current_health
	var dealt := mira.receive_damage(3.0, world.player, {"is_normal_attack": true})
	_expect(dealt > 0.0 and mira.health.current_health < before_health, "combat failed offline")
	world.transition_to(&"base:wilderness")
	await _settle(4)
	_expect(String(world.current_region_id) == "base:wilderness", "region transition failed offline")
	_expect(world.save_world_state(), "offline Save v4 failed")
	_expect_save_versions()
	world.free()


func _run_flush() -> void:
	var world := await _boot_world(true)
	if world == null:
		return
	var cache := world.cognition_service.save_provider.cache
	_expect(not cache.pending_turn_outbox.is_empty(), "offline turn outbox did not survive restart")
	_expect(not cache.pending_event_outbox.is_empty(), "offline event outbox did not survive restart")
	var result := await _sync(world)
	_expect(bool(result.get("ok", false)), "recovered Backend did not Ack outbox")
	_expect(cache.pending_turn_outbox.is_empty(), "turn outbox remained after Ack")
	_expect(cache.pending_event_outbox.is_empty(), "event outbox remained after Ack")
	_expect(not world.cognition_service.sync_pending(), "empty outbox attempted duplicate sync")
	_expect(world.save_world_state(), "post-Ack Save v4 failed")
	world.free()


func _ask(
	world: WorldSession,
	npc: NPCController,
	text: String,
	maximum_frames: int = 900,
) -> Dictionary:
	if npc == null:
		return {"ok": false, "error_code": "missing_npc"}
	var state := {"done": false, "reply": {}}
	var callback := func(reply: Dictionary) -> void:
		state.done = true
		state.reply = reply.duplicate(true)
	world.cognition_service.conversation_controller.reply_ready.connect(callback, CONNECT_ONE_SHOT)
	var payload := world.cognition_service.build_turn_payload(npc, text)
	if payload.is_empty() or not world.cognition_service.conversation_controller.ask(npc, payload):
		if world.cognition_service.conversation_controller.reply_ready.is_connected(callback):
			world.cognition_service.conversation_controller.reply_ready.disconnect(callback)
		return {"ok": false, "error_code": "request_not_started"}
	for _index in maximum_frames:
		if bool(state.done):
			return state.reply as Dictionary
		await _tree.process_frame
	if world.cognition_service.conversation_controller.reply_ready.is_connected(callback):
		world.cognition_service.conversation_controller.reply_ready.disconnect(callback)
	world.cognition_service.conversation_controller.cancel()
	return {"ok": false, "error_code": "timeout"}


func _sync(world: WorldSession, maximum_frames: int = 900) -> Dictionary:
	var state := {"done": false, "reply": {}}
	var callback := func(reply: Dictionary) -> void:
		state.done = true
		state.reply = reply.duplicate(true)
	world.cognition_service.gateway.sync_completed.connect(callback, CONNECT_ONE_SHOT)
	if not world.cognition_service.sync_pending():
		world.cognition_service.gateway.sync_completed.disconnect(callback)
		return {"ok": false, "error_code": "sync_not_started"}
	for _index in maximum_frames:
		if bool(state.done):
			await _tree.process_frame
			return state.reply as Dictionary
		await _tree.process_frame
	if world.cognition_service.gateway.sync_completed.is_connected(callback):
		world.cognition_service.gateway.sync_completed.disconnect(callback)
	world.cognition_service.gateway.cancel()
	return {"ok": false, "error_code": "timeout"}


func _boot_world(resume: bool) -> WorldSession:
	_autoload("GameManager").set("resume_requested", resume)
	var packed := load(WORLD_SCENE) as PackedScene
	if packed == null:
		_fail("world scene could not be loaded")
		return null
	var world := packed.instantiate() as WorldSession
	_tree.root.add_child(world)
	await _settle(8)
	if world.player == null or world.cognition_service == null:
		_fail("WorldSession did not initialize production services")
		world.free()
		return null
	return world


func _configure_private_settings() -> void:
	var save_service := _autoload("SaveService")
	var settings: Dictionary = save_service.get("settings")
	settings["ai_dialogue_enabled"] = true
	settings["allow_conversation_storage"] = true
	settings["allow_memory_personalization"] = true
	settings["client_install_id"] = CLIENT_ID
	settings["player_profile_id"] = PLAYER_ID
	save_service.call("save_settings")


func _expect_identity(npc: NPCController, expected: StringName, label: String) -> void:
	_expect(npc != null, "%s was not loaded" % label)
	if npc != null:
		_expect(
			NPCIdentityResolver.resolve_persistent_id(npc) == expected,
			"%s did not use WorldEntityIdentity.persistent_id" % label,
		)


func _expect_save_versions() -> void:
	var manifest := _read_json("user://saves/slot_01/manifest.json")
	var cognition := _read_json("user://saves/slot_01/npc_cognition.json")
	_expect(int(manifest.get("save_version", 0)) == 4, "world save version changed from 4")
	_expect(int(cognition.get("section_version", 0)) == 1, "npc_cognition section version changed")


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _clear_local_save() -> void:
	_autoload("WorldSaveService").call("clear_world")
	_autoload("QuestManager").call("reset_all")
	_autoload("RelationshipService").call("reset_all")
	_remove_recursive("user://saves")


func _remove_recursive(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		var child := path.path_join(name)
		if directory.current_is_dir():
			_remove_recursive(child)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(child))
		name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(absolute)


func _autoload(name: String) -> Node:
	return _tree.root.get_node(name)


func _settle(count: int) -> void:
	for _index in count:
		await _tree.process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
