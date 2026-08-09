class_name BreakIdolObjective
extends MissionObjective

func _init() -> void:
	objective_id = &"BREAK_IDOL"
	label = "BREAK THE FABRICATED IDOL WITH KINETIC FORCE"

func is_complete(context: Dictionary) -> bool:
	return int(context.get("synthetics_defeated", 0)) > 0
