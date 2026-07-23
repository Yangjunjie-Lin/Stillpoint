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
