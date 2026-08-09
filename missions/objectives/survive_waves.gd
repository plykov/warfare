class_name SurviveWavesObjective
extends MissionObjective

var duration: float

func _init(required_seconds: float = 45.0) -> void:
	objective_id = &"SURVIVE_WAVES"
	duration = required_seconds
	label = "HOLD THE ANCHOR FOR %d SECONDS" % roundi(required_seconds)

func is_complete(context: Dictionary) -> bool:
	return float(context.get("elapsed", 0.0)) >= duration
