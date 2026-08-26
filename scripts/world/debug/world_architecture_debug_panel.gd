extends CanvasLayer
## Debug-build-only world and embodied-economy acceptance surface.
##
## The controls make a real exported Debug Build observable when an automation
## host cannot deliver physical keyboard input. Action buttons synthesize the
## same InputMap actions as a player keyboard; navigation still goes through the
## normal region/session services. No control mutates wallet, inventory,
## equipment, employment, skill, payroll, or work results directly.

@onready var label: Label = %Label
@onready var previous_npc_button: Button = %PreviousNPCButton
@onready var next_npc_button: Button = %NextNPCButton
@onready var near_npc_button: Button = %NearNPCButton
@onready var near_worksite_button: Button = %NearWorksiteButton
@onready var spawn_sibling_button: Button = %SpawnSiblingButton
@onready var previous_interactable_button: Button = %PreviousInteractableButton
@onready var next_interactable_button: Button = %NextInteractableButton
@onready var near_interactable_button: Button = %NearInteractableButton
@onready var interact_button: Button = %InteractButton
@onready var step_button: Button = %StepButton
@onready var camera_button: Button = %CameraButton
@onready var target_button: Button = %TargetButton
@onready var attack_button: Button = %AttackButton
@onready var dodge_button: Button = %DodgeButton
@onready var guard_button: Button = %GuardButton
@onready var inventory_button: Button = %InventoryButton
@onready var pause_button: Button = %PauseButton
@onready var town_button: Button = %TownButton
@onready var farm_button: Button = %FarmButton
@onready var wilderness_button: Button = %WildernessButton
@onready var dungeon_button: Button = %DungeonButton

var _session: WorldSession
var _selected_actor_id: StringName = &""
var _selected_interactable_index: int = 0
var _last_region_id: StringName = &""
var _pointer_assist_applied := false
var _action_busy := false


func _ready() -> void:
	visible = OS.is_debug_build()
	if not visible:
		set_process(false)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_session = _find_session()
	previous_npc_button.pressed.connect(_cycle_npc.bind(-1))
	next_npc_button.pressed.connect(_cycle_npc.bind(1))
	near_npc_button.pressed.connect(_move_near_selected_npc)
	near_worksite_button.pressed.connect(_move_near_selected_worksite)
	spawn_sibling_button.pressed.connect(_spawn_selected_sibling)
	previous_interactable_button.pressed.connect(_cycle_interactable.bind(-1))
	next_interactable_button.pressed.connect(_cycle_interactable.bind(1))
	near_interactable_button.pressed.connect(_move_near_selected_interactable)
	interact_button.pressed.connect(_pulse_action.bind(&"interact"))
	step_button.pressed.connect(_hold_action.bind(&"move_forward", 30))
	camera_button.pressed.connect(_pulse_action.bind(&"toggle_camera_perspective"))
	target_button.pressed.connect(_pulse_action.bind(&"toggle_target_lock"))
	attack_button.pressed.connect(_pulse_action.bind(&"normal_attack"))
	dodge_button.pressed.connect(_pulse_action.bind(&"dodge"))
	guard_button.pressed.connect(_hold_action.bind(&"guard", 30))
	inventory_button.pressed.connect(_pulse_action.bind(&"open_menu"))
	pause_button.pressed.connect(_pulse_action.bind(&"pause"))
	town_button.pressed.connect(_travel_to_region.bind(&"base:town"))
	farm_button.pressed.connect(_travel_to_region.bind(&"base:farmland"))
	wilderness_button.pressed.connect(_travel_to_region.bind(&"base:wilderness"))
	dungeon_button.pressed.connect(_travel_to_region.bind(&"base:dungeon"))


func _process(_delta: float) -> void:
	if not visible:
		return
	if _session == null:
		_session = _find_session()
	if _session == null or label == null:
		return
	_apply_pointer_assist()
	if _last_region_id != _session.current_region_id:
		_last_region_id = _session.current_region_id
		_selected_interactable_index = 0
	_ensure_initial_actor_selection()
	var lines: PackedStringArray = []
	lines.append("DEBUG ACCEPTANCE ASSIST · actions use normal InputMap paths")
	lines.append("Region: %s · Entities: %d · Snapshots: %d · Interactables: %d" % [
		String(_session.current_region_id),
		_session.entity_repository.get_loaded_count(),
		_session.entity_repository.get_snapshot_count(),
		_session.interaction_index.get_registered_count(),
	])
	var tracked := QuestManager.get_tracked_quest()
	lines.append("Quest: %s · Last Save: %s" % [
		String(tracked.quest_id) if tracked else "-",
		_session.save_coordinator.get_last_save_result(),
	])
	var npc := _selected_npc()
	if npc != null:
		_append_economic_actor_lines(lines, npc)
	else:
		lines.append("--- Economic Actor ---")
		lines.append("Selected actor is not loaded in this region.")
	var interactable := _selected_interactable()
	lines.append("--- Interaction Assist ---")
	lines.append("Selected: %s" % (
		interactable.get_interaction_text(_session.player)
		if interactable != null and _session.player != null else "-"
	))
	label.text = "\n".join(lines)


