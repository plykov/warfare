class_name MissionResource
extends Resource

@export var mission_id: StringName
@export var chapter: int = 1
@export var title: String
@export_multiline var briefing: String
@export var scripture_reference: String
@export var objective_ids: PackedStringArray = PackedStringArray(["PURIFY_ZONE"])
@export var target_purity: float = 0.72
@export var fail_corruption: float = 0.93
@export var time_limit: float = 0.0
@export var survive_seconds: float = 0.0
@export var restore_integrity: float = 72.0
@export var starting_thin_integrity: float = 100.0
@export var starting_demons: int = 7
@export var enemy_budget: int = 18
@export var spawn_interval: float = 3.2
@export var fallen_trigger: float = 0.36
@export var synthetic_trigger: float = 0.50
@export var corruption_bias: float = 0.0
@export var enemy_power: float = 1.0
@export var garden_color: Color = Color(0.035, 0.23, 0.075)
@export var fog_color: Color = Color(0.08, 0.1, 0.11)
@export var accent_color: Color = Color(1.0, 0.65, 0.18)

func display_title() -> String:
	return "COMMISSION %02d // %s" % [chapter, title.to_upper()]
