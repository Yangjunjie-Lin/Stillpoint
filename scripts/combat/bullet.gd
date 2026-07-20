class_name Bullet
extends Area2D
## Projectile with piercing hit de-duplication via enemy_id.

@export var sprite: Sprite2D

var velocity: Vector2 = Vector2.ZERO
var damage: float = 12.0
var lifetime: float = 2.0
var piercing: bool = false
var owner_actor: Node = null
var _age: float = 0.0
var _hit_ids: Dictionary = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func setup(
	origin: Vector2,
	direction: Vector2,
	p_damage: float,
	speed: float,
	p_lifetime: float,
	p_piercing: bool,
	p_scale: float,
	p_owner: Node
) -> void:
	global_position = origin
	velocity = direction.normalized() * speed
	damage = p_damage
	lifetime = p_lifetime
	piercing = p_piercing
	owner_actor = p_owner
	scale = Vector2.ONE * p_scale
	monitoring = true
	monitorable = false
	collision_layer = 8  # projectile
	collision_mask = 4   # enemy bodies / hurtboxes as configured in scene


func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	_age += delta
	if _age >= lifetime:
		queue_free()


func _on_body_entered(body: Node) -> void:
	_try_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_try_hit(area.get_parent())


func _try_hit(node: Node) -> void:
	if node == null:
		return
	var enemy := node as EnemyController
	if enemy == null and is_instance_valid(node):
		var parent := node.get_parent()
		if parent != null:
			enemy = parent as EnemyController
	if enemy == null or enemy.health == null or enemy.health.is_dead():
		return
	if _hit_ids.has(enemy.enemy_id):
		return
	_hit_ids[enemy.enemy_id] = true
	enemy.apply_bullet_damage(damage, owner_actor)
	if not piercing:
		queue_free()
