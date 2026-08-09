class_name SyntheticEnemy
extends EnemyBase

var _immune_notice_cooldown: float = 0.0

func _init() -> void:
	kind = &"SYNTHETIC"
	max_integrity = 185.0
	integrity = max_integrity
	speed = 2.5
	attack_damage = 18.0
	tint = Color(0.17, 0.19, 0.21)
	scale_factor = 1.35
	spreads_corruption = false

func _physics_process(delta: float) -> void:
	_immune_notice_cooldown = maxf(0.0, _immune_notice_cooldown - delta)
	super._physics_process(delta)

func can_take_damage(damage_type: StringName) -> bool:
	if damage_type in [&"kinetic", &"explosive"]:
		return true
	if _immune_notice_cooldown <= 0.0:
		_immune_notice_cooldown = 1.0
		EventBus.message_posted.emit("NO SPIRIT TO PURIFY // USE KINETIC [5, 8, 11, 12]", &"danger")
	return false
