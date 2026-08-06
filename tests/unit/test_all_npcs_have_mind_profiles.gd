extends RefCounted

func run() -> bool:
	var npcs := ResourceRegistry.get_all_npcs()
	if npcs.is_empty():
		push_error("no NPC definitions registered")
		return false
	var seen := {}
	for npc in npcs:
		if npc == null or npc.mind_profile == null or not npc.mind_profile.is_valid():
			return false
		if seen.has(npc.mind_profile.id): return false
		seen[npc.mind_profile.id] = true
	return true
