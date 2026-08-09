class_name DemonEnemy
extends EnemyBase

func _init() -> void:
	kind = &"DEMON"
	max_integrity = 55.0
	integrity = max_integrity
	speed = 4.2
	attack_damage = 7.0
	tint = Color(0.34, 0.015, 0.025)
