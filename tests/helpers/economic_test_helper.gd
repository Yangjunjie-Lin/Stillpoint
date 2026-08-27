class_name EconomicTestHelper
extends RefCounted


static func make_blacksmith_actor(
	actor_id: StringName = &"base:town/npc/test_blacksmith",
	wallet_balance: int = 10,
	tool_id: StringName = &"starter_forge_hammer",
) -> NPCController:
	var actor := NPCController.new()
	actor.character_id = &"blacksmith"
	actor.region_id = &"base:town"
	actor.npc_definition = ResourceRegistry.get_npc(&"blacksmith")
	actor.definition = actor.npc_definition
	var identity := WorldEntityIdentity.new()
	identity.name = "WorldEntityIdentity"
	identity.persistent_id = actor_id
	identity.definition_id = &"blacksmith"
	identity.region_id = &"base:town"
	actor.add_child(identity)
	actor.wallet = WalletComponent.new()
	actor.wallet.name = "WalletComponent"
	actor.add_child(actor.wallet)
	actor.wallet.restore_balance(wallet_balance)
	actor.inventory = InventoryComponent.new()
	actor.inventory.name = "InventoryComponent"
	actor.add_child(actor.inventory)
	actor.equipment = EquipmentComponent.new()
	actor.equipment.name = "EquipmentComponent"
	actor.add_child(actor.equipment)
	actor.attributes = ActorAttributesComponent.new()
	actor.attributes.name = "ActorAttributesComponent"
	actor.add_child(actor.attributes)
	actor.attributes.apply_attributes({
		"strength": 14.0,
		"vitality": 12.0,
		"dexterity": 9.0,
		"intelligence": 13.0,
	})
	actor.skills = SkillComponent.new()
	actor.skills.name = "SkillComponent"
	actor.add_child(actor.skills)
	actor.energy = EnergyComponent.new()
	actor.energy.name = "EnergyComponent"
	actor.energy.max_energy = 100.0
	actor.energy.current_energy = 100.0
	actor.add_child(actor.energy)
	actor.employment = EmploymentComponent.new()
	actor.employment.name = "EmploymentComponent"
	actor.add_child(actor.employment)
	if tool_id != &"":
		actor.inventory.add_item(tool_id, 1)
		actor.equipment.equip_from_inventory(actor.inventory, 0)
	var job := ResourceRegistry.get_job(&"job:blacksmith")
	var contract := EmploymentContract.new()
	contract.actor_id = actor_id
	contract.job_id = job.id
	contract.worksite_id = &"worksite:town_smithy"
	contract.status = EmploymentContract.STATUS_ACTIVE
	contract.start_day = 1
	contract.wage_per_shift = job.base_wage
	contract.shift_start_hour = job.shift_start_hour
	contract.shift_end_hour = job.shift_end_hour
	actor.employment.initialize_contract(contract)
	return actor


static func worksite_state(payroll: int = 100) -> WorkSiteRuntimeState:
	var state := WorkSiteRuntimeState.new()
	state.worksite_id = &"worksite:town_smithy"
	state.payroll_balance = payroll
	return state
