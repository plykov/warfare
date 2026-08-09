class_name RestoreThinPlaceObjective
extends MissionObjective

var target_integrity: float

func _init(required_integrity: float = 72.0) -> void:
	objective_id = &"RESTORE_THIN_PLACE"
	label = "RESTORE THE THIN PLACE TO %d%%" % roundi(required_integrity)
	target_integrity = required_integrity

func is_complete(context: Dictionary) -> bool:
	return StringName(context.get("thin_state", &"SEVERED")) == &"ACTIVE" and float(context.get("thin_integrity", 0.0)) >= target_integrity
