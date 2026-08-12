extends RefCounted


func run() -> bool:
	var definition := ResourceRegistry.get_pet_companion(&"mossfox")
	var harness := ResourceRegistry.get_item(&"mossfox_harness")
	var charm := ResourceRegistry.get_item(&"quiet_bell_charm")
	var ok := definition != null and harness != null and charm != null
	if not ok:
		push_error("pet equipment fixtures are missing")
		return false

	var baseline := PetRuntimeState.new()
	var equipped := PetRuntimeState.new()
	ok = ok and baseline.initialize(
		definition, &"base:player/pet/equipment_baseline", &"base:player/main"
	)
	ok = ok and equipped.initialize(
		definition, &"base:player/pet/equipment_test", &"base:player/main"
	)
	ok = ok and equipped.equip_item(
		&"body", harness.id, harness.pet_tags, harness.equipment_weight
	)
	ok = ok and equipped.equip_item(
		&"charm", charm.id, charm.pet_tags, charm.equipment_weight
	)

	var baseline_damage := baseline.take_damage(20.0)
	var equipped_damage := equipped.take_damage(20.0)
	ok = ok and is_equal_approx(
		baseline_damage - equipped_damage, harness.defense_bonus
	)

	# Leave enough headroom that the base nine-point rest recovery does not
	# saturate either state and hide the charm's extra one point.
	ok = ok and baseline.spend_stamina(20.0)
	ok = ok and equipped.spend_stamina(20.0)
	var baseline_before_rest := baseline.get_current_stamina()
	var equipped_before_rest := equipped.get_current_stamina()
	ok = ok and baseline.advance_needs(1.0, true)
	ok = ok and equipped.advance_needs(1.0, true)
	var baseline_restored := baseline.get_current_stamina() - baseline_before_rest
	var equipped_restored := equipped.get_current_stamina() - equipped_before_rest
	ok = ok and is_equal_approx(
		equipped_restored - baseline_restored, charm.energy_regen_bonus
	)

	var restored := PetRuntimeState.new()
	ok = ok and restored.from_dict(equipped.to_dict(), definition)
	ok = ok and is_equal_approx(
		float(restored.get_equipment_effects().defense_bonus), harness.defense_bonus
	)
	ok = ok and is_equal_approx(
		float(restored.get_equipment_effects().stamina_regen_bonus),
		charm.energy_regen_bonus,
	)
	var tampered := equipped.to_dict()
	(tampered.equipment as Dictionary)["charm"] = String(harness.id)
	var sanitized := PetRuntimeState.new()
	ok = ok and sanitized.from_dict(tampered, definition)
	ok = ok and sanitized.get_equipped_item(&"body") == harness.id
	ok = ok and sanitized.get_equipped_item(&"charm") == &""
	ok = ok and is_zero_approx(
		float(sanitized.get_equipment_effects().stamina_regen_bonus)
	)

	if not ok:
		push_error("pet equipment did not affect deterministic attributes or persistence")
	return ok
