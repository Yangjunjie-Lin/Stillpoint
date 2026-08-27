extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var actor_a := _economic_node(&"npc:blacksmith:001", 30, &"starter_forge_hammer", 5.0, 1)
	var actor_b := _economic_node(&"npc:blacksmith:002", 80, &"improved_forge_hammer", 25.0, 2)
	tree.root.add_child(actor_a)
	tree.root.add_child(actor_b)
	var snap_a := EntitySnapshot.new()
	var snap_b := EntitySnapshot.new()
	snap_a.capture_from_node(actor_a)
	snap_b.capture_from_node(actor_b)
	var ok: bool = snap_a.persistent_id != snap_b.persistent_id
	ok = ok and snap_a.component_states.has("wallet")
	ok = ok and snap_a.component_states.has("inventory")
	ok = ok and snap_a.component_states.has("equipment")
	ok = ok and snap_a.component_states.has("employment")
	var wallet_a := actor_a.get_node("WalletComponent") as WalletComponent
	var wallet_b := actor_b.get_node("WalletComponent") as WalletComponent
	var skills_a := actor_a.get_node("SkillComponent") as SkillComponent
	var skills_b := actor_b.get_node("SkillComponent") as SkillComponent
	var equipment_a := actor_a.get_node("EquipmentComponent") as EquipmentComponent
	var equipment_b := actor_b.get_node("EquipmentComponent") as EquipmentComponent
	var employment_a := actor_a.get_node("EmploymentComponent") as EmploymentComponent
	var employment_b := actor_b.get_node("EmploymentComponent") as EmploymentComponent
	wallet_a.restore_balance(999)
	wallet_b.restore_balance(998)
	snap_a.apply_to_node(actor_a)
	snap_b.apply_to_node(actor_b)
	ok = ok and wallet_a.get_balance() == 30 and wallet_b.get_balance() == 80
	ok = ok and skills_a.get_points(&"smithing") == 5.0
	ok = ok and skills_b.get_points(&"smithing") == 25.0
	ok = ok and employment_a.economic_sequence == 1
	ok = ok and employment_b.economic_sequence == 2
	ok = ok and equipment_a.get_equipped_item(ItemDefinition.EquipSlot.WEAPON) == &"starter_forge_hammer"
	ok = ok and equipment_b.get_equipped_item(ItemDefinition.EquipSlot.WEAPON) == &"improved_forge_hammer"
	actor_a.free()
	actor_b.free()
	if not ok:
		push_error("same-definition NPC economic snapshot state was shared or lost")
	return ok


func _economic_node(
	actor_id: StringName,
	balance: int,
	tool_id: StringName,
	skill_points: float,
	sequence: int,
) -> Node3D:
	var actor := Node3D.new()
	var identity := WorldEntityIdentity.new()
	identity.name = "WorldEntityIdentity"
	identity.persistent_id = actor_id
	identity.definition_id = &"blacksmith"
	identity.region_id = &"base:town"
	actor.add_child(identity)
	var wallet := WalletComponent.new()
	wallet.name = "WalletComponent"
	wallet.starting_balance = balance
	actor.add_child(wallet)
	var inventory := InventoryComponent.new()
	inventory.name = "InventoryComponent"
	actor.add_child(inventory)
	var equipment := EquipmentComponent.new()
	equipment.name = "EquipmentComponent"
	actor.add_child(equipment)
	var skills := SkillComponent.new()
	skills.name = "SkillComponent"
	actor.add_child(skills)
	var employment := EmploymentComponent.new()
	employment.name = "EmploymentComponent"
	actor.add_child(employment)
	inventory.add_item(tool_id, 1)
	equipment.equip_from_inventory(inventory, 0)
	skills.set_proficiency_points(&"smithing", skill_points)
	employment.economic_sequence = sequence
	return actor
