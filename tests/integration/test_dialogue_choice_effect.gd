extends RefCounted


func run() -> bool:
	var dialogue := ResourceRegistry.get_dialogue(&"mira_intro")
	if dialogue == null:
		return false
	var node := dialogue.get_node(&"start")
	return node != null and not node.choices.is_empty()
