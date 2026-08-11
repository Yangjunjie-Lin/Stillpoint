class_name PlayerLevelCondition
extends WorldCondition

@export_range(1, 99, 1) var minimum_level: int = 1

func evaluate(context: WorldSessionContext) -> bool:
	return (
		context != null
		and context.player != null
		and context.player.experience != null
		and context.player.experience.level >= minimum_level
	)
