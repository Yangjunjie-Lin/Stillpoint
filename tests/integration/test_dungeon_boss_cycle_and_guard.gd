extends RefCounted

const WARDEN_ID := &"base:wilderness/npc/dungeon_warden_0001"
const MOSSJAW_ID := &"base:dungeon/boss/mossjaw_0001"


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var ok := ResourceRegistry.get_dungeon(&"returning_stars_hollow") != null
	ok = ok and ResourceRegistry.get_dungeon(&"returning_stars_hollow").is_valid()

	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree, 4)
	var warden := world.entity_repository.get_loaded_entity(WARDEN_ID) as NPCController
	ok = ok and warden != null and warden.definition.id == &"dungeon_warden"
	ok = ok and world.dungeon_progression_service.can_enter_depth(world.player, 1)
	ok = ok and not world.dungeon_progression_service.can_enter_depth(world.player, 2)

	ok = ok and world.start_dialogue(warden)
	world.apply_dialogue_choice(0)
	await WorldTestHelper.await_frames(tree, 4)
	ok = ok and world.current_region_id == &"base:dungeon"
	var depth_spawn := world.region_service.find_spawn(&"depth_1")
	ok = ok and world.player.global_position.distance_to(depth_spawn.origin) < 2.0
	var mossjaw := world.entity_repository.get_loaded_entity(MOSSJAW_ID) as NPCController
	ok = ok and mossjaw != null and mossjaw.definition.dungeon_boss_id == &"mossjaw"
	if mossjaw != null:
		mossjaw.set_physics_process(false)
		mossjaw.health.invulnerability_duration = 0.0
		mossjaw.receive_damage(100_000.0, world.player)
	await WorldTestHelper.await_frames(tree, 3)
	var state := world.dungeon_progression_service.get_boss_state(MOSSJAW_ID)
	ok = ok and int(state.get("next_respawn_day", 0)) == 4
	ok = ok and world.entity_repository.get_loaded_entity(MOSSJAW_ID) == null

	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree, 3)
	WorldTimeService.advance_days(3)
	await WorldTestHelper.await_frames(tree, 5)
	state = world.dungeon_progression_service.get_boss_state(MOSSJAW_ID)
	ok = ok and int(state.get("next_respawn_day", -1)) == 0
	world.transition_to(&"base:dungeon", &"depth_1")
	await WorldTestHelper.await_frames(tree, 4)
	var respawned := world.entity_repository.get_loaded_entity(MOSSJAW_ID) as NPCController
	ok = ok and respawned != null
	state = world.dungeon_progression_service.get_boss_state(MOSSJAW_ID)
	ok = ok and int(state.get("next_respawn_day", -1)) == 0
	ok = ok and world.save_world_state()
	world.free()
	if not ok:
		push_error("dungeon guard, depth gate, or boss respawn cycle failed")
	return ok
