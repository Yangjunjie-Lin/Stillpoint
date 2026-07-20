class_name HealthComponent
extends Node
## Owns max/current HP, invulnerability, and death for an actor.

signal health_changed(current: float, maximum: float)
signal damaged(amount: float, source: Node)
signal healed(amount: float)
signal died(source: Node)

@export var max_health: float = 100.0
@export var defense: float = 0.0
@export var invulnerability_duration: float = 0.75
@export var minimum_damage: float = 1.0

var current_health: float = 100.0
var invulnerable_until: float = -1.0
var hit_flash_until: float = -1.0
var death_recorded: bool = false


func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func is_dead() -> bool:
	return death_recorded or current_health <= 0.0


func is_invulnerable() -> bool:
	return Time.get_ticks_msec() / 1000.0 < invulnerable_until


func apply_damage(info: DamageInfo, ignore_invulnerability: bool = false) -> float:
	if is_dead():
		return 0.0
	if not ignore_invulnerability and is_invulnerable():
		return 0.0
	var dealt: float = CombatMath.calculate_damage(info.amount, defense, minimum_damage)
	current_health = maxf(0.0, current_health - dealt)
	invulnerable_until = Time.get_ticks_msec() / 1000.0 + invulnerability_duration
	hit_flash_until = Time.get_ticks_msec() / 1000.0 + 0.2
	damaged.emit(dealt, info.source)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		_mark_dead(info.source)
	return dealt


## Gameplay-clock aware damage used while the tree is pausable.
func apply_damage_at(info: DamageInfo, game_time: float, shielded: bool = false) -> float:
	if is_dead():
		return 0.0
	if shielded:
		return 0.0
	if game_time < invulnerable_until:
		return 0.0
	var dealt: float = CombatMath.calculate_damage(info.amount, defense, minimum_damage)
	current_health = maxf(0.0, current_health - dealt)
	invulnerable_until = game_time + invulnerability_duration
	hit_flash_until = game_time + 0.2
	damaged.emit(dealt, info.source)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		_mark_dead(info.source)
	return dealt


func heal(amount: float) -> float:
	if is_dead() or amount <= 0.0:
		return 0.0
	var before := current_health
	current_health = minf(max_health, current_health + amount)
	var gained := current_health - before
	if gained > 0.0:
		healed.emit(gained)
		health_changed.emit(current_health, max_health)
	return gained


func raise_max_health(amount: float, restore_amount: float = 0.0) -> void:
	max_health += amount
	if restore_amount > 0.0:
		heal(restore_amount)
	else:
		health_changed.emit(current_health, max_health)


func _mark_dead(source: Node) -> void:
	if death_recorded:
		return
	death_recorded = true
	current_health = 0.0
	died.emit(source)


func to_dict() -> Dictionary:
	return {
		"max_health": max_health,
		"current_health": current_health,
		"defense": defense,
		"death_recorded": death_recorded,
	}


func from_dict(data: Dictionary) -> void:
	var loaded_max := float(data.get("max_health", max_health))
	var loaded_current := float(data.get("current_health", current_health))
	var loaded_defense := float(data.get("defense", defense))
	death_recorded = bool(data.get("death_recorded", false))
	max_health = maxf(1.0, loaded_max)
	if is_finite(loaded_current):
		current_health = clampf(loaded_current, 0.0, max_health)
	else:
		current_health = 0.0
	defense = maxf(0.0, loaded_defense)
	health_changed.emit(current_health, max_health)
