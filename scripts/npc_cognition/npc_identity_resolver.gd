class_name NPCIdentityResolver
extends RefCounted
## Resolves only authored/runtime WorldEntityIdentity. Definition and node IDs are not identities.

static func resolve_persistent_id(npc: Node) -> StringName:
	if npc == null:
		return &""
	var identity := npc.get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
	if identity == null:
		for child in npc.get_children():
			if child is WorldEntityIdentity:
				identity = child as WorldEntityIdentity
				break
	if identity == null or not identity.is_valid():
		push_warning(
			"NPCIdentityResolver: persistent NPC '%s' has no WorldEntityIdentity.persistent_id; cognition blocked"
			% npc.name
		)
		return &""
	return identity.persistent_id
