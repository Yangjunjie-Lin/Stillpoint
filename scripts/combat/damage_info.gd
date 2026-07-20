class_name DamageInfo
extends RefCounted
## Payload carried by Hitbox → Hurtbox → HealthComponent.

var amount: float = 0.0
var source: Node = null
var damage_type: StringName = &"physical"
var knockback: Vector2 = Vector2.ZERO
var critical: bool = false
var hit_id: StringName = &""


static func make(
	p_amount: float,
	p_source: Node = null,
	p_damage_type: StringName = &"physical",
	p_knockback: Vector2 = Vector2.ZERO,
	p_critical: bool = false,
	p_hit_id: StringName = &""
) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = p_amount
	info.source = p_source
	info.damage_type = p_damage_type
	info.knockback = p_knockback
	info.critical = p_critical
	info.hit_id = p_hit_id
	return info