func _append_economic_actor_lines(lines: PackedStringArray, npc: NPCController) -> void:
	lines.append("--- Economic Actor ---")
	lines.append("Persistent ID: %s · Definition: %s" % [
		String(npc.get_persistent_actor_id()),
		String(npc.definition.id) if npc.definition != null else "-",
	])
	lines.append("Wallet: %d · Energy: %.1f / %.1f" % [
		npc.wallet.get_balance() if npc.wallet != null else 0,
		npc.energy.current_energy if npc.energy != null else 0.0,
		npc.energy.max_energy if npc.energy != null else 0.0,
	])
	var contract := npc.employment.current_contract if npc.employment != null else null
	lines.append("Job: %s · Worksite: %s" % [
		String(contract.job_id) if contract != null else "-",
		String(contract.worksite_id) if contract != null else "-",
	])
	var worksite_state := _session.actor_economy_service.get_worksite_state(contract.worksite_id) \
		if contract != null and _session.actor_economy_service != null else null
	lines.append("Payroll: %d · State: %s · Site distance: %s" % [
		worksite_state.payroll_balance if worksite_state != null else 0,
		NPCController.NPCState.keys()[npc.npc_state],
		_worksite_distance_text(npc, contract),
	])
	lines.append("Smithing: %.1f · Inventory: %s" % [
		npc.skills.get_points(&"smithing") if npc.skills != null else 0.0,
		_inventory_summary(npc.inventory),
	])
	var smithing_tags: Array[StringName] = [&"smithing"]
	var tool := EquipmentEffectCalculator.best_work_tool(npc.equipment, smithing_tags)
	lines.append("Work Tool: %s" % (tool.display_name if tool != null else "-"))
	if npc.employment != null:
		lines.append("Sequence: %d · Work actions: %d · Lifetime income: %d" % [
			npc.employment.economic_sequence,
			npc.employment.completed_work_actions,
			npc.employment.lifetime_income,
		])
		lines.append("Last Work: %s" % _work_result_summary(npc.employment.last_work_result))
	lines.append("Last Wallet Tx: %s" % _last_wallet_transaction(npc.wallet))


func _find_session() -> WorldSession:
	var node := get_parent()
	if node is WorldSession:
		return node as WorldSession
	return null


func _ensure_initial_actor_selection() -> void:
	if _selected_actor_id != &"" or _session == null:
		return
	var candidates := _current_npcs()
	for npc in candidates:
		if (
			npc.employment != null
			and npc.employment.current_contract != null
			and npc.employment.current_contract.job_id == &"job:blacksmith"
		):
			_selected_actor_id = npc.get_persistent_actor_id()
			return
	if not candidates.is_empty():
		_selected_actor_id = candidates[0].get_persistent_actor_id()


func _selected_npc() -> NPCController:
	if _session == null or _selected_actor_id == &"":
		return null
	var entity := _session.entity_repository.get_loaded_entity(_selected_actor_id)
	if entity is NPCController and RegionIdUtil.normalize((entity as NPCController).region_id) \
			== RegionIdUtil.normalize(_session.current_region_id):
		return entity as NPCController
	return null


func _current_npcs() -> Array[NPCController]:
	var result: Array[NPCController] = []
	if _session == null or _session.entity_repository == null:
		return result
	for entity in _session.entity_repository.get_loaded_entities_in_region(
		_session.current_region_id
	):
		if entity is NPCController:
			result.append(entity as NPCController)
	result.sort_custom(func(a: NPCController, b: NPCController) -> bool:
		return String(a.get_persistent_actor_id()) < String(b.get_persistent_actor_id())
	)
	return result


