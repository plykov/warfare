class_name BindTargetObjective
extends MissionObjective

func _init() -> void:
	objective_id = &"BIND_TARGET"
	label = "REBUKE AND BIND A FALLEN"

func is_complete(context: Dictionary) -> bool:
	return bool(context.get("bound_target", false))
