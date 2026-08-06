extends CanvasLayer
## World architecture debug panel (disabled in release by default).

@onready var label: Label = $Panel/Label

var _session: WorldSession


func _ready() -> void:
	visible = OS.is_debug_build()
	_session = _find_session()


func _process(_delta: float) -> void:
	if not visible or _session == null or label == null:
		return
	var lines: PackedStringArray = []
	lines.append("Current Region: %s" % String(_session.current_region_id))
	lines.append("Loaded Entities: %d" % _session.entity_repository.get_loaded_count())
	lines.append("Snapshots: %d" % _session.entity_repository.get_snapshot_count())
	lines.append("Interactables: %d" % _session.interaction_index.get_registered_count())
	var tracked := QuestManager.get_tracked_quest()
	lines.append("Tracked Quest: %s" % (String(tracked.quest_id) if tracked else "-"))
	lines.append("Active Quests: %d" % QuestManager.get_active_quests().size())
	lines.append("Last Save: %s" % _session.save_coordinator.get_last_save_result())
	label.text = "\n".join(lines)


func _find_session() -> WorldSession:
	var node := get_parent()
	if node is WorldSession:
		return node as WorldSession
	return null
