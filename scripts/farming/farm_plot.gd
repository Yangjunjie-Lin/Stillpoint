class_name FarmPlot
extends Interactable
## One persistent soil tile with an authored crop and a day-based growth cycle.

enum PlotState {
	UNTILLED,
	TILLED,
	PLANTED,
	READY,
}

@export var crop_id: StringName = &"turnip"
@export var identity: WorldEntityIdentity
@export_range(0.0, 20.0, 0.5) var till_energy_cost: float = 4.0
@export_range(0.0, 20.0, 0.5) var water_energy_cost: float = 2.0

var plot_state: PlotState = PlotState.UNTILLED
var planted_day: int = 0
var last_processed_day: int = 0
var growth_stage: int = 0
var watered_days: Dictionary = {}

var _session: WorldSession
var _soil_visual: MeshInstance3D
var _plant_root: Node3D


func _ready() -> void:
	interaction_priority = 20
	_session = _find_session()
	if identity == null:
		identity = get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
	if not WorldTimeService.day_changed.is_connected(_on_day_changed):
		WorldTimeService.day_changed.connect(_on_day_changed)
	_ensure_visuals()
	_refresh_growth(WorldTimeService.day)
	_update_visuals()


func can_interact(actor: CharacterController, context: InteractionContext) -> bool:
	return actor is PlayerController3D and super.can_interact(actor, context)


func get_interaction_text(actor: CharacterController) -> String:
	var player := actor as PlayerController3D
	var selected := _selected_item_id(player)
	var crop := _crop()
	match plot_state:
		PlotState.UNTILLED:
			return "Till soil" if _selected_tool_supports(player, &"till_soil") \
				else "Select a soil-working tool to till"
		PlotState.TILLED:
			return (
				"Plant %s" % crop.display_name
				if crop != null and selected == crop.seed_item_id
				else "Select crop seeds"
			)
		PlotState.PLANTED:
			if _is_watered_today():
				return "%s watered today" % (crop.display_name if crop != null else "Crop")
			return "Water crop" if selected == &"watering_can" else "Select Watering Can"
		PlotState.READY:
			return "Harvest %s" % (crop.display_name if crop != null else "crop")
	return "Inspect field"


func interact(actor: CharacterController, _context: InteractionContext) -> void:
	var player := actor as PlayerController3D
	if player == null or player.inventory == null:
		return
	_refresh_growth(WorldTimeService.day)
	var changed := false
	match plot_state:
		PlotState.UNTILLED:
			changed = _till(player)
		PlotState.TILLED:
			changed = _plant(player)
		PlotState.PLANTED:
			changed = _water(player)
		PlotState.READY:
			changed = _harvest(player)
	if changed:
		_update_visuals()
		_mark_dirty()


func get_state_summary() -> Dictionary:
	return {
		"state": plot_state,
		"crop_id": String(crop_id),
		"growth_stage": growth_stage,
		"watered_today": _is_watered_today(),
		"ready": plot_state == PlotState.READY,
	}


func get_persistence_key() -> StringName:
	return &"farm_plot"


func capture_state() -> Dictionary:
	return {
		"plot_state": plot_state,
		"crop_id": String(crop_id),
		"planted_day": planted_day,
		"last_processed_day": last_processed_day,
		"growth_stage": growth_stage,
		"watered_days": watered_days.duplicate(true),
	}


func restore_state(data: Dictionary) -> void:
	plot_state = clampi(
		int(data.get("plot_state", PlotState.UNTILLED)),
		PlotState.UNTILLED,
		PlotState.READY,
	) as PlotState
	crop_id = StringName(str(data.get("crop_id", crop_id)))
	planted_day = maxi(0, int(data.get("planted_day", 0)))
	last_processed_day = maxi(0, int(data.get("last_processed_day", planted_day)))
	growth_stage = maxi(0, int(data.get("growth_stage", 0)))
	var raw_watered: Variant = data.get("watered_days", {})
	watered_days = raw_watered.duplicate(true) if raw_watered is Dictionary else {}
	_refresh_growth(WorldTimeService.day)
	_update_visuals()


func get_state_version() -> int:
	return 1


func _till(player: PlayerController3D) -> bool:
	if not _selected_tool_supports(player, &"till_soil"):
		EventBus.notice_requested.emit("Select a tool that can till soil, then interact.")
		return false
	if player.energy != null and not player.energy.spend(till_energy_cost):
		EventBus.notice_requested.emit("Not enough energy to till this soil.")
		return false
	plot_state = PlotState.TILLED
	last_processed_day = WorldTimeService.day
	EventBus.notice_requested.emit("The soil is ready for seeds.")
	return true


func _plant(player: PlayerController3D) -> bool:
	var crop := _crop()
	if crop == null or not crop.is_valid():
		EventBus.notice_requested.emit("This field has no valid crop definition.")
		return false
	if _selected_item_id(player) != crop.seed_item_id:
		var seed_definition := ResourceRegistry.get_item(crop.seed_item_id)
		var seed_name := seed_definition.display_name if seed_definition != null else "the required seeds"
		EventBus.notice_requested.emit("Select %s first." % seed_name)
		return false
	var slot := player.hotbar.get_inventory_slot_index()
	if player.inventory.remove_from_slot(slot, 1) != 1:
		return false
	plot_state = PlotState.PLANTED
	planted_day = WorldTimeService.day
	last_processed_day = planted_day
	growth_stage = 0
	watered_days.clear()
	EventBus.notice_requested.emit("%s planted. Water it once per growing day." % crop.display_name)
	return true


