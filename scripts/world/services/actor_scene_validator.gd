class_name ActorSceneValidator
extends RefCounted
## Validates actor scenes have required components.

const REQUIRED_NPC_NODES: Array[String] = [
	"HealthComponent",
	"EnergyComponent",
	"FactionComponent",
	"RelationshipComponent",
	"InteractionComponent",
	"CombatComponent",
	"Hurtbox3D",
]


static func validate(actor: Node) -> bool:
	if actor == null:
		return false
	var ok := true
	for node_name in REQUIRED_NPC_NODES:
		if actor.get_node_or_null(node_name) == null:
			push_warning("ActorSceneValidator: %s missing %s" % [actor.name, node_name])
			ok = false
	return ok