func _cycle_npc(step: int) -> void:
	var candidates := _current_npcs()
	if candidates.is_empty():
		return
	var current_index := -1
	for index in candidates.size():
		if candidates[index].get_persistent_actor_id() == _selected_actor_id:
			current_index = index
			break
	current_index = wrapi(current_index + step, 0, candidates.size())
	_selected_actor_id = candidates[current_index].get_persistent_actor_id()


func _current_interactables() -> Array[Interactable]:
	var result: Array[Interactable] = []
	if _session == null or _session.region_service == null:
		return result
	_collect_interactables(_session.region_service.get_current_region_root(), result)
	result.sort_custom(func(a: Interactable, b: Interactable) -> bool:
		var a_text: String = a.get_interaction_text(_session.player) \
			if _session.player != null else String(a.name)
		var b_text: String = b.get_interaction_text(_session.player) \
			if _session.player != null else String(b.name)
		return a_text < b_text
	)
	return result


func _collect_interactables(node: Node, result: Array[Interactable]) -> void:
	if node == null:
		return
	if node is Interactable:
		var interactable := node as Interactable
		if (
			interactable.is_interaction_enabled()
			and RegionIdUtil.normalize(interactable.region_id)
				== RegionIdUtil.normalize(_session.current_region_id)
		):
			result.append(interactable)
	for child in node.get_children():
		_collect_interactables(child, result)


func _selected_interactable() -> Interactable:
	var candidates := _current_interactables()
	if candidates.is_empty():
		return null
	_selected_interactable_index = wrapi(_selected_interactable_index, 0, candidates.size())
	return candidates[_selected_interactable_index]


func _cycle_interactable(step: int) -> void:
	var candidates := _current_interactables()
	if candidates.is_empty():
		return
	_selected_interactable_index = wrapi(
		_selected_interactable_index + step,
		0,
		candidates.size(),
	)


func _move_near_selected_npc() -> void:
	_move_player_near(_selected_npc())


func _move_near_selected_worksite() -> void:
	var npc := _selected_npc()
	if npc == null or npc.employment == null or npc.employment.current_contract == null:
		return
	var worksite := ResourceRegistry.get_worksite(
		npc.employment.current_contract.worksite_id
	)
	var root := _session.region_service.get_current_region_root()
	var marker := root.find_child(String(worksite.work_marker_id), true, false) as Node3D \
		if root != null and worksite != null else null
	_move_player_near(marker)


func _move_near_selected_interactable() -> void:
	_move_player_near(_selected_interactable())


func _move_player_near(target: Node3D) -> void:
	if target == null or _session == null or _session.player == null:
		return
	var target_position := target.global_position
	var vertical_offset := 0.2 if target_position.y >= 0.8 else 1.2
	_session.player.global_position = target_position + Vector3(0.0, vertical_offset, 1.8)
	var facing_point := Vector3(
		target_position.x,
		_session.player.global_position.y,
		target_position.z,
	)
	if _session.player.global_position.distance_squared_to(facing_point) > 0.01:
		_session.player.look_at(facing_point, Vector3.UP)
		var direction := facing_point - _session.player.global_position
		var rig := _session.player.get_camera_controller()
		if rig != null and direction.length_squared() > 0.01:
			rig.set_look_angles(atan2(-direction.x, -direction.z), deg_to_rad(-10.0))
	_session.player.velocity = Vector3.ZERO
	_session.player.update_interaction_targets(
		_session.interaction_index.query_nearby(_session.player, 3.0)
	)


func _spawn_selected_sibling() -> void:
	var source := _selected_npc()
	if source == null or _session == null or _session.actor_factory == null:
		return
	var source_identity := source.get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
	var parent := _session.region_service.get_dynamic_parent()
	if source_identity == null or parent == null:
		return
	var sibling_id := &""
	for index in range(1, 100):
		var candidate := StringName(
			"%s/npc/%s_debug_%02d" % [
				String(_session.current_region_id),
				String(source_identity.definition_id),
				index,
			]
		)
		if (
			_session.entity_repository.get_loaded_entity(candidate) == null
			and _session.entity_repository.get_snapshot(candidate) == null
		):
			sibling_id = candidate
			break
	if sibling_id == &"":
		return
	var context := ActorSpawnContext.new()
	context.definition_id = source_identity.definition_id
	context.persistent_id = sibling_id
	context.region_id = _session.current_region_id
	context.parent = parent
	context.transform = source.global_transform
	context.transform.origin += Vector3(2.0, 0.0, 2.0)
	var sibling := _session.actor_factory.spawn_actor(
		source_identity.definition_id,
		context,
	) as NPCController
	if sibling == null:
		return
	var sibling_identity := sibling.get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
	if sibling_identity != null:
		sibling_identity.runtime_spawned = true
		sibling_identity.persistence_policy = WorldEntityIdentity.PersistencePolicy.REGION
	var interactable := sibling.get_node_or_null("NPCInteractable") as Interactable
	if interactable != null:
		_session.interaction_index.register(interactable)
	_selected_actor_id = sibling_id
	_session.save_coordinator.mark_region_dirty(_session.current_region_id)
	EventBus.notice_requested.emit(
		"Debug sibling created through ActorFactory: %s" % String(sibling_id)
	)


