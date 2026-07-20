extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		push_error("Bullet test requires SceneTree")
		return false

	var root := Node.new()
	tree.root.add_child(root)
	var ok := true

	var enemy_a := _spawn_enemy(root, &"enemy_a", Vector2(100, 100))
	var enemy_b := _spawn_enemy(root, &"enemy_b", Vector2(200, 100))
	if enemy_a == null or enemy_b == null:
		push_error("Bullet test: enemy spawn failed")
		root.free()
		return false

	var bullet := Bullet.new()
	root.add_child(bullet)
	bullet.setup(Vector2(90, 100), Vector2.RIGHT, 5.0, 0.0, 2.0, false, 1.0, null)
	var hp_before := enemy_a.health.current_health
	bullet._try_hit(enemy_a)
	ok = ok and enemy_a.health.current_health < hp_before
	ok = ok and bullet.is_queued_for_deletion()

	bullet = Bullet.new()
	root.add_child(bullet)
	bullet.setup(Vector2.ZERO, Vector2.RIGHT, 5.0, 0.0, 2.0, true, 1.0, null)
	hp_before = enemy_a.health.current_health
	bullet._try_hit(enemy_a)
	ok = ok and not bullet.is_queued_for_deletion()
	ok = ok and enemy_a.health.current_health < hp_before
	var mid_hp := enemy_a.health.current_health
	bullet._try_hit(enemy_a)
	ok = ok and is_equal_approx(enemy_a.health.current_health, mid_hp)

	var hp_b := enemy_b.health.current_health
	bullet._try_hit(enemy_b)
	ok = ok and enemy_b.health.current_health < hp_b

	bullet._age = 10.0
	bullet._physics_process(0.016)
	ok = ok and bullet.is_queued_for_deletion()

	bullet = Bullet.new()
	root.add_child(bullet)
	bullet.setup(Vector2.ZERO, Vector2.RIGHT, 5.0, 0.0, 2.0, false, 1.0, null)
	var orphan := Node.new()
	bullet._try_hit(null)
	bullet._try_hit(orphan)
	orphan.free()
	ok = ok and not bullet.is_queued_for_deletion()

	root.queue_free()
	if not ok:
		push_error("Bullet assertions failed")
	return ok


func _spawn_enemy(parent: Node, id: StringName, pos: Vector2) -> EnemyController:
	var packed: PackedScene = load("res://scenes/actors/enemies/enemy_base.tscn") as PackedScene
	var enemy := packed.instantiate() as EnemyController
	if enemy == null:
		return null
	parent.add_child(enemy)
	enemy.enemy_id = id
	enemy.global_position = pos
	var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
	if health == null:
		push_error("Bullet test: HealthComponent missing")
		return null
	# Ensure typed accessor is usable even if @onready timing differs in headless.
	enemy.health = health
	health.max_health = 100.0
	health.current_health = 100.0
	return enemy
