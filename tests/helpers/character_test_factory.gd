class_name CharacterTestFactory
extends RefCounted
## Builds the smallest CharacterController that satisfies the production scene contract.


static func create(node_name: String = "TestCharacter") -> CharacterController:
	var character := CharacterController.new()
	character.name = node_name
	character.character_id = StringName(node_name.to_snake_case())

	var body_shape := CollisionShape3D.new()
	body_shape.name = "CollisionShape3D"
	body_shape.shape = CapsuleShape3D.new()
	character.add_child(body_shape)

	_add_named(character, HealthComponent.new(), "HealthComponent")
	_add_named(character, EnergyComponent.new(), "EnergyComponent")
	_add_named(character, FactionComponent.new(), "FactionComponent")
	_add_named(character, RelationshipComponent.new(), "RelationshipComponent")
	_add_named(character, InteractionComponent.new(), "InteractionComponent")
	_add_named(character, CombatComponent.new(), "CombatComponent")
	_add_named(character, SkillComponent.new(), "SkillComponent")
	_add_named(character, StatusEffectComponent.new(), "StatusEffectComponent")

	var hurtbox := Hurtbox3D.new()
	hurtbox.name = "Hurtbox3D"
	var hurt_shape := CollisionShape3D.new()
	hurt_shape.name = "CollisionShape3D"
	hurt_shape.shape = CapsuleShape3D.new()
	hurtbox.add_child(hurt_shape)
	character.add_child(hurtbox)
	return character


static func _add_named(parent: Node, child: Node, node_name: String) -> void:
	child.name = node_name
	parent.add_child(child)
