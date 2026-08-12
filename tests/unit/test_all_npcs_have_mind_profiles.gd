extends RefCounted

func run() -> bool:
	var npcs := ResourceRegistry.get_all_npcs()
	var expected: Array[StringName] = [
		&"bandit",
		&"bank_clerk",
		&"blacksmith",
		&"dungeon_warden",
		&"fallen_star_warden",
		&"lantern_widow",
		&"mira",
		&"mossjaw",
		&"ren",
	]
	if ResourceRegistry.get_all_npc_ids() != expected:
		push_error("NPC definition catalog does not match the nine authored profiles")
		return false
	var seen := {}
	for npc in npcs:
		if npc == null or npc.mind_profile == null or not npc.mind_profile.is_valid():
			return false
		if seen.has(npc.mind_profile.id): return false
		seen[npc.mind_profile.id] = true
	return true
