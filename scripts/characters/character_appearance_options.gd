class_name CharacterAppearanceOptions
extends RefCounted
## Canonical modular appearance slots shared by character creation, preview and saves.

const BODY_OPTIONS: Array[StringName] = [&"balanced", &"slender", &"sturdy"]
const SKIN_OPTIONS: Array[StringName] = [&"origin", &"light", &"warm", &"olive", &"brown", &"deep"]
const HAIR_OPTIONS: Array[StringName] = [&"origin", &"short", &"topknot", &"shaved"]
const HEADWEAR_OPTIONS: Array[StringName] = [&"origin", &"none", &"travel_hood", &"brimmed_hat"]
const PALETTE_OPTIONS: Array[StringName] = [&"origin", &"jade", &"ocean", &"ember", &"earth"]
const ACCESSORY_OPTIONS: Array[StringName] = [&"none", &"satchel", &"travel_pack", &"bedroll"]

const LABELS: Dictionary = {
	&"balanced": "匀称",
	&"slender": "轻盈",
	&"sturdy": "健壮",
	&"light": "浅色",
	&"warm": "暖色",
	&"olive": "橄榄色",
	&"brown": "棕色",
	&"deep": "深色",
	&"origin": "出身预设",
	&"short": "短发",
	&"topknot": "束发",
	&"shaved": "无发饰",
	&"travel_hood": "旅行兜帽",
	&"brimmed_hat": "宽檐帽",
	&"jade": "青玉",
	&"ocean": "海蓝",
	&"ember": "余烬",
	&"earth": "大地",
	&"none": "无",
	&"satchel": "行囊",
	&"travel_pack": "旅背包",
	&"bedroll": "铺盖卷",
}


static func default_options() -> Dictionary:
	return {
		"body_id": "balanced",
		"skin_id": "origin",
		"hair_id": "origin",
		"headwear_id": "origin",
		"palette_id": "origin",
		"accessory_id": "none",
	}


static func normalize(options: Dictionary) -> Dictionary:
	return {
		"body_id": String(_normalize_id(options.get("body_id", "balanced"), BODY_OPTIONS, &"balanced")),
		"skin_id": String(_normalize_id(options.get("skin_id", "origin"), SKIN_OPTIONS, &"origin")),
		"hair_id": String(_normalize_id(options.get("hair_id", "origin"), HAIR_OPTIONS, &"origin")),
		"headwear_id": String(_normalize_id(options.get("headwear_id", "origin"), HEADWEAR_OPTIONS, &"origin")),
		"palette_id": String(_normalize_id(options.get("palette_id", "origin"), PALETTE_OPTIONS, &"origin")),
		"accessory_id": String(_normalize_id(options.get("accessory_id", "none"), ACCESSORY_OPTIONS, &"none")),
	}


static func label_for(id: StringName) -> String:
	return str(LABELS.get(id, String(id)))


static func _normalize_id(value: Variant, allowed: Array[StringName], fallback: StringName) -> StringName:
	var id := StringName(str(value))
	return id if allowed.has(id) else fallback
