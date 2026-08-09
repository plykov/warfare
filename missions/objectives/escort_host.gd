class_name EscortHostObjective
extends MissionObjective

func _init() -> void:
	objective_id = &"ESCORT_HOST"
	label = "RECEIVE THE HOST THROUGH PRAYER"

func is_complete(context: Dictionary) -> bool:
	return bool(context.get("host_arrived", false))
