extends RefCounted


func run() -> bool:
	QuestManager.start_quest(&"demo_errand")
	QuestManager.advance_objective(&"demo_errand", &"collect_herb", 1)
	var runtime := QuestManager.get_runtime(&"demo_errand")
	return runtime != null and runtime.state == QuestDefinition.QuestState.ACTIVE
