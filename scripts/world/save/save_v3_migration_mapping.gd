class_name SaveV3MigrationMapping
extends RefCounted
## Legacy node-name to persistent ID mapping (migration only).

const INTERACTABLE_REGION_MAP: Dictionary = {
	"HerbPickup": &"base:wilderness",
	"ForestPortal": &"base:town",
	"DungeonPortal": &"base:town",
	"Chest": &"base:town",
	"PetInteract": &"base:town",
	"MountInteract": &"base:town",
	"MiraTalk": &"base:town",
	"RenTalk": &"base:town",
	"TownPortal": &"base:wilderness",
}


static func npc_persistent_id(npc_key: String) -> StringName:
	match npc_key:
		"mira":
			return &"base:town/npc/mira"
		"ren":
			return &"base:town/npc/ren"
		"bandit":
			return &"base:dungeon/npc/bandit_0001"
		_:
			return StringName("base:unknown/npc/%s" % npc_key)


static func interactable_persistent_id(node_name: String, region_id: StringName) -> StringName:
	var region := String(region_id).trim_prefix("base:")
	match node_name:
		"HerbPickup":
			return &"base:wilderness/pickup/herb_0001"
		"Chest":
			return &"base:town/interactable/chest_0001"
		"ForestPortal":
			return &"base:town/portal/wilderness"
		"DungeonPortal":
			return &"base:town/portal/dungeon"
		"TownPortal":
			return &"base:wilderness/portal/town"
		_:
			return StringName("base:%s/interactable/%s" % [region, node_name.to_lower()])


static func migrate_legacy_npc_state(legacy_data: Dictionary) -> Dictionary:
	var character: Dictionary = {}
	for key in [
		"character_id", "position", "health", "energy", "faction", "skills", "npc_state",
	]:
		if legacy_data.has(key):
			var value: Variant = legacy_data[key]
			if typeof(value) == TYPE_DICTIONARY:
				character[key] = (value as Dictionary).duplicate(true)
			elif typeof(value) == TYPE_ARRAY:
				character[key] = (value as Array).duplicate(true)
			else:
				character[key] = value
	var legacy_region := StringName(str(legacy_data.get("region_id", "base:town")))
	character["region_id"] = String(RegionIdUtil.normalize(legacy_region))
	var state: Dictionary = {}
	var raw_state: Variant = legacy_data.get("state", {})
	if typeof(raw_state) == TYPE_DICTIONARY:
		state = (raw_state as Dictionary).duplicate(true)
	state["is_downed"] = bool(legacy_data.get("is_downed", state.get("is_downed", false)))
	state["is_permanently_dead"] = bool(
		legacy_data.get("is_permanently_dead", state.get("is_permanently_dead", false))
	)
	state["is_running"] = bool(state.get("is_running", false))
	state["is_crouching"] = bool(state.get("is_crouching", false))
	character["state"] = state
	return {"character": character}


static func migrate_legacy_interactable_state(
	node_name: String,
	legacy_data: Dictionary,
) -> Dictionary:
	var state := legacy_data.duplicate(true)
	match node_name:
		"Chest":
			return {"chest": state}
		"HerbPickup":
			return {"pickup": state}
		_:
			# Other v3 interactables retain their node-level compatibility payload.
			return {"entity": state}
