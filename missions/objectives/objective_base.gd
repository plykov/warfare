class_name MissionObjective
extends RefCounted

var objective_id: StringName
var label: String

func is_complete(_context: Dictionary) -> bool:
	return false