func _water(player: PlayerController3D) -> bool:
	if _is_watered_today():
		EventBus.notice_requested.emit("This crop is already watered today.")
		return false
	if _selected_item_id(player) != &"watering_can":
		EventBus.notice_requested.emit("Select the Watering Can first.")
		return false
	if player.energy != null and not player.energy.spend(water_energy_cost):
		EventBus.notice_requested.emit("Not enough energy to water this crop.")
		return false
	watered_days[str(WorldTimeService.day)] = true
	EventBus.notice_requested.emit("Crop watered for Day %d." % WorldTimeService.day)
	return true


func _harvest(player: PlayerController3D) -> bool:
	var crop := _crop()
	if crop == null or not player.inventory.can_add_item(crop.produce_item_id, crop.harvest_quantity):
		EventBus.notice_requested.emit("Backpack is full.")
		return false
	if player.inventory.add_item(crop.produce_item_id, crop.harvest_quantity) != crop.harvest_quantity:
		return false
	plot_state = PlotState.TILLED
	planted_day = 0
	last_processed_day = WorldTimeService.day
	growth_stage = 0
	watered_days.clear()
	EventBus.notice_requested.emit("Harvested %d %s." % [crop.harvest_quantity, crop.display_name])
	return true


func _on_day_changed(new_day: int) -> void:
	if _refresh_growth(new_day):
		_update_visuals()
		_mark_dirty()


func _refresh_growth(current_day: int) -> bool:
	if plot_state != PlotState.PLANTED:
		return false
	var crop := _crop()
	if crop == null:
		return false
	var changed := false
	var first_day := maxi(last_processed_day + 1, planted_day + 1)
	for processed_day in range(first_day, current_day + 1):
		if bool(watered_days.get(str(processed_day - 1), false)):
			growth_stage += 1
			changed = true
		last_processed_day = processed_day
	if growth_stage >= crop.watered_days_to_mature:
		plot_state = PlotState.READY
		changed = true
	return changed


func _selected_item_id(player: PlayerController3D) -> StringName:
	if player == null or player.inventory == null:
		return &""
	var stack := player.inventory.get_slot(player.hotbar.get_inventory_slot_index())
	return stack.item_id if stack != null and not stack.is_empty() else &""


func _selected_tool_supports(player: PlayerController3D, action_id: StringName) -> bool:
	if player == null:
		return false
	var definition := player.get_selected_item_definition()
	return definition != null and definition.supports_utility_action(action_id)


func _is_watered_today() -> bool:
	return bool(watered_days.get(str(WorldTimeService.day), false))


func _crop() -> CropDefinition:
	return ResourceRegistry.get_crop(crop_id)


func _mark_dirty() -> void:
	if _session == null:
		_session = _find_session()
	if _session == null:
		return
	if identity != null:
		_session.entity_repository.mark_dirty(identity.persistent_id)
	_session.save_coordinator.mark_region_dirty(region_id)


func _find_session() -> WorldSession:
	var node := get_parent()
	while node != null:
		if node is WorldSession:
			return node as WorldSession
		node = node.get_parent()
	return null


func _ensure_visuals() -> void:
	_soil_visual = get_node_or_null("SoilVisual") as MeshInstance3D
	if _soil_visual == null:
		_soil_visual = MeshInstance3D.new()
		_soil_visual.name = "SoilVisual"
		var soil_mesh := BoxMesh.new()
		soil_mesh.size = Vector3(1.55, 0.12, 1.55)
		_soil_visual.mesh = soil_mesh
		_soil_visual.position = Vector3(0, 0.12, 0)
		add_child(_soil_visual)
	_plant_root = get_node_or_null("PlantVisual") as Node3D
	if _plant_root == null:
		_plant_root = Node3D.new()
		_plant_root.name = "PlantVisual"
		add_child(_plant_root)


func _update_visuals() -> void:
	if _soil_visual == null or _plant_root == null:
		_ensure_visuals()
	for child in _plant_root.get_children():
		child.free()
	var soil_color := Color("667a45") if plot_state == PlotState.UNTILLED else Color("795337")
	if plot_state == PlotState.PLANTED and _is_watered_today():
		soil_color = Color("4c352b")
	_set_material(_soil_visual, soil_color)
	if plot_state not in [PlotState.PLANTED, PlotState.READY]:
		return
	var crop := _crop()
	if crop == null:
		return
	var maturity := 1.0 if plot_state == PlotState.READY else clampf(float(growth_stage + 1) / float(crop.watered_days_to_mature + 1), 0.28, 0.8)
	for index in 5:
		var angle := TAU * float(index) / 5.0
		var offset := Vector3(cos(angle) * 0.28, 0, sin(angle) * 0.28)
		_add_cylinder(_plant_root, "Stem%d" % index, 0.025, 0.3 + maturity * 0.42, offset + Vector3.UP * (0.28 + maturity * 0.2), crop.mature_leaf_color)
		_add_sphere(_plant_root, "Leaf%d" % index, 0.13 + maturity * 0.08, offset + Vector3(0, 0.5 + maturity * 0.2, 0), crop.sprout_color, Vector3(1.35, 0.5, 0.85))
	if plot_state == PlotState.READY:
		_add_sphere(_plant_root, "Produce", 0.3, Vector3(0, 0.34, 0), crop.produce_color, Vector3(0.9, 1.0, 0.9))


func _add_cylinder(parent: Node3D, name_: String, radius: float, height: float, position_: Vector3, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	var part := MeshInstance3D.new()
	part.name = name_
	part.mesh = mesh
	part.position = position_
	parent.add_child(part)
	_set_material(part, color)


func _add_sphere(parent: Node3D, name_: String, radius: float, position_: Vector3, color: Color, scale_: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var part := MeshInstance3D.new()
	part.name = name_
	part.mesh = mesh
	part.position = position_
	part.scale = scale_
	parent.add_child(part)
	_set_material(part, color)


func _set_material(part: MeshInstance3D, color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	part.material_override = material