func _travel_to_region(target_region_id: StringName) -> void:
	if _session == null or target_region_id == _session.current_region_id:
		return
	if target_region_id == &"base:dungeon":
		_session.dungeon_progression_service.travel_to_depth(1)
		return
	var source := ResourceRegistry.get_region(
		RegionIdUtil.normalize(_session.current_region_id)
	)
	var target := ResourceRegistry.get_region(RegionIdUtil.normalize(target_region_id))
	if source == null or target == null:
		return
	var spawn_id := target.default_spawn_id
	if target_region_id == &"base:town" and _session.current_region_id == &"base:farmland":
		spawn_id = &"from_farmland"
	elif target_region_id == &"base:farmland" and _session.current_region_id == &"base:town":
		spawn_id = &"from_town"
	if source.connected_region_ids.has(target.id) and target.connected_region_ids.has(source.id):
		_session.travel_via_road(target.id, spawn_id)
	elif source.portal_region_ids.has(target.id):
		_session.travel_via_portal(target.id, spawn_id)
	else:
		EventBus.notice_requested.emit(
			"No authored direct route from %s to %s." % [source.display_name, target.display_name]
		)


func _pulse_action(action: StringName) -> void:
	if _action_busy:
		return
	_action_busy = true
	_parse_action(action, true)
	await get_tree().process_frame
	_parse_action(action, false)
	_action_busy = false


func _hold_action(action: StringName, physics_frames: int) -> void:
	if _action_busy:
		return
	_action_busy = true
	_parse_action(action, true)
	for _frame in maxi(1, physics_frames):
		await get_tree().physics_frame
	_parse_action(action, false)
	_action_busy = false


func _parse_action(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)


func _apply_pointer_assist() -> void:
	if _pointer_assist_applied or _session == null or _session.player == null:
		return
	var rig := _session.player.get_camera_controller()
	if rig != null:
		rig.mouse_capture_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_pointer_assist_applied = true


func _inventory_summary(inventory: InventoryComponent) -> String:
	if inventory == null:
		return "-"
	var parts: Array[String] = []
	for index in inventory.slot_count:
		var stack := inventory.get_slot(index)
		if stack == null or stack.is_empty():
			continue
		parts.append("%s x%d" % [String(stack.item_id), stack.quantity])
		if parts.size() >= 5:
			break
	return "-" if parts.is_empty() else ", ".join(parts)


func _worksite_distance_text(npc: NPCController, contract: EmploymentContract) -> String:
	if npc == null or contract == null or _session == null:
		return "-"
	var worksite := ResourceRegistry.get_worksite(contract.worksite_id)
	var root := _session.region_service.get_current_region_root()
	var marker := root.find_child(String(worksite.work_marker_id), true, false) as Node3D \
		if root != null and worksite != null else null
	return "%.2f m" % npc.global_position.distance_to(marker.global_position) \
		if marker != null else "-"


func _work_result_summary(result: Dictionary) -> String:
	if result.is_empty():
		return "-"
	return "units %.2f · quality %.2f · wage %d · energy %.1f · tool %s · seq %d" % [
		float(result.get("work_units", 0.0)),
		float(result.get("quality_score", 0.0)),
		int(result.get("wage", 0)),
		float(result.get("energy_spent", 0.0)),
		str(result.get("tool_id", "-")),
		int(result.get("transaction_sequence", 0)),
	]


func _last_wallet_transaction(wallet: WalletComponent) -> String:
	if wallet == null:
		return "-"
	var transactions := wallet.get_recent_transactions()
	if transactions.is_empty():
		return "-"
	var transaction: Dictionary = transactions.back()
	return "%s %d · delta %+d · seq %d" % [
		str(transaction.get("reason", "unspecified")),
		int(transaction.get("amount", 0)),
		int(transaction.get("delta", 0)),
		int(transaction.get("transaction_sequence", 0)),
	]
