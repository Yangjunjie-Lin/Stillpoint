class_name FarmsteadBuilder
extends Node3D
## Deterministically creates persistent plots without duplicating scene markup.

@export_range(1, 8, 1) var rows: int = 3
@export_range(1, 8, 1) var columns: int = 4
@export var spacing: Vector2 = Vector2(1.9, 1.9)
@export var crop_id: StringName = &"turnip"
@export var region_id: StringName = &"base:farmland"


func _ready() -> void:
	if get_child_count() > 0:
		return
	for row in rows:
		for column in columns:
			var plot := FarmPlot.new()
			plot.name = "FarmPlot_%02d_%02d" % [row, column]
			plot.crop_id = crop_id
			plot.region_id = region_id
			plot.position = Vector3(
				(float(column) - float(columns - 1) * 0.5) * spacing.x,
				0,
				(float(row) - float(rows - 1) * 0.5) * spacing.y,
			)
			var identity := WorldEntityIdentity.new()
			identity.name = "WorldEntityIdentity"
			identity.persistent_id = StringName(
				"base:farmland/farm_plot/%02d_%02d" % [row, column]
			)
			identity.definition_id = StringName("farm_plot:%s" % String(crop_id))
			identity.region_id = region_id
			identity.persistence_policy = WorldEntityIdentity.PersistencePolicy.REGION
			plot.identity = identity
			plot.add_child(identity)
			add_child(plot)
