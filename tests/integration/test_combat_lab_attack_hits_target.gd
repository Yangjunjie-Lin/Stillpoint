extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var packed := load("res://scenes/combat/combat_lab.tscn") as PackedScene
	var lab := packed.instantiate() as CombatLabManager
	tree.root.add_child(lab)
	await WorldTestHelper.await_frames(tree, 3)

	var player := lab.player
	var dummy := lab.get_node_or_null("TrainingDummy") as NPCController
	var bandit := lab.get_node_or_null("Bandit") as NPCController
	if player == null or dummy == null or bandit == null:
		push_error("Combat Lab did not instantiate its player and target actors")
		lab.free()
		return false
	var hitbox := player.get_node_or_null("CombatPivot/HitboxRoot/Hitbox3D") as Hitbox3D
	var player_hurtbox := player.get_node_or_null("Hurtbox3D") as Hurtbox3D
	var dummy_hurtbox := dummy.get_node_or_null("Hurtbox3D") as Hurtbox3D
	var bandit_hurtbox := bandit.get_node_or_null("Hurtbox3D") as Hurtbox3D
	var ok := hitbox != null and hitbox.get_node_or_null("CollisionShape3D") != null
	ok = ok and player_hurtbox != null and player_hurtbox.team == &"player"
	ok = ok and dummy_hurtbox != null and dummy_hurtbox.team == &"npc"
	ok = ok and dummy_hurtbox.get_node_or_null("CollisionShape3D") != null
	ok = ok and bandit_hurtbox != null and bandit_hurtbox.team == &"npc"
	ok = ok and bandit_hurtbox.get_node_or_null("CollisionShape3D") != null
	if not ok:
		push_error("Combat Lab player/target hitbox scene contract is incomplete")
		lab.free()
		return false

	# Keep the scene actors fixed while exercising the real J/normal_attack route.
	player.set_physics_process(false)
	dummy.set_physics_process(false)
	bandit.set_physics_process(false)
	player.global_position = dummy.global_position + Vector3(0.0, 0.0, 1.0)
	player.global_basis = Basis.IDENTITY
	await WorldTestHelper.await_frames(tree, 2)

	var before := dummy.health.current_health
	var animation_player := player.get_node("CombatAnimationController/AnimationPlayer") as AnimationPlayer
	var animation_controller := player.get_node("CombatAnimationController") as CombatAnimationController
	var attack_event := InputEventKey.new()
	attack_event.pressed = true
	attack_event.keycode = KEY_J
	attack_event.physical_keycode = KEY_J
	tree.root.push_input(attack_event)
	await tree.create_timer(1.0).timeout

	ok = dummy.health.current_health < before
	ok = ok and not player.combat.is_attacking
	ok = ok and not player.combat.hitbox_active
	var after := dummy.health.current_health
	var still_attacking := player.combat.is_attacking
	var combat_state := player.combat.combat_state
	var hitbox_still_active := hitbox.active
	var current_animation := animation_player.current_animation
	var current_position := animation_player.current_animation_position
	var animation_root := animation_player.root_node
	var attack_clip := animation_player.get_animation(&"combat/attack_light_1")
	var method_path := attack_clip.track_get_path(0) if attack_clip != null else NodePath()
	var animation_has_combat := animation_controller.get("_combat") != null
	lab.free()
	if not ok:
		push_error(
			(
				"Combat Lab normal attack did not damage the real target or finish via animation "
				+ "events (hp %.1f -> %.1f, attacking=%s, state=%s, active=%s, "
				+ "animation=%s@%.2f, root=%s, method_path=%s, anim_combat=%s)"
			)
			% [
				before,
				after,
				str(still_attacking),
				str(combat_state),
				str(hitbox_still_active),
				String(current_animation),
				current_position,
				str(animation_root),
				str(method_path),
				str(animation_has_combat),
			]
		)
	return ok
