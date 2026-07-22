class_name CombatHitResult
extends RefCounted
## Immutable snapshot of a resolved combat interaction.

var attacker: Node
var defender: CharacterController
var attack_id: StringName
var damage_dealt: float
var was_blocked: bool
var was_back_attack: bool
var hit_direction: Vector3
var hit_stop_duration: float
var knockback_distance: float
var knockback_duration: float
var launch_velocity: float
var hitstun_duration: float
var guard_damage: float


static func make(
	attacker_node: Node,
	defender_char: CharacterController,
	attack: AttackDefinition,
	dealt: float,
	blocked: bool,
	back_attack: bool,
	direction: Vector3,
) -> CombatHitResult:
	var result := CombatHitResult.new()
	result.attacker = attacker_node
	result.defender = defender_char
	result.attack_id = attack.id if attack != null else &""
	result.damage_dealt = dealt
	result.was_blocked = blocked
	result.was_back_attack = back_attack
	result.hit_direction = direction
	if attack != null:
		result.hit_stop_duration = attack.hit_stop_duration
		result.knockback_distance = attack.knockback_distance
		result.knockback_duration = attack.knockback_duration
		result.launch_velocity = attack.launch_velocity
		result.hitstun_duration = attack.hitstun_duration
		result.guard_damage = attack.guard_damage
	return result
