class_name HotbarBar
extends PanelContainer
## Always-visible eight-slot hotbar backed by the first inventory row.

@onready var slots_container: HBoxContainer = %Slots

var _world: WorldSession
var _player: PlayerController3D
var _buttons: Array[InventorySlotButton] = []


func _ready() -> void:
	_build_slots()
	call_deferred("_bind_world")


func _bind_world() -> void:
	_world = _find_world()
	if _world == null or _world.player == null:
		call_deferred("_bind_world")
		return
	_player = _world.player
	if _player.inventory != null and not _player.inventory.inventory_changed.is_connected(_refresh):
		_player.inventory.inventory_changed.connect(_refresh)
	if not _player.hotbar.selection_changed.is_connected(_on_selection_changed):
		_player.hotbar.selection_changed.connect(_on_selection_changed)
	_refresh()


func _build_slots() -> void:
	for child in slots_container.get_children():
		child.queue_free()
	_buttons.clear()
	for index in HotbarController.SLOT_COUNT:
		var button := InventorySlotButton.new()
		button.custom_minimum_size = Vector2(82.0, 72.0)
		button.focus_mode = Control.FOCUS_NONE
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 34)
		button.configure(self, &"hotbar", index)
		button.pressed.connect(_on_slot_pressed.bind(index))
		button.gui_input.connect(_on_slot_gui_input.bind(index))
		slots_container.add_child(button)
		_buttons.append(button)


func _refresh() -> void:
	if _player == null or _player.inventory == null:
		return
	for hotbar_index in _buttons.size():
		var button := _buttons[hotbar_index]
		var inventory_index := _inventory_index_for(hotbar_index)
		var stack := _player.inventory.get_slot(inventory_index)
		var selected := hotbar_index == _player.hotbar.selected_index
		_apply_slot_style(button, selected)
		button.icon = null
		if stack == null or stack.is_empty():
			button.set_compact_visual(str(hotbar_index + 1), null, 0, "—")
			button.tooltip_text = "Hotbar %d · Empty" % (hotbar_index + 1)
			continue
		var definition := ResourceRegistry.get_item(stack.item_id)
		var name := definition.display_name if definition != null else String(stack.item_id)
		button.set_compact_visual(
			str(hotbar_index + 1),
			definition.icon if definition != null else null,
			stack.quantity,
			_short_name(name),
		)
		button.tooltip_text = _item_tooltip(definition, name, stack.quantity)


func _on_selection_changed(_index: int) -> void:
	_refresh()


func _on_slot_pressed(index: int) -> void:
	if _player == null:
		return
	_player.hotbar.select_index(index)


func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed:
		return
	if mouse.button_index == MOUSE_BUTTON_RIGHT or (
		mouse.button_index == MOUSE_BUTTON_LEFT and mouse.double_click
	):
		if _player != null:
			_player.hotbar.select_index(index)
			if _player.has_method("use_selected_hotbar_item"):
				_player.call("use_selected_hotbar_item")
		accept_event()


func get_slot_drag_data(button: InventorySlotButton) -> Dictionary:
	if _player == null or _player.inventory == null:
		return {}
	var inventory_index := _inventory_index_for(button.slot_index)
	var stack := _player.inventory.get_slot(inventory_index)
	if stack == null or stack.is_empty():
		return {}
	return {
		"source_kind": "inventory",
		"inventory_index": inventory_index,
	}


func can_drop_slot_data(button: InventorySlotButton, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or button.slot_kind != &"hotbar":
		return false
	var source: Dictionary = data
	return str(source.get("source_kind", "")) == "inventory" \
		and int(source.get("inventory_index", -1)) >= 0


func drop_slot_data(button: InventorySlotButton, data: Variant) -> void:
	if not can_drop_slot_data(button, data) or _player == null or _player.inventory == null:
		return
	var source: Dictionary = data
	var from_index := int(source.get("inventory_index", -1))
	var to_index := _inventory_index_for(button.slot_index)
	if _player.inventory.has_method("move_or_merge"):
		_player.inventory.call("move_or_merge", from_index, to_index)
	elif _player.inventory.has_method("merge_or_swap"):
		_player.inventory.call("merge_or_swap", from_index, to_index)
	elif _player.inventory.has_method("swap_slots"):
		_player.inventory.call("swap_slots", from_index, to_index)
	_refresh()


func _inventory_index_for(hotbar_index: int) -> int:
	if _player == null or hotbar_index < 0 or hotbar_index >= _player.hotbar.slot_refs.size():
		return hotbar_index
	return _player.hotbar.slot_refs[hotbar_index]


func _apply_slot_style(button: Button, selected: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("f0d49a") if selected else Color("cda765")
	normal.border_color = Color("fff0b0") if selected else Color("72502a")
	normal.set_border_width_all(4 if selected else 2)
	normal.set_corner_radius_all(7)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("f3dcaa")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", Color("302111"))
	button.add_theme_color_override("font_hover_color", Color("302111"))
	button.add_theme_font_size_override("font_size", 13)


func _item_tooltip(definition: ItemDefinition, fallback_name: String, quantity: int) -> String:
	if definition == null:
		return "%s ×%d" % [fallback_name, quantity]
	var detail := definition.description.strip_edges()
	return "%s ×%d%s" % [
		definition.display_name,
		quantity,
		"\n%s" % detail if not detail.is_empty() else "",
	]


func _short_name(value: String) -> String:
	var cleaned := value.strip_edges()
	if cleaned.length() <= 10:
		return cleaned
	return "%s…" % cleaned.left(9)


func _find_world() -> WorldSession:
	var node := get_parent()
	while node != null:
		if node is WorldSession:
			return node as WorldSession
		node = node.get_parent()
	return null
