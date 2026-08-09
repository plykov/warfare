class_name WeaponResource
extends Resource

@export var weapon_id: StringName
@export var display_name: String
@export_multiline var source_note: String
@export var role: String
@export var damage_type: StringName = &"purify"
@export var damage: float = 20.0
@export var range: float = 20.0
@export var radius: float = 2.0
@export var cooldown: float = 0.4
@export var glory_cost: float = 0.0
@export var requires_commission: bool = false
@export var tint: Color = Color(1.0, 0.72, 0.22)
