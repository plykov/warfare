class_name PurifyZoneObjective
extends MissionObjective

var target: float

func _init(required_purity: float = 0.72) -> void:
	objective_id = &"PURIFY_ZONE"
	label = "RECLAIM %d%% OF THE GARDEN" % roundi(required_purity * 100.0)
	target = required_purity

func is_complete(context: Dictionary) -> bool:
	return float(context.get("purity", 0.0)) >= target
