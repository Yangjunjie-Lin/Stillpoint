class_name PlayerProfessionCondition
extends WorldCondition

@export var profession_id: StringName = &""


func evaluate(context: WorldSessionContext) -> bool:
	return (
		context != null
		and context.player != null
		and profession_id != &""
		and context.player.profession_id == profession_id
	)
