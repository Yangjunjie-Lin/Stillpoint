extends RefCounted


func run() -> bool:
	var legacy_item := ItemDefinition.new()
	var ok := legacy_item.equip_slot == ItemDefinition.EquipSlot.NONE
	ok = ok and legacy_item.use_kind == ItemDefinition.UseKind.NONE
	ok = ok and legacy_item.health_restore == 0.0
	ok = ok and legacy_item.energy_restore == 0.0
	ok = ok and legacy_item.attack_bonus == 0.0
	ok = ok and legacy_item.defense_bonus == 0.0
	ok = ok and legacy_item.energy_regen_bonus == 0.0
	ok = ok and legacy_item.starter_balance_value == 0
	legacy_item.use_kind = ItemDefinition.UseKind.CONSUME
	legacy_item.health_restore = 12.0
	legacy_item.energy_restore = 8.0
	return ok \
		and legacy_item.use_kind == ItemDefinition.UseKind.CONSUME \
		and legacy_item.health_restore == 12.0 \
		and legacy_item.energy_restore == 8.0
