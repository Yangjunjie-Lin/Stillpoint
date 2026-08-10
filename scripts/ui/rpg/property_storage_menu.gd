class_name PropertyStorageMenu
extends Control
## Modal inventory transfer and property-management surface for home and bank.

@onready var title_label: Label = %Title
@onready var account_label: Label = %AccountSummary
@onready var property_label: Label = %PropertySummary
@onready var storage_label: Label = %StorageHeading
@onready var backpack_list: ItemList = %BackpackList
@onready var storage_list: ItemList = %StorageList
@onready var status_label: Label = %Status
@onready var money_controls: Control = %MoneyControls
@onready var property_controls: Control = %PropertyControls
@onready var plans_container: VBoxContainer = %PlansContainer
@onready var buyback_button: Button = %BuybackButton

var _world: WorldSession
var _player: PlayerController3D
var _service: PropertyBankService
var _mode: StringName = PropertyBankService.BANK_STORAGE_MODE
var _tree_was_paused := false
var _player_input_was_enabled := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	call_deferred("_bind_world")


func _exit_tree() -> void:
	if visible and get_tree() != null:
		get_tree().paused = _tree_was_paused


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"pause"):
		close_menu()
		get_viewport().set_input_as_handled()


func open_menu(mode: StringName = PropertyBankService.BANK_STORAGE_MODE) -> void:
	_bind_world()
	if visible or _player == null or _service == null:
		return
	if mode == PropertyBankService.HOME_STORAGE_MODE and not _service.has_active_house():
		EventBus.notice_requested.emit("Your former residence is in bank custody.")
		return
	_mode = mode
	_tree_was_paused = get_tree().paused
	_player_input_was_enabled = _player.state.input_enabled
	_player.set_input_enabled(false)
	get_tree().paused = true
	visible = true
	status_label.text = ""
	_refresh()


func close_menu() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _tree_was_paused
	if _player != null:
		_player.set_input_enabled(_player_input_was_enabled)


func is_open() -> bool:
	return visible


func _bind_world() -> void:
	_world = _find_world()
	if _world == null or _world.player == null:
		return
	_player = _world.player
	_service = _world.property_bank_service
	if _player.inventory != null and not _player.inventory.inventory_changed.is_connected(_refresh):
		_player.inventory.inventory_changed.connect(_refresh)
	if _service != null and not _service.property_state_changed.is_connected(_refresh):
		_service.property_state_changed.connect(_refresh)


func _refresh() -> void:
	if not visible or _service == null or _player == null:
		return
	var at_home := _mode == PropertyBankService.HOME_STORAGE_MODE
	title_label.text = "Private Home Storage" if at_home else "Stillpoint Bank & Property Office"
	storage_label.text = "HOME STORE" if at_home else "PRIVATE BANK VAULT"
	account_label.text = "Wallet: %d coin    Bank: %d coin    Total: %d" % [
		_service.wallet_balance,
		_service.bank_balance,
		_service.get_total_funds(),
	]
	property_label.text = _service.get_status_summary()
	money_controls.visible = not at_home
	property_controls.visible = not at_home
	_populate_list(backpack_list, _player.inventory)
	_populate_list(storage_list, _service.get_storage(_mode))
	if not at_home:
		_rebuild_plan_buttons()


func _populate_list(list: ItemList, inventory: InventoryComponent) -> void:
	list.clear()
	if inventory == null:
		return
	for slot_index in inventory.slot_count:
		var stack := inventory.get_slot(slot_index)
		if stack == null or stack.is_empty():
			continue
		var definition := ResourceRegistry.get_item(stack.item_id)
		var display_name := definition.display_name if definition != null else String(stack.item_id)
		var row := list.add_item("[%02d] %s ×%d" % [slot_index + 1, display_name, stack.quantity])
		list.set_item_metadata(row, slot_index)


func _rebuild_plan_buttons() -> void:
	for child in plans_container.get_children():
		child.free()
	buyback_button.visible = not _service.has_active_house() and _service.repossessed_house_id != &""
	buyback_button.text = "Buy back previous home — %d coin" % _service.get_buyback_price()
	buyback_button.disabled = _service.get_total_funds() < _service.get_buyback_price()
	if _service.has_active_house():
		var owned := Label.new()
		owned.text = "Your deed is active. Store household goods at home or in this vault."
		owned.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		plans_container.add_child(owned)
		return
	for plan in ResourceRegistry.get_player_housing_plans():
		var button := Button.new()
		button.text = "Construct %s — %d coin (%d slots)" % [
			plan.display_name, plan.construction_cost, plan.private_storage_slots,
		]
		button.disabled = _service.get_total_funds() < plan.construction_cost
		button.pressed.connect(_on_construct_pressed.bind(plan.id))
		plans_container.add_child(button)


func _on_store_one_pressed() -> void:
	_transfer_from_backpack(1)


func _on_store_stack_pressed() -> void:
	_transfer_from_backpack(-1)


func _on_withdraw_one_pressed() -> void:
	_transfer_from_storage(1)


func _on_withdraw_stack_pressed() -> void:
	_transfer_from_storage(-1)


func _transfer_from_backpack(amount: int) -> void:
	var slot := _selected_slot(backpack_list)
	var moved := _service.store_from_player(_player.inventory, _mode, slot, amount) if slot >= 0 else 0
	status_label.text = "Stored %d item(s)." % moved if moved > 0 else "Select an item; the destination may be full."
	_refresh()


func _transfer_from_storage(amount: int) -> void:
	var slot := _selected_slot(storage_list)
	var moved := _service.withdraw_to_player(_player.inventory, _mode, slot, amount) if slot >= 0 else 0
	status_label.text = "Withdrew %d item(s)." % moved if moved > 0 else "Select an item; your backpack may be full."
	_refresh()


func _on_deposit_100_pressed() -> void:
	var moved := _service.deposit(100)
	status_label.text = "Deposited %d coin." % moved
	_refresh()


func _on_deposit_all_pressed() -> void:
	var moved := _service.deposit(_service.wallet_balance)
	status_label.text = "Deposited %d coin." % moved
	_refresh()


func _on_withdraw_100_pressed() -> void:
	var moved := _service.withdraw(100)
	status_label.text = "Withdrew %d coin." % moved
	_refresh()


func _on_withdraw_all_pressed() -> void:
	var moved := _service.withdraw(_service.bank_balance)
	status_label.text = "Withdrew %d coin." % moved
	_refresh()


func _on_buyback_pressed() -> void:
	var succeeded := _service.buy_back_repossessed_house()
	status_label.text = "Previous home deed restored." if succeeded else "Insufficient funds for buyback."
	_refresh()


func _on_construct_pressed(plan_id: StringName) -> void:
	var succeeded := _service.construct_house(plan_id)
	var plan := ResourceRegistry.get_house(plan_id)
	status_label.text = "Construction authorized for %s." % plan.display_name if succeeded and plan != null else "Construction could not be authorized."
	_refresh()


func _selected_slot(list: ItemList) -> int:
	var selected := list.get_selected_items()
	if selected.is_empty():
		return -1
	var metadata: Variant = list.get_item_metadata(selected[0])
	return int(metadata) if typeof(metadata) in [TYPE_INT, TYPE_FLOAT] else -1


func _find_world() -> WorldSession:
	var node := get_parent()
	while node != null:
		if node is WorldSession:
			return node as WorldSession
		node = node.get_parent()
	return get_tree().get_first_node_in_group("world_manager") as WorldSession
